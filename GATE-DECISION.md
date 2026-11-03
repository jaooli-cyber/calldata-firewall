# Calldata Firewall - historical gate decision

## Scope

This document freezes the decision for the original decoder/forwarder
viability gate. It does not certify later interface or policy changes.

## Historical verdict

**GO** on the historical technical gate.

The evaluated baseline is commit
`3830b36a0df35bc3a0fb567e8a2d408261c217e0`, tree
`c56e477e704dfbf500038848339a84214a56574f`, with a clean worktree and
Fe 26.5.0 (`3dab95f`).

## Historical executed evidence

- Release build: RC 0.
- Full grouped runtime suite: 12 passed, 0 failed.
- Four rejection traces: RC 0 and zero calls to the target.
- Reentrancy trace: guarded inner firewall rejection, one target success, and
  outer firewall success.
- Exact 8-call/4,096-byte boundaries, eight exhausted callees, input/output
  scratch reuse, 65,536-byte returndata bomb, and recurrence saturation pass.
- Input, output, evidence, and verification SHA-256 manifests verify.

## Historical ABI and deployment closure

Fe correctly warned that the raw zero-field receiver could not be represented
in the generated function ABI. The companion fragment was independently
derived from an equivalent Fe typed-message contract. Ethers 6.17 encoded
selector `0x7bd5292b`, the actual baseline runtime executed on EthereumJS VM
10.1.3 Cancun, and the seven-field tuple decoded as expected.

The same baseline bytecode reached an invalid opcode under Shanghai because
the transient guard requires EIP-1153. Cancun-or-later remains a deployment
requirement.

No open S0 or S1 remains for this historical gate claim. Evidence is retained
at `evidence/final-20261103T092200Z`; its manifest SHA-256 is
`249ec8c5beb8090d39ef1a7bce970a94b10cb1096a8fb0fec642f0a6d88e13dd`.

## Post-gate submission candidate

Commit `6d3b43ce8ed49f033b0f883a73a404bb8bf5c6bd` introduced:

- immutable immediate-caller and target authorization;
- an immutable 1-3 selector allowlist;
- preflight rejection of short or disallowed payloads;
- constructor fail-closed checks and explicit constructor boundary tests; and
- a per-index EVM-call success bitmap.

The submission candidate referenced by `fe-014-submission-v1` passes
`make verify`: 14/14 tests, five clean rejection traces plus guarded
reentrancy, byte-identical metadata, combined-ABI validation, and
actual-initcode Cancun deployment with eight-field decoding. The demo also
proves Shanghai deployment rejection. Submission-candidate status is **GO**.

## Policy decisions and residual limitations

- Active selector slots are determined by `selectorCount`. Selector zero is
  valid when active; inactive slots must be zero.
- `authorizedCaller == allowedTarget` is permitted. The transient guard still
  rejects nested firewall execution.
- The configured target must have code at deployment and execution, but no code
  hash is pinned. Proxies, code replacement, and later semantic changes remain
  outside the guarantee.
- Selector admission does not validate arguments or application intent.
- The bitmap records only EVM `CALL` success. Returndata metadata describes
  only the final attempt.
- The API remains intentionally narrow, zero-value, and Cancun-or-later.
- Exact minimum outer gas and peak total VM memory are not benchmark claims.

Fresh evidence was regenerated from the exact tagged candidate; the historical
GO remains context, not a substitute. The official form's 40-character SHA is
the authoritative identity.
