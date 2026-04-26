#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="${1:-$(pwd)}"
cd "$ROOT_DIR"

VERSION="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' version.json | head -n 1)"
if [[ -z "$VERSION" ]]; then
  echo "Unable to determine version from version.json" >&2
  exit 1
fi

DIST_DIR="$ROOT_DIR/dist"
STAGE_DIR="$DIST_DIR/stage/base-coat"
ARCHIVE_BASE="base-coat-$VERSION"

rm -rf "$DIST_DIR"
mkdir -p "$STAGE_DIR"

for item in README.md CHANGELOG.md INVENTORY.md version.json sync.sh sync.ps1 instructions skills prompts agents scripts .githooks docs examples .github; do
  if [[ -e "$item" ]]; then
    cp -R "$item" "$STAGE_DIR/$item"
  fi
done

(cd "$DIST_DIR/stage" && zip -qr "../$ARCHIVE_BASE.zip" base-coat)
tar -C "$DIST_DIR/stage" -czf "$DIST_DIR/$ARCHIVE_BASE.tar.gz" base-coat

(cd "$DIST_DIR" && sha256sum "$ARCHIVE_BASE.zip" "$ARCHIVE_BASE.tar.gz" > SHA256SUMS.txt)

# Clean up staging directory so dist/ only contains release-ready files.
# Without this, `dist/*` globs (used by upload-artifact and gh release upload)
# include the stage directory, which causes upload failures. Fixes #86.
rm -rf "$DIST_DIR/stage"

echo "Packaged artifacts into $DIST_DIR"