#!/usr/bin/env node

import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const CORPORATE_NPM_PROXY = 'https://packagefeedproxy.microsoft.io/npm/';

const TRUSTED_REDIRECT_SUFFIXES = [
  '.vsassets.io',
  '.blob.core.windows.net',
];

const INTEGRITY_DIGEST_LENGTHS = new Map([
  ['sha1', 20],
  ['sha256', 32],
  ['sha384', 48],
  ['sha512', 64],
]);

function cloneJson(value) {
  return JSON.parse(JSON.stringify(value));
}

function parseSingleIntegrity(value) {
  if (typeof value !== 'string') {
    return null;
  }

  const match = /^(sha1|sha256|sha384|sha512)-([A-Za-z0-9+/]+={0,2})$/.exec(value);
  if (!match) {
    return null;
  }

  const [, algorithm, encodedDigest] = match;
  const decodedDigest = Buffer.from(encodedDigest, 'base64');
  if (
    decodedDigest.length !== INTEGRITY_DIGEST_LENGTHS.get(algorithm) ||
    decodedDigest.toString('base64') !== encodedDigest
  ) {
    return null;
  }

  return { algorithm, encodedDigest };
}

function parseIntegritySet(value) {
  if (typeof value !== 'string' || value.length === 0) {
    return null;
  }

  const tokens = value.split(/\s+/);
  const parsedTokens = tokens.map(parseSingleIntegrity);
  return parsedTokens.every(Boolean) ? parsedTokens : null;
}

export function isStrictSha512Integrity(value) {
  return parseSingleIntegrity(value)?.algorithm === 'sha512';
}

export function packageNameFromLockPath(packagePath, packageEntry) {
  if (typeof packageEntry.name === 'string' && packageEntry.name.length > 0) {
    return packageEntry.name;
  }

  const marker = 'node_modules/';
  const markerIndex = packagePath.lastIndexOf(marker);
  if (markerIndex === -1) {
    throw new Error(`Cannot derive a package name from lockfile path '${packagePath}'.`);
  }

  const remainder = packagePath.slice(markerIndex + marker.length);
  const segments = remainder.split('/');
  if (segments[0].startsWith('@')) {
    if (segments.length < 2) {
      throw new Error(`Scoped package path '${packagePath}' is incomplete.`);
    }
    return `${segments[0]}/${segments[1]}`;
  }

  return segments[0];
}

export function buildProxyTarballUrl(packageName, version) {
  if (
    typeof packageName !== 'string' ||
    !/^(@[^/]+\/)?[^/@]+$/.test(packageName) ||
    typeof version !== 'string' ||
    version.length === 0
  ) {
    throw new Error(`Cannot build a proxy tarball URL for '${packageName}@${version}'.`);
  }

  const nameSegments = packageName.split('/').map(encodeURIComponent);
  const tarballName = packageName.split('/').at(-1);
  const pathname = [
    ...nameSegments,
    '-',
    `${encodeURIComponent(tarballName)}-${encodeURIComponent(version)}.tgz`,
  ].join('/');

  return new URL(pathname, CORPORATE_NPM_PROXY).href;
}

export function isInternalFeedUrl(value) {
  if (typeof value !== 'string') {
    return false;
  }

  let url;
  try {
    url = new URL(value);
  } catch {
    return false;
  }

  const host = url.hostname.toLowerCase();
  return (
    host === 'packagefeedproxy.microsoft.io' ||
    host.endsWith('.pkgs.visualstudio.com') ||
    host === 'pkgs.dev.azure.com'
  );
}

export function isTrustedProxyRedirect(value) {
  let url;
  try {
    url = new URL(value);
  } catch {
    return false;
  }

  if (url.protocol !== 'https:') {
    return false;
  }

  const host = url.hostname.toLowerCase();
  return (
    host === 'packagefeedproxy.microsoft.io' ||
    TRUSTED_REDIRECT_SUFFIXES.some((suffix) => host.endsWith(suffix))
  );
}

function digest(buffer, algorithm) {
  return `${algorithm}-${createHash(algorithm).update(buffer).digest('base64')}`;
}

