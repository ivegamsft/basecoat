#!/usr/bin/env node

import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { McpServer } from "@modelcontextprotocol/server";
import { StdioServerTransport } from "@modelcontextprotocol/server/stdio";
import { z } from "zod";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, "..");
const allowedDirectories = new Set([
  "instructions",
  "skills",
  "prompts",
  "agents",
  "docs",
  "examples",
  "scripts",
  ".github",
]);
const allowedFiles = new Set([
  "README.md",
  "CHANGELOG.md",
  "version.json",
]);

function normalizeRelativePath(assetPath) {
  const normalized = path.posix
    .normalize(assetPath.replace(/\\/g, "/"))
    .replace(/^\//, "");
  if (!normalized || normalized === "." || normalized.startsWith("..")) {
    throw new Error(`Asset path is not allowed: ${assetPath}`);
  }

  const topLevel = normalized.split("/")[0];
  if (!allowedDirectories.has(topLevel) && !allowedFiles.has(normalized)) {
    throw new Error(`Asset path is not allowed: ${assetPath}`);
  }

  return normalized;
}

async function readTextFile(relativePath) {
  const normalized = normalizeRelativePath(relativePath);
  const fullPath = path.join(repoRoot, normalized);
  const contents = await fs.readFile(fullPath, "utf8");
  return {
    path: normalized,
    contents,
  };
}

async function collectFiles(relativeDir) {
  const root = path.join(repoRoot, relativeDir);
  const output = [];

  async function walk(currentDir) {
    const entries = await fs.readdir(currentDir, { withFileTypes: true });
    for (const entry of entries) {
      if (entry.name === "node_modules" || entry.name === ".git") {
        continue;
      }

      const fullPath = path.join(currentDir, entry.name);
      if (entry.isDirectory()) {
        await walk(fullPath);
      } else {
        output.push(path.relative(repoRoot, fullPath).replace(/\\/g, "/"));
      }
    }
  }

  await walk(root);
  output.sort((left, right) => left.localeCompare(right));
  return output;
}

async function getVersion() {
  const raw = await fs.readFile(path.join(repoRoot, "version.json"), "utf8");
  return JSON.parse(raw);
}

async function buildInventory() {
  const version = await getVersion();
  const groups = [
    "instructions",
    "skills",
    "prompts",
    "agents",
    "docs",
    "examples",
  ];

  const files = [];
  for (const group of groups) {
    const groupFiles = await collectFiles(group);
    files.push(...groupFiles);
  }

  return {
    name: version.name,
    version: version.version,
    releaseDate: version.releaseDate,
    files,
  };
}

function formatSearchResults(query, matches) {
  if (matches.length === 0) {
    return `No Base Coat assets matched query: ${query}`;
  }

  return [
    `Matches for query: ${query}`,
    ...matches.map((match) => `- ${match}`),
  ].join("\n");
}

async function runSelfTest() {
  const requiredPaths = [
    "README.md",
    "docs/reference/inventory.md",
    "version.json",
    "instructions/basecoat-10-core-mcp.instructions.md",
    "scripts/package-basecoat.sh",
    "scripts/package-basecoat.ps1",
  ];

  for (const requiredPath of requiredPaths) {
    await readTextFile(requiredPath);
  }

  const inventory = await buildInventory();
  process.stdout.write(JSON.stringify(inventory, null, 2));
}

async function runInventory() {
  const inventory = await buildInventory();
  process.stdout.write(JSON.stringify(inventory, null, 2));
}

async function main() {
  if (process.argv.includes("--self-test")) {
    await runSelfTest();
    return;
  }

  if (process.argv.includes("--inventory")) {
    await runInventory();
    return;
  }

  const version = await getVersion();
  const server = new McpServer({
    name: "basecoat-mcp",
    version: version.version,
  });

  server.registerTool(
    "basecoat_inventory",
    {
      description:
        "Return the Base Coat version and the list of packaged assets available to consumers.",
      inputSchema: {},
    },
    async () => {
      const inventory = await buildInventory();
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(inventory, null, 2),
          },
        ],
      };
    },
  );

  server.registerTool(
    "basecoat_read_asset",
    {
      description:
        "Read the contents of a specific packaged Base Coat asset by relative path.",
      inputSchema: {
        path: z.string().min(1),
      },
    },
    async ({ path: assetPath }) => {
      const asset = await readTextFile(assetPath);
      return {
        content: [
          {
            type: "text",
            text: `# ${asset.path}\n\n${asset.contents}`,
          },
        ],
      };
    },
  );

  server.registerTool(
    "basecoat_search_assets",
    {
      description:
        "Search packaged Base Coat asset paths using a case-insensitive substring match.",
      inputSchema: {
        query: z.string().min(1),
      },
    },
    async ({ query }) => {
      const inventory = await buildInventory();
      const matches = inventory.files.filter((file) =>
        file.toLowerCase().includes(query.toLowerCase()),
      );
      return {
        content: [
          {
            type: "text",
            text: formatSearchResults(query, matches),
          },
        ],
      };
    },
  );

  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((error) => {
  process.stderr.write(`${error.stack || error.message}\n`);
  process.exit(1);
});
