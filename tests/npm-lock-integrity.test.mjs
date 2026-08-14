import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import test from 'node:test';

import {
  CORPORATE_NPM_PROXY,
  buildProxyTarballUrl,
  fetchProxyTarballIntegrity,
  isInternalFeedUrl,
  isStrictSha512Integrity,
  mapWithConcurrency,
  repairLockfileData,
  runSequentiallyCollectingFailures,
  validateLockfileData,
  verifyLockfileData,
} from '../scripts/npm-lock-integrity.mjs';

const tarball = Buffer.from('proxy-delivered tarball');
const sha1 = `sha1-${createHash('sha1').update(tarball).digest('base64')}`;
const sha512 = `sha512-${createHash('sha512').update(tarball).digest('base64')}`;

test('builds tarball URLs only under the corporate proxy', () => {
  const url = buildProxyTarballUrl('@scope/example', '1.2.3');
  assert.equal(
    url,
    `${CORPORATE_NPM_PROXY}%40scope/example/-/example-1.2.3.tgz`,
  );
  assert.throws(
    () => buildProxyTarballUrl('../example', '1.2.3'),
    /Cannot build a proxy tarball URL/,
  );
});

const invalidIntegrities = [
  ['malformed digest text', 'sha512-not-a-digest'],
  ['wrong-length base64', `sha512-${Buffer.alloc(63).toString('base64')}`],
  ['mixed integrity tokens', `${sha512} ${sha512}`],
  ['extra token text', `${sha512} extra`],
  ['missing integrity', undefined],
  ['SHA-1 integrity', sha1],
];

for (const [label, integrity] of invalidIntegrities) {
  test(`strict SHA-512 validation rejects ${label}`, async () => {
    assert.equal(isStrictSha512Integrity(integrity), false);
    const lockData = {
      packages: {
        '': {},
        'node_modules/example': { version: '1.2.3', integrity },
      },
    };

    const errors = validateLockfileData(lockData, {
      lockfile: 'package-lock.json',
      publishable: false,
    });
    assert.equal(errors.length, 1);

    let repairs = 0;
    const result = await repairLockfileData(lockData, {
      publishable: false,
      fetchIntegrity: async (_name, _version, existingIntegrity) => {
        repairs += 1;
        assert.equal(existingIntegrity, integrity || undefined);
        return sha512;
      },
    });
    assert.equal(repairs, 1);
    assert.equal(result.data.packages['node_modules/example'].integrity, sha512);
  });
}

test('strict SHA-512 validation accepts one canonical 64-byte digest', () => {
  assert.equal(isStrictSha512Integrity(sha512), true);
});

test('follows trusted proxy storage redirects and verifies existing SHA-1', async () => {
  const requested = [];
  const fetchImpl = async (url) => {
    requested.push(url);
    if (requested.length === 1) {
      return new Response(null, {
        status: 303,
        headers: { location: 'https://unit.vsblob.vsassets.io/package.tgz' },
      });
    }
    return new Response(tarball, { status: 200 });
  };

  const actual = await fetchProxyTarballIntegrity(
    '@scope/example',
    '1.2.3',
    sha1,
    { fetchImpl },
  );

  assert.equal(actual, sha512);
  assert.equal(requested[0], buildProxyTarballUrl('@scope/example', '1.2.3'));
  assert.equal(requested[1], 'https://unit.vsblob.vsassets.io/package.tgz');
});

test('verifies every valid token in an existing mixed integrity set', async () => {
  const fetchImpl = async () => new Response(tarball, { status: 200 });
  const actual = await fetchProxyTarballIntegrity(
    '@scope/example',
    '1.2.3',
    `${sha1} ${sha512}`,
    { fetchImpl },
  );

  assert.equal(actual, sha512);
});

test('fails closed for a non-empty malformed existing integrity', async () => {
  const fetchImpl = async () => new Response(tarball, { status: 200 });
  await assert.rejects(
    fetchProxyTarballIntegrity(
      '@scope/example',
      '1.2.3',
      'sha512-not-a-digest',
      { fetchImpl },
    ),
    /has malformed integrity/,
  );
});

test('rejects redirects outside the corporate proxy delivery chain', async () => {
  const fetchImpl = async () =>
    new Response(null, {
      status: 302,
      headers: { location: 'https://registry.npmjs.org/example/-/example-1.2.3.tgz' },
    });

  await assert.rejects(
    fetchProxyTarballIntegrity('example', '1.2.3', sha1, { fetchImpl }),
    /untrusted tarball URL/,
  );
});

test('falls back to a trusted metadata tarball URL when the proxy tarball endpoint fails', async () => {
  const requested = [];
  const fetchImpl = async (url) => {
    requested.push(url);
    if (requested.length === 1) {
      return new Response(null, { status: 400 });
    }
    return new Response(tarball, { status: 200 });
  };

  const actual = await fetchProxyTarballIntegrity(
    '@scope/example',
    '1.2.3',
    sha1,
    {
      fetchImpl,
      resolveTarballUrl: async () => 'https://unit.vsblob.vsassets.io/package.tgz',
    },
  );

  assert.equal(actual, sha512);
  assert.equal(requested[0], buildProxyTarballUrl('@scope/example', '1.2.3'));
  assert.equal(requested[1], 'https://unit.vsblob.vsassets.io/package.tgz');
});

