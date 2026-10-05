#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PS_SCRIPT="${SCRIPT_DIR}/deploy-merge-queue.ps1"
mode="${1:---dry-run}"

case "$mode" in
  --dry-run)
    exec pwsh -NoProfile -File "$PS_SCRIPT" -DryRun
    ;;
  --preflight)
    exec pwsh -NoProfile -File "$PS_SCRIPT" -Preflight
    ;;
  --apply)
    exec pwsh -NoProfile -File "$PS_SCRIPT" -Apply
    ;;
  --rollback)
    if [[ $# -ne 2 ]]; then
      echo "Usage: $0 --rollback <snapshot-path>" >&2
      exit 2
    fi
    exec pwsh -NoProfile -File "$PS_SCRIPT" -Rollback -BackupPath "$2"
    ;;
  *)
    echo "Usage: $0 [--dry-run|--preflight|--apply|--rollback <snapshot-path>]" >&2
    exit 2
    ;;
esac
