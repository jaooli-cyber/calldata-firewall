# Calldata Firewall test matrix

This inventory covers every `#[test]` function in the source snapshot changed
alongside this matrix. It is an evidence plan, not runtime evidence and not a
GO decision; the final commit and file digest identify the snapshot externally.

## Evidence vocabulary

- **AUTHORED**: the case and its assertions exist in the pinned source.
- **STATIC-CHECKED**: `GATE-LOG.md` records a successful Fe 26.5.0 semantic
  check after the hardening that introduced these cases. This is a source-only
  check and does not execute any test.
- **NOT EXECUTED**: no build, runtime test, deployment, or call trace has been
  run for this source snapshot.
- **Internal oracle**: an assertion inside the Fe test. It becomes evidence
  only after that test executes successfully.
- **Trace oracle**: a property that must be checked in `--call-trace` output.
  A source assertion that a firewall call failed does not prove that zero
  nested calls were attempted, because a later revert can roll back their
  effects.

Every test below has the same current evidence state:
`AUTHORED / STATIC-CHECKED / NOT EXECUTED`.

## Test inventory

### T01 - `canonical_batch_forwards_and_classifies`

Source: `gate/src/lib.fe:583-603`

| Case | Expected internal oracle | Trace oracle |
|---|---|---|
| Canonical `hit / fail / hit` batch | `attempted=3`, `succeeded=2`, `failed=1`; last returndata and copied prefix are 32 bytes; last word is `2`; target hit counter is `2` | None required; ordinary runtime assertions |

Status: **AUTHORED / STATIC-CHECKED / NOT EXECUTED**.

### T02 - `malformed_canonicality_matrix_zero_call_trace_oracle`

Source: `gate/src/lib.fe:606-671`

| Case | Expected internal oracle | Trace oracle |
|---|---|---|
| Top-level `bytes[]` offset `128` instead of `96` | Firewall call fails | Required: failed firewall-call subtree contains no nested `CALL` |
| First element offset `64` instead of canonical `32` | Firewall call fails | Required: no nested `CALL` |
| One trailing zero byte | Firewall call fails | Required: no nested `CALL` |
| Dirty first padding byte | Firewall call fails | Required: no nested `CALL` |
| Address word with a high bit set | Firewall call fails | Required: no nested `CALL` |
| Fabricated count `9` without a complete nine-head region | Firewall call fails structurally | Required: no nested `CALL` |
| Final canonical padding byte removed | Firewall call fails | Required: no nested `CALL` |

Status: **AUTHORED / STATIC-CHECKED / NOT EXECUTED**.

### T03 - `bounds_zero_call_trace_oracle`

Source: `gate/src/lib.fe:674-724`

| Case | Expected internal oracle | Trace oracle |
|---|---|---|
| Nine fully encoded calls | Reject count `9` | Required: failed firewall-call subtree contains no nested `CALL` |
| One call of `1,025` bytes | Reject per-call limit | Required: no nested `CALL` |
| Five calls of `1,024` bytes (`5,120` total) | Reject aggregate limit | Required: no nested `CALL` |

Status: **AUTHORED / STATIC-CHECKED / NOT EXECUTED**.

### T04 - `raw_rejection_hardening_zero_call_trace_oracle`

Source: `gate/src/lib.fe:727-955`

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

Status: **AUTHORED / STATIC-CHECKED / NOT EXECUTED**.

### T05 - `accepted_maximum_count_and_data_boundaries_complete`

Source: `gate/src/lib.fe:958-1002`

| Case | Expected internal oracle | Trace oracle |
|---|---|---|
| Eight calls of 512 bytes (`4,096` total) | `attempted=8`, `succeeded=8`, `failed=0`; sink count becomes `8` | None required; runtime boundary assertion |
| One call of exactly `1,024` bytes | `attempted=1`, `succeeded=1`; cumulative sink count becomes `9` | None required; runtime boundary assertion |

Status: **AUTHORED / STATIC-CHECKED / NOT EXECUTED**.

### T06 - `value_and_gas_zero_call_trace_oracle`

Source: `gate/src/lib.fe:1005-1026`

| Case | Expected internal oracle | Trace oracle |
|---|---|---|
| One wei sent to nonpayable endpoint | Firewall call fails | Required: failed firewall-call subtree contains no nested `CALL` |
| Outer allowance `150,000` with requested forwarding gas `500,000` | Adjacent admission rejects before target call | Required: no nested `CALL` |

Status: **AUTHORED / STATIC-CHECKED / NOT EXECUTED**.

### T07 - `eight_exhausted_callees_preserve_suffix_reserves`

Source: `gate/src/lib.fe:1028-1062`

| Case | Expected internal oracle | Trace oracle |
|---|---|---|
| Assert deployed burner `extcodesize=4`, then send eight 512-byte payloads (`4,096` total) with `100,000` gas each to official runtime `0x5b600056` under candidate outer allowance `2,600,000` | All eight calls are attempted; `succeeded=0`, `failed=8`; last full returndata and prefix lengths are zero; no later-index admission revert | Optional diagnostic trace may confirm eight target calls; runtime must calibrate the candidate outer allowance before any exact-margin claim |

Status: **AUTHORED / STATIC-CHECKED / NOT EXECUTED**.

### T08 - `input_scratch_reuse_1024_zero_one_is_observable`

Source: `gate/src/lib.fe:1065-1108`

| Case | Expected internal oracle | Trace oracle |
|---|---|---|
| Reuse one input scratch buffer for payload lengths `1,024 -> 0 -> 1`; place distinct markers at offsets `0` and `992` of the first payload | Three successful calls; observer sees exact lengths `1024,0,1`, both boundary markers, zero for the empty payload, and exactly `0xbb` followed by zeros for the one-byte payload | None required; target-observed runtime assertions prove the copy reaches its final word plus non-stale logical extent |

