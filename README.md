# Calldata Firewall

A specialized Fe gate that accepts exactly one canonical ABI shape, validates the entire lazy calldata view before any external call, and forwards with fixed scratch memory.

Contest work in this repository began after 2026-11-03T00:00:00Z. The implementation was authored from scratch after the Calldata Firewall gate opened at 2026-11-03T07:30:07Z. Precontest research and AI assistance are disclosed; no precontest implementation or pseudocode was copied here.

## Gate status

- Fe 26.5.0 semantic check: PASS.
- Formatting: PASS.
- Release build: PASS.
- Runtime suite: 12 passed, 0 failed.
- Five retained call traces: PASS; all rejection oracles have zero target calls.
- Ethers 6.17 / EthereumJS VM Cancun ABI smoke: PASS.
- Current Red Team disposition: technical GO.

See `GATE-LOG.md` for evidence, `RED-TEAM.md` for open gates, and
`PROVENANCE.md` for the contest boundary and private history normalization.

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

A backwards recurrence reserves enough gas for bounded between-call work, every remaining admission, and final static return encoding. The eight-call all-gas-burner stress passes under the retained gate evidence.

## Adversarial runtime matrix

The retained suite executed all cases below successfully:

- canonical success plus a reverting target while the batch continues;
- short envelope, wrong selector with all lower 224 bits preserved and the Probe target asserted intact, zero count, invalid gas, and invalid targets;
- U256_MAX metadata plus 2^64 aliases whose low bits remain canonical (`count=1`, first offset `32`, and bytes lengths `0/1`), so truncation would reach the target;
- second-tail gap/overlap, alternate top-level offsets, suffixes, and padding;
- full raw-rejection, bounds, and value/gas trace oracles with no post-rejection target query;
- accepted 8-call/4,096-byte-total and 1,024-byte-per-item boundaries;
- eight 512-byte, 100,000-gas calls to the official four-byte all-gas burner under a 2,600,000 outer allowance;
- input scratch reuse across lengths 1,024 -> 0 -> 1, with distinct first- and last-word markers observed by a target;
- output scratch reuse across bomb -> empty and bomb -> empty-revert;
- reentrant callback rejection and a 65,536-byte returndata bomb; and
- reserve monotonicity and saturation.

The exact serial commands and hashes are recorded in `GATE-LOG.md`.

## ABI companion and EVM requirement

The raw receiver intentionally has no typed fields, so Fe's generated ABI
contains the constructor and custom errors but omits `execute`. The exact
function fragment is tracked at
`interfaces/CalldataFirewall.function.abi.json`. It was derived with Fe
26.5.0 from an equivalent typed message and then tested with Ethers against
the actual raw runtime. Clients may use the fragment directly or concatenate
it with the generated ABI entries.

The transient reentrancy guard emits EIP-1153 opcodes. Deployment therefore
requires Cancun or a later fork with EIP-1153 enabled. The retained smoke test
executes and decodes successfully on Cancun and reaches an invalid opcode on
Shanghai, making the fork requirement explicit.

## Final gate evidence

- Evaluated commit: `3830b36a0df35bc3a0fb567e8a2d408261c217e0`.
- Evaluated tree: `c56e477e704dfbf500038848339a84214a56574f`.
- Evidence: `evidence/final-20261103T092200Z` (ignored from Git).
- Evidence-manifest SHA-256:
  `249ec8c5beb8090d39ef1a7bce970a94b10cb1096a8fb0fec642f0a6d88e13dd`.
- Manifest-verification SHA-256:
  `24a48c777a4dca3eeec0e135559274e5bed052f1f84b37185519b5972b0b3d5a`.

Final technical verdict: **GO**. The generated-ABI warning is expected and
closed by the tested companion fragment; it is not an unreported integration
gap.
