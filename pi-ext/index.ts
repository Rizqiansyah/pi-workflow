/**
 * subagent tool — delegate tasks to specialized agents with isolated context.
 *
 * Based on the official pi-coding-agent subagent example, trimmed:
 * - single / parallel / chain modes
 * - plain-text output rendering (no TUI chrome)
 * - agent discovery from ~/.pi/agent/agents and .pi/agents (agents.ts)
 *
 * Each subagent runs as a separate `pi --mode json -p --no-session` process
 * with the agent's markdown body appended to the system prompt, an optional
 * model pin, and an optional tool allowlist.
 */

import { spawn } from "node:child_process";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import type { AgentToolResult, ThinkingLevel } from "@earendil-works/pi-agent-core";
import type { Message } from "@earendil-works/pi-ai";
import { StringEnum } from "@earendil-works/pi-ai";
import {
	CONFIG_DIR_NAME,
	type ExtensionAPI,
	getAgentDir,
} from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { type AgentConfig, type AgentScope, discoverAgents } from "./agents.ts";

const MAX_PARALLEL_TASKS = 8;
const MAX_CONCURRENCY = 4;
const PER_TASK_OUTPUT_CAP = 50 * 1024;

function formatTokens(count: number): string {
	if (count < 1000) return count.toString();
	if (count < 10000) return `${(count / 1000).toFixed(1)}k`;
	if (count < 1000000) return `${Math.round(count / 1000)}k`;
	return `${(count / 1000000).toFixed(1)}M`;
}

function formatUsageStats(
	usage: {
		input: number;
		output: number;
		cacheRead: number;
		cacheWrite: number;
		cost: number;
		contextTokens?: number;
		turns?: number;
	},
	model?: string,
): string {
	const parts: string[] = [];
	if (usage.turns) parts.push(`${usage.turns} turn${usage.turns > 1 ? "s" : ""}`);
	if (usage.input) parts.push(`↑${formatTokens(usage.input)}`);
	if (usage.output) parts.push(`↓${formatTokens(usage.output)}`);
	if (usage.cacheRead) parts.push(`R${formatTokens(usage.cacheRead)}`);
	if (usage.cacheWrite) parts.push(`W${formatTokens(usage.cacheWrite)}`);
	if (usage.cost) parts.push(`$${usage.cost.toFixed(4)}`);
	if (usage.contextTokens && usage.contextTokens > 0)
		parts.push(`ctx:${formatTokens(usage.contextTokens)}`);
	if (model) parts.push(model);
	return parts.join(" ");
}

type SingleResult = {
	agent: string;
	agentSource: string;
	task: string;
	exitCode: number;
	messages: Message[];
	stderr: string;
	usage: {
		input: number;
		output: number;
		cacheRead: number;
		cacheWrite: number;
		cost: number;
		contextTokens: number;
		turns: number;
	};
	model?: string;
	stopReason?: string;
	errorMessage?: string;
	step?: number;
};

function getFinalText(result: SingleResult): string {
	for (let i = result.messages.length - 1; i >= 0; i--) {
		const msg = result.messages[i] as any;
		if (msg.role === "assistant" && Array.isArray(msg.content)) {
			const text = msg.content
				.filter((c: any) => c.type === "text")
				.map((c: any) => c.text)
				.join("\n")
				.trim();
			if (text) return text;
		}
	}
	return "";
}

function getToolCallTrace(result: SingleResult): string {
	const lines: string[] = [];
	for (const msg of result.messages) {
		const m = msg as any;
		if (m.role === "assistant" && Array.isArray(m.content)) {
			for (const c of m.content) {
				if (c.type === "toolCall") {
					let argPreview = "";
					try {
						const args = JSON.parse(JSON.stringify(c.arguments ?? {}));
						if (c.name === "bash") argPreview = String(args.command ?? "").slice(0, 80);
						else if (c.name === "read" || c.name === "write" || c.name === "edit")
							argPreview = String(args.file_path ?? args.path ?? "").slice(0, 80);
					} catch {
						argPreview = "";
					}
					lines.push(`  [${m.turn ?? ""}] ${c.name}${argPreview ? `: ${argPreview}` : ""}`);
				}
			}
		}
	}
	return lines.join("\n");
}

