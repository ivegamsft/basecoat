'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { canCloseRemediation, countSurfaces, surfaceFromProbes, trendFor } =
  require('../.github/scripts/post-onboarding-drift-loop-contract.js');
const workflow = fs.readFileSync(
  path.join(__dirname, '..', '.github', 'workflows', 'post-onboarding-drift-loop.yml'),
  'utf8'
).replace(/\r\n/g, '\n');
const scriptMarker = '          script: |\n';
const scriptStart = workflow.indexOf(scriptMarker);
assert.notEqual(scriptStart, -1, 'Expected the workflow github-script block.');
const scriptBodyStart = scriptStart + scriptMarker.length;
const scriptEnd = workflow.indexOf('\n      - name: Upload drift scorecard artifacts', scriptBodyStart);
assert.notEqual(scriptEnd, -1, 'Expected the github-script block to end before artifact upload.');
const scriptSource = workflow.slice(scriptBodyStart, scriptEnd)
  .split(/\r?\n/)
  .map(line => line.startsWith('            ') ? line.slice(12) : line)
  .join('\n');
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
assert.doesNotThrow(() => new AsyncFunction('github', 'context', 'core', 'getOctokit', 'require', scriptSource));

const complete = {
  branch_ruleset: { status: 'ok' },
  intake_surface: { status: 'ok' },
  reviewer_routing: { status: 'ok' },
  metadata_hygiene: { status: 'ok' }
};
const inaccessible = Object.fromEntries(
  Object.keys(complete).map(name => [name, { status: 'inaccessible' }])
);
const mixed = {
  branch_ruleset: { status: 'drift' },
  intake_surface: { status: 'ok' },
  reviewer_routing: { status: 'inaccessible' },
  metadata_hygiene: { status: 'unknown' }
};

assert.deepEqual(countSurfaces(complete), { driftCount: 0, unknownCount: 0 });
assert.equal(surfaceFromProbes(
  [{ path: 'present', exists: true, inaccessible: false, unknown: false }],
  'all files present',
  'missing: '
).status, 'ok');
assert.equal(trendFor(
  { driftCount: 0, unknownCount: 0, surfaces: complete },
  { driftCount: 0, unknownCount: 0, surfaces: complete }
), 'stable');
assert.equal(canCloseRemediation({ driftCount: 0, unknownCount: 0, surfaces: complete }), true);

assert.deepEqual(countSurfaces(inaccessible), { driftCount: 0, unknownCount: 4 });
assert.equal(surfaceFromProbes(
  [{ path: 'hidden', exists: false, inaccessible: true, unknown: false, detail: 'HTTP 403' }],
  'all files present',
  'missing: '
).status, 'inaccessible');
assert.equal(trendFor({ driftCount: 0, surfaces: inaccessible }, { driftCount: 0 }), 'unknown');
assert.equal(canCloseRemediation({ driftCount: 0, surfaces: inaccessible }), false);

assert.deepEqual(countSurfaces(mixed), { driftCount: 1, unknownCount: 2 });
const mixedProbeSurface = surfaceFromProbes([
  { path: 'missing', exists: false, inaccessible: false, unknown: false },
  { path: 'forbidden', exists: false, inaccessible: true, unknown: false, detail: 'HTTP 403' },
  { path: 'failed', exists: false, inaccessible: false, unknown: true, detail: 'HTTP 500' }
], 'all files present', 'missing: ');
assert.equal(mixedProbeSurface.status, 'unknown');
assert.equal(mixedProbeSurface.hasDrift, true);
assert.deepEqual(countSurfaces({ intake: mixedProbeSurface }), { driftCount: 1, unknownCount: 1 });
assert.equal(surfaceFromProbes(
  [{ path: 'not-found', exists: false, inaccessible: false, unknown: false }],
  'all files present',
  'missing: '
).status, 'drift');
assert.equal(trendFor({ driftCount: 1, surfaces: mixed }, { driftCount: 0 }), 'unknown');
assert.equal(canCloseRemediation({ driftCount: 1, surfaces: mixed }), false);

assert.equal(trendFor(
  { driftCount: 0, unknownCount: 0, surfaces: complete },
  { driftCount: 2, unknownCount: 0, surfaces: { branch_ruleset: { status: 'drift' } } }
), 'improvement');
assert.equal(canCloseRemediation({ driftCount: 0, unknownCount: 0, surfaces: complete }), true);
assert.equal(trendFor(
  { driftCount: 0, unknownCount: 0, surfaces: complete },
  { driftCount: 0, surfaces: inaccessible }
), 'unknown');

console.log('PASS post-onboarding drift contract fixtures.');
