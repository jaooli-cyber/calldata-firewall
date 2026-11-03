# Calldata Firewall

A specialized Fe firewall that authenticates one immediate caller, enforces one
target and a small selector allowlist, validates the complete canonical ABI
shape before any external call, and forwards through bounded, reused scratch
buffers.

Contest work in this repository began after 2026-11-03T00:00:00Z. The implementation was authored from scratch after the Calldata Firewall gate opened at 2026-11-03T07:30:07Z. Precontest research and AI assistance are disclosed; no precontest implementation or pseudocode was copied here.

Official Fe Builders Challenge registration identifier: **FE-014**.

## Status

### Historical viability baseline

Commit `3830b36a0df35bc3a0fb567e8a2d408261c217e0` established the
decoder/forwarder gate: release build, 12/12 runtime tests, four zero-target-call
rejection traces, one reentrancy trace, and the Ethers/Cancun smoke all passed.
That evidence predates the immutable policy and success bitmap; it is a
historical feasibility result, not evidence for the current interface.

### Current hardening snapshot

Commit `6d3b43ce8ed49f033b0f883a73a404bb8bf5c6bd` is the code snapshot
for the immutable caller/target/selector policy, exact policy errors,
constructor rejection coverage, and per-index success bitmap. In the current
local worktree, `make verify` passes: 14/14 tests, five zero-target-call
rejection traces plus reentrancy, byte-identical metadata reproduction,
combined-ABI checks, and an actual-initcode Cancun demo decoding the eight-field
tuple. The final candidate commit and evidence hashes remain TBD.

See `GATE-LOG.md` for historical evidence, `RED-TEAM.md` for security review,
and `PROVENANCE.md` for the contest boundary and private history normalization.

## Endpoint

| Property | Value |
|---|---|
| Signature | `execute(address target,uint256 gas_limit,bytes[] calls)` |
| Selector | `0x7bd5292b` |
| Constructor | `(address authorizedCaller,address allowedTarget,uint8 selectorCount,uint32 selector0,uint32 selector1,uint32 selector2)` |
| Caller | immediate `msg.sender` must equal `authorizedCaller` |
| Value | rejected; every forwarded call uses zero wei |
| Target | must equal immutable `allowedTarget` and have current code |
| Selectors | every payload begins with one of 1-3 immutable selectors |
| Calls | 1-8 |
| Per-call input | 4-1,024 bytes |
| Total input | 4-4,096 bytes |
| Gas per call | 1-1,000,000 |
| Returndata copied | at most 64 bytes per call, into one reused buffer |
| Failure policy | continue; aggregate successes/failures |
| Return | counts, a per-index success bitmap, and final-call bounded-prefix metadata |

This is not a generic ABI firewall. It protects one configured venue-to-target
route and intentionally rejects alternative ABI layouts that ordinary
Solidity-compatible decoders may accept.

## Immutable deployment policy

- Caller and target must be nonzero. The target must contain code at deployment
  and cannot be the firewall being created.
- `selectorCount` is 1-3. Active selectors must be distinct and inactive slots
  must be zero.
- Selector `0x00000000` is deliberately valid in an active slot: the explicit
  count, not the selector value, marks a slot active.
- `authorizedCaller == allowedTarget` is deliberately valid. A venue may call
  its firewall and receive a callback through its own target entry point; the
  transient guard still rejects a nested firewall execution.
- There are no setters or policy-admin entry points.

## Canonical policy

The handler first rejects reentrancy and any immediate caller other than the
configured caller. After rebasing calldata past the four-byte selector, it
requires:

1. a complete three-word head;
2. a canonical address word equal to the configured target;
3. a gas limit within policy;
4. the `bytes[]` offset to equal 96;
5. a count between 1 and 8;
6. the first element tail to follow all element heads immediately;
7. every later tail to follow the previous padded tail immediately;
8. every `bytes` length to be 4-1,024 and the aggregate to be at most 4,096;
9. every payload selector to be in the immutable allowlist;
10. every padding byte to be zero; and
11. the final padded tail to end exactly at calldata end.