function cap(text: string): string {
	if (text.length <= PER_TASK_OUTPUT_CAP) return text;
	const cut = text.slice(0, PER_TASK_OUTPUT_CAP);
	return `${cut}\n\n[... truncated ${text.length - PER_TASK_OUTPUT_CAP} chars ...]`;
}

async function writePromptToTempFile(agentName: string, prompt: string) {
	const tmpDir = await fs.promises.mkdtemp(path.join(os.tmpdir(), "pi-subagent-"));
	const safeName = agentName.replace(/[^\w.-]+/g, "_");
	const filePath = path.join(tmpDir, `prompt-${safeName}.md`);
	await fs.promises.writeFile(filePath, prompt, { encoding: "utf-8", mode: 0o600 });
	return { dir: tmpDir, filePath };
}

function getPiInvocation(args: string[]): { command: string; args: string[] } {
	const currentScript = process.argv[1];
	const isBunVirtualScript = currentScript?.startsWith("/$bunfs/root/");
	if (currentScript && !isBunVirtualScript && fs.existsSync(currentScript)) {
		return { command: process.execPath, args: [currentScript, ...args] };
	}
	const execName = path.basename(process.execPath).toLowerCase();
	const isGenericRuntime = /^(node|bun)(\.exe)?$/.test(execName);
	if (!isGenericRuntime) {
		return { command: process.execPath, args };
	}
	return { command: "pi", args };
}

type DispatchDefaults = {
	model?: string;
	thinkingLevel?: ThinkingLevel;
};

async function runSingleAgent(
	defaultCwd: string,
	dispatchDefaults: DispatchDefaults,
	agents: AgentConfig[],
	agentName: string,
	task: string,
	cwd: string | undefined,
	step: number | undefined,
	signal: AbortSignal | undefined,
): Promise<SingleResult> {
	const agent = agents.find((a) => a.name === agentName);
	const base: SingleResult = {
		agent: agentName,
		agentSource: agent?.source ?? "unknown",
		task,
		exitCode: 1,
		messages: [],
		stderr: "",
		usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, contextTokens: 0, turns: 0 },
		step,
	};
	if (!agent) {
		const available = agents.map((a) => `"${a.name}"`).join(", ") || "none";
		base.stderr = `Unknown agent: "${agentName}". Available agents: ${available}.`;
		return base;
	}

	const result = base;
	const model = agent.model ?? dispatchDefaults.model;
	const thinkingLevel = agent.thinking ?? dispatchDefaults.thinkingLevel;
	let tmpPromptPath: string | undefined;
	let tmpPromptDir: string | undefined;

	const args: string[] = ["--mode", "json", "-p", "--no-session"];
	if (model) args.push("--model", model);
	if (thinkingLevel) args.push("--thinking", thinkingLevel);
	if (agent.tools && agent.tools.length > 0) args.push("--tools", agent.tools.join(","));

	try {
		if (agent.systemPrompt.trim()) {
			const tmp = await writePromptToTempFile(agent.name, agent.systemPrompt);
			tmpPromptDir = tmp.dir;
			tmpPromptPath = tmp.filePath;
			args.push("--append-system-prompt", tmpPromptPath);
		}

		args.push(`Task: ${task}`);
		let wasAborted = false;

		const exitCode = await new Promise<number>((resolve) => {
			const invocation = getPiInvocation(args);
			const proc = spawn(invocation.command, invocation.args, {
				cwd: cwd ?? defaultCwd,
				shell: false,
				stdio: ["ignore", "pipe", "pipe"],
			});
			let buffer = "";

			const processLine = (line: string) => {
				if (!line.trim()) return;
				let event: any;
				try {
					event = JSON.parse(line);
				} catch {
					return;
				}
				if (event.type === "message_end" && event.message) {
					result.messages.push(event.message);
					const msg = event.message as any;
					if (msg.role === "assistant") {
						result.usage.turns++;
						const usage = msg.usage;
						if (usage) {
							result.usage.input += usage.input || 0;
							result.usage.output += usage.output || 0;
							result.usage.cacheRead += usage.cacheRead || 0;
							result.usage.cacheWrite += usage.cacheWrite || 0;
							result.usage.cost += usage.cost?.total || 0;
							result.usage.contextTokens = usage.totalTokens || 0;
						}
						if (!result.model && msg.model) result.model = msg.model;
						if (msg.stopReason) result.stopReason = msg.stopReason;
						if (msg.errorMessage) result.errorMessage = msg.errorMessage;
					}
				}
				if (event.type === "tool_result_end" && event.message) {
					result.messages.push(event.message);
				}
			};

			proc.stdout.on("data", (data: Buffer) => {
				buffer += data.toString();
				const lines = buffer.split("\n");
				buffer = lines.pop() || "";
				for (const line of lines) processLine(line);
			});
			proc.stderr.on("data", (data: Buffer) => {
				result.stderr += data.toString();
			});
			proc.on("close", (code: number | null) => {
				if (buffer.trim()) processLine(buffer);
				resolve(code ?? 0);
			});
			proc.on("error", () => resolve(1));

			if (signal) {
				const killProc = () => {
					wasAborted = true;
					proc.kill("SIGTERM");
					setTimeout(() => {
						if (!proc.killed) proc.kill("SIGKILL");
					}, 5000);
				};
				if (signal.aborted) killProc();
				else signal.addEventListener("abort", killProc, { once: true });
			}
		});

		result.exitCode = exitCode;
		if (wasAborted) throw new Error(`Subagent "${agentName}" was aborted`);
		return result;
	} finally {
		if (tmpPromptPath) {
			try {
				fs.unlinkSync(tmpPromptPath);
			} catch {
				/* ignore */
			}
			try {
				fs.rmdirSync(tmpPromptDir ?? "");
			} catch {
				/* ignore */
			}
		}
	}
}

