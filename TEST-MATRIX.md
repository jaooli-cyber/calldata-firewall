# Calldata Firewall test matrix

This inventory covers all 14 `#[test]` functions in the current source. It
separates the frozen 12-test feasibility baseline from the later immutable
policy and bitmap hardening.

The historical commit `3830b36` passed 12/12 tests, four rejection traces,
one reentrancy trace, and its original ABI/fork smoke. The submission candidate
referenced by `fe-014-submission-v3` passes all 14 tests, five zero-target-call
rejection traces, the guarded reentrancy trace, byte-identical metadata
regeneration, combined-ABI validation, and the Cancun/Shanghai demo through
`make verify`.

## Evidence vocabulary

- **Internal oracle**: an assertion evaluated by a passing Fe test.
- **Trace oracle**: a property inspected in `--call-trace` output. A reverted
  state change alone cannot prove that no nested call was attempted.
- **CANDIDATE EXECUTED-PASS**: `make verify` executed successfully on the exact
  commit referenced by `fe-014-submission-v3`.
- **External release record**: the full SHA and evidence-manifest digest are
  stored with the tag/release and official form to avoid self-reference.

## Test inventory

### T01 - `canonical_batch_forwards_and_classifies`

Source: `gate/src/lib.fe:845-885`

| Case | Expected internal oracle | Trace oracle |
|---|---|---|
| Canonical `hit / fail / hit` batch | `attempted=3`, `succeeded=2`, `failed=1`, `bitmap=0b101`; last word `2`; target hits `2` | None required |
| Inverse `fail / hit / fail` batch | `attempted=3`, `succeeded=1`, `failed=2`, `bitmap=0b010`; cumulative target hits `3` | None required |

Status: **CANDIDATE EXECUTED-PASS**.

### T02 - `malformed_canonicality_matrix_zero_call_trace_oracle`

Source: `gate/src/lib.fe:888-957`

| Case | Expected internal oracle | Trace oracle |
|---|---|---|
| Top-level `bytes[]` offset `128` instead of `96` | Firewall call fails | Required: failed firewall-call subtree contains no nested `CALL` |
| First element offset `64` instead of canonical `32` | Firewall call fails | Required: no nested `CALL` |
| One trailing zero byte | Firewall call fails | Required: no nested `CALL` |
| Dirty first padding byte | Firewall call fails | Required: no nested `CALL` |
| Address word with a high bit set | Firewall call fails | Required: no nested `CALL` |
| Fabricated count `9` without a complete nine-head region | Firewall call fails structurally | Required: no nested `CALL` |
| Final canonical padding byte removed | Firewall call fails | Required: no nested `CALL` |

Status: **CANDIDATE EXECUTED-PASS**.

### T03 - `bounds_zero_call_trace_oracle`

Source: `gate/src/lib.fe:958-1010`

| Case | Expected internal oracle | Trace oracle |
|---|---|---|
| Nine fully encoded calls | Reject count `9` | Required: failed firewall-call subtree contains no nested `CALL` |
| One call of `1,025` bytes | Reject per-call limit | Required: no nested `CALL` |
| Five calls of `1,024` bytes (`5,120` total) | Reject aggregate limit | Required: no nested `CALL` |

Status: **CANDIDATE EXECUTED-PASS**.

### T04 - `raw_rejection_hardening_zero_call_trace_oracle`

Source: `gate/src/lib.fe:1011-1242`

| Case | Expected internal oracle | Trace oracle |
|---|---|---|
| Three-byte selector prefix | Dispatch fails closed | Required: failed firewall-call subtree contains no nested `CALL` |
| Correct selector with only 68 total bytes | Incomplete envelope is rejected | Required: no nested `CALL` |
| Unknown selector `0xdeadbeef`, changing only the high four bytes; `read_word(4)` still equals the Probe address word | Dispatch rejects before raw handler while the valid target remains reachable if dispatch were wrong | Required: no nested `CALL` |
| Canonical count `0` | Policy rejects empty batch | Required: no nested `CALL` |
| `gas_limit=0` | Policy rejects gas limit | Required: no nested `CALL` |
| `gas_limit=MAX_FORWARD_GAS+1` | Policy rejects gas limit | Required: no nested `CALL` |
| Count `U256_MAX` | Structural/policy rejection | Required: no nested `CALL` |
| Count `2^64+1` on the canonical one-element shape | High-bit alias is rejected; truncating to low count `1` would reach Probe | Required: no nested `CALL` |
| First element offset `U256_MAX` | Offset rejected without wraparound forwarding | Required: no nested `CALL` |
| First element offset `2^64+32` on the canonical one-element shape | High-bit alias is rejected; truncating to low offset `32` would reach Probe | Required: no nested `CALL` |
| First element length `U256_MAX` | Length rejected without allocation or forwarding | Required: no nested `CALL` |
| First element length `2^64` on a canonical empty-bytes shape | High-bit alias is rejected; truncating to low length `0` would reach Probe | Required: no nested `CALL` |
| First element length `2^64+1` on a canonical one-byte shape | High-bit alias is rejected; truncating to low length `1` would reach Probe | Required: no nested `CALL` |
| Second tail offset `160` instead of canonical `128` | Gap rejected | Required: no nested `CALL` |
| Second tail offset `64` instead of canonical `128` | Overlap/backward tail rejected | Required: no nested `CALL` |
| Zero target | Target rejected | Required: no nested `CALL` |
| Firewall itself as target | Self-target rejected | Required: no nested `CALL` |
| Address `0xdead` with no code | Code-less target rejected | Required: no nested `CALL` |