Status: **AUTHORED / STATIC-CHECKED / NOT EXECUTED**.

### T09 - `output_scratch_bomb_then_empty_or_failure_is_not_stale`

Source: `gate/src/lib.fe:1110-1157`

| Case | Expected internal oracle | Trace oracle |
|---|---|---|
| `65,536`-byte return bomb followed by successful empty return | `succeeded=2`, `failed=0`; final full length, prefix length, and prefix word are zero; final prefix hash is `keccak256(empty)` | None required; runtime assertions prove logical output extent was reset |
| Return bomb followed by empty revert | `succeeded=1`, `failed=1`; final full length, prefix length, and prefix word are zero; final prefix hash is `keccak256(empty)` | None required; runtime assertions prove failed empty returndata does not expose stale bytes |

Status: **AUTHORED / STATIC-CHECKED / NOT EXECUTED**.

### T10 - `reentrancy_is_rejected_before_nested_validation`

Source: `gate/src/lib.fe:1160-1176`

| Case | Expected internal oracle | Trace oracle |
|---|---|---|
| Target callbacks into the firewall while the transient guard is set | Nested call returns exact `ReentrantExecution`; outer target returns true; outer summary has one success, zero failures, and last prefix word `1` | Optional diagnostic trace should show the callback and guarded rejection; exact error and outer success are internal runtime assertions |

Status: **AUTHORED / STATIC-CHECKED / NOT EXECUTED**.

### T11 - `returndata_copy_is_capped_but_full_length_is_reported`

Source: `gate/src/lib.fe:1179-1195`

| Case | Expected internal oracle | Trace oracle |
|---|---|---|
| Target returns `65,536` bytes | Call succeeds; reported full length is `65,536`; copied prefix length is exactly `64` | None required; runtime assertions establish bounded copy versus full-length reporting |

Status: **AUTHORED / STATIC-CHECKED / NOT EXECUTED**.

### T12 - `reserve_recurrence_is_monotone_and_saturating`

Source: `gate/src/lib.fe:1198-1206`

| Case | Expected internal oracle | Trace oracle |
|---|---|---|
| Three-call reserve recurrence at `200,000` gas | `reserve[0] > reserve[1] > reserve[2]` and final entry equals `FINAL_RESERVE` | None; pure internal assertion |
| Admission requirement with both inputs `U256_MAX` | Saturates to `U256_MAX` without wrapping | None; pure internal assertion |

Status: **AUTHORED / STATIC-CHECKED / NOT EXECUTED**.

## Call-trace inspection contract

The required zero-nested-call trace set is exactly:

1. `malformed_canonicality_matrix_zero_call_trace_oracle`;
2. `bounds_zero_call_trace_oracle`;
3. `raw_rejection_hardening_zero_call_trace_oracle`; and
4. `value_and_gas_zero_call_trace_oracle`.

For every rejected firewall invocation inside those compound tests, inspect the
failed firewall-call subtree. Setup deployments and the outer test-to-firewall
call are expected; any nested `CALL` issued by the firewall after entering the
rejected invocation is proof-killing, regardless of destination. These tests
intentionally make no post-rejection target query, so such a nested call cannot
be confused with an oracle read.

The internal `!success` assertions and the call-trace oracle are separate
evidence classes. Passing the former does not close the latter.

## GO evidence map

| GO class | Authored coverage | Evidence still required |
|---|---|---|
| Canonical forwarding and failure classification | T01 | Runtime test green |
| Raw rejection before any target call | T02, T03, T04, T06 | Runtime assertions green **and** required zero-nested-`CALL` traces clean |
| Count boundaries `0 / 8 / 9` | T04 rejects `0`; T05 accepts `8`; T03 rejects a complete `9`; T02 rejects fabricated `9`; T07 stresses eight attempted calls | Runtime green; rejection cases also need clean traces |
| Per-call `1,024` and aggregate `4,096` | T05 accepts both exact boundaries; T03 rejects `1,025` and `5,120` | Runtime green; rejection cases also need clean traces |
| Eight-call OOG burner (`burner8`) | T07 | Runtime completion with all eight failures and no later-index admission failure |
| Input/output scratch reuse | T08 and T09 | Runtime observer and final-prefix assertions green |
| Returndata bomb | T09 and T11 | Runtime proves `65,536` full length, 64-byte cap, and no stale prefix after empty success/revert |
| Reentrancy | T10 | Selected backend returns exact guarded inner failure while outer call succeeds |
| Reserve recurrence | T12 algorithmic checks plus T07 empirical suffix-reserve stress | Pure assertions and burner stress both green |

GO is not established by authorship or semantic checking. It requires all
runtime assertions above, the four required trace-oracle functions with clean
failed subtrees, and closure of the independent Red Team gates in
`RED-TEAM.md`.

## Authoritative execution result

The planning rows above retain their historical pending wording. The final
evaluated baseline supersedes those statuses:

- Build: RC 0.
- T01-T12: 12 passed, 0 failed.
- Required rejection traces: 4 passed; zero target calls.
- Reentrancy trace: passed with the expected guarded callback sequence.
- ABI companion/Ethers/Cancun runtime smoke: passed.
- Shanghai negative-fork smoke: expected invalid opcode, proving the EIP-1153
  deployment boundary.
- Evaluated commit:
  `3830b36a0df35bc3a0fb567e8a2d408261c217e0`.
- Evidence: `evidence/final-20261103T092200Z`; manifest SHA-256
  `249ec8c5beb8090d39ef1a7bce970a94b10cb1096a8fb0fec642f0a6d88e13dd`.

Final matrix status: **EXECUTED-PASS / technical GO**.
