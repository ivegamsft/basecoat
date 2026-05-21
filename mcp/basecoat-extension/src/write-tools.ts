import { createHash } from "node:crypto";
import { spawn } from "node:child_process";
import { access, mkdir, writeFile } from "node:fs/promises";
import path from "node:path";

export type WriteToolName = "scaffold" | "validate" | "create-pr";

type ToolStatus = "needs_confirmation" | "success" | "error" | "blocked";

type ConfirmableRequest = {
  confirm?: boolean;
  confirmationToken?: string;
};

type AssetType = "agent" | "skill" | "instruction" | "prompt";

type ScaffoldRequest = ConfirmableRequest & {
  assetType: AssetType;
  name: string;
  description?: string;
};

type ValidateRequest = ConfirmableRequest & {
  scope?: "full" | "structure";
};

type CreatePrRequest = ConfirmableRequest & {
  title: string;
  body: string;
  headBranch: string;
  baseBranch?: string;
  draft?: boolean;
};

type CommandResult = {
  exitCode: number;
  stdout: string;
  stderr: string;
};

export type WriteToolResult = {
  tool: WriteToolName;
  status: ToolStatus;
  message: string;
  confirmationToken?: string;
  preview?: unknown;
  result?: unknown;
  errorCode?: string;
};

export class WriteToolError extends Error {
  readonly code: string;

  constructor(code: string, message: string) {
    super(message);
    this.name = "WriteToolError";
    this.code = code;
  }
}

function stableStringify(value: unknown): string {
  if (value === null || typeof value !== "object") {
    return JSON.stringify(value);
  }

  if (Array.isArray(value)) {
    return `[${value.map(stableStringify).join(",")}]`;
  }

  const entries = Object.entries(value as Record<string, unknown>).sort(([a], [b]) =>
    a.localeCompare(b),
  );
  return `{${entries
    .map(([key, nested]) => `${JSON.stringify(key)}:${stableStringify(nested)}`)
    .join(",")}}`;
}

function confirmationToken(tool: WriteToolName, payload: unknown): string {
  const hash = createHash("sha256");
  hash.update(`${tool}:${stableStringify(payload)}`);
  return hash.digest("hex");
}

function normalizeName(name: string): string {
  return name
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

function assertSafePath(repoRoot: string, relativePath: string): string {
  const absolute = path.resolve(repoRoot, relativePath);
  const normalizedRoot = `${path.resolve(repoRoot)}${path.sep}`;
  if (!absolute.startsWith(normalizedRoot)) {
    throw new WriteToolError("unsafe_path", `Path '${relativePath}' resolves outside repository root.`);
  }

  return absolute;
}

async function exists(targetPath: string): Promise<boolean> {
  try {
    await access(targetPath);
    return true;
  } catch {
    return false;
  }
}

function getScaffoldTarget(assetType: AssetType, slug: string): string {
  switch (assetType) {
    case "agent":
      return `agents/${slug}.agent.md`;
    case "instruction":
      return `instructions/${slug}.instructions.md`;
    case "prompt":
      return `prompts/${slug}.prompt.md`;
    case "skill":
      return `skills/${slug}/SKILL.md`;
    default:
      throw new WriteToolError("invalid_asset_type", `Unsupported asset type: ${assetType}`);
  }
}

function getScaffoldContent(input: { assetType: AssetType; name: string; description: string }): string {
  const frontmatterName =
    input.assetType === "skill"
      ? path.basename(input.name).trim()
      : input.name.trim().toLowerCase().replace(/\s+/g, "-");

  const description = input.description.trim();
  if (input.assetType === "skill") {
    return `---
name: ${frontmatterName}
description: "${description}"
---

## Purpose

Describe when to use this skill and what outcomes it should drive.

## Inputs

- List expected input parameters and constraints.

## Outputs

- List output shape and expected quality bars.
`;
  }

  const applyTo = input.assetType === "instruction" ? "\napplyTo: \"**/*\"" : "";
  return `---
name: ${frontmatterName}
description: "${description}"${applyTo}
---

## Overview

Summarize the asset intent and boundaries.

## Guidance

- Add concrete, testable guidance.
`;
}

function truncateOutput(text: string): string {
  const max = 4000;
  if (text.length <= max) {
    return text;
  }
  return `${text.slice(0, max)}\n...[truncated]`;
}

async function runCommand(
  command: string,
  args: string[],
  cwd: string,
  timeoutMs: number,
): Promise<CommandResult> {
  return await new Promise<CommandResult>((resolve, reject) => {
    const child = spawn(command, args, {
      cwd,
      stdio: ["ignore", "pipe", "pipe"],
      shell: false,
      windowsHide: true,
    });

    let stdout = "";
    let stderr = "";

    const timeout = setTimeout(() => {
      child.kill();
      reject(new WriteToolError("command_timeout", `Command timed out: ${command} ${args.join(" ")}`));
    }, timeoutMs);

    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString();
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });

    child.on("error", (error) => {
      clearTimeout(timeout);
      reject(new WriteToolError("command_start_failed", error.message));
    });

    child.on("close", (code) => {
      clearTimeout(timeout);
      resolve({
        exitCode: code ?? 1,
        stdout,
        stderr,
      });
    });
  });
}

