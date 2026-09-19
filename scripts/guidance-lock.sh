#!/usr/bin/env bash

guidance_normalize_path() {
  local path="${1//\\//}"
  while [[ "$path" == ./* ]]; do path="${path#./}"; done
  while [[ "$path" == *//* ]]; do path="${path//\/\//\/}"; done

  if [[ -z "$path" || "$path" == /* || "$path" == */ || "$path" == "." || "$path" == ".." ||
        "$path" == ../* || "$path" == */../* || "$path" == */.. ||
        "$path" == ./* || "$path" == */./* || "$path" == */. ||
        ! "$path" =~ ^[A-Za-z0-9._/+@()-]+$ ]]; then
    echo "GUIDANCE_LOCK_INVALID path='$1' reason='path must be a normalized repository-relative file path'" >&2
    return 1
  fi
  case "$path" in
    .github/skills/*|.github/agents/*|.github/instructions/*|.github/prompts/*|.agents/skills/*) ;;
    *)
      echo "GUIDANCE_LOCK_INVALID path='$1' reason='path is outside the shared guidance destinations'" >&2
      return 1
      ;;
  esac
  printf '%s' "$path"
}

guidance_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print tolower($1)}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print tolower($1)}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 "$1" | sed -E 's/^.*= //' | tr '[:upper:]' '[:lower:]'
  else
    echo "GUIDANCE_LOCK_INVALID reason='sha256sum, shasum, or openssl is required'" >&2
    return 1
  fi
}

guidance_validate_field() {
  local name="$1" value="$2"
  if [[ -n "$value" && ( ${#value} -gt 512 || ! "$value" =~ ^[A-Za-z0-9][A-Za-z0-9._/+:-]*$ ) ]]; then
    echo "GUIDANCE_LOCK_INVALID field='$name' reason='optional metadata must use the portable [A-Za-z0-9._/+:-] vocabulary'" >&2
    return 1
  fi
}

# Reads the canonical guidance-lock/v1 JSON representation into a pipe-delimited
# file: path, owner, guidanceUnit, sourceVersion, sha256. The portable contract
# vocabulary excludes "|" so omitted optional columns remain lossless.
guidance_read_lock() {
  local lock_path="$1" output_tsv="$2"
  : > "$output_tsv"
  if [[ -e "$lock_path" || -L "$lock_path" ]]; then
    if [[ -L "$lock_path" || ! -f "$lock_path" ]]; then
      echo "GUIDANCE_LOCK_INVALID file='$lock_path' reason='lock path must be a regular file'" >&2
      return 1
    fi
  else
    return 0
  fi

  local compact body
  compact="$(tr -d '\r\n\t ' < "$lock_path")"
  case "$compact" in
    '{"schema":"guidance-lock/v1","entries":['*']}') ;;
    *)
      echo "GUIDANCE_LOCK_INVALID file='$lock_path' reason='malformed JSON or unsupported schema'" >&2
      return 1
      ;;
  esac
  body="${compact#\{\"schema\":\"guidance-lock/v1\",\"entries\":\[}"
  body="${body%\]\}}"
  [[ -z "$body" ]] && return 0

  printf '%s\n' "$body" | sed 's/},{/}\n{/g' | while IFS= read -r object; do
    local path owner unit version hash rest
    path="$(printf '%s' "$object" | sed -nE 's/^\{"path":"([^"]+)","owner":".*$/\1/p')"
    owner="$(printf '%s' "$object" | sed -nE 's/^\{"path":"[^"]+","owner":"([^"]+)".*$/\1/p')"
    hash="$(printf '%s' "$object" | sed -nE 's/^.*,"sha256":"([a-f0-9]{64})"\}$/\1/p')"
    unit="$(printf '%s' "$object" | sed -nE 's/^.*,"guidanceUnit":"([^"]*)".*$/\1/p')"
    version="$(printf '%s' "$object" | sed -nE 's/^.*,"sourceVersion":"([^"]*)".*$/\1/p')"
    rest="$(printf '%s' "$object" | sed -E \
      -e 's/^\{"path":"[^"]+","owner":"[^"]+"//' \
      -e 's/,"guidanceUnit":"[^"]*"//' \
      -e 's/,"sourceVersion":"[^"]*"//' \
      -e 's/,"sha256":"[a-f0-9]{64}"\}$//')"

    if [[ -z "$path" || -z "$owner" || -z "$hash" || -n "$rest" ||
          ! "$owner" =~ ^[a-z0-9][a-z0-9._-]*$ ]]; then
      echo "GUIDANCE_LOCK_INVALID file='$lock_path' reason='invalid or non-canonical entry'" >&2
      return 1
    fi
    path="$(guidance_normalize_path "$path")" || return 1
    guidance_validate_field guidanceUnit "$unit" || return 1
    guidance_validate_field sourceVersion "$version" || return 1
    printf '%s|%s|%s|%s|%s\n' "$path" "$owner" "$unit" "$version" "$hash"
  done > "$output_tsv"

  if [[ "$(cut -d '|' -f1 "$output_tsv" | sort | uniq -d | wc -l | tr -d ' ')" -ne 0 ]]; then
    echo "GUIDANCE_LOCK_INVALID file='$lock_path' reason='duplicate path entry'" >&2
    return 1
  fi
}

guidance_enter_lease() {
  local repo_root="$1" timeout_seconds="${2:-30}"
  local lease_path="$repo_root/.github/base-coat/guidance-lock.lease"
  local deadline=$((SECONDS + timeout_seconds))
  mkdir -p "$(dirname "$lease_path")"
  while ! mkdir "$lease_path" 2>/dev/null; do
    if (( SECONDS >= deadline )); then
      echo "GUIDANCE_LOCK_BUSY lease='$lease_path' timeoutSeconds='$timeout_seconds'" >&2
      return 1
    fi
    sleep 0.1
  done
  printf 'pid=%s\nacquired=%s\n' "$$" "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" > "$lease_path/owner"
  printf '%s' "$lease_path"
}

guidance_exit_lease() {
  [[ -n "${1:-}" ]] && rm -rf "$1"
}

guidance_write_lock() {
  local lock_path="$1" input_tsv="$2"
  local parent temporary first=true
  parent="$(dirname "$lock_path")"
  mkdir -p "$parent"
  temporary="$lock_path.$$.tmp"
  {
    printf '{\n  "schema": "guidance-lock/v1",\n  "entries": [\n'
    while IFS='|' read -r path owner unit version hash; do
      [[ -z "$path" ]] && continue
      if [[ "$first" == false ]]; then printf ',\n'; fi
      first=false
      printf '    {"path":"%s","owner":"%s"' "$path" "$owner"
      [[ -n "$unit" ]] && printf ',"guidanceUnit":"%s"' "$unit"
      [[ -n "$version" ]] && printf ',"sourceVersion":"%s"' "$version"
      printf ',"sha256":"%s"}' "$hash"
    done < <(sort -t '|' -k1,1 "$input_tsv")
    printf '\n  ]\n}\n'
  } > "$temporary"
  mv -f "$temporary" "$lock_path"
}