function verifyExistingIntegrity(buffer, existingIntegrity, packageId) {
  if (typeof existingIntegrity !== 'string' || existingIntegrity.length === 0) {
    return;
  }

  const parsedTokens = parseIntegritySet(existingIntegrity);
  if (!parsedTokens) {
    throw new Error(`${packageId} has malformed integrity '${existingIntegrity}'.`);
  }

  for (const parsed of parsedTokens) {
    const expected = `${parsed.algorithm}-${parsed.encodedDigest}`;
    const actual = digest(buffer, parsed.algorithm);
    if (actual !== expected) {
      throw new Error(
        `${packageId} proxy tarball does not match an existing ${parsed.algorithm} integrity.`,
      );
    }
  }
}

export async function fetchProxyTarballIntegrity(
  packageName,
  version,
  existingIntegrity,
  options = {},
) {
  const fetchImpl = options.fetchImpl ?? globalThis.fetch;
  const maxRedirects = options.maxRedirects ?? 5;
  const packageId = `${packageName}@${version}`;
  let url = buildProxyTarballUrl(packageName, version);

  for (let redirectCount = 0; redirectCount <= maxRedirects; redirectCount += 1) {
    if (!isTrustedProxyRedirect(url)) {
      throw new Error(`${packageId} attempted an untrusted tarball URL: ${url}`);
    }

    const response = await fetchImpl(url, {
      headers: { 'user-agent': 'basecoat-npm-lock-integrity/1' },
      redirect: 'manual',
      signal: AbortSignal.timeout(120_000),
    });

    if (response.status >= 300 && response.status < 400) {
      const location = response.headers.get('location');
      if (!location) {
        throw new Error(`${packageId} proxy redirect did not include a location.`);
      }
      url = new URL(location, url).href;
      continue;
    }

    if (!response.ok) {
      throw new Error(`${packageId} proxy tarball request failed with HTTP ${response.status}.`);
    }

    const buffer = Buffer.from(await response.arrayBuffer());
    verifyExistingIntegrity(buffer, existingIntegrity, packageId);
    const integrity = digest(buffer, 'sha512');
    if (!isStrictSha512Integrity(integrity)) {
      throw new Error(`${packageId} generated an invalid SHA-512 integrity value.`);
    }
    return integrity;
  }

  throw new Error(`${packageId} exceeded ${maxRedirects} proxy redirects.`);
}

function isRegistryPackage(packagePath, packageEntry) {
  return (
    packagePath.includes('node_modules/') &&
    packageEntry?.link !== true &&
    typeof packageEntry?.version === 'string' &&
    packageEntry.version.length > 0
  );
}

export function validateLockfileData(lockData, options) {
  const errors = [];
  const packages = lockData?.packages;
  if (!packages || typeof packages !== 'object') {
    return [`${options.lockfile}: missing npm lockfile 'packages' object.`];
  }

  for (const [packagePath, packageEntry] of Object.entries(packages)) {
    if (!packageEntry || typeof packageEntry !== 'object') {
      continue;
    }

    const label = packagePath || '<root>';
    if (isRegistryPackage(packagePath, packageEntry)) {
      if (typeof packageEntry.integrity !== 'string') {
        errors.push(`${options.lockfile}: ${label} is missing integrity.`);
      } else if (!isStrictSha512Integrity(packageEntry.integrity)) {
        errors.push(
          `${options.lockfile}: ${label} does not contain one strict SHA-512 integrity value.`,
        );
      }
    }

    if ('resolved' in packageEntry) {
      if (isInternalFeedUrl(packageEntry.resolved)) {
        errors.push(
          `${options.lockfile}: ${label} contains internal feed URL '${packageEntry.resolved}'.`,
        );
      }
      if (options.publishable) {
        errors.push(
          `${options.lockfile}: ${label} contains a resolved field in a publishable package.`,
        );
      }
    }
  }

  return errors;
}