function resolveRepoRoot(): string {
  const explicit = process.env.BASECOAT_REPO_ROOT?.trim();
  if (explicit) {
    return path.resolve(explicit);
  }

  const cwd = process.cwd();
  if (cwd.endsWith(`${path.sep}mcp${path.sep}basecoat-extension`)) {
    return path.resolve(cwd, "..", "..");
  }

  return cwd;
}

function getTokenCheckedPayload<T extends ConfirmableRequest>(tool: WriteToolName, input: T): T {
  const { confirm: _confirm, confirmationToken: _confirmationToken, ...payload } = input as T & {
    confirm?: boolean;
    confirmationToken?: string;
  };
  const expected = confirmationToken(tool, payload);

  if (!input.confirm) {
    throw new WriteToolError("needs_confirmation", "Confirmation required to run write action.");
  }

  if (input.confirmationToken !== expected) {
    throw new WriteToolError("confirmation_mismatch", "Invalid or stale confirmation token.");
  }

  return payload as T;
}

export class WriteToolService {
  private readonly repoRoot: string;

  constructor(repoRoot?: string) {
    this.repoRoot = repoRoot ?? resolveRepoRoot();
  }

  async execute(tool: WriteToolName, rawInput: unknown): Promise<WriteToolResult> {
    try {
      switch (tool) {
        case "scaffold":
          return await this.scaffold(rawInput);
        case "validate":
          return await this.validate(rawInput);
        case "create-pr":
          return await this.createPr(rawInput);
        default:
          throw new WriteToolError("unknown_tool", `Unknown write tool: ${tool}`);
      }
    } catch (error) {
      if (error instanceof WriteToolError) {
        return {
          tool,
          status: error.code === "blocked_external_dependency" ? "blocked" : "error",
          message: error.message,
          errorCode: error.code,
        };
      }

      const message = error instanceof Error ? error.message : "Unknown tool error";
      return {
        tool,
        status: "error",
        message,
        errorCode: "internal_error",
      };
    }
  }

  private parseScaffold(input: unknown): ScaffoldRequest {
    if (!input || typeof input !== "object") {
      throw new WriteToolError("invalid_input", "Scaffold input must be an object.");
    }

    const parsed = input as ScaffoldRequest;
    if (!parsed.assetType || !["agent", "skill", "instruction", "prompt"].includes(parsed.assetType)) {
      throw new WriteToolError("invalid_asset_type", "assetType must be one of: agent, skill, instruction, prompt.");
    }
    if (!parsed.name || typeof parsed.name !== "string") {
      throw new WriteToolError("invalid_name", "name is required.");
    }

    return {
      ...parsed,
      description: parsed.description?.trim() || `Scaffolded ${parsed.assetType} for ${parsed.name}`,
    };
  }

  private async scaffold(rawInput: unknown): Promise<WriteToolResult> {
    const input = this.parseScaffold(rawInput);
    const slug = normalizeName(input.name);

    if (!slug) {
      throw new WriteToolError("invalid_name", "name must include letters or numbers.");
    }

    const relativePath = getScaffoldTarget(input.assetType, slug);
    const content = getScaffoldContent({
      assetType: input.assetType,
      name: input.name,
      description: input.description ?? "",
    });

    const payload = {
      assetType: input.assetType,
      name: input.name,
      description: input.description,
      path: relativePath,
      content,
    };

    const token = confirmationToken("scaffold", payload);
    if (!input.confirm) {
      return {
        tool: "scaffold",
        status: "needs_confirmation",
        message: "Scaffold preview generated. Re-submit with confirm=true and the same confirmationToken to create files.",
        confirmationToken: token,
        preview: {
          files: [{ path: relativePath, content }],
        },
      };
    }

    getTokenCheckedPayload("scaffold", {
      ...payload,
      confirm: input.confirm,
      confirmationToken: input.confirmationToken,
    });

    const absolutePath = assertSafePath(this.repoRoot, relativePath);
    const parentDir = path.dirname(absolutePath);
    await mkdir(parentDir, { recursive: true });

    if (await exists(absolutePath)) {
      throw new WriteToolError("already_exists", `Target file already exists: ${relativePath}`);
    }

    await writeFile(absolutePath, content, "utf-8");

    return {
      tool: "scaffold",
      status: "success",
      message: `Scaffolded ${input.assetType} at ${relativePath}.`,
      result: { filesCreated: [relativePath] },
    };
  }

