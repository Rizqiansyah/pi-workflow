# Milestone Planning Format Guide (Central)

Guide version: this guide is versioned by the pi workflow repository; resolve the current version with `git -C ~/.pi/agent/workflow describe --tags --always`. Do not hardcode a version here.

Purpose: canonical, project-neutral schema and template set for turning
roadmap milestones into implementation-ready planning documents. This is the
authoritative copy, centralized in the OpenCode configuration; repository
copies of a format guide are pointer stubs. Project-specific instantiations
(named fixtures, scales, tolerances, numbering precedents, decision records)
live in each repository's `PLANNING_FORMAT_ADDENDUM.md` — see Project
Addendum Discovery below. An addendum may tighten or instantiate this guide;
it may never weaken it.

## Output Contract

The strict structural musts. Agents told to "re-read the Output Contract"
read this section; the full detail follows in the reference body below.

1. One milestone produces exactly three planning documents plus one review
   file each:
   `<PREFIX>_IMPLEMENTATION_PLAN.md`, `<PREFIX>_SPEC_SHEETS.md`,
   `<PREFIX>_AGENT_INSTRUCTIONS.md`, and the corresponding `*_REVIEW.md`
   files, all in the resolved output directory.
2. Every artifact carries, near its date line: `Workflow-Version:
   <WORKFLOW_VERSION>` (resolved from the OpenCode config repository).
3. ID grammar: `Mi-Pj-Tk` — i = milestone number, j = phase number, k = task
   number. Phases are `<MILESTONE_ID>-Pj`; tasks are `<MILESTONE_ID>-Pj-Tk`.
   Decimal milestone IDs (e.g. `M8.1`) are valid milestone numbers; a
   phase-shaped ID must never be used where a task ID is required.
4. New non-integer milestone IDs require a written numbering justification in
   the roadmap (see Universal Planning Rule 20); the plan reviewer rejects
   plans that mint one without it.
5. Task commit messages start with the task ID:
   `<MILESTONE_ID>-Pj-Tk <lowercase imperative subject>`.
6. Every parity gate names its reference artifact, system scale, and
   tolerance source; every benchmark gate names its system scale and baseline
   record (Gate Integrity Rules 1 and 3; the addendum defines the project's
   real-scale default and named artifacts).
7. Review files contain: reviewed path(s), a verdict line (`APPROVED` or
   `CHANGES REQUIRED`), findings ordered by severity, exact required fixes,
   and an `Addressed By Planner` section once fixes are applied.
8. Residual file structure: `# Residuals for Milestone N` /
   `## Residuals from Milestone X` / bullets; plus at most one
   addendum-declared non-milestone backlog header, entries citing the
   accepting scope decision.
9. The same milestone ID, title, branch name, and file prefix appear in all
   three documents; the branch name follows the Branch Name Rules (decimal
   IDs drop the dot).
10. No unresolved placeholders (`<MILESTONE_ID>`, `<BRANCH_NAME>`, ...) may
    remain in generated project files.
11. Blocked work is marked `BLOCKED` with the missing prerequisite named —
    never silently skipped, reinterpreted, or substituted.
12. Planning artifacts are committed as they are produced (commit-as-you-go):
    the planner stages exactly the files its task names and commits with the
    exact message the orchestrator supplies; no planning artifact is left
    uncommitted between workflow steps.

## Project Addendum Discovery

The per-project addendum is `PLANNING_FORMAT_ADDENDUM.md`, discovered in the
roadmap's directory first, then by repository search. Wherever this guide
says "the project addendum defines X", agents must read and obey the
addendum. If no addendum exists, proceed under this guide alone and record
the absence in the planning artifacts and the orchestrator's final response —
a reviewable warning, not a blocker. Typical addendum contents: the project
numeric/tolerance policy pointer, real-scale defaults and named reference
artifacts for gates, milestone numbering precedents, a declared backlog
residual header, decision-record requirements, project test commands and
tiers, and governance specifics.

## Core Contract

Each milestone produces three documents:

1. Implementation plan: what to build, why, scope boundaries, phases, gates, deliverables.
2. Spec sheet: concrete interfaces, schemas, file layouts, commands, acceptance criteria.
3. Agent instructions: small delegated implementation tasks with exact files, tests, commits, and review gates.

Each produced document also has one review markdown file:

1. Implementation plan review.
2. Spec sheet review.
3. Agent instruction review.

The three documents must be internally consistent. The agent instruction file must be executable by an implementation orchestration agent without guessing.

