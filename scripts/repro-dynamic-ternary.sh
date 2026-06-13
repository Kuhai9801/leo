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
"${LEO[@]}" build
echo "Generated call.dynamic and ternary instructions:"
grep -n 'call.dynamic\|ternary' build/dyn_ternary_issue/dyn_ternary_issue.aleo

call_count="$(grep -c 'call.dynamic' build/dyn_ternary_issue/dyn_ternary_issue.aleo)"
if [[ "$call_count" -ne 2 ]]; then
  echo "Expected exactly two unconditional call.dynamic instructions, found $call_count" >&2
  exit 1
fi

echo "DYNAMIC_TERNARY_REPRO_CONFIRMED"
