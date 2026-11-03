# Calldata Firewall gate log

All times are UTC. This log records only work created in this isolated contest repository after its gate opened.

## Timeline

- 2026-11-03T07:30:07Z - coordinator declared the Calldata Firewall window open. Resource guard remained RG-STOP because external heavy work (two python3 processes and one fe process at about one CPU each) was already sustained. No process arguments or external paths were inspected.
- 2026-11-03T07:30:10Z - server clock independently confirmed the opening time. Repository inspection began only after this confirmation.
- 2026-11-03T07:31Z-07:46Z - implementation, adversarial fixtures, source research, formatting, and semantic checks were performed. No build, test execution, deployment, or other heavy job was started.
- 2026-11-03T07:46:36Z - source was format-clean and `fe check gate` was green; runtime evidence remained deliberately pending.
- 2026-11-03T08:00Z-08:06Z - post-Red-Team hardening added expanded raw rejection traces, an official-pattern OOG burner stress, and observable input/output scratch reuse. Formatting and semantic checks were repeated; no build or runtime test was started.
- 2026-11-03T08:22Z-08:28Z - independent test-oracle review found four source-evidence weaknesses: selector mutation also changed target bytes, exact-2^64 cases could reject after low-bit truncation, the burner used empty calldata, and only the first 1,024-byte input word was observed. Source cases were corrected to preserve the target and canonical low bits, stress 8 x 512 bytes with a four-byte code assertion, and observe offsets 0 and 992. Formatting and semantic checking passed; no build or runtime test was started. The 2.6M outer allowance remains an uncalibrated runtime hypothesis.

## Toolchain

- Fe release: `26.5.0`
- Commit: `3dab95f8eebdccf9a2382bb59a33f7bbd03540ca`
- Local binary SHA-256: `3732fbe8a6e9d2ea3925d02d0e3a1478bc1e01d742c2be75d3ea7300c46c45f0`
- Binary: `.contest-tools/fe_linux_amd64`

## Authored gate

The gate was written from scratch after opening. It implements one deliberately narrow endpoint:

`execute(address target,uint256 gas_limit,bytes[] calls)`

The raw receiver selector is `0x7bd5292b`. Fe's textual selector form cannot be attached to a zero-field raw variant because it enforces field arity, so the raw receiver uses the literal. A typed message with the exact textual signature remains beside it as an encoder and drift check.

Implemented properties:

- lazy `ArrayView<CallData, Bytes>` inspection;
- exact top-level and per-element offsets;
- complete zero-padding and exact-end checks;
- validation of every element before the first external call;
- limits of 8 calls, 1,024 bytes per call, and 4,096 bytes total;
- one 1,024-byte input scratch plus one 64-byte output scratch, each allocated once and reused;
- full returndata length plus a bounded last-prefix report;
- zero-value forwarding only;
- transient reentrancy guard;
- code-bearing, nonzero, non-self target policy;
- adjacent EIP-150 admission with a suffix reserve recurrence;
- source tests for valid/malformed/bounds/maximum cases, reentrancy, returndata bombs, recurrence, and observable scratch reuse;
- a complete trace-only rejection matrix including target-preserving wrong dispatch, zero/oversized policy fields, canonical-low-bit 2^64 aliases, U256_MAX metadata, tail gap/overlap, and invalid targets;
- an eight-call, 4,096-byte-total OOG-burner stress derived from the pinned official Fe fixture, with the deployed four-byte runtime asserted before forwarding.

These source tests have passed semantic checking only. They remain runtime claims to be proved by the single authorized runner.

## Primary-source evidence

All sources are pinned to Fe commit `3dab95f8eebdccf9a2382bb59a33f7bbd03540ca`.

- `ingots/std/src/evm/calldata.fe:8-87` - rebased calldata view and ByteSource implementation.
- `ingots/std/src/abi/array_view.fe:19-33,54-96,98-244` - lazy array view, head bounds, and bytes views.
- `ingots/core/src/abi.fe:20-65,738-878` - padded ByteSource semantics and bounded BytesView copying.
- `crates/fe/tests/fixtures/fe_test/abi_array_view.fe:153-237` - raw calldata test construction and proof that ordinary decoding accepts noncanonical offsets/trailing data.
- `crates/fe/tests/fixtures/fe_test/abi_unpadded_dynamic_payload.fe:20-69,163-220` - ordinary bytes decoding tolerates unpadded/dirty slack, motivating explicit canonical checks.
- `ingots/std/src/evm/effects.fe:553-614` - bounded raw-call output and minimum-gas helper semantics.
- `ingots/std/src/evm/calls.fe:1-33` - conservative EIP-150 admission inequality and 40,000-gas allowance.
- `ingots/core/src/ptr.fe:547-615,628-738` - touched allocation, logical length, capacity, and scratch reuse.
- `ingots/std/src/abi/sol.fe:43-48` - selector is the high four bytes of Keccak.
- `ingots/std/src/evm/effects.fe:41-131` - canonical address word rules.
- `crates/fe/tests/fixtures/fe_test/minimum_gas_calls.fe:23-50,123-139` - tiny raw runtime deployment and the exact all-gas burner `0x5b600056`.