## Placeholder Vocabulary

Use these placeholders in reusable templates. The planning orchestration workflow should resolve them automatically from the appended milestone and repository state; users should not have to fill them manually.

| Placeholder | Meaning |
|---|---|
| `<PROJECT_NAME>` | Project or repository name |
| `<ROADMAP_PATH>` | Roadmap containing target milestone |
| `<DOC_OUTPUT_DIR>` | Directory for generated planning docs |
| `<MILESTONE_ID>` | Short milestone ID, for example `M1` or `M8.1` |
| `<MILESTONE_NUMBER>` | Numeric milestone value if available |
| `<MILESTONE_TITLE>` | Human-readable milestone title |
| `<MILESTONE_ID_AND_TITLE>` | ID plus title |
| `<MILESTONE_FILE_PREFIX>` | Shared generated file prefix |
| `<BRANCH_NAME>` | Branch planned for implementation |
| `<ADDENDUM_PATH>` | Resolved project addendum path, or `absent` |
| `<WORKFLOW_VERSION>` | OpenCode config version (git describe) governing this artifact |
| `<TEST_COMMAND>` | Concrete test command |
| `<COMPLETION_TOKEN>` | Required implementation-agent completion token |
| `<PLANNER_AGENT>` | Milestone planning subagent, default `@milestone-planner` |
| `<PLAN_REVIEWER_AGENT>` | Milestone planning review subagent, default `@milestone-plan-reviewer` |
| `<PLANNER_SENTINEL>` | Planner completion token, default `[MILESTONE PLAN COMPLETE]` |
| `<PLAN_REVIEW_SENTINEL>` | Plan reviewer completion token, default `[MILESTONE PLAN REVIEW COMPLETE]` |

Recommended default completion token: `[TASK COMPLETED]`.

Planning workflow defaults:

1. Planner agent: `@milestone-planner`.
2. Plan reviewer agent: `@milestone-plan-reviewer`.
3. Planner sentinel: `[MILESTONE PLAN COMPLETE]`.
4. Plan reviewer sentinel: `[MILESTONE PLAN REVIEW COMPLETE]`.

## Universal Planning Rules

1. One milestone per document set.
2. Preserve roadmap goal, scope, requirements, phases, tasks, and gates.
3. Convert roadmap prose into concrete implementation work without broadening scope.
4. Prefer explicit blockers over guessed behavior.
5. Make tasks small enough for weaker implementation agents.
6. Specify exact files, exact commands, exact commit messages, and exact acceptance gates.
7. Treat example documents as style references only.
8. Do not invent fixtures, APIs, validation claims, benchmark thresholds, external dependencies, or migration behavior. Verify that a required reference artifact can actually be produced by the reference implementation before writing a gate that demands it.
9. Make acceptance evidence concrete: tests, generated artifacts, docs, benchmark records, or review signoff.
10. Capture project-specific governance rules (from the project addendum) in each generated agent instruction file.
11. Planning orchestration must not draft, repair, or review milestone artifacts itself.
12. Planning orchestration must delegate document writing/editing to `@milestone-planner` and file-based document review to `@milestone-plan-reviewer`.
13. Planning orchestration must require sentinel tokens from planning subagents and retry missing gates instead of taking over.
14. Anything that should become a planning document must be written to disk by `@milestone-planner`; the orchestrator must not accept document content only in chat.
15. Reviews must read the target document files from disk and write comments/findings to review markdown files; reviewers must not rewrite the planning documents.
16. Planner fixes must read the review markdown file, edit the target planning document on disk, and update the review markdown file with an `Addressed By Planner` section.
17. Milestones must be broken into phases, and phases must be broken into individually delegated tasks with individual commits.
18. Phase IDs must use `<MILESTONE_ID>-Pj`, for example `M0-P1` for milestone 0 phase 1, `M8.1-P2` for milestone 8.1 phase 2.
19. Task IDs must use `<MILESTONE_ID>-Pj-Tk`, for example `M0-P1-T2`, `M8.1-P2-T1`.
20. Milestone numbering convention: milestone numbers are integers in execution order. Non-integer milestone IDs (e.g. `M8.1`) are permitted in exactly two cases, and sparingly: (a) an addendum to an already-completed milestone — work that surfaced after milestone i was done, belongs with it, and fits no future milestone's scope; (b) an in-stage insertion for new work that cannot merge cleanly into any existing milestone's scope and whose stage grouping would be broken by deferring it to an appended integer milestone. Preference order: merge into an existing milestone > non-integer insertion in the correct stage > appended end-of-roadmap integer (acceptable only if implementation ordering is preserved). Any NEW non-integer milestone requires a written numbering justification in the roadmap. The project addendum lists the project's precedent decimal IDs. Do not use a phase-shaped ID (`Mi-Pj` with no `-Tk`) where a task ID is required.
21. Do not use phase IDs like `M1-P1` as task IDs unless the workflow explicitly treats the entire phase as one task; prefer `M1-P1-T1` even for a one-task phase.
22. Task commit messages must start with the task ID, for example `M1-P3-T2 add tire matrix parity`.
23. Phase review gates remain phase-level and reference phase IDs such as `M1-P3`, not task IDs.
24. All blockers/findings for the target milestone must be resolved regardless of severity.
25. Genuine future-milestone residuals must be assigned to a specific future milestone — or to the addendum-declared backlog target for owner-accepted deferred scope — and recorded in `*_MILESTONE_RESIDUAL_BLOCKERS.md` using the Residual Blocker File Rules.
26. Planning for a milestone must read the residual blocker file when present and address residual blockers filed under the target milestone header.

