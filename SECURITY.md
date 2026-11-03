# Security model

## Protected boundary

A deployed firewall has no administration path. Its constructor fixes:

- one nonzero immediate caller;
- one nonzero, non-self target that has code at deployment;
- a selector count from one to three; and
- distinct active selector slots, with inactive slots required to be zero.

The active selector `0x00000000` is deliberately valid because the explicit
count, not the selector value, marks active slots. The authorized caller and
target may deliberately be the same code-bearing venue.

For every invocation, reentrancy and caller authorization are checked before
argument validation. The complete batch is then checked for exact canonical
layout, fixed target, allowed selector on every item, size limits, zero padding,
and exact end. No forwarding `CALL` is reachable until that pass completes.

## Guarantees in scope

- zero target calls for rejected envelopes and rejected policies;
- no ETH accepted or forwarded;
- one target, one gas allowance, one to eight calls;
- 4-1,024 bytes per call and at most 4,096 bytes in total;
- one reused 1,024-byte input buffer and one reused 64-byte output buffer;
- full returndata length reported without copying more than 64 bytes;
- transient reentrancy rejection on Cancun or later;
- continuation after target reverts; and
- a least-significant-bit-first bitmap where bit `i` is one exactly when the
  EVM `CALL` for item `i` returned success.

## Non-goals and residual threats

A set bitmap bit is not application or business success. Return values are not
interpreted. Selector admission does not validate the target function's
internal argument semantics.

The firewall checks that the configured target has code at construction and
again before forwarding, but it does not pin `EXTCODEHASH`. Proxy upgrades,
implementation changes, selector collisions, target semantic changes, and code
disappearance or replacement are outside the guarantee. The configured caller
may itself be an upgradeable or otherwise mutable contract; immutability of its
address does not imply immutability of its behavior.

The final receipt retains full metadata only for the last call and aggregate
counts plus the bitmap for the batch. Exact minimum outer gas, gas portability
to other compiler versions, mainnet readiness, and pre-Cancun deployment are
not claimed.

## Reporting

Please use GitHub private vulnerability reporting for this repository when it
is available. Include the exact commit, Fe version, minimal calldata, expected
invariant, actual trace, and a reproducible command. Do not include secrets or
test against public infrastructure.
