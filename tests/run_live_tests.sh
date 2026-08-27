#!/usr/bin/env bash
# Live test suite for the pi milestone workflow. Run after install.sh.
# Each test prints PASS/FAIL; exits non-zero if any fail.
set -uo pipefail
export PATH="$HOME/.hermes/node/bin:$HOME/.local/bin:$PATH"

PASS=0
FAIL=0
ok()   { PASS=$((PASS+1)); echo "PASS: $1"; }
bad()  { FAIL=$((FAIL+1)); echo "FAIL: $1"; }
check() { # check <name> <condition-exit-code>
  if [ "$2" -eq 0 ]; then ok "$1"; else bad "$1"; fi
}

WORKDIR=$(mktemp -d /tmp/pwf-test.XXXXXX)
trap 'rm -rf "$WORKDIR"' EXIT

echo "### T1: extension loads clean"
out=$(timeout 90 pi -p "Reply with exactly: OK" 2>&1)
echo "$out" | grep -qi "Failed to load extension"; check "T1 extension loads (no load error)" $((! $?))
echo "$out" | grep -q "OK"; check "T1b pi still answers" $((! $?))

echo "### T2: subagent tool exists + agent discovery"
out=$(timeout 90 pi -p "Call the subagent tool with no arguments. Reply with the number of available agents listed in its output, nothing else." 2>&1)
echo "  (model reply: $out)"
n=$(echo "$out" | grep -oE '[0-9]+' | head -1)
[ -n "$n" ] && [ "$n" -ge 8 ] 2>/dev/null; check "T2 subagent lists >=8 agents (got: ${n:-0})" $((! $?))

echo "### T3: live dispatch — test agent, local model"
cat > "$HOME/.pi/agent/agents/__pwftest.md" <<EOF
---
name: pwftest
description: test agent
tools: read, bash
---
You are a test agent. Reply with exactly: PWF-SUBAGENT-OK
EOF
out=$(timeout 180 pi -p 'Use the subagent tool, single mode, agent "pwftest", task "do it". Then reply with one word: done.' 2>&1)
rm -f "$HOME/.pi/agent/agents/__pwftest.md"
echo "$out" | grep -q "PWF-SUBAGENT-OK"; check "T3 subagent final text surfaced (PWF-SUBAGENT-OK)" $((! $?))

echo "### T4: subagent uses the pinned model + tool allowlist"
cat > "$HOME/.pi/agent/agents/__pwftest2.md" <<EOF
---
name: pwftest2
description: model pin test
tools: bash
model: vllm-local/kv520
---
Reply with exactly: MODEL-CHECK
EOF
out=$(timeout 180 pi -p --mode json 'Use the subagent tool, single mode, agent "pwftest2", task "do it". Reply done.' 2>&1)
rm -f "$HOME/.pi/agent/agents/__pwftest2.md"
echo "$out" | grep -q "MODEL-CHECK"; check "T4a pinned-model subagent ran" $((! $?))
echo "$out" | grep -qE '"agent": ?"pwftest2"'; check "T4b result metadata includes agent name" $((! $?))

echo "### T5: prompt templates registered + well-formed"
tmpl_ok=0
for t in milestone-planning milestone-implementation milestone-pr-review; do
  f="$HOME/.pi/agent/prompts/$t.md"
  if [ -f "$f" ] \
     && head -1 "$f" | grep -q '^---$' \
     && grep -q '^description:' "$f" \
     && grep -q '^argument-hint:' "$f" \
     && grep -q 'subagent tool' "$f"; then
    ok "T5 template $t (frontmatter + subagent dispatch)"
  else
    bad "T5 template $t (frontmatter/subagent check failed)"
    tmpl_ok=1
  fi
done

echo "### T6: validator runs via pwf (pixi)"
mkdir -p "$WORKDIR/docs"
cat > "$WORKDIR/docs/TEST-1_IMPLEMENTATION_PLAN.md" <<'EOF'
# Implementation Plan — Milestone 1

Date: 2026-08-27
Workflow-Version: wf-v1.9

## M1-P1 — Test phase

### M1-P1-T1 — Test task
Do a thing.
EOF
out=$(pwf "$HOME/.pi/agent/workflow/support/validate_milestone_docs.py" "$WORKDIR/docs" TEST-1 --partial 2>&1)
code=$?
echo "  (validator exit: $code; first line: $(echo "$out" | head -1))"
[ "$code" -eq 0 ]; check "T6 validator --partial passes on valid plan" $((! $?))

echo "### T7: pixi-block still active in subagents"
cat > "$HOME/.pi/agent/agents/__pwftest3.md" <<'EOF
---
name: pwftest3
description: pixi block test
tools: bash
---
Run bash: python3 --version. Then reply with one word: done.
EOF
out=$(timeout 180 pi -p --mode json 'Use the subagent tool, single mode, agent "pwftest3", task "do it". Reply done.' 2>&1)
rm -f "$HOME/.pi/agent/agents/__pwftest3.md"
echo "$out" | grep -q "deliberately disabled"; check "T7 bare python3 blocked inside subagent process" $((! $?))

echo "### T8: global AGENTS.md rules loaded"
out=$(timeout 90 pi -p --mode json "What rule do your global instructions give about python? Quote it exactly. One line." 2>&1)
echo "$out" | grep -qi "pixi"; check "T8 global AGENTS.md pixi rule visible to model" $((! $?))

echo
echo "=============================="
echo "PASS: $PASS   FAIL: $FAIL"
[ "$FAIL" -eq 0 ]