  private parseValidate(input: unknown): ValidateRequest {
    if (!input || typeof input !== "object") {
      return {};
    }

    const parsed = input as ValidateRequest;
    if (parsed.scope && !["full", "structure"].includes(parsed.scope)) {
      throw new WriteToolError("invalid_scope", "scope must be 'full' or 'structure'.");
    }
    return parsed;
  }

  private async validate(rawInput: unknown): Promise<WriteToolResult> {
    const input = this.parseValidate(rawInput);
    const scope = input.scope ?? "full";
    const commands =
      scope === "structure"
        ? [{ command: "pwsh", args: ["scripts/validate-basecoat.ps1"] }]
        : [
            { command: "pwsh", args: ["scripts/validate-basecoat.ps1"] },
            { command: "pwsh", args: ["tests/run-tests.ps1"] },
          ];

    const payload = { scope, commands };
    const token = confirmationToken("validate", payload);

    if (!input.confirm) {
      return {
        tool: "validate",
        status: "needs_confirmation",
        message: "Validation run is ready. Re-submit with confirm=true and confirmationToken to execute scripts.",
        confirmationToken: token,
        preview: payload,
      };
    }

    getTokenCheckedPayload("validate", {
      ...payload,
      confirm: input.confirm,
      confirmationToken: input.confirmationToken,
    });

    const outputs: Array<{ command: string; exitCode: number; stdout: string; stderr: string }> = [];
    for (const cmd of commands) {
      const run = await runCommand(cmd.command, cmd.args, this.repoRoot, 30 * 60 * 1000);
      outputs.push({
        command: `${cmd.command} ${cmd.args.join(" ")}`,
        exitCode: run.exitCode,
        stdout: truncateOutput(run.stdout),
        stderr: truncateOutput(run.stderr),
      });
      if (run.exitCode !== 0) {
        throw new WriteToolError("validation_failed", `Validation command failed: ${cmd.command} ${cmd.args.join(" ")}`);
      }
    }

    return {
      tool: "validate",
      status: "success",
      message: `Validation completed with scope '${scope}'.`,
      result: { outputs },
    };
  }

  private parseCreatePr(input: unknown): CreatePrRequest {
    if (!input || typeof input !== "object") {
      throw new WriteToolError("invalid_input", "create-pr input must be an object.");
    }

    const parsed = input as CreatePrRequest;
    if (!parsed.title || !parsed.body || !parsed.headBranch) {
      throw new WriteToolError("missing_fields", "title, body, and headBranch are required.");
    }

    return parsed;
  }

  private async createPr(rawInput: unknown): Promise<WriteToolResult> {
    const input = this.parseCreatePr(rawInput);
    const payload = {
      title: input.title,
      body: input.body,
      headBranch: input.headBranch,
      baseBranch: input.baseBranch ?? "main",
      draft: Boolean(input.draft),
    };

    const token = confirmationToken("create-pr", payload);
    if (!input.confirm) {
      return {
        tool: "create-pr",
        status: "needs_confirmation",
        message: "PR creation preview generated. Re-submit with confirm=true and confirmationToken to execute.",
        confirmationToken: token,
        preview: payload,
      };
    }

    getTokenCheckedPayload("create-pr", {
      ...payload,
      confirm: input.confirm,
      confirmationToken: input.confirmationToken,
    });

    if (process.env.BASECOAT_EXTENSION_ENABLE_PR_WRITES !== "true") {
      throw new WriteToolError(
        "blocked_external_dependency",
        "create-pr execution is blocked until GitHub App registration and write auth are available (tracked by issue #1073).",
      );
    }

    const args = [
      "pr",
      "create",
      "--title",
      payload.title,
      "--body",
      payload.body,
      "--head",
      payload.headBranch,
      "--base",
      payload.baseBranch,
    ];
    if (payload.draft) {
      args.push("--draft");
    }

    const run = await runCommand("gh", args, this.repoRoot, 5 * 60 * 1000);
    if (run.exitCode !== 0) {
      throw new WriteToolError("pr_create_failed", truncateOutput(run.stderr || run.stdout));
    }

    return {
      tool: "create-pr",
      status: "success",
      message: "Pull request created successfully.",
      result: {
        output: truncateOutput(run.stdout),
      },
    };
  }
}
