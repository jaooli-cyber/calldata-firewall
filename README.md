# Calldata Firewall

A specialized Fe gate that accepts exactly one canonical ABI shape, validates the entire lazy calldata view before any external call, and forwards with fixed scratch memory.

Contest work in this repository began after 2026-11-03T00:00:00Z. The implementation was authored from scratch after the Calldata Firewall gate opened at 2026-11-03T07:30:07Z. Precontest research and AI assistance are disclosed; no precontest implementation or pseudocode was copied here.

## Gate status

- Fe 26.5.0 semantic check: PASS.
- Formatting: PASS.
- Build and runtime tests: pending the coordinator's resource guard.
- Zero-nested-CALL trace: pending.
- Current Red Team disposition: conditional PLAN B, not GO.

See `GATE-LOG.md` for evidence and `RED-TEAM.md` for open gates.

## Endpoint

| Property | Value |
|---|---|
| Signature | `execute(address target,uint256 gas_limit,bytes[] calls)` |
| Selector | `0x7bd5292b` |
| Value | rejected; every forwarded call uses zero wei |
| Target | one nonzero, non-self address with current code |
| Calls | 1-8 |
| Per-call input | 0-1,024 bytes |
| Total input | 0-4,096 bytes |
| Gas per call | 1-1,000,000 |
| Returndata copied | at most 64 bytes per call, into one reused buffer |
| Failure policy | continue; aggregate successes/failures |
| Return | static `ForwardSummary`; last full returndata length and bounded-prefix metadata |

This is not a generic ABI firewall. It verifies only the signature above and intentionally rejects alternative ABI layouts that ordinary Solidity-compatible decoders may accept.

## Canonical policy

After rebasing calldata past the four-byte selector, the handler requires:

1. a complete three-word head;
2. a canonical address word;
3. a gas limit within policy;
4. the `bytes[]` offset to equal 96;
5. a count between 1 and 8;
6. the first element tail to follow all element heads immediately;
7. every later tail to follow the previous padded tail immediately;
8. every `bytes` length to stay within per-item and total bounds;
9. every padding byte to be zero; and
10. the final padded tail to end exactly at calldata end.

All tails are touched by the validation pass before target code is checked and before the transient guard is set for forwarding. Therefore a malformed batch has no reachable CALL instruction in the handler's control flow.

## Fixed scratch architecture

The handler uses `ArrayView<CallData, Bytes>` and `BytesView` for lazy inspection. It does not decode `bytes[]` into owned memory.

After validation it allocates and touches exactly:

- one 1,024-byte input buffer, truncated and refilled for each call;
- one 64-byte output buffer, reused by `raw_call`;
- one eight-word suffix-reserve array; and
- one static summary.

The output buffer's capacity caps copied returndata while `RawCallOutcome::returndata_len()` preserves the target's full length.

## Forwarding and gas

Each call receives the same requested gas and zero wei. Before each CALL, current input and output memory expansion has already been paid. The gate then applies Fe stdlib's conservative EIP-150 check adjacent to `raw_call`.

A backwards recurrence reserves enough gas for bounded between-call work, every remaining admission, and final static return encoding. The constants are deliberately conservative but still require runtime stress evidence before GO.

## Adversarial matrix

The source includes tests for:

- canonical success plus a reverting target while the batch continues;
- alternate top-level and element offsets;
- trailing bytes, dirty padding, missing padding, and dirty address bits;
- fabricated count, per-item bound, and total bound;
- nonpayable value rejection and insufficient forwarding gas;
- reentrant callback rejection;
- 65,536-byte returndata with a 64-byte copied prefix;
- reserve monotonicity/saturation; and
- accepted 8-call/4,096-byte-total and 1,024-byte-per-item boundaries; and
- full malformed, bounds, and value/gas trace oracles with no post-rejection target query.

The single authorized runner should use the exact serial commands recorded in `GATE-LOG.md`; do not start a competing build/test process while RG-STOP is active.