## Gate Integrity Rules

These rules exist because gates degrade silently: real-scale parity gates
have historically been satisfied with toy-scale tests plus in-code
"transitivity" comments, and CPU-pinned tests have stood in for hardware
claims. They bind planners, implementers, and reviewers. The project addendum
may cite the project's incident history.

1. Parity gates must name the reference artifact and the system scale. Write
   "matches `<named fixture>` (`<system scale per the project addendum>`) at
   tolerances from `<the project tolerance source>`", never "matches
   references" or "where references exist". A gate without a named fixture
   and scale is not reviewable and must be rejected by the plan reviewer.
   The named fixture must exist or be producible by the documented
   reference/golden-generation path (see Universal Planning Rule 8).
2. No silent gate substitution. If an implementation agent finds a gate
   impractical, the task is BLOCKED: stop, record a residual with the
   evidence, and obtain an orchestrator/reviewer decision. An in-code comment
   reinterpreting or weakening a gate (transitivity arguments, reduced scale,
   alternate references) never satisfies the gate. Reviewers must check test
   parameters against the gate's named scale, not just test names and pass
   status.
3. Benchmark gates must specify system scale and follow the benchmark scale
   rules in the project numeric policy (named in the addendum). Solver timing
   recorded on toy systems does not satisfy a benchmark gate.
4. Device discipline: a gate that claims GPU (or other hardware) behavior
   must be evidenced by tests executing on that hardware, or the claim must
   be explicitly re-scoped in the plan. Pinning tests to CPU to avoid device
   numerics requires a numeric-policy entry (tolerance tier), not a comment.
   Skipped hardware tests are not evidence.
5. Tolerance integrity: tolerance relaxations must follow the project numeric
   policy's tolerance-integrity rules (measured cause, bounded relaxation,
   retained detection power). Relaxing a tolerance to make a failing gate
   pass is grounds for review rejection.
6. Residual hygiene: a milestone that resolves a residual must update the
   residual blocker file in the same PR. Planners and reviewers must verify
   residual entries against the current code, not trust the file; a stale
   residual entry found during planning must be corrected before the plan is
   approved.
7. Test budget: prefer shared fixtures and parametrization over per-quantity
   copy-paste tests (e.g., one solve asserted for displacement, velocity, and
   acceleration — not three tests each re-running the solve). Plans must keep
   the milestone gate command practically runnable; if the suite cannot be
   run in full at milestone exit, the exit evidence must state exactly which
   subsets ran.

## Planning Subagent Gate Rules

These rules apply to the planning workflow that creates the three document set.

Planner gate:

1. Use subagent type `@milestone-planner`.
2. Accept completion only when requested document file is written or edited on disk (analysis-only tasks request no file; their deliverable is the analysis in chat).
3. Accept completion only when final response includes `[MILESTONE PLAN COMPLETE]`.
4. For review-fix tasks, accept completion only when the review markdown file includes an `Addressed By Planner` section.
5. If disk write/edit, resolution section, or sentinel is missing, retry same subagent session.
6. Accept completion only when the mechanical validator passes on the written artifact(s): `--partial` mode while the three-document set is incomplete; full mode once the agent-instruction file exists.
7. When the task instructed a commit, accept completion only when that commit exists with the exact message and touches only the allowed files (planning artifacts are committed as they are produced by the planner — commit-as-you-go).