async function runWithConcurrency<T>(
	items: T[],
	limit: number,
	fn: (item: T, index: number) => Promise<void>,
): Promise<void> {
	let next = 0;
	const workers = Array.from({ length: Math.min(limit, items.length) }, async () => {
		while (next < items.length) {
			const i = next++;
			await fn(items[i], i);
		}
	});
	await Promise.all(workers);
}

function renderResult(result: SingleResult): string {
	const header = `## [${result.step ? `step ${result.step} · ` : ""}${result.agent}] (source: ${result.agentSource}, exit ${result.exitCode})`;
	const finalText = getFinalText(result);
	const toolTrace = getToolCallTrace(result);
	const usage = formatUsageStats(result.usage, result.model);
	const errorLine = result.errorMessage ? `\nError: ${result.errorMessage}` : "";
	const stderrLine = result.stderr && result.exitCode !== 0 ? `\nstderr: ${cap(result.stderr.slice(-2000))}` : "";
	const traceBlock = toolTrace ? `\n\nTool calls:\n${toolTrace}` : "";
	const body = finalText ? `\n\n${cap(finalText)}` : "\n\n(No final assistant text)";
	return `${header}\n\n${usage}${errorLine}${stderrLine}${traceBlock}${body}`;
}

const TaskItem = Type.Object({
	agent: Type.String({ description: "Name of the agent to invoke" }),
	task: Type.String({ description: "Task to delegate to the agent" }),
	cwd: Type.Optional(Type.String({ description: "Working directory for the agent process" })),
});

const ChainItem = Type.Object({
	agent: Type.String({ description: "Name of the agent to invoke" }),
	task: Type.String({ description: "Task with optional {previous} placeholder for prior output" }),
	cwd: Type.Optional(Type.String({ description: "Working directory for the agent process" })),
});

const AgentScopeSchema = StringEnum(["user", "project", "both"] as const, {
	description: 'Which agent directories to use. Default: "user". Use "both" to include project-local agents.',
	default: "user",
});

const SubagentParams = Type.Object({
	agent: Type.Optional(Type.String({ description: "Name of the agent to invoke (single mode)" })),
	task: Type.Optional(Type.String({ description: "Task to delegate (single mode)" })),
	tasks: Type.Optional(Type.Array(TaskItem, { description: "Array of {agent, task} for parallel execution" })),
	chain: Type.Optional(Type.Array(ChainItem, { description: "Array of {agent, task} for sequential execution" })),
	agentScope: Type.Optional(AgentScopeSchema),
	cwd: Type.Optional(Type.String({ description: "Working directory for the agent process (single mode)" })),
});

