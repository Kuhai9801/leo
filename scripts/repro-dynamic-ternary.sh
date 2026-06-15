#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$ROOT/target/dynamic-ternary-repro"
LEO=(cargo run -p leo-lang --bin leo --locked --features only_testnet --)

rm -rf "$WORK"
mkdir -p "$WORK"

cd "$WORK"
"${LEO[@]}" new dyn_ternary_issue
cat > dyn_ternary_issue/src/main.leo <<'LEO'
program dyn_ternary_issue.aleo {
    fn main(target: field, net: field, f_true: field, f_false: field, x: u64, pick: bool) -> u64 {
        let result: u64 = pick
            ? _dynamic_call::[u64](target, net, f_true, x)
            : _dynamic_call::[u64](target, net, f_false, x);
        return result;
    }

    @noupgrade
    constructor() {}
}
LEO

cd dyn_ternary_issue
set +e
build_output="$("${LEO[@]}" build 2>&1)"
build_status=$?
set -e

printf '%s\n' "$build_output"
if [[ "$build_status" -eq 0 ]]; then
  echo "Expected dynamic calls in ternary arms to be rejected, but build succeeded" >&2
  exit 1
fi

if ! grep -q 'dynamic calls cannot be used inside a conditional branch' <<<"$build_output"; then
  echo "Expected conditional dynamic-call diagnostic was not emitted" >&2
  exit 1
fi

echo "DYNAMIC_TERNARY_REJECTION_CONFIRMED"
