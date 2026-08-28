# pi-workflow

Pi (coding agent) port of the OpenCode milestone workflow from
`~/.config/opencode` on r9-7900x (repo `opencode-pixi-python-block`'s sibling:
the wf-v1.9 workflow: 8 agents, 3 slash commands, mechanical doc validator,
format guide).

Sister projects:
- OpenCode version: `~/.config/opencode` on r9-7900x (git, tags wf-v1…wf-v1.9)
- pixi python blocker for pi: https://github.com/Rizqiansyah/pi-pixi-python-block

## What this provides

| OpenCode concept | pi equivalent here |
|---|---|
| `agents/*.md` (mode: primary/subagent, model, permission) | `agents/*.md` in `~/.pi/agent/agents/` (frontmatter: name, description, model, tools, thinking) + `subagent` tool |
| slash commands (`/milestone-*`) | prompt templates in `~/.pi/agent/prompts/milestone-*.md` (invoked as `/milestone-*`) |
| `AGENTS.md` global rules | `~/.pi/agent/AGENTS.md` (same one-line pixi + long-test rule) |
| `task` tool / `@agent` mentions | `subagent` extension tool (single/parallel/chain, isolated pi subprocess) |
| `permission:` blocks | `tools:` allowlists (pi has no permission system; reviewers get no bash) |
| `variant: max` (thinking) | `thinking: xhigh` frontmatter |
| `python3 <validator>` | `pwf <validator>` — pixi shim, because pi globally blocks bare python3 |
| providers in opencode.jsonc | merged into `~/.pi/agent/models.json` (vllm-local 8105, llm-router 8082) |

## Agents

| Agent | Model | Tools | Notes |
|---|---|---|---|
| workflow-orchestrator | current default (kv520) | all | In pi the main session orchestrates; its prompt is prepended to each milestone template. Also available as a subagent. |
| milestone-planner | openai/gpt-5.6-sol | all | Writes the 3 planning docs; `[MILESTONE PLAN COMPLETE]` sentinel |
| milestone-plan-reviewer | openrouter/stealth/ox-alpha (xhigh thinking) | read,edit | Adversarial plan review; `[MILESTONE PLAN REVIEW COMPLETE]` |
| implementation | current default (kv520 local) | all | Coding agent; `[TASK COMPLETED]` sentinel |
| senior-implementer | opencode-go/deepseek-v4-pro | all | Escalation coder |
| phase-reviewer | openai/gpt-5.6-terra | read,edit | Phase review + root-cause mode |
| glm-milestone-reviewer | openrouter/stealth/ox-alpha (xhigh) | read,edit | Milestone PR review |
| gpt-milestone-reviewer | openai/gpt-5.6-sol | read,edit | Milestone PR review |

**Model notes:**
- `implementation` pins `llm-router/qwen-3.8-27b-q8` (local 8082 router), matching the OpenCode pin `3945wx-llm-router/qwen-3.8-27b-q8`.
- External-model agents need credentials: `OPENAI_API_KEY` (gpt-5.6-*), `OPENROUTER_API_KEY` (ox-alpha). Check with `pi auth check --provider openai` / `--provider openrouter`.
- `senior-implementer` pins `opencode-go/deepseek-v4-pro` — that provider does not exist in pi. It must be repointed (e.g. `deepseek/deepseek-chat` or an OpenRouter route) before that agent works; the rest of the workflow runs without it.

## Operating on the 3945wx box — use 8082, not 8105

This machine's Hermes agent itself is backed by `kv520` on port **8105** (a single-slot
vLLM server). If pi (or any subagent child) is pointed at 8105, it **self-competes with
the Hermes session** and both starve — observed: a full planning cycle took 40+ min and
only 2 dispatches completed on 8105, versus a clean **6-document planning cycle in ~24 min
on 8082**.

So:
- Point pi's session and every subagent at the **`llm-router`** provider (port **8082**,
  model `qwen-3.8-27b-q8`). `implementation` is already pinned there; for a full local run,
  pin the other agents the same way (see the e2e harness, which rewrites the `model:`
  frontmatter line to `llm-router/qwen-3.8-27b-q8`).
