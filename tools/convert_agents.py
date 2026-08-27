#!/usr/bin/env python3
"""Convert OpenCode agent definitions to pi agent definitions.

Reads the staged files from /tmp/opencode-audit/ and writes pi-format
agents/*.md into the pi-workflow repo, preserving prompt bodies verbatim.
"""
import re
import sys
from pathlib import Path

SRC = Path("/tmp/opencode-audit")
DST = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / "ai/pi-workflow/agents"
DST.mkdir(parents=True, exist_ok=True)

FULL_TOOLS = "read, bash, edit, write, grep, find, ls"
READ_EDIT = "read, edit, grep, find, ls"
FULL_ACCESS = "read, bash, edit, write, grep, find, ls"

# name -> (model, tools, thinking)
AGENT_MAP = {
    "workflow-orchestrator": (None, FULL_ACCESS, None),
    "milestone-planner": ("openai/gpt-5.6-sol", FULL_TOOLS, None),
    "milestone-plan-reviewer": ("openrouter/stealth/ox-alpha", READ_EDIT, "xhigh"),
    "implementation": (None, FULL_TOOLS, None),  # inherits current pi default (kv520)
    "senior-implementer": ("opencode-go/deepseek-v4-pro", FULL_TOOLS, None),
    "phase-reviewer": ("openai/gpt-5.6-terra", READ_EDIT, None),
    "glm-milestone-reviewer": ("openrouter/stealth/ox-alpha", READ_EDIT, "xhigh"),
    "gpt-milestone-reviewer": ("openai/gpt-5.6-sol", READ_EDIT, None),
}


def split_frontmatter(text: str):
    if not text.startswith("---\n"):
        return {}, text
    end = text.find("\n---", 4)
    if end == -1:
        return {}, text
    fm_raw = text[4:end]
    body = text[end + 4 :].lstrip("\n")
    return fm_raw, body


def main():
    for name, (model, tools, thinking) in AGENT_MAP.items():
        src = SRC / f"agents-{name}.md"
        _, body = split_frontmatter(src.read_text())
        lines = [
            "---",
            f"name: {name}",
            f'description: {json_desc(name)}',
        ]
        if model:
            lines.append(f"model: {model}")
        if thinking:
            lines.append(f"thinking: {thinking}")
        lines.append(f"tools: {tools}")
        lines.append("---")
        lines.append("")
        out = "\n".join(lines) + body
        if not out.endswith("\n"):
            out += "\n"
        (DST / f"{name}.md").write_text(out)
        print(f"wrote {DST / (name + '.md')} ({len(out)} bytes)")


import json as _json


def json_desc(name):
    # descriptions sourced from the original frontmatter (reused, single-quoted-safe)
    descs = {
        "workflow-orchestrator": "General workflow orchestrator that coordinates subagents according to slash-command workflows without doing delegated work itself.",
        "milestone-planner": "Plans one milestone from source materials under orchestration.",
        "milestone-plan-reviewer": "Adversarially reviews milestone planning artifacts under orchestration.",
        "implementation": "Coding Agent to implement specific tasks.",
        "senior-implementer": "Senior coding agent for implementation tasks after repeated implementation-agent failures.",
        "phase-reviewer": "Reviews an implemented phase against plan goals, requirements, scope, regressions, incompleteness, incorrectness, and scope creep.",
        "glm-milestone-reviewer": "Ox Alpha (GLM) reviewer for milestone pull requests against milestone goals, requirements, scope, regressions, incompleteness, incorrectness, scope creep, and residual risk.",
        "gpt-milestone-reviewer": "GPT 5.6 Sol reviewer for milestone pull requests against milestone goals, requirements, scope, regressions, incompleteness, incorrectness, scope creep, and residual risk.",
    }
    d = descs[name]
    assert '"' not in d
    return d


if __name__ == "__main__":
    main()
