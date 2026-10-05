#!/usr/bin/env bash

basecoat_distribution_excluded() {
  [[ ! -L "$1" ]] || { echo "Unsafe distribution source: $1" >&2; return 2; }
  awk -v path="$1" '
    NR == 1 { sub(/^\357\273\277/, ""); sub(/\r$/, ""); if ($0 !~ /^---[ \t]*$/) exit; opened=1; next }
    { sub(/\r$/, "") }
    /^---[ \t]*$/ { closed=1; exit }
    tolower($0) ~ /^distribute[ \t]*:/ {
      if (++fields > 1 || $0 !~ /^distribute[ \t]*:/) { invalid=1; next }
      value=$0; sub(/^distribute[ \t]*:[ \t]*/, "", value)
      sub(/[ \t]*$/, "", value)
      if (value ~ /^"[^"]*"([ \t]+#.*)?$/ || value ~ /^\047[^\047]*\047([ \t]+#.*)?$/) next
      sub(/[ \t]+#.*$/, "", value); sub(/[ \t]*$/, "", value)
      if (value !~ /^(true|True|TRUE|false|False|FALSE)$/) { invalid=1; next }
      if (tolower(value) == "false") excluded=1
    }
    END {
      if (invalid || (opened && !closed)) {
        print "Invalid distribution metadata: " path > "/dev/stderr"; exit 2
      }
      exit !excluded
    }
  ' "$1"
}

basecoat_validate_distribution() {
  local root="$1" file code
  [[ ! -L "$root/instructions" ]] || { echo "Unsafe distribution source: $root/instructions" >&2; return 2; }
  [[ -d "$root/instructions" ]] || return 0
  while IFS= read -r -d '' file; do
    if basecoat_distribution_excluded "$file"; then :; else
      code=$?
      [[ "$code" -eq 1 ]] || return "$code"
    fi
  done < <(find "$root/instructions" -maxdepth 1 -name '*.instructions.md' -print0)
}

basecoat_filter_distribution() {
  local root="$1" directory file relative prefix path
  local excluded=()
  basecoat_validate_distribution "$root" || return $?
  for relative in .github .github/base-coat .github/instructions .github/base-coat/instructions .agents .agents/instructions \
    asset-manifest.json .github/base-coat/asset-manifest.json .github/asset-manifest.json .agents/asset-manifest.json; do
    [[ ! -L "$root/$relative" ]] || { echo "Unsafe distribution destination: $root/$relative" >&2; return 2; }
  done
  for directory in instructions; do
    [[ -d "$root/$directory" ]] || continue
    while IFS= read -r -d '' file; do
      if basecoat_distribution_excluded "$file"; then
        relative="${file#"$root/"}"
        excluded+=("$relative")
        echo "Excluded internal instruction: $relative"
      fi
    done < <(find "$root/$directory" -maxdepth 1 -type f -name '*.instructions.md' -print0)
  done
  for prefix in "" .github/base-coat .github .agents; do
    for relative in "${excluded[@]}"; do
      rm -rf "$root/${prefix:+$prefix/}$relative"
    done
    path="$root/${prefix:+$prefix/}asset-manifest.json"
    if [[ -f "$path" && ${#excluded[@]} -gt 0 ]]; then
      # Each manifest asset is emitted as its own object by the generator.
      # Buffer objects so exclusion does not depend on property ordering.
      local expression="" escaped
      for relative in "${excluded[@]}"; do
        escaped="$(printf '%s' "$relative" | sed 's/[][\\.^$*+?(){}|]/\\&/g')"
        expression="${expression:+$expression|}$escaped(/[^\"\r\n]*)?"
      done
      expression="${expression//\\/\\\\}"
      awk -v paths="$expression" '
        /^[[:space:]]*"assets"[[:space:]]*:/ { assets=1; print; next }
        assets && /^[[:space:]]*\{/ { object=$0 ORS; buffering=1; next }
        buffering {
          object=object $0 ORS
          if ($0 ~ /^[[:space:]]*\},?[[:space:]]*$/) {
            if (object !~ "\"path\"[[:space:]]*:[[:space:]]*\"(" paths ")\"") {
              sub(/,[[:space:]]*$/, "", object)
              if (previous != "") printf "%s,\n", previous
              previous=object
            }
            buffering=0
          }
          next
        }
        assets && /^[[:space:]]*\]/ { if (previous != "") printf "%s\n", previous; assets=0 }
        { print }
      ' "$path" > "$path.filtered"
      mv "$path.filtered" "$path"
    fi
  done
}