test('repairs integrity and strips resolved fields according to publication policy', async () => {
  const lockData = {
    lockfileVersion: 3,
    packages: {
      '': { name: '@basecoat/example', version: '1.0.0' },
      'node_modules/@scope/example': {
        version: '1.2.3',
        integrity: sha1,
        resolved:
          'https://ms-feed-17.pkgs.visualstudio.com/feed/npm/@scope/example/-/example-1.2.3.tgz',
      },
    },
  };

  const result = await repairLockfileData(lockData, {
    publishable: true,
    fetchIntegrity: async (name, version, existingIntegrity) => {
      assert.equal(name, '@scope/example');
      assert.equal(version, '1.2.3');
      assert.equal(existingIntegrity, sha1);
      return sha512;
    },
  });

  const repaired = result.data.packages['node_modules/@scope/example'];
  assert.equal(repaired.integrity, sha512);
  assert.equal('resolved' in repaired, false);
  assert.equal(lockData.packages['node_modules/@scope/example'].integrity, sha1);
  assert.deepEqual(
    { integrityRepairs: result.integrityRepairs, resolvedRemovals: result.resolvedRemovals },
    { integrityRepairs: 1, resolvedRemovals: 1 },
  );
});

test('repair rejects malformed integrity returned by a fetch implementation', async () => {
  const lockData = {
    packages: {
      '': {},
      'node_modules/example': { version: '1.2.3', integrity: sha1 },
    },
  };

  await assert.rejects(
    repairLockfileData(lockData, {
      publishable: false,
      fetchIntegrity: async () => 'sha512-not-a-digest',
    }),
    /fetch returned malformed SHA-512 integrity/,
  );
});

test('bounded worker pool never exceeds its concurrency limit', async () => {
  let active = 0;
  let maximumActive = 0;
  const visited = [];
  const items = Array.from({ length: 12 }, (_, index) => index);

  await mapWithConcurrency(
    items,
    async (item) => {
      active += 1;
      maximumActive = Math.max(maximumActive, active);
      await new Promise((resolve) => setTimeout(resolve, 5));
      visited.push(item);
      active -= 1;
    },
    3,
  );

  assert.equal(maximumActive, 3);
  assert.deepEqual([...visited].sort((left, right) => left - right), items);
});

test('verify uses bounded concurrency, attempts every entry, and reports failures in order', async () => {
  const packages = { '': {} };
  for (let index = 0; index < 8; index += 1) {
    packages[`node_modules/package-${index}`] = {
      version: `1.0.${index}`,
      integrity: sha512,
    };
  }

  let active = 0;
  let maximumActive = 0;
  const visited = [];
  await assert.rejects(
    verifyLockfileData(
      { packages },
      {
        concurrency: 2,
        lockfile: 'package-lock.json',
        fetchIntegrity: async (name) => {
          active += 1;
          maximumActive = Math.max(maximumActive, active);
          await new Promise((resolve) => setTimeout(resolve, 5));
          visited.push(name);
          active -= 1;
          if (name === 'package-2' || name === 'package-6') {
            throw new Error(`unavailable ${name}`);
          }
          return sha512;
        },
      },
    ),
    (error) => {
      assert.match(error.message, /package-2@1\.0\.2.*unavailable package-2/);
      assert.match(error.message, /package-6@1\.0\.6.*unavailable package-6/);
      assert.ok(error.message.indexOf('package-2') < error.message.indexOf('package-6'));
      return true;
    },
  );

  assert.equal(maximumActive, 2);
  assert.equal(visited.length, 8);
});

test('verification sequence continues through later lockfiles after failures', async () => {
  const lockfiles = ['first-lock.json', 'second-lock.json', 'third-lock.json'];
  const visited = [];

  const outcome = await runSequentiallyCollectingFailures(
    lockfiles,
    async (lockfile) => {
      visited.push(lockfile);
      if (lockfile !== 'second-lock.json') {
        throw new Error(`failed ${lockfile}`);
      }
      return `verified ${lockfile}`;
    },
  );

  assert.deepEqual(visited, lockfiles);
  assert.deepEqual(
    outcome.failures.map(({ item }) => item),
    ['first-lock.json', 'third-lock.json'],
  );
  assert.equal(outcome.results[1], 'verified second-lock.json');
});

test('validation rejects weak integrity, internal feeds, and publishable resolved fields', () => {
  const lockData = {
    packages: {
      '': {},
      'node_modules/example': {
        version: '1.2.3',
        integrity: sha1,
        resolved:
          'https://pkgs.dev.azure.com/org/project/_packaging/feed/npm/registry/example/-/example-1.2.3.tgz',
      },
    },
  };

  const errors = validateLockfileData(lockData, {
    lockfile: 'package-lock.json',
    publishable: true,
  });
  assert.equal(errors.length, 3);
  assert.match(errors[0], /strict SHA-512/);
  assert.match(errors[1], /internal feed URL/);
  assert.match(errors[2], /publishable package/);
  assert.equal(
    isInternalFeedUrl('https://registry.npmjs.org/example/-/example-1.2.3.tgz'),
    false,
  );
});
