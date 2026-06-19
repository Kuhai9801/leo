#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
. "$SCRIPT_DIR/common.sh"

show_tooling
log "constant ternary fallible arm"

new_project const_ternary_bug
write_main const_ternary_bug <<'LEO'
program const_ternary_bug.aleo {
    @noupgrade
    constructor() {}

    fn main(x: u8) -> u8 {
        let y: u8 = true ? x : x.div_wrapped(0u8);
        return y;
    }
}
LEO

out="$ROOT/const_ternary_bug.out"
(cd "$ROOT/const_ternary_bug" && run_cmd "$out" "$LEO_BIN" run main 7u8)
const_status=$?
show_output "$out"

const_build_out="$ROOT/const_ternary_bug_build.out"
(cd "$ROOT/const_ternary_bug" && run_cmd "$const_build_out" "$LEO_BIN" build --enable-all-ast-snapshots)
show_output "$const_build_out"
show_project_files const_ternary_bug
show_project_matches const_ternary_bug 'div|ternary|true|false|7u8|return|const|propagation|\.aleo'
copy_project_evidence const_ternary_bug

log "dynamic ternary control"
new_project dynamic_ternary_probe
write_main dynamic_ternary_probe <<'LEO'
program dynamic_ternary_probe.aleo {
    @noupgrade
    constructor() {}

    fn main(cond: bool, x: u8) -> u8 {
        let y: u8 = cond ? x : x.div_wrapped(0u8);
        return y;
    }
}
LEO

dyn_out="$ROOT/dynamic_ternary_probe.out"
(cd "$ROOT/dynamic_ternary_probe" && run_cmd "$dyn_out" "$LEO_BIN" run main true 7u8)
dyn_status=$?
show_output "$dyn_out"

dyn_build_out="$ROOT/dynamic_ternary_probe_build.out"
(cd "$ROOT/dynamic_ternary_probe" && run_cmd "$dyn_build_out" "$LEO_BIN" build --enable-all-ast-snapshots)
show_output "$dyn_build_out"
show_project_files dynamic_ternary_probe
show_project_matches dynamic_ternary_probe 'div|ternary|cond|true|false|return|ssa|propagation|\.aleo'
copy_project_evidence dynamic_ternary_probe

if [ "$const_status" -eq 0 ] && grep -q '7u8' "$out" && [ "$dyn_status" -ne 0 ]; then
  result const_ternary_fallible confirmed "constant fold returns while the same generated-ternary fallible arm halts; artifacts/snapshots uploaded"
elif [ "$const_status" -eq 0 ] && grep -q '7u8' "$out"; then
  result const_ternary_fallible partial "constant fold returns 7u8; dynamic control did not fail"
else
  result const_ternary_fallible inconclusive "constant case status=$const_status dynamic status=$dyn_status"
fi
