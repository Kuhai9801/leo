#!/usr/bin/env bash

LEO_BIN="${LEO_BIN:-$(pwd)/target/debug/leo}"
ROOT="$(mktemp -d)"
ARTIFACT_DIR="${ARTIFACT_DIR:-$(pwd)/audit-repro-evidence}"
mkdir -p "$ARTIFACT_DIR"
trap 'rm -rf "$ROOT"' EXIT

log() {
  printf '\n## %s\n' "$1"
}

result() {
  printf 'RESULT %-28s %-14s %s\n' "$1" "$2" "$3"
}

run_cmd() {
  local outfile="$1"
  shift
  "$@" >"$outfile" 2>&1
  return $?
}

new_project() {
  local name="$1"
  (cd "$ROOT" && "$LEO_BIN" new "$name" >/dev/null)
}

write_main() {
  local name="$1"
  cat > "$ROOT/$name/src/main.leo"
}

show_output() {
  local file="$1"
  sed -n '1,220p' "$file"
}

copy_project_evidence() {
  local name="$1"
  local src="$ROOT/$name"
  local dst="$ARTIFACT_DIR/$name"
  mkdir -p "$dst"
  cp "$src/program.json" "$dst/" 2>/dev/null || true
  mkdir -p "$dst/src"
  cp "$src/src/main.leo" "$dst/src/main.leo"
  if [ -d "$src/build" ]; then
    cp -R "$src/build" "$dst/build"
  fi
}

show_project_files() {
  local name="$1"
  local dir="$ROOT/$name"
  log "$name evidence files"
  find "$dir" -path '*/build/*' -type f | sort | sed "s#^$dir/##" | sed -n '1,120p'
}

show_project_matches() {
  local name="$1"
  local pattern="$2"
  local dir="$ROOT/$name"
  log "$name matches: $pattern"
  grep -RInE "$pattern" "$dir/src" "$dir/build" 2>/dev/null | sed "s#^$dir/##" | sed -n '1,160p' || true
}

show_tooling() {
  log "Tooling"
  printf 'LEO_BIN=%s\n' "$LEO_BIN"
  printf 'ARTIFACT_DIR=%s\n' "$ARTIFACT_DIR"
  "$LEO_BIN" --version || true
}
