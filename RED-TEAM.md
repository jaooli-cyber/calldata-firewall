# Calldata Firewall - independent Red Team

## Scope and adversary

This review covers the specialized `execute(address,uint256,bytes[])` gate only. The attacker controls all calldata words, lengths, offsets, padding, target behavior, returndata size, reentrant callbacks, and supplied outer gas. The MVP forwards no ETH.

The two protected invariants are:

1. rejected calldata causes zero external CALLs; and
2. accepted calldata cannot make firewall memory scale with the sum of payload or returndata sizes beyond documented fixed buffers.

## Findings

| ID | Severity | Status | Finding and disposition |
|---|---:|---|---|
| RT-01 | S0 | Open | No build or runtime tests have run while RG-STOP is active. A semantic check alone cannot support GO. |
| RT-02 | S1 | Open | The zero-call property needs an opcode/call trace. State counters are rollback-blind. The wrong-selector case mutates only the high four bytes and asserts the Probe target is intact. Count, element-offset, and length high-bit aliases retain canonical low values, so truncation would reach Probe; U256_MAX cases remain. All no-query traces are pending. |
| RT-03 | S1 | Open | `BETWEEN_CALL_RESERVE=100000` and `FINAL_RESERVE=300000` are unmeasured. The source test asserts the official burner's deployed code size is four, then sends eight 512-byte calls (4,096 total), each with 100,000 gas. The 2,600,000 outer allowance is a hypothesis, not an exact calibration, until runtime; any late admission failure is proof-killing. |
| RT-04 | S1 | Open | The transient `TSlot<bool>` guard must be exercised on the selected EVM backend. A compile-only pass does not prove backend/runtime EIP-1153 behavior. |
| RT-05 | S1 | Mitigated | Ordinary Solidity-compatible decoding accepts alternate offsets, trailing bytes, missing padding, and dirty padding. The gate adds exact offset, exact-end, and every-padding-byte checks before forwarding. |
| RT-06 | S1 | Open | Static code caps `raw_call` output at a touched 64-byte buffer and preserves full length. Source tests now cover bomb -> empty and bomb -> empty-revert, including zero length/word/empty hash; runtime execution is pending. |
| RT-07 | S1 | Mitigated | Reentrancy could interleave batches or reuse scratch assumptions. The transient guard is checked before parsing and set before the first CALL; a callback fixture expects the exact custom error. Runtime proof is still covered by RT-04. |
| RT-08 | S2 | Accepted scope | Only the last call's prefix metadata is returned. Per-call results are reduced to aggregate success/failure counts; this is a gate simplification, not a general batch receipt format. |
| RT-09 | S2 | Accepted scope | The policy rejects precompiles, targets with no current code, the firewall itself, empty batches, value, and heterogeneous targets/gas. This is intentional specialization and must not be advertised as a generic firewall. |
| RT-10 | S2 | Mitigated | The raw selector is a literal because textual selectors enforce variant arity. The exact typed message remains in source, and Fe independently confirmed `0x7bd5292b`. |
| RT-11 | S1 | Open | Source instrumentation observes input scratch lengths across 1,024 -> 0 -> 1, distinct first and last words at offsets 0 and 992 for the full payload, and the one-byte prefix after reuse. It has only passed semantic checking; runtime evidence that copying reaches the final word and no length/content is stale is pending. |

## Algorithmic review

- The top-level dynamic offset is exactly 96, so no gap, overlap, or reordering is accepted.
- `ArrayView` bounds the length word and complete element-head region. Each dynamic tail is then forced to the next expected contiguous offset.
- Every `bytes` tail is accessed during the preflight pass, so lazy tail validation cannot be deferred until after a CALL.
- Per-item length is bounded before padded-length arithmetic. Total length uses `total > MAX_TOTAL_DATA - item_len`, avoiding addition overflow.
- Each padded tail end is checked against actual calldata before padding bytes are read.
- Final expected end must equal rebased calldata length, rejecting both zero and nonzero suffixes.
- Address high bits are rejected before `Address::new`.
- Calldata is immutable, so re-reading each validated view during forwarding cannot change the approved bytes.
- Input and output allocations are touched before gas measurement. Target, gas, reserve, and input span are materialized before the adjacent gas check.
- The reserve recurrence saturates on arbitrary words. The public gas limit is additionally capped at 1,000,000.

## Memory claim

Payload-dependent firewall scratch is fixed at:

- 1,024 bytes for forwarded input;
- 64 bytes for copied returndata;
- an 8-word reserve array; and
- a static seven-word summary.

`ArrayView` and `BytesView` retain calldata positions and do not materialize `bytes[]`. This claim excludes normal compiler frame/ABI bookkeeping and the test caller's own allocations. It also does not claim constant validation gas: validation is bounded by 8 elements and at most 31 padding-byte checks per element.

## Contest Red Team

Upside:

- demonstrates a new Fe-specific composition: raw selector dispatch, lazy views, strict canonical policy, bounded raw forwarding, and traceable no-call rejection;
- has a crisp adversarial demo and a measurable fixed-scratch claim;
- exposes why compatibility decoding and a security firewall are different products.

Risks:

- narrow API may look like a batch forwarder unless the canonical-malleability threat and trace evidence lead the demo;
- no user interface and limited receipt shape reduce product completeness;
- judging value collapses if the trace cannot prove preflight-before-CALL or if the gas recurrence flakes.

## Decision criteria

GO requires all of the following:

1. clean build;
2. every gate test green serially;
3. raw-hardening, malformed, bounds, and value/gas traces with zero nested CALLs of any destination;
4. returndata-bomb case reports 65,536 full bytes while copying exactly 64;
5. reentrancy fixture returns the guarded inner failure and outer success;
6. maximum-count/data and eight-OOG-call stress (8 x 512 bytes, four-byte burner code) produce no later-index admission failure;
7. input reuse reports exactly 1,024 -> 0 -> 1 with the expected first word, final word at offset 992, and one-byte prefix;
8. bomb -> empty/failure reports an empty, non-stale final prefix; and
9. no new S0/S1 finding.

PLAN B is appropriate if the strict canonical validator and bounded forwarding work but the recurrence or transient-guard demo needs simplification. In that case, reduce to one forwarded call rather than weakening canonical validation.

KILL if malformed input reaches a target, memory/returndata copying is unbounded, canonical layouts are rejected nondeterministically, the selector cannot be dispatched correctly, or the shared validator cannot pass Fe runtime tests.