export async function mapWithConcurrency(items, worker, concurrency = 6) {
  const limit = Math.max(1, Math.floor(concurrency));
  const results = new Array(items.length);
  const failures = [];
  let cursor = 0;

  const runWorker = async () => {
    while (cursor < items.length) {
      const index = cursor;
      cursor += 1;
      try {
        results[index] = await worker(items[index], index);
      } catch (error) {
        failures.push({ error, index });
      }
    }
  };

  await Promise.all(
    Array.from({ length: Math.min(limit, Math.max(1, items.length)) }, runWorker),
  );

  if (failures.length > 0) {
    failures.sort((left, right) => left.index - right.index);
    throw new AggregateError(
      failures.map(({ error }) => error),
      failures.map(({ error }) => error.message).join('\n'),
    );
  }

  return results;
}

export async function runSequentiallyCollectingFailures(items, worker) {
  const failures = [];
  const results = new Array(items.length);

  for (let index = 0; index < items.length; index += 1) {
    try {
      results[index] = await worker(items[index], index);
    } catch (error) {
      failures.push({ error, index, item: items[index] });
    }
  }

  return { failures, results };
}

export async function repairLockfileData(lockData, options) {
  const updated = cloneJson(lockData);
  const packages = updated.packages ?? {};
  const integrityRepairs = [];
  let resolvedRemovals = 0;

  for (const [packagePath, packageEntry] of Object.entries(packages)) {
    if (!packageEntry || typeof packageEntry !== 'object') {
      continue;
    }

    if (
      'resolved' in packageEntry &&
      (options.publishable || isInternalFeedUrl(packageEntry.resolved))
    ) {
      delete packageEntry.resolved;
      resolvedRemovals += 1;
    }

    if (
      isRegistryPackage(packagePath, packageEntry) &&
      !isStrictSha512Integrity(packageEntry.integrity)
    ) {
      const packageName = packageNameFromLockPath(packagePath, packageEntry);
      integrityRepairs.push({
        packageEntry,
        packageName,
        packagePath,
        version: packageEntry.version,
        existingIntegrity:
          typeof packageEntry.integrity === 'string' && packageEntry.integrity.length > 0
            ? packageEntry.integrity
            : undefined,
      });
    }
  }

  const concurrency = Math.max(1, options.concurrency ?? 6);
  await mapWithConcurrency(
    integrityRepairs,
    async (repair) => {
      const integrity = await options.fetchIntegrity(
        repair.packageName,
        repair.version,
        repair.existingIntegrity,
      );
      if (!isStrictSha512Integrity(integrity)) {
        throw new Error(
          `${repair.packageName}@${repair.version} fetch returned malformed SHA-512 integrity.`,
        );
      }
      repair.packageEntry.integrity = integrity;
    },
    concurrency,
  );

  return {
    data: updated,
    integrityRepairs: integrityRepairs.length,
    resolvedRemovals,
  };
}

function parseArguments(argv) {
  const modes = argv.filter((argument) =>
    ['--check', '--dry-run', '--apply', '--verify'].includes(argument),
  );
  if (modes.length !== 1) {
    throw new Error('Choose exactly one mode: --check, --dry-run, --apply, or --verify.');
  }

  const files = argv.filter((argument) => !argument.startsWith('--'));
  const unknown = argv.filter(
    (argument) =>
      argument.startsWith('--') &&
      !['--check', '--dry-run', '--apply', '--verify'].includes(argument),
  );
  if (unknown.length > 0) {
    throw new Error(`Unknown option(s): ${unknown.join(', ')}`);
  }

  return { mode: modes[0].slice(2), files };
}

function trackedLockfiles() {
  const output = execFileSync(
    'git',
    ['ls-files', '--', '**/package-lock.json', 'package-lock.json'],
    { encoding: 'utf8' },
  );
  return output.split(/\r?\n/).filter(Boolean);
}