## Lightweight evidence completed

Executed successfully:

```text
./.contest-tools/fe_linux_amd64 fmt gate/src/lib.fe --check --color never
nice -n 15 timeout 60s ./.contest-tools/fe_linux_amd64 check gate --color never
```

Selector derivation was independently confirmed twice with Fe const evaluation:

- the exact signature evaluated to decimal `2077567275`, i.e. `0x7bd5292b`;
- a typed temporary comparison produced a duplicate-selector diagnostic between `sol("execute(address,uint256,bytes[])")` and `0x7bd5292b`.

Temporary selector probes were removed. The same `fmt --check` and low-priority `fe check gate` commands were repeated successfully after the 08:00Z hardening and after the later selector/alias, maximum-workload burner, and first/last-marker corrections. These are still semantic checks, not runtime evidence.

## Heavy evidence plan (completed later)

This section recorded the pre-run condition: GO required the authoritative serial, low-priority sequence in `GATE-RUNBOOK.md`. The sequence has now completed and is recorded under Complete empirical gate below.

For the trace oracles, every failed firewall-call subtree must contain no nested CALL of any destination. The filtered raw-hardening, malformed, bounds, and value/gas tests intentionally perform no post-rejection external call, so any nested CALL is proof-killing.

## Pre-run gate state (historical)

- Semantic feasibility: PASS.
- Runtime/build evidence at that point: PENDING.
- Zero-call trace evidence at that point: PENDING.
- OOG reserve stress and scratch-reuse evidence at that point: PENDING.
- Later final disposition: GO; see Complete empirical gate below.

## Coordinator resource-policy override

- 2026-11-03T09:04Z: the user explicitly clarified that this is a shared
  machine and authorized concurrent gate work whenever aggregate capacity is
  sufficient. This supersedes the earlier stop-on-any-external-heavy-work
  rule for the remaining Calldata Firewall gate only.
- External work remains out of scope and will not be inspected, modified,
  reprioritized, signalled, or stopped.
- Pre-run snapshot at 2026-11-03T09:04:51Z: 8 logical CPUs, load average
  2.13/2.18/2.24, 11.48 GiB MemAvailable, and 112.64 GiB disk free.
- The authorized runner remained limited to one Fe job, one Rayon/Cargo job,
  CPUs 6-7, nice level 15, and idle I/O priority.

## Complete empirical gate

- Fresh evaluated baseline: commit
  `25722e4c53a3bc160b2bc94e5ad1045a1b2b88d6`, tree
  `2f10a33c5a47381ce89f2f9bb8d9100ec8b7e38d`.
- Release build RC 0. The expected ABI warning records that the raw receiver
  cannot be emitted as a typed function.
- Full grouped suite: 12 passed, 0 failed.
- Four rejection-oracle traces passed and each contains zero calls to the
  deployed target. The reentrancy trace contains the expected inner firewall
  revert, target success, and outer firewall success.
- A companion ABI fragment was derived using an equivalent Fe typed receiver.
  The official derived function shape matches the tracked fragment after
  setting the real receiver's mutability to nonpayable.
- Ethers 6.17 encoded selector `0x7bd5292b`; EthereumJS VM 10.1.3 executed
  the actual runtime and decoded the seven-field summary on Cancun.
- The same runtime reached an invalid opcode on Shanghai, confirming that
  EIP-1153/Cancun-or-later is a deployment requirement.
- Evidence: `evidence/final-20261103T092200Z`.
- Evidence-manifest SHA-256:
  `249ec8c5beb8090d39ef1a7bce970a94b10cb1096a8fb0fec642f0a6d88e13dd`.
- Manifest-verification SHA-256:
  `24a48c777a4dca3eeec0e135559274e5bed052f1f84b37185519b5972b0b3d5a`.
- Technical verdict: **GO**.
