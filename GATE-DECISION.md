# Calldata Firewall gate decision

## Verdict

**GO** on the complete technical gate.

The evaluated baseline is commit
`3830b36a0df35bc3a0fb567e8a2d408261c217e0`, tree
`c56e477e704dfbf500038848339a84214a56574f`, with a clean worktree and
Fe 26.5.0 (`3dab95f`).

## Executed evidence

- Release build: RC 0.
- Full grouped runtime suite: 12 passed, 0 failed.
- Four rejection traces: RC 0 and zero calls to the target.
- Reentrancy trace: guarded inner firewall rejection, one target success, and
  outer firewall success.
- Exact 8-call/4,096-byte boundaries, eight exhausted callees, input/output
  scratch reuse, 65,536-byte returndata bomb, and recurrence saturation pass.
- Input, output, evidence, and verification SHA-256 manifests verify.

## ABI and deployment closure

Fe correctly warns that the raw zero-field receiver cannot be represented in
the generated function ABI. The tracked companion fragment
`interfaces/CalldataFirewall.function.abi.json` was independently derived
from an equivalent Fe typed-message contract. Ethers 6.17 encoded selector
`0x7bd5292b`, actual runtime bytecode executed on EthereumJS VM 10.1.3
Cancun, and the returned tuple decoded to the expected summary.

The same bytecode reaches an invalid opcode under Shanghai because the
transient guard requires EIP-1153. Cancun-or-later is therefore a documented
deployment requirement, not an unresolved compatibility claim.

## Residual limitations

- The API is intentionally narrow and zero-value.
- Exact minimum outer-gas and peak total VM memory are not benchmark claims.
- The generated ABI and companion fragment must be distributed together.
- The receipt summarizes the final bounded prefix rather than every call.

No open S0 or S1 remains for the gate claim. Evidence is retained at
`evidence/final-20261103T092200Z`; its manifest SHA-256 is
`249ec8c5beb8090d39ef1a7bce970a94b10cb1096a8fb0fec642f0a6d88e13dd`.
