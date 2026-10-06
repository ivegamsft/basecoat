import { readdir, readFile, stat, writeFile } from 'node:fs/promises';
import path from 'node:path';

const distSourceRoot = path.resolve('dist/src');
const aliases = [
  ['@controllers/', 'controllers/'],
  ['@services/', 'services/'],
  ['@models/', 'models/'],
  ['@middleware/', 'middleware/'],
  ['@routes/', 'routes/'],
  ['@utils/', 'utils/'],
  ['@config/', 'config/'],
  ['@types/', 'types/'],
  ['@/', ''],
];

async function listJavaScriptFiles(directory) {
  const entries = await readdir(directory);
  const files = [];

  for (const entry of entries) {
    const fullPath = path.join(directory, entry);
    const entryStat = await stat(fullPath);
    if (entryStat.isDirectory()) {
      files.push(...(await listJavaScriptFiles(fullPath)));
    } else if (entry.endsWith('.js')) {
      files.push(fullPath);
    }
  }

  return files;
}

function rewriteSpecifier(specifier, filePath) {
  const alias = aliases.find(([prefix]) => specifier.startsWith(prefix));
  if (!alias) {
    return specifier;
  }

  const [, targetPrefix] = alias;
  const targetPath = path.join(distSourceRoot, targetPrefix, specifier.slice(alias[0].length));
  let relativePath = path.relative(path.dirname(filePath), targetPath).replaceAll(path.sep, '/');
  if (!relativePath.startsWith('.')) {
    relativePath = `./${relativePath}`;
  }

  return relativePath;
}

for (const filePath of await listJavaScriptFiles(distSourceRoot)) {
  const original = await readFile(filePath, 'utf8');
  const rewritten = original.replace(
    /(require\(\s*["'])(@[^"']+)(["']\s*\))/g,
    (match, prefix, specifier, suffix) => `${prefix}${rewriteSpecifier(specifier, filePath)}${suffix}`,
  );

  if (rewritten !== original) {
    await writeFile(filePath, rewritten);
  }
}