- 8082 is a lighter native-262k server, so it is *faster* than the 520k YaRN/FP8-KV kv520
  AND does not fight the Hermes session. Use 8105/kv520 only if a task genuinely needs the
  >262k context and the Hermes session is idle.

## Verified end-to-end (local model)

On 2026-08-28 a synthetic one-task milestone (M1 "Greeting CLI") ran `/milestone-planning`
fully on local `qwen-3.8-27b-q8` (all 8 agents repointed to the local model; no external
credentials). Result, from the live run:
- Orchestrator created branch `m1-greeting-cli`, resolved the roadmap + central format
  guide + workflow version, and delegated only (never drafted documents itself).
- Planner (subagent) wrote **all 3 planning docs** to disk and committed each
  (`IMPLEMENTATION_PLAN`, `SPEC_SHEETS`, `AGENT_INSTRUCTIONS`).
- Plan-reviewer (subagent, read/edit only) wrote **all 3 `_REVIEW.md` files**, each ending
  in `APPROVED` with its sentinel; the orchestrator ran the mechanical gates after each.
- Full-mode `validate_milestone_docs.py` reported **0 FAIL, 2 WARN**; the reviewer triaged
  both WARNs as benign (no parity/benchmark gates declared for M1).
- Orchestrator's final report listed the 6 files, 4 commits, "Blockers: none", and
  `agent_settled` fired (1449s).

This proves the pi port orchestrates correctly end-to-end with a local model. It does **not**
yet prove the external-model agents (gpt-5.6-*, ox-alpha, deepseek) — those need the
credentials in "Model notes" above before a faithful production run.

## Install

```bash
git clone <this repo> ~/ai/pi-workflow   # if not already there
cd ~/ai/pi-workflow
./install.sh
```

Install is additive: it copies the extension, agents, templates, and
supporting files into `~/.pi/agent/`, merges two local providers into
`models.json`, and creates a pixi env for the validator. Existing pi
content (tokenjuice, pixi-python-block, your models) is preserved.

## Test

```bash
./tests/run_live_tests.sh
```

Covers: extension load, subagent tool + discovery (≥8 agents), live
dispatch with final-text surfacing, model pinning, template frontmatter,
validator under pixi, python3-block enforcement inside subagents, and the
global AGENTS.md rule.

## Repo layout

```
pi-ext/index.ts      # subagent tool extension (single/parallel/chain)
pi-ext/agents.ts     # agent discovery (from official pi example, + thinking field)
agents/*.md          # 8 converted agent definitions
prompts/*.md         # 3 milestone prompt templates (orchestrator preamble + converted workflow)
support/             # validate_milestone_docs.py (verbatim from OpenCode)
docs/                # MILESTONE_PLANNING_FORMAT_GUIDE.md (paths updated)
bin/pwf              # pixi-backed python shim (pi blocks bare python3)
install.sh           # additive installer
tests/run_live_tests.sh
tools/convert_*.py   # the OpenCode→pi converters (re-run if the source workflow changes)
```

## Deltas to the OpenCode behavior (honest list)

1. **No permission system.** OpenCode's `permission:` blocks (doom_loop: ask,
   external_directory: ask, *.env: ask, question/plan: deny) have no pi
   equivalent. Approximated by `tools:` allowlists (reviewers get no bash at
   all) and prompt discipline. Pi's bash runs with whatever the host user can do.
2. **Orchestration model.** OpenCode runs commands under the
   workflow-orchestrator primary agent; in pi the main session performs the
   orchestration (template preamble = orchestrator prompt) and dispatches via
   the `subagent` tool. The orchestrator is also available as a subagent if you
   prefer nested orchestration.
3. **`variant: max`** → `thinking: xhigh` (closest pi level; max exists in pi's
   scale too — use `thinking: max` if you want the literal mapping).
4. **Long-test rule** (AGENTS.md) is advisory in pi as in OpenCode — pi has no
   background-process tool, so "run it as a process" means the subagent's own
   bash; pi has no native process monitor, so per-minute monitoring is manual
   or via `nohup` + a follow-up subagent task.