Reviewer gate:

1. Use subagent type `@milestone-plan-reviewer`.
2. Accept completion only when reviewer confirms it read target file(s) from disk and writes the requested review markdown file with findings plus verdict.
3. Accept completion only when final response includes `[MILESTONE PLAN REVIEW COMPLETE]`.
4. If disk-read confirmation, review markdown file, findings, verdict, or sentinel are missing, retry same subagent session.

Retry rule:

0. Unclear-scope tokens (`[UNCLEAR MILESTONE]`, `[UNCLEAR REVIEW SCOPE]`, `[UNCLEAR SCOPE]`) are not failures: answer the questions from already-resolved source documents in one re-delegation if possible, otherwise stop and report the questions to the user verbatim. Never answer from guesswork; never retry blindly demanding the sentinel.
1. Retry same subagent session at most 3 times for same task/review.
2. After 3 failed retries, start a new subagent of the same type with original request and current file state.
3. If replacement subagent also fails, stop and report failure.
4. The planning orchestration agent must never create missing documents, repair documents, or review documents itself.

## Document Naming Schema

Use one prefix for all files in a milestone set:

```text
<DOC_OUTPUT_DIR>/<MILESTONE_FILE_PREFIX>_IMPLEMENTATION_PLAN.md
<DOC_OUTPUT_DIR>/<MILESTONE_FILE_PREFIX>_SPEC_SHEETS.md
<DOC_OUTPUT_DIR>/<MILESTONE_FILE_PREFIX>_AGENT_INSTRUCTIONS.md
<DOC_OUTPUT_DIR>/<MILESTONE_FILE_PREFIX>_IMPLEMENTATION_PLAN_REVIEW.md
<DOC_OUTPUT_DIR>/<MILESTONE_FILE_PREFIX>_SPEC_SHEETS_REVIEW.md
<DOC_OUTPUT_DIR>/<MILESTONE_FILE_PREFIX>_AGENT_INSTRUCTIONS_REVIEW.md
```

Recommended prefixes:

1. `MILESTONE_<MILESTONE_NUMBER>` (decimal IDs use underscores: `MILESTONE_10_2`)
2. `<MILESTONE_ID>`
3. `<STAGE_ID>_<MILESTONE_ID>`

## Implementation Plan Template

Use this structure exactly unless a section is truly not applicable. If not applicable, write `Not applicable` and explain why.

````markdown
# <MILESTONE_ID> Implementation Plan

Date: <YYYY-MM-DD>

Workflow-Version: <WORKFLOW_VERSION>

Branch: `<BRANCH_NAME>`

Goal: <one paragraph copied or tightly derived from roadmap>

<Milestone boundary paragraph: what this milestone covers and explicitly does not cover.>

## Scope

In scope:

1. <item>
2. <item>

Out of scope:

1. <item>
2. <item>

## Source Inputs

Primary docs:

1. `<ROADMAP_PATH>`
2. `<supporting doc path>`
3. `<residual blocker file path or Not applicable>`
4. `<ADDENDUM_PATH>`

Relevant existing code or artifacts:

1. `<path or Not applicable>`

Prerequisite milestone outputs:

1. `<prior milestone gate or artifact>`

## Deliverables

1. `<path or artifact>`
2. `<path or artifact>`

## Dependencies And Entry Criteria

1. <prior gate that must be complete>
2. <required fixture/data/API/hardware/tooling>

## <MILESTONE_ID>-P1 <Phase Title>

### Goal

<phase goal>

### Tasks

1. `<MILESTONE_ID>-P1-T1` <specific action>
2. `<MILESTONE_ID>-P1-T2` <specific action>

### Gate

1. <measurable acceptance condition naming reference artifact, scale, and tolerance source where applicable>
2. <test or review evidence>

### Blockers

1. <none or BLOCKED: missing prerequisite>

## <MILESTONE_ID>-P2 <Phase Title>

<repeat phase shape>

## Test And Verification Plan

1. `<TEST_COMMAND>` proves <scope>.
2. `<TEST_COMMAND>` proves <scope>.

## Commit Plan

1. `<MILESTONE_ID>-P1-T1 <commit subject>`
2. `<MILESTONE_ID>-P1-T2 <commit subject>`
3. `<MILESTONE_ID>-P2-T1 <commit subject>`

## Milestone Exit Checklist

