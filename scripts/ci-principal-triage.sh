#!/usr/bin/env bash
set -u -o pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$ROOT/target/triage-repro"
LEO=(cargo run -p leo-lang --bin leo --locked --features only_testnet --)

rm -rf "$WORK"
mkdir -p "$WORK"

section() {
  printf '\n===== %s =====\n' "$1"
}

run_cmd() {
  printf '+ %q' "$@"
  printf '\n'
  "$@"
}

write_main() {
  local dir="$1"
  local body="$2"
  mkdir -p "$dir/src"
  printf '%s\n' "$body" > "$dir/src/main.leo"
}

new_project() {
  local name="$1"
  (cd "$WORK" && run_cmd "${LEO[@]}" new "$name")
}

build_project() {
  local name="$1"
  (cd "$WORK/$name" && run_cmd "${LEO[@]}" build)
}

run_project() {
  local name="$1"
  shift
  (cd "$WORK/$name" && run_cmd "${LEO[@]}" run "$@")
}

section "toolchain"
run_cmd rustc --version
run_cmd cargo --version

section "abi collision"
new_project abi_collision
write_main "$WORK/abi_collision" 'program abi_collision.aleo {
    record Payload {
        owner: address,
        public amount: u64,
    }

    fn echo(x: utils::Payload) -> utils::Payload {
        return x;
    }

    @noupgrade
    constructor() {}
}'
cat > "$WORK/abi_collision/src/utils.leo" <<'LEO'
struct Payload {
    amount: u64,
}
LEO
if build_project abi_collision; then
  jq '.functions[] | select(.name == "echo") | {inputs, outputs}' "$WORK/abi_collision/build/abi_collision/abi.json"
  grep -A5 '^function echo:' "$WORK/abi_collision/build/abi_collision/abi_collision.aleo" || true
else
  echo "ABI_COLLISION_BUILD_FAILED"
fi

section "void dynamic call return"
new_project dyn_void_return
write_main "$WORK/dyn_void_return" 'program dyn_void_return.aleo {
    fn dropped(target: field, net: identifier, fun: identifier) {
        return _dynamic_call::[()](target, net, fun);
    }

    fn preserved(target: field, net: identifier, fun: identifier) {
        _dynamic_call::[()](target, net, fun);
        return;
    }

    @noupgrade
    constructor() {}
}'
if build_project dyn_void_return; then
  awk '/^function dropped:/{p=1} /^function preserved:/{p=0} p {print}' "$WORK/dyn_void_return/build/dyn_void_return/dyn_void_return.aleo"
  awk '/^function preserved:/{p=1} p {print}' "$WORK/dyn_void_return/build/dyn_void_return/dyn_void_return.aleo"
  echo "dropped call.dynamic count: $(awk '/^function dropped:/{p=1} /^function preserved:/{p=0} p {print}' "$WORK/dyn_void_return/build/dyn_void_return/dyn_void_return.aleo" | grep -c 'call.dynamic' || true)"
  echo "preserved call.dynamic count: $(awk '/^function preserved:/{p=1} p {print}' "$WORK/dyn_void_return/build/dyn_void_return/dyn_void_return.aleo" | grep -c 'call.dynamic' || true)"
else
  echo "DYN_VOID_RETURN_BUILD_FAILED"
fi

section "dynamic call ternary"
new_project dyn_ternary_issue
write_main "$WORK/dyn_ternary_issue" 'program dyn_ternary_issue.aleo {
    fn main(target: field, net: field, f_true: field, f_false: field, x: u64, pick: bool) -> u64 {
        let result: u64 = pick
            ? _dynamic_call::[u64](target, net, f_true, x)
            : _dynamic_call::[u64](target, net, f_false, x);
        return result;
    }

    @noupgrade
    constructor() {}
}'
if build_project dyn_ternary_issue; then
  grep -n 'call.dynamic\|ternary' "$WORK/dyn_ternary_issue/build/dyn_ternary_issue/dyn_ternary_issue.aleo" || true
else
  echo "DYN_TERNARY_BUILD_FAILED_OR_REJECTED"
fi

section "flattened inactive branch division"
new_project branch_guard_halt
write_main "$WORK/branch_guard_halt" 'program branch_guard_halt.aleo {
    fn main(flag: bool, denom: u8) -> u8 {
        if flag {
            let q: u8 = 1u8 / denom;
            assert_eq(q, 1u8);
        }

        return 7u8;
    }

    @noupgrade
    constructor() {}
}'
if build_project branch_guard_halt; then
  grep -n 'div\|assert\|output' "$WORK/branch_guard_halt/build/branch_guard_halt/branch_guard_halt.aleo" || true
fi
if run_project branch_guard_halt main false 0u8; then
  echo "BRANCH_GUARD_RUN_SUCCEEDED"
else
  echo "BRANCH_GUARD_RUN_FAILED"
fi

section "dce wrapped div"
new_project dce_wrapped_div_zero
write_main "$WORK/dce_wrapped_div_zero" 'program dce_wrapped_div_zero.aleo {
    fn main(x: u8) -> u8 {
        let unused: u8 = x.div_wrapped(0u8);
        return x;
    }

    @noupgrade
    constructor() {}
}'
if build_project dce_wrapped_div_zero; then
  grep -n 'div.w\|output' "$WORK/dce_wrapped_div_zero/build/dce_wrapped_div_zero/dce_wrapped_div_zero.aleo" || true
fi
if run_project dce_wrapped_div_zero main 7u8; then
  echo "DCE_DIV_WRAPPED_RUN_SUCCEEDED"
else
  echo "DCE_DIV_WRAPPED_RUN_FAILED"
fi

section "dce wrapped rem"
new_project dce_wrapped_rem_zero
write_main "$WORK/dce_wrapped_rem_zero" 'program dce_wrapped_rem_zero.aleo {
    fn main(x: u8) -> u8 {
        let unused: u8 = x.rem_wrapped(0u8);
        return x;
    }

    @noupgrade
    constructor() {}
}'
if build_project dce_wrapped_rem_zero; then
  grep -n 'rem.w\|output' "$WORK/dce_wrapped_rem_zero/build/dce_wrapped_rem_zero/dce_wrapped_rem_zero.aleo" || true
fi
if run_project dce_wrapped_rem_zero main 7u8; then
  echo "DCE_REM_WRAPPED_RUN_SUCCEEDED"
else
  echo "DCE_REM_WRAPPED_RUN_FAILED"
fi

section "dyn record dce"
new_project dyn_record_dce_probe
write_main "$WORK/dyn_record_dce_probe" 'program dyn_record_dce_probe.aleo {
    record BadToken {
        owner: address,
        balance: field,
    }

    fn probe(t: BadToken) -> bool {
        let r: dyn record = t as dyn record;
        let must_halt: u64 = r.balance;
        return true;
    }

    @noupgrade
    constructor() {}
}'
if build_project dyn_record_dce_probe; then
  grep -n 'dynamic.record\|get.record.dynamic\|output' "$WORK/dyn_record_dce_probe/build/dyn_record_dce_probe/dyn_record_dce_probe.aleo" || true
else
  echo "DYN_RECORD_DCE_BUILD_FAILED"
fi

section "complete"
