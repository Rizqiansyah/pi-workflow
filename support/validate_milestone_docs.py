#!/usr/bin/env python3
"""Mechanical validator for milestone planning document sets.

Usage:
    python3 validate_milestone_docs.py <doc_directory> <file_prefix>
        [--warn-only] [--partial] [--backlog-header=<header line>]...

Example:
    python3 validate_milestone_docs.py conversion-docs MILESTONE_10_1

--partial: validate only the documents that exist; a missing document is not
a FAIL. Use during planning while the three-document set is still being
written. Full mode (no --partial) requires the complete set and is used once
the agent-instruction file exists, and by /milestone-implementation.

Enforces the mechanically checkable subset of the central
MILESTONE_PLANNING_FORMAT_GUIDE.md (Output Contract). Exit code 0 when no
FAIL findings (WARNs allowed), 1 when any FAIL finding, 2 on usage error.
With --warn-only, FAIL findings are reported but the exit code is 0
(pilot/triage mode).

Checks:
  F1  document set completeness (plan/spec/instructions present)
  F2  ID grammar: phase IDs Mi-Pj, task IDs Mi-Pj-Tk (decimal milestone
      numbers valid); no bare phase ID in task-ID positions (commit plan,
      task headings); IDs belong to the target milestone
  F3  commit-plan entries start with a valid task ID of this milestone
  F4  review files (when present) contain a verdict line and findings section
  F5  residual file headers match "# Residuals for Milestone N", a declared
      backlog header (--backlog-header may be repeated; e.g.
      --backlog-header="# Residuals for Stage 3 Exit" --backlog-header=
      "# Residuals for Post-Stage-6 Backlog"), any "# Residuals for ...
      Backlog" target, or a "Stage N Exit" target
  F6  unresolved template placeholders (<MILESTONE_ID>, <BRANCH_NAME>, ...)
  F7  Workflow-Version line present in each planning document
  F8  branch name consistent across the three documents
  W1  gate lines with no backtick-quoted reference and no digit (heuristic:
      possibly unnamed reference/scale) -- always WARN, never FAIL
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

PLACEHOLDER_RE = re.compile(
    r"<(MILESTONE_ID|MILESTONE_NUMBER|MILESTONE_TITLE|MILESTONE_ID_AND_TITLE|"
    r"MILESTONE_FILE_PREFIX|BRANCH_NAME|ROADMAP_PATH|DOC_OUTPUT_DIR|"
    r"TEST_COMMAND|COMPLETION_TOKEN|WORKFLOW_VERSION|ADDENDUM_PATH)>"
)
# Milestone id like M10 or M10.2 (captured), then -P<j>, optionally -T<k>.
PHASE_RE = re.compile(r"\bM(\d+(?:\.\d+)?)-P(\d+)\b(?!-T)")
TASK_RE = re.compile(r"\bM(\d+(?:\.\d+)?)-P(\d+)-T(\d+)\b")
# Uppercase verdict token anywhere on a line (verdicts appear with prefixes
# like "Review loop 2: `APPROVED`"); uppercase requirement avoids prose hits.
VERDICT_RE = re.compile(r"`?(APPROVED|CHANGES REQUIRED)`?", )
WORKFLOW_VERSION_RE = re.compile(r"^Workflow-Version:\s*\S+", re.M)
BRANCH_RE = re.compile(r"^Branch:\s*`([^`]+)`", re.M)
RESIDUAL_HEADER_RE = re.compile(r"^# Residuals for (.+)$", re.M)
RESIDUAL_MILESTONE_RE = re.compile(r"^(?:Milestone\s+\S+|M\d+(?:\.\d+)?.*)$")
GATE_LINE_RE = re.compile(r"^\s*(?:\d+\.|\-|\|)?.*\bgate\b.*$", re.I | re.M)


def milestone_number_from_prefix(prefix: str) -> str:
    """MILESTONE_10_2 -> 10.2 ; MILESTONE_8 -> 8 ; M10_2 -> 10.2."""
    m = re.search(r"(?:MILESTONE|M)_?(\d+(?:_\d+)?)", prefix)
    if not m:
        return ""
    return m.group(1).replace("_", ".")


class Report:
    def __init__(self) -> None:
        self.fails: list[str] = []
        self.warns: list[str] = []

    def fail(self, msg: str) -> None:
        self.fails.append(msg)

    def warn(self, msg: str) -> None:
        self.warns.append(msg)


def check_doc(path: Path, mnum: str, rep: Report) -> str | None:
    """Per-document checks. Returns branch name if found."""
    text = path.read_text(encoding="utf-8", errors="replace")
    name = path.name

    for match in PLACEHOLDER_RE.finditer(text):
        rep.fail(f"{name}: unresolved placeholder {match.group(0)}")

    if not WORKFLOW_VERSION_RE.search(text):
        rep.fail(f"{name}: missing 'Workflow-Version:' line")

    # IDs must belong to the target milestone.
    for match in TASK_RE.finditer(text):
        if match.group(1) != mnum:
            rep.warn(
                f"{name}: task ID M{match.group(1)}-P{match.group(2)}-T{match.group(3)} "
                f"does not belong to milestone {mnum} (cross-reference or drift?)"
            )
    # Phase-ID-as-task-ID violations are only detectable where a task ID is
    # definitely required: `git commit -m` lines anywhere, and numbered
    # entries inside a "Commit Plan" section. Numbered lists elsewhere may
    # legitimately reference phase IDs (exit checklists, review gates).
    in_commit_plan = False
    for line in text.splitlines():
        heading = re.match(r"^#{1,6}\s+(.*)$", line)
        if heading:
            in_commit_plan = "commit plan" in heading.group(1).lower()
            continue
        requires_task_id = bool(re.search(r"git commit -m", line)) or (
            in_commit_plan and re.match(r"^\s*(?:\d+\.|\-)\s*`?M\d", line)
        )
        if requires_task_id:
            has_task = TASK_RE.search(line)
            phase_only = PHASE_RE.search(line)
            if phase_only and not has_task:
                rep.fail(
                    f"{name}: phase-shaped ID used where a task ID is required: "
                    f"{line.strip()[:100]}"
                )

    # Gate heuristic (warn-only). Strip list/table markers first so an
    # enumeration digit ("2. ...") cannot satisfy the has-a-number check.
    for line in GATE_LINE_RE.findall(text):
        stripped = line.strip()
        if len(stripped) < 12 or stripped.startswith("#"):
            continue
        body = re.sub(r"^(?:\d+\.|\-|\*|\|)\s*", "", stripped)
        if "`" not in body and not re.search(r"\d", body):
            rep.warn(f"{name}: gate line without named reference or scale? "
                     f"'{stripped[:90]}'")

    bm = BRANCH_RE.search(text)
    return bm.group(1) if bm else None


def check_review(path: Path, rep: Report) -> None:
    text = path.read_text(encoding="utf-8", errors="replace")
    if not VERDICT_RE.search(text):
        rep.fail(f"{path.name}: no verdict line (APPROVED / CHANGES REQUIRED)")
    if "Review Findings" not in text and "## Findings" not in text:
        rep.fail(f"{path.name}: no findings section")


def check_residual_file(doc_dir: Path, backlog_headers: list[str],
                        rep: Report) -> None:
    for path in sorted(doc_dir.glob("*_MILESTONE_RESIDUAL_BLOCKERS.md")) or \
            sorted(doc_dir.glob("MILESTONE_RESIDUAL_BLOCKERS.md")):
        text = path.read_text(encoding="utf-8", errors="replace")
        for match in RESIDUAL_HEADER_RE.finditer(text):
            target = match.group(1).strip()
            if RESIDUAL_MILESTONE_RE.match(target):
                continue
            if target.lower().startswith("resolved"):
                continue
            # Any --backlog-header declaration (repeatable) legitimizes the
            # exact header; the keyword fallbacks below always stay active.
            if f"# Residuals for {target}" in backlog_headers:
                continue
            lowered = target.lower()
            if "backlog" in lowered or re.search(r"stage\s+\d+\s+exit", lowered):
                continue
            rep.fail(f"{path.name}: unrecognized residual target header "
                     f"'# Residuals for {target}'")


def main(argv: list[str]) -> int:
    args = [a for a in argv[1:] if not a.startswith("--")]
    warn_only = "--warn-only" in argv
    partial = "--partial" in argv
    backlog_headers = [a.split("=", 1)[1] for a in argv[1:]
                       if a.startswith("--backlog-header=")]
    if len(args) != 2:
        print(__doc__)
        return 2

    doc_dir = Path(args[0]).expanduser()
    prefix = args[1]
    if not doc_dir.is_dir():
        print(f"FAIL: doc directory not found: {doc_dir}")
        return 2

    mnum = milestone_number_from_prefix(prefix)
    rep = Report()

    required = [f"{prefix}_IMPLEMENTATION_PLAN.md",
                f"{prefix}_SPEC_SHEETS.md",
                f"{prefix}_AGENT_INSTRUCTIONS.md"]
    branches: dict[str, str] = {}
    for fname in required:
        path = doc_dir / fname
        if not path.exists():
            if partial:
                rep.warn(f"document not yet written (partial mode): {fname}")
            else:
                rep.fail(f"missing required document: {fname}")
            continue
        branch = check_doc(path, mnum, rep)
        if branch:
            branches[fname] = branch

    if len(set(branches.values())) > 1:
        rep.fail(f"branch name differs across documents: {branches}")

    for fname in required:
        rpath = doc_dir / fname.replace(".md", "_REVIEW.md")
        if rpath.exists():
            check_review(rpath, rep)

    check_residual_file(doc_dir, backlog_headers, rep)

    for msg in rep.warns:
        print(f"WARN: {msg}")
    for msg in rep.fails:
        print(f"FAIL: {msg}")
    print(f"validate_milestone_docs: {len(rep.fails)} FAIL, "
          f"{len(rep.warns)} WARN for {prefix} in {doc_dir}")
    if rep.fails and not warn_only:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
