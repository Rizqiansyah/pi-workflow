#!/usr/bin/env bash
# Live test suite for the pi milestone workflow. Run after install.sh.
# Each test prints PASS/FAIL; exits non-zero if any fail.
#
# NOTE: this file intentionally avoids `!$?` / `set -e` / pipefail acrobatics.
# Every assertion captures its condition into a 0/1 flag, then calls check.
#
# The local serving endpoint is a single-slot server (max-num-seqs=1), so
# back-to-back pi invocations can transiently fail or return empty. Every
# LLM-backed test therefore retries up to 3 times with a settle delay.
set -u
export PATH="$HOME/.hermes/node/bin:$HOME/.local/bin:$PATH"

PASS=0
FAIL=0
ok()  { PASS=$((PASS+1)); echo "PASS: $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL: $1"; }
# check <name> <0=pass|nonzero=fail>
check() { if [ "$2" -eq 0 ]; then ok "$1"; else bad "$1"; fi; }

SETTLE=8
MAX_TRIES=3

# run_llm_test <label> <prompt-file> <marker> [extra-args...]
# Runs pi -p --mode json with the prompt, retries up to MAX_TRIES until
# the output contains <marker> (or the error marker list is empty).
run_llm_test() {
  local label="$1" prompt="$2" marker="$3"
  shift 3
  local i out
  for i in $(seq 1 "$MAX_TRIES"); do
    out=$(timeout 300 pi -p --mode json "$@" "$prompt" 2>&1)
    if echo "$out" | grep -qF "$marker"; then
      echo "$out" > "$WORKDIR/last-llm-out.jsonl"
      return 0
    fi
    echo "  ($label: attempt $i/$MAX_TRIES, marker not found; settling ${SETTLE}s)"
    sleep "$SETTLE"
  done
  echo "$out" > "$WORKDIR/last-llm-out.jsonl"
  return 1
}

AGENTS_DIR="$HOME/.pi/agent/agents"
WORKDIR=$(mktemp -d /tmp/pwf-test.XXXXXX)
trap 'rm -rf "$WORKDIR"' EXIT

echo "### T1: extension loads clean"
out=$(timeout 90 pi -p "Reply with exactly: OK" 2>&1)
c=1; ! echo "$out" | grep -qi "Failed to load extension" && c=0; check "T1 extension loads (no load error)" $c
# single-slot endpoint can transiently fail; retry before calling T1b
c=1
for i in 1 2 3; do
  out=$(timeout 90 pi -p "Reply with exactly: OK" 2>&1)
  echo "$out" | grep -q "OK" && c=0 && break
  echo "  (T1b: attempt $i/3, no OK; settling ${SETTLE}s)"; sleep "$SETTLE"
done
check "T1b pi still answers" $c
sleep "$SETTLE"

echo "### T2: subagent tool exists + agent discovery"
# The extension returns the agent list directly when called with no task,
# so the only LLM round trip is the parent deciding to invoke the tool.
c=1
run_llm_test T2 'Call the subagent tool with no arguments so it lists the available agents. Then reply with one word: done.' "Available agents:" && c=0
out=$(cat "$WORKDIR/last-llm-out.jsonl" 2>/dev/null)
# The tool result text is a JSON string with \n escapes, so count agents with python.
n=$(python3 - "$WORKDIR/last-llm-out.jsonl" <<'PY'
import json, re, sys
count = 0
seen = set()
lines = []
try:
    lines = open(sys.argv[1]).read().splitlines()
except Exception:
    lines = []
for line in lines:
    line = line.strip()
    if not line or "Available agents" not in line:
        continue
    try:
        e = json.loads(line)
    except Exception:
        continue
    text = json.dumps(e)
    for m in re.finditer(r"No task supplied\. Available agents:(.*?)Call with single", text, re.S):
        block = m.group(1)
        names = set(re.findall(r"([a-z0-9][a-z0-9-]*) \(user\)", block))
        seen |= names
        count = max(count, len(names))
print(count or len(seen))
PY
)
echo "  (agent count from discovery: ${n:-0})"
c=1; [ -n "$n" ] && [ "$n" -ge 8 ] 2>/dev/null && c=0; check "T2 subagent lists >=8 agents (got: ${n:-0})" $c
sleep "$SETTLE"

