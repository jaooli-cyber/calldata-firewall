#!/usr/bin/env bash
set -euo pipefail

FE="${FE:-build/tools/fe}"
OUT_DIR="${OUT_DIR:-build/traces}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"

./scripts/verify-fe.sh "$FE" >/dev/null
./scripts/safe-output-dir.sh --reset "$OUT_DIR" >/dev/null

run_trace() {
    local test_name="$1"
    local output="$2"
    env RAYON_NUM_THREADS=1 CARGO_BUILD_JOBS=1 \
        "$FE" test gate --jobs 1 --grouped --filter "$test_name" \
        --call-trace --color never >"$output" 2>&1
    grep -Fq "test result: ok. 1 passed; 0 failed" "$output"
}

assert_absent() {
    local needle="$1"
    local file="$2"
    if grep -Fq "$needle" "$file"; then
        echo "forbidden trace edge '$needle' found in $file" >&2
        exit 1
    fi
}

assert_create_count() {
    local expected="$1"
    local file="$2"
    local actual
    actual="$(grep -Fc 'CREATE2 ok -> ' "$file" || true)"
    if [[ "$actual" != "$expected" ]]; then
        echo "unexpected CREATE2 count in $file: expected=$expected actual=$actual" >&2
        exit 1
    fi
}

assert_call_destinations() {
    local file="$1"
    shift
    local allowed=" $* "
    local opcode destination remainder
    while read -r opcode destination remainder; do
        [[ "$opcode" == "CALL" ]] || continue
        if [[ "$allowed" != *" $destination "* ]]; then
            echo "unexpected CALL destination $destination in $file" >&2

            exit 1
        fi
    done <"$file"
}
assert_call_count() {
    local file="$1"
    local destination="$2"
    local expected="$3"
    local actual
    actual="$(grep -Fc "CALL $destination " "$file" || true)"
    if [[ "$actual" != "$expected" ]]; then
        echo "unexpected CALL count for $destination in $file: expected=$expected actual=$actual" >&2
        exit 1
    fi
}

for test_name in \
    malformed_canonicality_matrix_zero_call_trace_oracle \
    bounds_zero_call_trace_oracle \
    raw_rejection_hardening_zero_call_trace_oracle \
    value_and_gas_zero_call_trace_oracle
do
    output="$OUT_DIR/${test_name}.log"
    run_trace "$test_name" "$output"
    # These fixtures create the protected target first and the firewall second.
    assert_create_count 2 "$output"
    assert_call_destinations "$output" '$0' '$2'
    assert_call_count "$output" '$0' 1
    case "$test_name" in
        malformed_canonicality_matrix_zero_call_trace_oracle) expected_firewall_calls=7 ;;
        bounds_zero_call_trace_oracle) expected_firewall_calls=3 ;;
        raw_rejection_hardening_zero_call_trace_oracle) expected_firewall_calls=18 ;;
        value_and_gas_zero_call_trace_oracle) expected_firewall_calls=2 ;;
    esac
    assert_call_count "$output" '$2' "$expected_firewall_calls"
    assert_absent 'CALL $1 ' "$output"
done

policy_output="$OUT_DIR/policy_rejections_zero_target_call_trace_oracle.log"
run_trace policy_rejections_zero_target_call_trace_oracle "$policy_output"
# This fixture creates the configured and alternate targets before the firewall.
assert_create_count 4 "$policy_output"
assert_call_destinations "$policy_output" '$0' '$3' '$4'
assert_call_count "$policy_output" '$0' 1
assert_call_count "$policy_output" '$3' 8
assert_call_count "$policy_output" '$4' 1
assert_absent 'CALL $1 ' "$policy_output"
assert_absent 'CALL $2 ' "$policy_output"

reentrancy_output="$OUT_DIR/reentrancy_is_rejected_before_nested_validation.log"
run_trace reentrancy_is_rejected_before_nested_validation "$reentrancy_output"
assert_create_count 2 "$reentrancy_output"
assert_call_destinations "$reentrancy_output" '$0' '$1' '$2'
assert_call_count "$reentrancy_output" '$0' 1
target_calls="$(grep -Fc 'CALL $1 ' "$reentrancy_output" || true)"
firewall_calls="$(grep -Fc 'CALL $2 ' "$reentrancy_output" || true)"
guard_reverts="$(grep -Ec 'CALL \$2 .* -> revert ret=4c5b9744' "$reentrancy_output" || true)"
if [[ "$target_calls" != "1" || "$firewall_calls" != "2" || "$guard_reverts" != "1" ]]; then
    echo "unexpected reentrancy trace: target=$target_calls firewall=$firewall_calls guard=$guard_reverts" >&2
    exit 1
fi

printf 'verified 5 zero-target rejection traces and 1 guarded reentrancy trace\n'