async function loadLockfile(lockfile) {
  const absolutePath = path.resolve(lockfile);
  const packageJsonPath = path.join(path.dirname(absolutePath), 'package.json');
  const [lockText, packageText] = await Promise.all([
    readFile(absolutePath, 'utf8'),
    readFile(packageJsonPath, 'utf8'),
  ]);
  const packageData = JSON.parse(packageText);
  const indentation = lockText.match(/\r?\n(?<indent>[ \t]+)"/)?.groups?.indent ?? '  ';
  return {
    absolutePath,
    indentation,
    lockData: JSON.parse(lockText),
    packageData,
    publishable: packageData.private !== true,
  };
}

export async function verifyLockfileData(lockData, options) {
  const entries = Object.entries(lockData.packages ?? {})
    .filter(([packagePath, packageEntry]) =>
      isRegistryPackage(packagePath, packageEntry),
    )
    .map(([packagePath, packageEntry]) => ({
      integrity: packageEntry.integrity,
      packageName: packageNameFromLockPath(packagePath, packageEntry),
      packagePath,
      version: packageEntry.version,
    }));

  await mapWithConcurrency(
    entries,
    async (entry) => {
      try {
        await options.fetchIntegrity(
          entry.packageName,
          entry.version,
          entry.integrity,
        );
      } catch (error) {
        throw new Error(
          `${options.lockfile}: ${entry.packagePath} ` +
            `(${entry.packageName}@${entry.version}): ${error.message}`,
        );
      }
    },
    options.concurrency ?? 6,
  );

  return entries.length;
}

async function verifyLockfile(lockfile, loaded) {
  const verified = await verifyLockfileData(loaded.lockData, {
    concurrency: 6,
    fetchIntegrity: fetchProxyTarballIntegrity,
    lockfile,
  });
  console.log(`${lockfile}: verified ${verified} proxy tarball SHA-512 integrities`);
}

async function main() {
  const { mode, files: requestedFiles } = parseArguments(process.argv.slice(2));
  const files = requestedFiles.length > 0 ? requestedFiles : trackedLockfiles();
  if (files.length === 0) {
    throw new Error('No package-lock.json files were found.');
  }

  if (mode === 'verify') {
    const { failures } = await runSequentiallyCollectingFailures(
      files,
      async (lockfile) => {
        const loaded = await loadLockfile(lockfile);
        const errors = validateLockfileData(loaded.lockData, {
          lockfile,
          publishable: loaded.publishable,
        });
        if (errors.length > 0) {
          throw new Error(errors.join('\n'));
        }
        await verifyLockfile(lockfile, loaded);
      },
    );

    for (const { error } of failures) {
      console.error(`ERROR: ${error.message}`);
    }
    if (failures.length > 0) {
      process.exitCode = 1;
    }
    return;
  }

  let errorCount = 0;
  for (const lockfile of files) {
    const loaded = await loadLockfile(lockfile);

    if (mode === 'check') {
      const errors = validateLockfileData(loaded.lockData, {
        lockfile,
        publishable: loaded.publishable,
      });
      if (errors.length > 0) {
        errors.forEach((error) => console.error(`ERROR: ${error}`));
        errorCount += errors.length;
        continue;
      }
      console.log(`${lockfile}: lock integrity policy passed`);
      continue;
    }

    const result = await repairLockfileData(loaded.lockData, {
      publishable: loaded.publishable,
      fetchIntegrity: fetchProxyTarballIntegrity,
    });
    const changes = result.integrityRepairs + result.resolvedRemovals;

    const errors = validateLockfileData(result.data, {
      lockfile,
      publishable: loaded.publishable,
    });
    if (errors.length > 0) {
      errors.forEach((error) => console.error(`ERROR: ${error}`));
      errorCount += errors.length;
      continue;
    }

    if (mode === 'apply' && changes > 0) {
      await writeFile(
        loaded.absolutePath,
        `${JSON.stringify(result.data, null, loaded.indentation)}\n`,
        'utf8',
      );
    }

    const action =
      changes === 0 ? 'no changes' : mode === 'apply' ? 'updated' : 'would update';
    console.log(
      `${lockfile}: ${action}; SHA-512 repairs=${result.integrityRepairs}, ` +
        `resolved removals=${result.resolvedRemovals}`,
    );
  }

  if (errorCount > 0) {
    process.exitCode = 1;
  }
}

const invokedPath = process.argv[1] ? path.resolve(process.argv[1]) : '';
if (invokedPath === fileURLToPath(import.meta.url)) {
  main().catch((error) => {
    console.error(`ERROR: ${error.message}`);
    process.exitCode = 1;
  });
}