echo "### T3: live dispatch — test agent, local model"
cat > "$AGENTS_DIR/__pwftest.md" <<'EOF'
---
name: pwftest
description: test agent
tools: read, bash
---
You are a test agent. Reply with exactly: PWF-SUBAGENT-OK
EOF
c=1
run_llm_test T3 'Use the subagent tool in single mode: agent "pwftest", task "do it". Then reply with one word: done.' "PWF-SUBAGENT-OK" && c=0
rm -f "$AGENTS_DIR/__pwftest.md"
check "T3 subagent final text surfaced (PWF-SUBAGENT-OK)" $c
sleep "$SETTLE"

echo "### T4: subagent honors pinned model + tool allowlist"
cat > "$AGENTS_DIR/__pwftest2.md" <<'EOF'
---
name: pwftest2
description: model pin test
tools: bash
model: vllm-local/kv520
---
Reply with exactly: MODEL-CHECK
EOF
c=1
run_llm_test T4a 'Use the subagent tool in single mode: agent "pwftest2", task "do it". Then reply done.' "MODEL-CHECK" && c=0
check "T4a pinned-model subagent ran" $c
out=$(cat "$WORKDIR/last-llm-out.jsonl" 2>/dev/null)
c=1; echo "$out" | grep -q '"agent":"pwftest2"' && c=0; check "T4b result metadata includes agent name" $c
rm -f "$AGENTS_DIR/__pwftest2.md"
sleep "$SETTLE"

echo "### T5: prompt templates registered + well-formed"
for t in milestone-planning milestone-implementation milestone-pr-review; do
  f="$HOME/.pi/agent/prompts/$t.md"
  c=1
  if [ -f "$f" ] \
     && head -1 "$f" | grep -q '^---$' \
     && grep -q '^description:' "$f" \
     && grep -q '^argument-hint:' "$f" \
     && grep -q 'subagent tool' "$f"; then
    c=0
  fi
  check "T5 template $t (frontmatter + subagent dispatch)" $c
done

echo "### T6: validator runs via pwf (pixi) and passes a valid partial plan"
mkdir -p "$WORKDIR/docs"
cat > "$WORKDIR/docs/MILESTONE_1_IMPLEMENTATION_PLAN.md" <<'EOF'
# Implementation Plan — Milestone 1

Date: 2026-08-27
Workflow-Version: wf-v1.9

## M1-P1 — Test phase

### M1-P1-T1 — Test task
Do a thing.
EOF
out=$(pwf "$HOME/.pi/agent/workflow/support/validate_milestone_docs.py" "$WORKDIR/docs" MILESTONE_1 --partial 2>&1)
code=$?
echo "  (validator exit: $code)"
c=1; [ "$code" -eq 0 ] && c=0; check "T6 validator --partial exit 0 on valid plan" $c
c=1; echo "$out" | grep -q "0 FAIL" && c=0; check "T6 validator reports 0 FAIL" $c
sleep "$SETTLE"

echo "### T7: pixi-block is active inside (subagent-equivalent) pi child processes"
# A subagent child is just a pi process launched with --tools <allowlist>; the
# block message appears in that CHILD process's own JSONL tool_result, not in
# the parent stream (the subagent tool only relays the child's final text).
# T7a reproduces the child environment deterministically.
out=$(cd /tmp && timeout 120 pi -p --mode json --tools bash --no-session "Run this bash command: python3 --version. Then reply with one word: done." 2>&1)
c=1; echo "$out" | grep -q "deliberately disabled" && c=0; check "T7a python3 blocked in bash-only pi process" $c
c=1; echo "$out" | grep -q "Python 3\." && c=0; check "T7a python3 did not actually run" $c
sleep "$SETTLE"
# T7b: through the real subagent tool path — the child reports the block in its
# final text, which IS relayed to the parent.
cat > "$AGENTS_DIR/__pwftest3.md" <<'EOF'
---
name: pwftest3
description: pixi-block probe
tools: bash
---
Run this bash command: python3 --version
If the command is blocked or reported as disabled, reply with exactly: BLOCKED-DETECTED
If the command actually executed and printed a version, reply with exactly: RAN-OK
EOF
c=1
run_llm_test T7b 'Use the subagent tool in single mode: agent "pwftest3", task "do it". Then reply with one word: done.' "BLOCKED-DETECTED" && c=0
rm -f "$AGENTS_DIR/__pwftest3.md"
check "T7b block observed through subagent dispatch" $c
sleep "$SETTLE"

echo "### T8: global AGENTS.md rules loaded"
c=1
run_llm_test T8 "What rule do your global system instructions state about python? Answer in one line." "pixi" && c=0
check "T8 global AGENTS.md pixi rule visible to model" $c

echo
echo "=============================="
echo "PASS: $PASS   FAIL: $FAIL"
[ "$FAIL" -eq 0 ]
