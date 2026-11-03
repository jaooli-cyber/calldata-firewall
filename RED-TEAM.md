# Calldata Firewall - independent Red Team

## Scope and adversary

This review separates the historical viability gate from the current immutable
policy/bitmap hardening. The attacker can choose calldata words, lengths,
offsets, padding, gas, and call origin; the configured target can return
arbitrary data, revert, exhaust gas, or attempt reentrancy. The MVP forwards no
ETH.

The protected invariants are:

1. only the configured immediate caller can use the configured target and
   selector allowlist;
2. every rejected invocation reaches zero forwarding `CALL` instructions;
3. accepted input cannot make forwarding scratch scale with aggregate payload
   or returndata beyond the documented caps; and
4. bitmap bit `i` reports only the EVM `CALL` success flag for input index
   `i`, with index zero in the least-significant bit.

## Findings

| ID | Severity | Status | Finding and disposition |
|---|---:|---|---|
| RT-01 | S0 | Historical closed | Release build and 12/12 tests passed on baseline `3830b36`. |
| RT-02 | S1 | Local closed | The hardening snapshot passes 14/14 Fe tests. Exact candidate reproduction remains pending. |
| RT-03 | S1 | Local closed | All five current rejection traces pass with zero target calls; final-commit retention remains a release step. |
| RT-04 | S1 | Local closed | The demo deploys current initcode on Cancun and confirms deployment rejection on Shanghai. |
| RT-05 | S1 | Mitigated | Exact offsets, exact end, high-bit rejection, and every padding byte are checked before forwarding. |
| RT-06 | S1 | Local closed | Tests cover the 64-byte copy cap, full 65,536-byte length, and non-stale bomb -> empty summaries. |
| RT-07 | S1 | Local closed | The callback fixture proves guarded inner rejection and successful outer call; fresh trace retention remains part of the candidate gate. |
| RT-08 | S2 | Accepted scope | The bitmap classifies each EVM call, but only the final attempt's bounded returndata metadata is returned. |
| RT-09 | S2 | Accepted scope | One caller, one target, 1-3 selectors, zero ETH, homogeneous gas, 1-8 calls, and Cancun+ are intentional scope. |
| RT-10 | S2 | Mitigated | The raw selector is literal because textual selectors enforce variant arity; the typed message independently fixes `0x7bd5292b`. |
| RT-11 | S1 | Local closed | Runtime observes scratch lengths 1,024 -> 4 -> 5, boundary words, and no stale logical extent. |
| RT-12 | S1 | Local closed | Constructor and runtime matrices reject invalid policy, unauthorized caller, target mismatch, short payloads, and denied selectors. |
| RT-13 | S2 | Accepted risk | Immutable addresses do not freeze proxy or metamorphic-code semantics; no code hash is pinned. |
| RT-14 | S1 | Local closed | Combined ABI, eight-field decoding, and metadata regeneration pass byte-for-byte under `make verify`. |
| RT-15 | S1 | Local closed | Final infrastructure review requires exact trace destinations/counts, always-on Fe hash/version checks, repository-confined outputs, and full ABI schema validation; all four gates pass under `make verify`. |

## Algorithmic review

- The transient guard check precedes caller authorization; caller authorization
  precedes calldata validation; target and selector policy complete before the
  forwarding guard is set and before any external `CALL`.
- Every payload is at least four bytes and every selector, including the final
  element's selector, is validated during the complete preflight.
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
- a static eight-word summary.

`ArrayView` and `BytesView` retain calldata positions and do not materialize `bytes[]`. This claim excludes normal compiler frame/ABI bookkeeping and the test caller's own allocations. It also does not claim constant validation gas: validation is bounded by 8 elements and at most 31 padding-byte checks per element.

## Contest Red Team

Upside:

- demonstrates a Fe-specific composition of immutable venue policy, raw
  selector dispatch, lazy views, bounded forwarding, bitmap receipts, and traceable no-call rejection;
- has a crisp adversarial demo and a measurable fixed-scratch claim;
- exposes why compatibility decoding and a security firewall are different products.

Risks:

- the narrow API can still look like a batch forwarder unless authorization,
  whole-batch preflight, bitmap semantics, and trace evidence lead the demo;
- no user interface and limited receipt shape reduce product completeness;
- judging value collapses if the trace cannot prove preflight-before-CALL or if the gas recurrence flakes.

## Decision criteria

GO requires all of the following:

1. `make verify` reproduces a clean build and byte-identical generated metadata;
2. all 14 Fe tests pass serially;
3. malformed, bounds, raw-hardening, value/gas, and policy rejection traces
   contain zero forwarding `CALL` instructions;
4. the reentrancy trace shows guarded inner rejection and outer success;
5. constructor tests prove invalid policy fails closed and the documented
   selector-zero and `caller == target` decisions remain intentional;
6. the returndata bomb reports 65,536 full bytes while copying exactly 64;
7. maximum count/data and eight-OOG-call stress produce no late admission
   failure;
8. input reuse reports exactly 1,024 -> 4 -> 5 with the boundary markers;
9. bomb -> empty/failure reports an empty, non-stale final prefix;
10. the combined ABI deploys actual initcode on Cancun and decodes the
    eight-field tuple, including the exact bitmap; and
11. no new S0/S1 finding remains open.

PLAN B is appropriate if strict preflight and policy enforcement hold but the
multi-call gas recurrence or receipt demo must be simplified. Reduce to one
forwarded call rather than weaken caller, target, selector, or canonicality
checks.

KILL if malformed or unauthorized input reaches a target, copying becomes
unbounded, policy can be mutated or bypassed, bitmap indexes are ambiguous, or
the exact runtime cannot pass the combined-ABI Cancun demo.

## Empirical Red Team closure

Historical baseline `3830b36` remains closed at 12/12 tests, four
zero-target-call rejection traces, one reentrancy trace, and its original
Cancun/Shanghai smoke.

Current local hardening evidence now closes the added technical gates:

- **S0/S1:** none open in the verified local worktree.
- All 14 Fe tests pass.
- All five rejection traces contain zero target calls; the reentrancy trace
  shows guarded inner rejection and outer success.
- Generated metadata is byte-identical after regeneration.
- The combined ABI includes the constructor, custom errors, raw `execute`
  fragment, and eight-field summary.
- The current initcode demo deploys the actual constructor on Cancun, decodes
  the exact tuple and bitmap, and confirms deployment rejection on Shanghai.
- `make verify` passes as the one-command local reproduction path.
- **S2:** proxy/code semantic mutability, selector-only semantics, exact minimum
  gas, peak total VM memory, broader receipts, and pre-Cancun compatibility
  remain outside the claim.

Red Team technical verdict: **GO**, not PLAN B. Release evidence still needs to
be pinned to the final commit (TBD) and rerun there without changing artifacts.