Status: **CANDIDATE EXECUTED-PASS**.

### T05 - `accepted_maximum_count_and_data_boundaries_complete`

Source: `gate/src/lib.fe:1479-1531`

| Case | Expected internal oracle | Trace oracle |
|---|---|---|
| Eight selector-prefixed calls of 512 bytes (`4,096` total) | `attempted=8`, `succeeded=8`, `failed=0`, `bitmap=0xff`; sink count `8` | None required |
| One selector-prefixed call of exactly `1,024` bytes | `attempted=1`, `succeeded=1`, `bitmap=1`; cumulative sink count `9` | None required |

Status: **CANDIDATE EXECUTED-PASS**.

### T06 - `value_and_gas_zero_call_trace_oracle`

Source: `gate/src/lib.fe:1532-1554`

| Case | Expected internal oracle | Trace oracle |
|---|---|---|
| One wei sent to nonpayable endpoint | Firewall call fails | Required: failed firewall-call subtree contains no nested `CALL` |
| Outer allowance `150,000` with requested forwarding gas `500,000` | Adjacent admission rejects before target call | Required: no nested `CALL` |

Status: **CANDIDATE EXECUTED-PASS**.

### T07 - `eight_exhausted_callees_preserve_suffix_reserves`

Source: `gate/src/lib.fe:1555-1594`

| Case | Expected internal oracle | Trace oracle |
|---|---|---|
| Assert burner `extcodesize=4`, then send eight selector-prefixed 512-byte payloads with `100,000` gas each | `attempted=8`, `succeeded=0`, `failed=8`, `bitmap=0`; no late admission revert | Optional diagnostic trace confirms eight target calls |

Status: **CANDIDATE EXECUTED-PASS**.

### T08 - `input_scratch_reuse_1024_four_five_is_observable`

Source: `gate/src/lib.fe:1595-1643`

| Case | Expected internal oracle | Trace oracle |
|---|---|---|
| Reuse one input buffer for lengths `1,024 -> 4 -> 5`; keep the allowed selector in each payload and boundary markers in the first | Three successes, `bitmap=0b111`; observer sees `1024,4,5`, both boundary markers, selector-only second payload, and selector plus `0xbb` third payload | None required; target observations prove the logical extent is reset |

Status: **CANDIDATE EXECUTED-PASS**.

### T09 - `output_scratch_bomb_then_empty_or_failure_is_not_stale`

Source: `gate/src/lib.fe:1644-1701`

| Case | Expected internal oracle | Trace oracle |
|---|---|---|
| `65,536`-byte return bomb followed by successful empty return | `succeeded=2`, `failed=0`, `bitmap=0b11`; final length/prefix zero and empty hash | None required |
| Return bomb followed by empty revert | `succeeded=1`, `failed=1`, `bitmap=0b01`; final length/prefix zero and empty hash | None required |

Status: **CANDIDATE EXECUTED-PASS**.

### T10 - `reentrancy_is_rejected_before_nested_validation`

Source: `gate/src/lib.fe:1702-1723`

| Case | Expected internal oracle | Trace oracle |
|---|---|---|
| Allowed `attack(address)` target callbacks into the firewall | Nested call returns exact `ReentrantExecution`; outer call succeeds with `bitmap=1` and last prefix word `1` | Reentrancy trace shows callback and guarded rejection |

Status: **CANDIDATE EXECUTED-PASS**.

### T11 - `returndata_copy_is_capped_but_full_length_is_reported`

Source: `gate/src/lib.fe:1724-1745`

| Case | Expected internal oracle | Trace oracle |
|---|---|---|
| Target returns `65,536` bytes | Call succeeds with `bitmap=1`; full length `65,536` and copied prefix exactly `64` | None required |

Status: **CANDIDATE EXECUTED-PASS**.

### T12 - `reserve_recurrence_is_monotone_and_saturating`

Source: `gate/src/lib.fe:1746-1754`

| Case | Expected internal oracle | Trace oracle |
|---|---|---|
| Three-call reserve recurrence at `200,000` gas | `reserve[0] > reserve[1] > reserve[2]` and final entry equals `FINAL_RESERVE` | None; pure internal assertion |
| Admission requirement with both inputs `U256_MAX` | Saturates to `U256_MAX` without wrapping | None; pure internal assertion |