All tails are touched by the validation pass before target code is checked and
before the transient guard is set for forwarding. Therefore a malformed batch
has no reachable `CALL` instruction in the handler's control flow.

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

Bit `i` of `success_bitmap` corresponds to input index `i`, with index zero
in the least-significant bit. A one means only that the EVM `CALL` returned its
success flag; it does not prove application-level or business success. The
returndata length and bounded-prefix fields describe only the final attempted
call.

## Adversarial runtime matrix

The 14-test local suite at the current hardening snapshot covers:

- canonical and inverse success/failure sequences with exact `0b101` and
  `0b010` bitmaps;
- constructor rejection for zero caller/target, code-less target, invalid
  selector counts, nonzero inactive slots, and duplicate active selectors;
- deliberate constructor acceptance of selector zero and `caller == target`;
- unauthorized caller, configured-target mismatch, 0-3-byte payloads, and
  denied selectors at the first and final indexes;
- short envelope, wrong selector with all lower 224 bits preserved, zero count,
  invalid gas, and invalid targets;
- U256_MAX metadata plus 2^64 aliases whose low bits remain canonical;
- tail gaps/overlaps, alternate top-level offsets, suffixes, and dirty padding;
- five rejection trace-oracle functions with no post-rejection target query;
- accepted 8-call/4,096-byte-total and 1,024-byte-per-item boundaries;
- eight 512-byte, 100,000-gas calls to the four-byte all-gas burner;
- input scratch reuse across lengths 1,024 -> 4 -> 5, with first- and last-word
  markers observed by a target;
- output scratch reuse across bomb -> empty and bomb -> empty-revert;
- reentrant callback rejection and a 65,536-byte returndata bomb; and
- reserve monotonicity and saturation.

`GATE-LOG.md` records the historical baseline. The current path is tracked in
the Makefile, scripts, and CI; `make verify` passes locally. It must be rerun
unchanged from the final candidate commit before release hashes are recorded.

## ABI companion and EVM requirement

The raw receiver intentionally has no typed fields, so Fe's generated ABI
contains the constructor and custom errors but omits `execute`. The raw
function fragment and assembled interface are tracked at
`interfaces/CalldataFirewall.function.abi.json` and
`interfaces/CalldataFirewall.abi.json`. `make abi-check` proves that a fresh
assembly is byte-identical to the tracked combined ABI.

The current demo deploys actual initcode on Cancun with all six constructor
arguments, calls `execute`, and decodes the eight-field summary including the
exact bitmap. It also attempts the same deployment on Shanghai and confirms
rejection at the EIP-1153 boundary. The transient reentrancy guard therefore
requires Cancun or later; no pre-Cancun support is claimed.

## Security boundaries

- Authorization is based on the immediate caller, not `tx.origin`. An
  upgradeable or compromised authorized-caller contract can change who is
  admitted at its own layer.
- Address immutability does not pin semantics. A proxy target can change
  implementation, and target code can disappear or be replaced. No
  `EXTCODEHASH` is pinned.
- Selector admission does not validate arguments, downstream state, fallback
  behavior, or application intent.
- A success bit is the EVM `CALL` success flag, not proof that the callee
  achieved a business outcome.
- The product deliberately excludes ETH forwarding, heterogeneous targets,
  per-call gas policies, mainnet readiness claims, and pre-Cancun deployment.

## Historical gate evidence

- Commit: `3830b36a0df35bc3a0fb567e8a2d408261c217e0`.
- Tree: `c56e477e704dfbf500038848339a84214a56574f`.
- Evidence: `evidence/final-20261103T092200Z` (ignored from Git).
- Evidence-manifest SHA-256:
  `249ec8c5beb8090d39ef1a7bce970a94b10cb1096a8fb0fec642f0a6d88e13dd`.
- Manifest-verification SHA-256:
  `24a48c777a4dca3eeec0e135559274e5bed052f1f84b37185519b5972b0b3d5a`.

Historical gate verdict: **GO**. Current local hardening verdict:
**technical GO**. The final candidate commit and evidence hashes remain TBD;
`make verify` must pass again from that exact commit before submission.
