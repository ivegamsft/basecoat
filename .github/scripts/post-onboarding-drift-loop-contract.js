'use strict';

const getSurfaceStatus = surface =>
  typeof surface === 'string' ? surface : surface?.status;

const isUnknownSurface = surface =>
  surface && (
    surface.unknown === true ||
    getSurfaceStatus(surface) === 'inaccessible' ||
    getSurfaceStatus(surface) === 'unknown'
  );

const countSurfaces = surfaces =>
  Object.values(surfaces || {}).reduce((counts, surface) => {
    if (getSurfaceStatus(surface) === 'drift' || surface.hasDrift === true) {
      counts.driftCount += 1;
    }
    if (isUnknownSurface(surface)) {
      counts.unknownCount += 1;
    }
    return counts;
  }, { driftCount: 0, unknownCount: 0 });

const surfaceFromProbes = (probes, okDetail, missingPrefix) => {
  const inaccessible = probes.filter(item => item.inaccessible);
  const unknown = probes.filter(item => item.unknown);
  const missing = probes.filter(item => !item.exists && !item.inaccessible && !item.unknown);
  const unresolved = probes.filter(item => item.inaccessible || item.unknown);
  if (unresolved.length > 0) {
    return {
      status: unknown.length > 0 ? 'unknown' : 'inaccessible',
      detail: [
        missing.length > 0 ? `${missingPrefix}${missing.map(item => item.path).join(', ')}` : '',
        inaccessible.length > 0
          ? `token cannot read ${inaccessible.map(item => `${item.path} (${item.detail})`).join(', ')}`
          : '',
        unknown.length > 0
          ? `unable to verify ${unknown.map(item => `${item.path} (${item.detail})`).join(', ')}`
          : ''
      ].filter(Boolean).join('; '),
      hasDrift: missing.length > 0
    };
  }
  if (missing.length > 0) {
    return {
      status: 'drift',
      detail: `${missingPrefix}${missing.map(item => item.path).join(', ')}`
    };
  }
  return { status: 'ok', detail: okDetail };
};

const getUnknownCount = row =>
  Number.isInteger(row?.unknownCount) && row.unknownCount >= 0
    ? row.unknownCount
    : countSurfaces(row?.surfaces).unknownCount;

const getDriftCount = row =>
  Number.isInteger(row?.driftCount) && row.driftCount >= 0
    ? row.driftCount
    : countSurfaces(row?.surfaces).driftCount;

const trendFor = (current, previous) => {
  if (getUnknownCount(current) > 0 || (previous && getUnknownCount(previous) > 0)) {
    return 'unknown';
  }
  if (!previous) {
    return 'new';
  }

  const currentDriftCount = getDriftCount(current);
  const previousDriftCount = getDriftCount(previous);
  if (currentDriftCount > previousDriftCount) {
    return 'regression';
  }
  if (currentDriftCount < previousDriftCount) {
    return 'improvement';
  }
  return 'stable';
};

const canCloseRemediation = row =>
  getDriftCount(row) === 0 && getUnknownCount(row) === 0;

module.exports = { canCloseRemediation, countSurfaces, surfaceFromProbes, trendFor };
