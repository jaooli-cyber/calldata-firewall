# Cancun demo

The demo executes Fe-generated initcode for a target and for
`CalldataFirewall` inside EthereumJS VM on Cancun. Ethers independently
encodes the six constructor arguments and the raw `execute` endpoint, then
decodes and compares the complete eight-field result.

The same constructor deployment is also required to fail with an invalid opcode
on Shanghai, making the EIP-1153 boundary executable rather than implicit.

It proves the visible scenario `hit / fail / hit -> bitmap 0b101` and records
EVM message edges. Unauthorized caller, target mismatch, and a denied final
selector must each revert with the exact custom error and produce zero nested
messages to either target.

Run from the repository root:

```sh
make demo
```

The demo deliberately does not interpret application return values. A set bit
means only that the corresponding EVM `CALL` opcode returned success.