1. <all phase gates pass>
2. <deliverables exist>
3. <tests pass or blockers accepted>
4. <no forbidden scope included>
````

### Implementation Plan Requirements

1. Scope must include both in-scope and out-of-scope lists.
2. Source inputs must name the roadmap, the project addendum (or `absent`), and relevant supporting evidence.
3. Deliverables must use paths or artifact names where possible.
4. Dependencies must be explicit and testable.
5. Each phase must have tasks and gates.
6. Gates must be measurable, not aspirational, and follow the Gate Integrity Rules.
7. Blocked items must name missing prerequisite and planned evidence.
8. Exit checklist must be pass/fail.
9. Each phase heading must use phase ID `<MILESTONE_ID>-Pj`.
10. Each task under a phase must use task ID `<MILESTONE_ID>-Pj-Tk`.
11. Each task commit message must start with its task ID.
12. The document must carry the `Workflow-Version:` line.

## Spec Sheet Template

Use spec sheets to define contracts that implementation agents should follow.

````markdown
# <MILESTONE_ID> Spec Sheets

Date: <YYYY-MM-DD>

Workflow-Version: <WORKFLOW_VERSION>

Branch: `<BRANCH_NAME>`

Purpose: define concrete interfaces, artifacts, schemas, commands, and acceptance criteria for <MILESTONE_ID_AND_TITLE>.

## Spec <MILESTONE_NUMBER>.1: Paths And Ownership

Implementation paths:

```text
<path>
<path>
```

Test paths:

```text
<path>
<path>
```

Ownership rules:

1. <allowed module or package boundary>
2. <forbidden path or public/private boundary>

Acceptance:

1. <path exists or remains untouched>

## Spec <MILESTONE_NUMBER>.2: Data Models Or Interfaces

```python
<interface sketch, dataclass, function signature, CLI contract, or Not applicable>
```

Requirements:

1. <shape/type/unit/error behavior>
2. <validation behavior>

Acceptance:

1. <test or review evidence>

## Spec <MILESTONE_NUMBER>.3: Runtime Or Workflow Behavior

Requirements:

1. <runtime behavior>
2. <edge case>
3. <failure behavior>

Acceptance:

1. <test or evidence>

## Spec <MILESTONE_NUMBER>.4: Artifact Or Output Schema

```json
{
  "schema_version": "<schema>",
  "required_field": "<value>"
}
```

Storage rules:

1. <format>
2. <metadata>
3. <size or reproducibility constraints>

Acceptance:

1. <schema validation evidence>

## Spec <MILESTONE_NUMBER>.5: Numeric, Performance, Or Quality Policy

Requirements:

1. <tolerance, benchmark field, quality threshold per the project numeric policy, or Not applicable>

Acceptance:

1. <test, benchmark record, review evidence>

## Spec <MILESTONE_NUMBER>.6: Commands

Required commands:

```bash
<TEST_COMMAND>
```

Acceptance:

1. <command pass condition>

## Spec <MILESTONE_NUMBER>.7: Final Acceptance Matrix

| Requirement | Evidence |
|---|---|
| <requirement> | <test/doc/artifact/review> |
````

### Spec Sheet Requirements

1. Every named interface in task instructions must appear in spec or plan.
2. Every artifact must have path, format, ownership, and acceptance rules.
3. Every numeric comparison must state tolerance or policy source.
4. Every performance claim must state benchmark fields and baseline.
5. Every optional dependency or hardware path must state skip/blocker behavior.
6. Every public/private boundary must be explicit.
7. Acceptance matrix must map every material requirement to evidence.
8. The document must carry the `Workflow-Version:` line.

## Agent Instruction Template

The agent instruction file is the execution contract for the implementation orchestration agent.

````markdown
# <MILESTONE_ID> Agent Instructions

Workflow-Version: <WORKFLOW_VERSION>

Use this file as the task source for an implementation orchestration agent.

The orchestration agent must follow the `/milestone-implementation` workflow and delegate tasks to implementation agents. Do not hand this whole file to one implementation agent.

## How To Start

```text
/milestone-implementation <MILESTONE_ID>
```

## How To Delegate Each Task

For every task below, the orchestration agent must create a prompt to an implementation agent with these fields:

1. Task ID and title.
2. Exact task scope.
3. Allowed files.
4. Forbidden files.
5. Exact test commands.
6. Exact commit message.
7. Required final token `<COMPLETION_TOKEN>`.

