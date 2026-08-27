#!/usr/bin/env python3
"""Convert OpenCode slash commands to pi prompt templates.

Transformations:
1. ~/.config/opencode/{bin,docs} -> ~/.pi/agent/workflow/{support,docs}
2. `git -C ~/.pi/agent/workflow describe` kept (repo is versioned by git)
3. @agent-name references -> `subagent` tool call phrasing
4. workflow-orchestrator prompt prepended as the orchestration layer
   (in pi the main session IS the orchestrator when running these templates)
5. frontmatter -> pi prompt-template frontmatter (description + argument-hint)
"""
import re
from pathlib import Path

SRC = Path("/tmp/opencode-audit")
DST = Path.home() / "ai/pi-workflow/prompts"
DST.mkdir(parents=True, exist_ok=True)

COMMANDS = {
    "milestone-planning": (
        "Create milestone plan/spec/instructions plus review markdowns from a roadmap milestone",
        "<milestone-ref>",
    ),
    "milestone-implementation": (
        "Implement a planned milestone phase-by-phase with subagents and phase review",
        "<milestone-ref>",
    ),
    "milestone-pr-review": (
        "Review a milestone PR with reviewer subagents and pushback handling",
        "<milestone-ref-or-pr>",
    ),
}

MENTION_MAP = {
    "milestone-planner": 'the subagent "milestone-planner"',
    "milestone-plan-reviewer": 'the subagent "milestone-plan-reviewer"',
    "implementation": 'the subagent "implementation"',
    "senior-implementer": 'the subagent "senior-implementer"',
    "phase-reviewer": 'the subagent "phase-reviewer"',
    "glm-milestone-reviewer": 'the subagent "glm-milestone-reviewer"',
    "gpt-milestone-reviewer": 'the subagent "gpt-milestone-reviewer"',
    "workflow-orchestrator": "this orchestration session",
}


def convert_text(text: str) -> str:
    # validator invocation: bare python3 is blocked in pi (incl. subagents),
    # so route through the pwf shim BEFORE path rewrites
    text = text.replace(
        "python3 ~/.config/opencode/bin/validate_milestone_docs.py",
        "pwf ~/.pi/agent/workflow/support/validate_milestone_docs.py",
    )
    text = text.replace(
        "python3 ~/.pi/agent/workflow/support/validate_milestone_docs.py",
        "pwf ~/.pi/agent/workflow/support/validate_milestone_docs.py",
    )
    # path rewrites
    text = text.replace("~/.config/opencode/bin/", "~/.pi/agent/workflow/support/")
    text = text.replace("~/.config/opencode/docs/", "~/.pi/agent/workflow/docs/")
    text = text.replace("git -C ~/.config/opencode describe", "git -C ~/.pi/agent/workflow describe")
    # @agent mentions
    for name, repl in sorted(MENTION_MAP.items(), key=lambda kv: -len(kv[0])):
        text = re.sub(rf"@{re.escape(name)}\b", repl, text)
    # remove backticks that wrapped the original @mentions
    text = re.sub(r"`(the subagent [^`]+)`", r"\1", text)
    text = text.replace("`this orchestration session`", "this orchestration session")
    # /slash refs to sibling commands stay as-is (pi has the same templates)
    return text


def main():
    orch_body = (Path.home() / "ai/pi-workflow/agents/workflow-orchestrator.md").read_text()
    # strip orchestrator frontmatter
    if orch_body.startswith("---\n"):
        end = orch_body.find("\n---", 4)
        orch_body = orch_body[end + 4 :].lstrip("\n")

    for name, (desc, hint) in COMMANDS.items():
        raw = (SRC / f"commands-{name}.md").read_text()
        if raw.startswith("---\n"):
            end = raw.find("\n---", 4)
            body = raw[end + 4 :].lstrip("\n")
        else:
            body = raw
        body = convert_text(body)

        preamble = (
            "## Orchestration layer (authoritative)\n\n"
            + orch_body.strip()
            + "\n\n## Active workflow\n\n"
            "Subagent dispatch in this workflow: every reference to a subagent (e.g. the subagent "
            "\"milestone-planner\") means a call to the subagent tool with that agent name and a "
            "self-contained task prompt (objective, source materials, current state, exact scope, "
            "constraints, expected output, completion requirements). The subagent tool returns "
            "the subagent's final text, usage stats, and tool-call trace. Accept a subagent's "
            "completion only per the sentinel and mechanical gates below; retry/replace/stop per policy.\n\n"
            "---\n\n"
        )
        out = (
            "---\n"
            f"description: {desc}\n"
            f'argument-hint: "{hint}"\n'
            "---\n\n"
            + preamble
            + body
            + "\n"
        )
        (DST / f"{name}.md").write_text(out)
        print(f"wrote {DST / (name + '.md')} ({len(out)} bytes)")


if __name__ == "__main__":
    main()
