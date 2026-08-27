#!/usr/bin/env bash
# Install the pi milestone workflow: subagent extension, agents, prompt
# templates, supporting files (as a git checkout, so `describe --tags`
# resolves the workflow version), and local providers.
#
# Everything is additive; existing ~/.pi/agent content is preserved.
set -euo pipefail

AGENT_DIR="${PI_AGENT_DIR:-$HOME/.pi/agent}"
SRC="$(cd "$(dirname "$0")" && pwd)"
WF_TAG="wf-pi-v0.1.0"

mkdir -p "$AGENT_DIR"

echo "== subagent extension =="
mkdir -p "$AGENT_DIR/extensions/subagent"
cp "$SRC/pi-ext/index.ts" "$AGENT_DIR/extensions/subagent/index.ts"
cp "$SRC/pi-ext/agents.ts" "$AGENT_DIR/extensions/subagent/agents.ts"

echo "== agents =="
mkdir -p "$AGENT_DIR/agents"
cp "$SRC"/agents/*.md "$AGENT_DIR/agents/"
echo "   $(ls "$SRC"/agents/*.md | wc -l) agents"

echo "== prompt templates (slash commands) =="
mkdir -p "$AGENT_DIR/prompts"
cp "$SRC"/prompts/milestone-*.md "$AGENT_DIR/prompts/"
echo "   $(ls "$SRC"/prompts/milestone-*.md | wc -l) templates"

echo "== supporting files (git checkout at $AGENT_DIR/workflow) =="
# The templates resolve paths like ~/.pi/agent/workflow/{support,docs}/ and
# the workflow version via `git -C ~/.pi/agent/workflow describe --tags`.
# So the workflow home must be a git checkout of this repo.
if [ -d "$AGENT_DIR/workflow/.git" ]; then
  git -C "$AGENT_DIR/workflow" fetch --quiet origin 2>/dev/null || true
  git -C "$AGENT_DIR/workflow" reset --hard --quiet origin/master 2>/dev/null \
    || git -C "$AGENT_DIR/workflow" reset --hard --quiet master
  git -C "$AGENT_DIR/workflow" tag "$WF_TAG" 2>/dev/null || true
  echo "   refreshed existing checkout"
else
  if [ -e "$AGENT_DIR/workflow" ]; then
    mv "$AGENT_DIR/workflow" "$AGENT_DIR/workflow.bak.$(date +%s)"
    echo "   moved existing non-git dir to workflow.bak.*"
  fi
  if git -C "$AGENT_DIR/workflow" rev-parse 2>/dev/null; then
    echo "   (unexpected)"
  else
    git clone -q "$SRC" "$AGENT_DIR/workflow"
    git -C "$AGENT_DIR/workflow" tag "$WF_TAG" 2>/dev/null || true
    echo "   cloned checkout"
  fi
fi
# pixi env for the pwf shim (validator runs under it); skip if env present
if [[ ! -x "$AGENT_DIR/workflow/.pixi/envs/default/bin/python" && ! -x "$AGENT_DIR/workflow/.pixi/bin/python" ]]; then
  (cd "$AGENT_DIR/workflow" && pixi install) || echo "   WARNING: pixi install failed; run manually in ~/.pi/agent/workflow"
fi
# pwf shim on PATH (also in the checkout at bin/, but PATH copy survives re-clones)
if [ -d "$HOME/.local/bin" ]; then
  cp "$SRC/bin/pwf" "$HOME/.local/bin/pwf"
  chmod +x "$HOME/.local/bin/pwf"
  echo "   pwf -> ~/.local/bin/pwf"
fi

echo "== providers (merged into models.json) =="
node -e '
const fs = require("fs");
const [agentDir, srcDir] = process.argv.slice(1);
const path = agentDir + "/models.json";
const src = srcDir + "/providers.json";
let cur = {};
try { cur = JSON.parse(fs.readFileSync(path, "utf8")); } catch {}
const add = JSON.parse(fs.readFileSync(src, "utf8"));
cur.providers = cur.providers || {};
for (const [k, v] of Object.entries(add.providers)) {
  cur.providers[k] = v;
}
fs.writeFileSync(path, JSON.stringify(cur, null, 2) + "\n");
console.log("   merged providers:", Object.keys(cur.providers).join(", "));
' "$AGENT_DIR" "$SRC"

echo "== default model (pinned in settings.json) =="
node -e '
const fs = require("fs");
const agentDir = process.argv[1];
const p = agentDir + "/settings.json";
let cur = {};
try { cur = JSON.parse(fs.readFileSync(p, "utf8")); } catch {}
// Pin the local model so pi -p and every subagent child resolve to it
// instead of a built-in cloud default (which may be 402/credit-gated).
if (cur.defaultProvider !== "vllm-local" || cur.defaultModel !== "kv520") {
  cur.defaultProvider = "vllm-local";
  cur.defaultModel = "kv520";
  fs.writeFileSync(p, JSON.stringify(cur, null, 2) + "\n");
  console.log("   pinned defaultProvider=vllm-local defaultModel=kv520");
} else {
  console.log("   already pinned");
}
' "$AGENT_DIR"

echo "== global AGENTS.md (append-only) =="
if [[ -f "$AGENT_DIR/AGENTS.md" ]] && grep -q "Python must use pixi" "$AGENT_DIR/AGENTS.md"; then
  echo "   already present, skipped"
elif [[ -f "$AGENT_DIR/AGENTS.md" ]]; then
  printf '\nPython must use pixi. If a test takes longer than 1 minute, run it as a process instead and monitor every minute.\n' >> "$AGENT_DIR/AGENTS.md"
  echo "   appended"
else
  cp "$SRC/global-instructions.md" "$AGENT_DIR/AGENTS.md"
  sed -i '1,2d' "$AGENT_DIR/AGENTS.md"
  echo "   created"
fi

echo
echo "installed. Verify with: pi (then /reload in an existing session, or start fresh)"
echo "   agents:    ls $AGENT_DIR/agents"
echo "   commands:  /milestone-planning /milestone-implementation /milestone-pr-review"
echo "   workflow:  $AGENT_DIR/workflow (git tag $WF_TAG)"