The implementation agent must not receive the whole milestone as one task.

Task ID format:

1. Phase IDs use `<MILESTONE_ID>-Pj`, for example `M1-P3`.
2. Task IDs use `<MILESTONE_ID>-Pj-Tk`, for example `M1-P3-T2`.
3. Every delegated task below must have a task ID.
4. Commit messages for task commits must start with the task ID.

## Phase Review Gates

Run a review gate after each phase before starting the next phase.

Phase review checkpoints:

1. After `<MILESTONE_ID>-P1 <Phase Title>` tasks are committed and phase tests are run.
2. After `<MILESTONE_ID>-P2 <Phase Title>` tasks are committed and phase tests are run.

For each phase review, supply:

1. Phase ID and title.
2. Relevant section from this file.
3. Relevant implementation plan and spec sections.
4. Commits included in phase.
5. Changed files.
6. Test commands and results.
7. Known blockers or future-scope residuals.

If review reports deficiencies, delegate fixes, rerun relevant tests, and review again. Repeat up to 3 times. If deficiencies remain after 3 loops, the `/milestone-implementation` phase-review recovery procedure (root-cause analysis) applies — follow that command's recovery section; do not stop silently and do not loop further without it.

## Mission

Implement `<MILESTONE_ID_AND_TITLE>` only on branch `<BRANCH_NAME>`.

Read first:

1. `<ROADMAP_PATH>`
2. `<DOC_OUTPUT_DIR>/<MILESTONE_FILE_PREFIX>_IMPLEMENTATION_PLAN.md`
3. `<DOC_OUTPUT_DIR>/<MILESTONE_FILE_PREFIX>_SPEC_SHEETS.md`
4. `<supporting docs>`
5. `<ADDENDUM_PATH>`

## Rules

1. <project command rule from the addendum, for example use package manager X>
2. <forbidden path rule>
3. <public/private API rule>
4. <commit/review rule>
5. <blocked-task rule>

## Commit Message Format

Use these commit messages exactly:

```text
<MILESTONE_ID>-P1-T1 <commit subject>
<MILESTONE_ID>-P1-T2 <commit subject>
<MILESTONE_ID>-P2-T1 <commit subject>
```

## Before First Commit

Run:

```bash
git status --short --branch
<environment check command>
```

Confirm branch is `<BRANCH_NAME>`.

## Phase <MILESTONE_ID>-P1: <Phase Title>

### Task <MILESTONE_ID>-P1-T1: <Task Title>

Create or modify:

```text
<path>
<path>
```

Implement:

1. <specific requirement>
2. <specific requirement>

Tests:

1. <test requirement>
2. <test requirement>

Allowed files:

1. `<path>`

Forbidden files:

1. `<path or pattern>`

Run:

```bash
<TEST_COMMAND>
```

Commit:

```bash
git add <paths>
git commit -m "<MILESTONE_ID>-P1-T1 <commit subject>"
```

## Final Verification

Run all:

```bash
<TEST_COMMAND>
git status --short
```

Check manually:

1. <forbidden paths unchanged>
2. <deliverables exist>
3. <review gates passed>

Final response should include:

1. Commit list.
2. Test commands and pass/fail status.
3. Blocked items, if any.
4. Known future-scope residuals, if any.
````

### Agent Instruction Requirements

1. Must tell the implementation orchestration agent to start with `/milestone-implementation <MILESTONE_ID>`.
2. Must require one delegated task at a time unless a task set is explicitly tiny and tightly coupled.
3. Must include allowed and forbidden files for every delegated task.
4. Must include exact test commands for every task.
5. Must include exact commit message for every task.
6. Must include phase review gates.
7. Must include final verification commands.
8. Must include blocker behavior.
9. Must not require implementation agents to infer scope from roadmap alone.
10. Must use phase IDs `<MILESTONE_ID>-Pj` and task IDs `<MILESTONE_ID>-Pj-Tk` consistently (decimal milestone IDs valid per rule 20).
11. Must not use phase-shaped IDs where task IDs are required (rule 20).
12. Must carry the `Workflow-Version:` line.

## Review Markdown Template

Each review file should use this structure. The reviewer writes `Review Findings`; the planner later adds or updates `Addressed By Planner` when fixing comments.

````markdown
# <MILESTONE_ID> <Artifact Name> Review

Date: <YYYY-MM-DD>

Reviewed artifact:

`<path>`

Reviewer: `@milestone-plan-reviewer`