Status: **CANDIDATE EXECUTED-PASS**.

### T13 - `constructor_policy_matrix_is_fail_closed`

Source: `gate/src/lib.fe:1244-1366`

| Case | Expected internal oracle | Trace oracle |
|---|---|---|
| Zero caller; zero target; code-less target | Deployment returns exact `InvalidPolicy` | None; constructor has no forwarding path |
| Selector counts `0` and `4` | Deployment returns exact `InvalidPolicy` | None |
| Nonzero inactive selector slots | Deployment returns exact `InvalidPolicy` | None |
| Duplicate active selectors for counts `2` and `3` | Deployment returns exact `InvalidPolicy` | None |
| Active selector `0x00000000` with inactive zeros | Deployment succeeds | None |
| `authorizedCaller == allowedTarget` | Deployment succeeds | None |

The last two rows are deliberate policy decisions. Selector count marks active
slots, and the caller and target roles need not be different addresses.

Status: **CANDIDATE EXECUTED-PASS**.

### T14 - `policy_rejections_zero_target_call_trace_oracle`

Source: `gate/src/lib.fe:1368-1477`

| Case | Expected internal oracle | Trace oracle |
|---|---|---|
| Proxy is not the configured immediate caller | Exact `UnauthorizedCaller` observed by the proxy | Required: firewall issues no target `CALL` |
| Alternate code-bearing target | Exact `PolicyTargetMismatch` | Required: no call to configured or alternate target |
| Payload lengths `0 / 1 / 2 / 3` | Exact `ShortCall(index=0,supplied=len)` | Required: no target `CALL` |
| Denied selector at index `0` | Exact `DisallowedSelector(0,0xdeadbeef)` | Required: no target `CALL` |
| Allowed index `0` plus denied selector at index `1` | Exact `DisallowedSelector(1,0xdeadbeef)` | Required: whole preflight completes before any target `CALL` |

Status: **CANDIDATE EXECUTED-PASS; required trace clean**.


## Call-trace inspection contract

The required zero-nested-call trace set is exactly:

1. `malformed_canonicality_matrix_zero_call_trace_oracle`;
2. `bounds_zero_call_trace_oracle`;
3. `raw_rejection_hardening_zero_call_trace_oracle`;
4. `value_and_gas_zero_call_trace_oracle`; and
5. `policy_rejections_zero_target_call_trace_oracle`.

For every rejected firewall invocation inside those compound tests, inspect the
failed firewall-call subtree. Setup deployments and the outer test-to-firewall
call are expected; any nested `CALL` issued by the firewall after entering the
rejected invocation is proof-killing, regardless of destination. These tests
intentionally make no post-rejection target query, so such a nested call cannot
be confused with an oracle read.

The internal `!success` assertions and the call-trace oracle are separate
evidence classes. Passing the former does not close the latter.

## GO evidence map

| GO class | Coverage | Candidate evidence |
|---|---|---|
| Canonical forwarding, classification, and bitmap indexing | T01 | Pass for `101` and `010` patterns |
| Raw rejection before target call | T02, T03, T04, T06, T14 | Runtime assertions pass and all five traces are clean |
| Immutable constructor policy | T13 | Invalid matrix rejects; selector zero and `caller == target` acceptance pass |
| Runtime caller/target/selector policy | T14 | Exact errors pass; rejected subtrees contain zero target calls |
| Count and data boundaries | T02-T05, T07 | Accepted and rejected boundaries pass |
| Eight-call OOG burner | T07 | Eight failures, bitmap zero, no late admission failure |
| Input/output scratch reuse | T08, T09 | Observer and non-stale final-prefix assertions pass |
| Returndata bomb | T09, T11 | 65,536 full length, 64-byte cap, no stale prefix |
| Reentrancy | T10 | Guarded inner failure and outer success pass |
| Reserve recurrence | T12 and T07 | Pure recurrence and empirical stress pass |
| ABI/runtime integration | Combined ABI and demo | Cancun initcode/eight-field decode pass; Shanghai deployment rejection passes |

All rows are closed by `make verify` on the exact submission candidate,
including required trace inspection and byte-identical metadata regeneration.

## Authoritative execution result

Historical baseline `3830b36` remains frozen at 12/12 tests, four clean
rejection traces, one reentrancy trace, and its original ABI/fork smoke.

The submission candidate referenced by `fe-014-submission-v3` has:

- `make verify`: pass;
- generated metadata regeneration: byte-identical;
- T01-T14: 14 passed, 0 failed;
- five rejection traces: pass, zero target calls;
- reentrancy trace: pass with guarded callback and outer success;
- combined constructor/errors/raw-function ABI: pass;
- actual Cancun initcode/eight-field decode: pass;
- Shanghai deployment rejection proves the Cancun+ EIP-1153 boundary; and
- the full SHA and evidence digest are retained in the external release record.

Candidate matrix status: **EXECUTED-PASS / GO**. The official form's full SHA
is authoritative; the annotated tag is its stable navigation label.