type SubagentParamsStatic = {
	agent?: string;
	task?: string;
	tasks?: Array<{ agent: string; task: string; cwd?: string }>;
	chain?: Array<{ agent: string; task: string; cwd?: string }>;
	agentScope?: "user" | "project" | "both";
	cwd?: string;
};

export default function (pi: ExtensionAPI) {
	pi.registerTool({
		name: "subagent",
		label: "Subagent",
		description: [
			"Delegate tasks to specialized subagents with isolated context.",
			"Modes: single (agent + task), parallel (tasks array), chain (sequential with {previous} placeholder).",
			`Agents come from ${path.join(getAgentDir(), "agents")} (default) or the project ${CONFIG_DIR_NAME}/agents dir (agentScope: "both").`,
			"Available agents are listed when you call the tool with no valid mode.",
		].join(" "),
		parameters: SubagentParams,

		async execute(_toolCallId, params: SubagentParamsStatic, signal, _onUpdate, ctx) {
			const agentScope: AgentScope = params.agentScope ?? "user";
			const dispatchDefaults: DispatchDefaults = {
				model: ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : undefined,
				thinkingLevel: ctx.thinkingLevel,
			};
			const discovery = discoverAgents(ctx.cwd, agentScope);
			const agents = discovery.agents;

			const hasChain = Boolean(params.chain?.length);
			const hasTasks = Boolean(params.tasks?.length);
			const hasSingle = Boolean(params.agent && params.task);

			if (!hasChain && !hasTasks && !hasSingle) {
				const list = agents
					.map((a) => `  ${a.name} (${a.source})${a.model ? ` [${a.model}]` : ""}: ${a.description}`)
					.join("\n") || "  (no agents found)";
				return {
					content: [
						{
							type: "text",
							text: `No task supplied. Available agents:\n${list}\n\nCall with single (agent+task), parallel (tasks: [...]), or chain (chain: [...]).`,
						},
					],
					details: {},
				};
			}

			const results: SingleResult[] = [];

			if (hasChain) {
				let previous = "";
				for (let i = 0; i < (params.chain?.length ?? 0); i++) {
					const item = params.chain![i];
					const task = item.task.replaceAll("{previous}", previous);
					const r = await runSingleAgent(
						ctx.cwd,
						dispatchDefaults,
						agents,
						item.agent,
						task,
						item.cwd,
						i + 1,
						signal,
					);
					results.push(r);
					previous = getFinalText(r) || `(no output, exit ${r.exitCode})`;
					if (r.exitCode !== 0) break;
				}
			} else if (hasTasks) {
				const items = params.tasks!.slice(0, MAX_PARALLEL_TASKS);
				await runWithConcurrency(items, MAX_CONCURRENCY, async (item, index) => {
					const r = await runSingleAgent(
						ctx.cwd,
						dispatchDefaults,
						agents,
						item.agent,
						item.task,
						item.cwd,
						index + 1,
						signal,
					);
					results.push(r);
				});
				results.sort((a, b) => (a.step ?? 0) - (b.step ?? 0));
			} else {
				results.push(
					await runSingleAgent(
						ctx.cwd,
						dispatchDefaults,
						agents,
						params.agent!,
						params.task!,
						params.cwd,
						undefined,
						signal,
					),
				);
			}

			const failed = results.filter((r) => r.exitCode !== 0);
			const statusLine = failed.length
				? `⚠ ${failed.length}/${results.length} subagent(s) failed`
				: `✓ ${results.length} subagent run(s) completed`;
			const totalUsage = results.reduce(
				(acc, r) => ({
					input: acc.input + r.usage.input,
					output: acc.output + r.usage.output,
					cost: acc.cost + r.usage.cost,
					turns: acc.turns + r.usage.turns,
				}),
				{ input: 0, output: 0, cost: 0, turns: 0 },
			);

			return {
				content: [
					{
						type: "text",
						text: `${statusLine} · total ${formatUsageStats(totalUsage)}\n\n${results.map(renderResult).join("\n\n---\n\n")}`,
					},
				],
				details: {
					mode: hasChain ? "chain" : hasTasks ? "parallel" : "single",
					results: results.map((r) => ({
						agent: r.agent,
						exitCode: r.exitCode,
						usage: r.usage,
						finalText: getFinalText(r),
					})),
				},
			};
		},
	});
}
