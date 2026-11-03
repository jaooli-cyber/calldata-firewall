# Judging guide

Project ID: **FE-014**

Calldata Firewall is a narrow execution boundary for a venue that must accept
only one canonical batch shape. It authenticates the immediate caller, pins one
target and one to three selectors at deployment, validates every item before
the first external call, and forwards with bounded reusable scratch buffers.

## Two-minute path

Run:

```sh
make demo
```

The Cancun demo executes Fe-generated initcode rather than injecting runtime
bytecode. Ethers independently encodes the constructor and endpoint; EthereumJS
executes the result. The visible happy path is:

```text
hit / fail / hit -> attempted 3, succeeded 2, failed 1, bitmap 0b101
```

It then proves three exact rejections with zero nested target messages:

1. unauthorized immediate caller;
2. configured-target mismatch; and
3. an allowed first item followed by a denied final selector.

For the complete reproducible check:

```sh
make verify
```

That command pins Fe 26.5.0 by SHA-256, checks formatting and semantics, builds
release artifacts, runs all 14 source tests, verifies five zero-target rejection
traces plus guarded reentrancy, reconstructs bytecode from Fe metadata, checks
the combined ABI, and runs the external Cancun demo.

## Why Fe matters

- The raw receiver inspects the original message through
  `ArrayView<CallData, Bytes>`; no owned `bytes[]` is decoded.
- Immutable contract fields hold the caller, target, selector count, and three
  selector slots in code-backed state with no setters.
- `TSlot<bool>` provides a Cancun transient reentrancy guard.
- `raw_call` writes into one 64-byte output buffer while reporting full
  returndata length.
- Fe's minimum-gas helper is composed with a backwards suffix-reserve
  recurrence so every admitted call leaves bounded work for the suffix.

## Evidence map

| Claim | Reproducible evidence |
|---|---|
| Complete preflight before forwarding | Five parsed rejection traces; denied last selector case |
| Immutable policy | Constructor matrix and absence of setters |
| Canonical ABI only | Offset, padding, exact-end, alias and overflow vectors |
| Bounded forwarding scratch | 1,024-byte input and 64-byte output reuse observers |
| Returndata bomb resistance | 65,536-byte full length with exactly 64 bytes copied |
| Per-index CALL classification | Bitmaps `101`, `010`, `111`, `ff`, and `0` |
| Cancun integration | Initcode deployment and full result decoding in the external demo |
| Reproducible compilation | Fe metadata rebuild compared byte-for-byte |

## Scope discipline

This is not a generic firewall, DEX, proxy inspector, or business-result
oracle. It forwards zero ETH to one configured code-bearing address, admits
one to eight calls of 4-1,024 bytes, caps total payload data at 4,096 bytes, and
supports at most three four-byte selectors. See `SECURITY.md` for exact
guarantees and non-goals.
