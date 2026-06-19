#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
. "$SCRIPT_DIR/common.sh"

show_tooling
log "inclusive equal-bound loop"

new_project inclusive_loop_eq
write_main inclusive_loop_eq <<'LEO'
program inclusive_loop_eq.aleo {
    @noupgrade
    constructor() {}

    fn main() -> u32 {
        let acc: u32 = 0u32;

        for i: u32 in 5u32..=5u32 {
            acc += 1u32;
        }

        return acc;
    }
}
LEO

out="$ROOT/inclusive_loop_eq.out"
(cd "$ROOT/inclusive_loop_eq" && run_cmd "$out" "$LEO_BIN" run main)
status=$?
show_output "$out"

build_out="$ROOT/inclusive_loop_eq_build.out"
(cd "$ROOT/inclusive_loop_eq" && run_cmd "$build_out" "$LEO_BIN" build --enable-all-ast-snapshots)
show_output "$build_out"
show_project_files inclusive_loop_eq
show_project_matches inclusive_loop_eq 'for i|5u32|acc|return|assert|\.aleo|loop'
copy_project_evidence inclusive_loop_eq

log "inclusive equal-bound loop erases failing assert"
new_project inclusive_loop_assert
write_main inclusive_loop_assert <<'LEO'
program inclusive_loop_assert.aleo {
    @noupgrade
    constructor() {}

    fn main() -> u32 {
        for i: u32 in 5u32..=5u32 {
            assert_eq(i, 6u32);
        }

        return 1u32;
    }
}
LEO

assert_out="$ROOT/inclusive_loop_assert.out"
(cd "$ROOT/inclusive_loop_assert" && run_cmd "$assert_out" "$LEO_BIN" run main)
assert_status=$?
show_output "$assert_out"

assert_build_out="$ROOT/inclusive_loop_assert_build.out"
(cd "$ROOT/inclusive_loop_assert" && run_cmd "$assert_build_out" "$LEO_BIN" build --enable-all-ast-snapshots)
show_output "$assert_build_out"
show_project_files inclusive_loop_assert
show_project_matches inclusive_loop_assert 'for i|assert_eq|assert|5u32|6u32|return|\.aleo|loop'
copy_project_evidence inclusive_loop_assert

if [ "$status" -eq 0 ] && grep -q '0u32' "$out" && [ "$assert_status" -eq 0 ] && grep -q '1u32' "$assert_out"; then
  result inclusive_loop_eq confirmed "inclusive 5u32..=5u32 ran zero iterations and erased a failing source assertion"
elif [ "$status" -eq 0 ] && grep -q '1u32' "$out"; then
  result inclusive_loop_eq fixed "inclusive equal-bound loop returned 1u32"
else
  result inclusive_loop_eq inconclusive "count status=$status assert status=$assert_status"
fi