## Verdict

`APPROVED` or `CHANGES REQUIRED`

## Review Findings

1. Severity: `<critical | high | medium | low>`
   Location: `<section or line if available>`
   Finding: `<issue>`
   Required fix: `<exact fix>`

## Open Questions

1. `<question or none>`

## Addressed By Planner

Planner: `@milestone-planner`

1. Finding: `<finding summary>`
   Resolution: `<what changed or why no change>`
   Changed paths: `<path>`

## Final Review Notes

1. `<notes from subsequent review loop or none>`
````

Review file rules:

1. One review file per planning output file.
2. Reviewer must not paste the full planning document into the review file.
3. Reviewer must include a verdict.
4. Planner must update `Addressed By Planner` when fixing comments.
5. Orchestrator passes review file paths between subagents instead of pasting review content.

## Branch Name Rules

Branch creation ownership belongs to the planning workflow. Implementation and PR review workflows must verify branch state, but must not create or switch milestone branches.

Before planning documents are written, the planning orchestration agent must:

1. Check current branch with `git status --short --branch`.
2. Check local branches with `git branch --list`.
3. Derive the target milestone branch name.
4. Continue if already on the target milestone branch.
5. Stop and ask before switching if already on a different milestone branch.
6. Stop and ask before switching or creating a branch if the current worktree has uncommitted changes.
7. Switch to the existing target milestone branch if it exists and the worktree is clean.
8. Create and switch to the target milestone branch if it does not exist and the worktree is clean.
9. Require the same resolved branch name in all generated planning docs.

Branch names should be concise and milestone-specific:

```text
<milestone-id-lowercase>-<short-slug>
```

Examples:

```text
m1-core-data-model
m2-runtime-engine
m3-public-api
```

Non-integer milestone IDs drop the dot in branch names (e.g. M8.1 becomes `m81-...`, M10.2 becomes `m102-...`).

The same branch name must appear in all three documents.

## Residual Blocker File Rules

The project residual blocker file is a central living markdown file named `*_MILESTONE_RESIDUAL_BLOCKERS.md`.

Use this structure exactly:

```markdown
# Residuals for Milestone N

## Residuals from Milestone X

- <residual blocker>
```

Rules:

1. The target milestone header is the milestone that should address the residual.
2. The source milestone subheader is where the residual was discovered.
3. Current target-milestone blockers/findings must be resolved, not recorded as residuals.
4. Only genuinely future-scope residuals may be recorded.
5. Preserve existing content and avoid duplicate exact bullets.
6. One non-milestone target header is permitted when the project addendum declares it (e.g. `# Residuals for Post-Final-Stage Backlog`), for owner-accepted deferrals that map to a roadmap backlog section rather than a numbered milestone. Entries there must cite the accepting scope decision.

## Commit Message Rules

Commit messages should start with task ID:

```text
<MILESTONE_ID>-P<J>-T<K> <lowercase imperative subject>
```

Examples:

```text
M1-P1-T1 add core data model
M1-P1-T2 add schema validation
M8.1-P3-T1 add rough road goldens
```

Cross-cutting commits (planning artifacts, review-fix and validator-fix
revisions, phase-review fixes spanning tasks) use:

```text
<MILESTONE_ID> <lowercase imperative subject>
```

Examples: `M10.2 add implementation plan`, `M10.2 revise spec sheets per
review`, `M10.2 fix contact mask off-by-one`.

## Test Command Rules

1. Use the project-approved runner (named in the project addendum).
2. Prefer focused commands per task.
3. Include phase-level commands after the final task in each phase.
4. Include milestone-level final verification.
5. If optional backend, service, or hardware is unavailable, specify skip or blocker behavior.
6. Do not allow agents to claim tests pass without command and result.

## Review Gate Rules

Agent instructions must require review after each phase.

Review context must include:

1. Phase ID and title.
2. Relevant agent instruction section.
3. Relevant implementation plan section.
4. Relevant spec sheet section.
5. Commit hashes.
6. Changed files.
7. Test commands and results.
8. Blockers or future-scope residuals.

If review finds deficiencies:

1. Delegate fixes narrowly.
2. Rerun relevant tests.
3. Review again.
4. Repeat up to 3 loops.
5. If unresolved after 3 loops: stop — unless the active workflow defines a recovery procedure (for example, the implementation workflow's root-cause-analysis recovery); then follow that procedure exactly, and stop when it says to stop.
6. Do not allow unresolved target-milestone findings of any severity to pass a review gate.
7. Future-scope residuals pass only when assigned to a specific future milestone (or the addendum-declared backlog target) and recorded in the residual blocker file.

## Cross-Document Consistency Checklist

Before accepting a generated planning set, check:

1. Same milestone ID, title, branch, and file prefix in all files.
2. Same phase list and order in plan and agent instructions.
3. Same deliverables in plan and spec.
4. Same function/class/file/artifact names in spec and task instructions.
5. Same gates in roadmap, plan, spec acceptance, and task tests.
6. Same forbidden paths in rules and task guidance.
7. Same final verification commands in agent instructions and plan exit checklist.
8. No task exists without plan/spec support.
9. No spec covers work outside milestone scope.
10. Phase IDs use `<MILESTONE_ID>-Pj` consistently (decimal milestone IDs valid per rule 20).
11. Task IDs use `<MILESTONE_ID>-Pj-Tk` consistently across plan/spec/agent instructions.
12. No phase-shaped IDs remain where task IDs are required (rule 20).
13. Task commit messages start with the corresponding task ID.
14. Residual blockers assigned to the target milestone are addressed.
15. Genuine future residuals are recorded in `*_MILESTONE_RESIDUAL_BLOCKERS.md`.
16. No roadmap requirement disappeared.
17. No placeholder remains accidentally unfilled in generated project-specific files.
18. Every parity gate names its reference artifact and system scale (Gate Integrity rule 1), using the project addendum's definitions.
19. Every benchmark gate names its system scale and baseline record (Gate Integrity rule 3).
20. Hardware-scoped gates run on the named hardware or are explicitly re-scoped in the plan (Gate Integrity rule 4).
21. Any NEW non-integer milestone ID carries a written numbering justification in the roadmap: either (a) addendum to a named, already-completed milestone, or (b) in-stage insertion with an explicit statement of why the work cannot merge into any existing milestone's scope (rule 20). The plan reviewer must REJECT a planning set that introduces a non-integer milestone without this justification, or where the justification's merge-impossibility claim does not hold on inspection.
22. All three planning documents carry the `Workflow-Version:` line.

## Milestone Pattern Rules

Use these when relevant. Delete or mark `Not applicable` when not relevant.

### Data Model Milestones

Require:

1. Model/schema contract.
2. Validation behavior.
3. Serialization or conversion behavior if applicable.
4. Tests for valid and invalid inputs.

### Runtime Or Solver Milestones

Require:

1. Input/output contracts.
2. Deterministic ordering rules.
3. Edge-case behavior.
4. Baseline or reference comparison.
5. Error and failure behavior.

### Backend Or Vectorization Milestones

Require:

1. Static shape or batching contract where applicable.
2. Padding and masking rules.
3. Ordering guarantees.
4. Backend availability behavior.
5. Parity against reference path.

### Optimization Milestones

Require:

1. Baseline remains available.
2. Correctness tests against baseline.
3. Benchmark schema and records per the project numeric policy.
4. Decision notes for rejected optimizations, recorded where the project addendum requires (e.g. an optimization decision record).
5. Accuracy policy for approximations.

### Public API Milestones

Require:

1. Public/private boundary.
2. Import/export contract.
3. Backward compatibility policy.
4. User-facing errors.
5. Examples or smoke tests.
6. External review if project governance requires it.

### Documentation Or Release Milestones

Require:

1. Docs paths and ownership.
2. Build or lint commands.
3. Example execution commands.
4. Release checklist.
5. Validation and future-scope residual summary.

## Anti-Patterns

Avoid:

1. Broad tasks like "implement the system".
2. Gates like "works correctly".
3. Specs that only repeat roadmap prose.
4. Agent instructions without allowed/forbidden files.
5. Commit messages without task IDs.
6. Silent skipped tasks.
7. Unreviewed implementation plans.
8. Example-driven drift from canonical templates.
9. Invented thresholds, claims, or reference artifacts the reference implementation cannot produce.
10. Public API changes hidden inside internal milestones.
11. Minting a non-integer milestone ID without the rule-20 numbering justification (merge into an existing milestone is always the first preference).

## Final Quality Bar

An implementation orchestration agent should be able to run:

```text
/milestone-implementation <MILESTONE_ID>
```

Then execute the milestone without inferring:

1. What files may change.
2. What each task means.
3. What tests prove completion.
4. What commit message to use.
5. When to run review.
6. What is blocked or out of scope.
