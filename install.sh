#!/usr/bin/env bash
# Install the pi milestone workflow: subagent extension, agents, prompt
# templates, supporting files, and local providers.
#
# Everything is additive; existing ~/.pi/agent content is preserved:
#   - extensions/subagent/           (this repo's pi-ext/)
#   - agents/*.md                    (this repo's agents/)
#   - prompts/milestone-*.md         (this repo's prompts/)
#   - workflow/support|docs|bin      (validators + format guide + pwf shim)
#   - models.json                    (merged: vllm-local + llm-router added)
#   - AGENTS.md                      (appended if absent, never overwritten)
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
AGENT_DIR="${HOME}/.pi/agent"
mkdir -p "$AGENT_DIR"

echo "== subagent extension =="
mkdir -p "$AGENT_DIR/extensions/subagent"
cp "$SRC/pi-ext/index.ts" "$AGENT_DIR/extensions/subagent/index.ts"
cp "$SRC/pi-ext/agents.ts" "$AGENT_DIR/extensions/subagent/agents.ts"

echo "== agents =="
mkdir -p "$AGENT_DIR/agents"
cp "$SRC"/agents/*.md "$AGENT_DIR/agents/"

echo "== prompt templates (slash commands) =="
mkdir -p "$AGENT_DIR/prompts"
cp "$SRC"/prompts/milestone-*.md "$AGENT_DIR/prompts/"

echo "== supporting files =="
mkdir -p "$AGENT_DIR/workflow/support" "$AGENT_DIR/workflow/docs" "$AGENT_DIR/workflow/bin"
cp "$SRC/support/validate_milestone_docs.py" "$AGENT_DIR/workflow/support/"
cp "$SRC/docs/MILESTONE_PLANNING_FORMAT_GUIDE.md" "$AGENT_DIR/workflow/docs/"
cp "$SRC/bin/pwf" "$AGENT_DIR/workflow/bin/"
chmod +x "$AGENT_DIR/workflow/bin/pwf"
# make pwf callable on PATH
if [[ -d "$HOME/.local/bin" ]] && [[ ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
  ln -sf "$AGENT_DIR/workflow/bin/pwf" "$HOME/.local/bin/pwf"
  echo "   pwf -> ~/.local/bin/pwf"
fi

# pixi env for the pwf shim (validator runs under it); skip if env present
if [[ ! -x "$AGENT_DIR/workflow/.pixi/bin/python" ]]; then
  cp "$SRC/pixi.toml" "$AGENT_DIR/workflow/pixi.toml"
  (cd "$AGENT_DIR/workflow" && pixi install) || echo "   WARNING: pixi install failed; run manually in ~/.pi/agent/workflow"
fi

echo "== providers (merged into models.json) =="
node -e '
const fs = require("fs");
const path = process.env.AGENT_DIR + "/models.json";
const src = process.env.SRC + "/providers.json";
let cur = {};
try { cur = JSON.parse(fs.readFileSync(path, "utf8")); } catch {}
const add = JSON.parse(fs.readFileSync(src, "utf8"));
cur.providers = cur.providers || {};
for (const [k, v] of Object.entries(add.providers)) {
  cur.providers[k] = v;
}
fs.writeFileSync(path, JSON.stringify(cur, null, 2) + "\n");
console.log("   merged providers:", Object.keys(cur.providers).join(", "));
' AGENT_DIR="$AGENT_DIR" SRC="$SRC"

echo "== global AGENTS.md (append-only) =="
if [[ -f "$AGENT_DIR/AGENTS.md" ]] && grep -q "Python must use pixi" "$AGENT_DIR/AGENTS.md"; then
  echo "   already present, skipped"
elif [[ -f "$AGENT_DIR/AGENTS.md" ]]; then
  printf '\nPython must use pixi. If a test takes longer than 1 minute, run it as a process instead and monitor every minute.\n' >> "$AGENT_DIR/AGENTS.md"
  echo "   appended"
else
  cp "$SRC/global-instructions.md" "$AGENT_DIR/AGENTS.md"
  # strip the header comment lines
  sed -i '1,2d' "$AGENT_DIR/AGENTS.md"
  echo "   created"
fi

echo
echo "installed. Verify with: pi (then /reload in an existing session, or start fresh)"
echo "   agents:    ls $AGENT_DIR/agents"
echo "   commands:  /milestone-planning /milestone-implementation /milestone-pr-review"
