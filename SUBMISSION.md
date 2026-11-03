# FE-014 submission copy

This file contains the public, non-secret text prepared for the official Fe
Builders Challenge submission form. The registered contact email and private
submission code are intentionally excluded and must never be committed.

## Final project name

Calldata Firewall

## One-sentence pitch

Calldata Firewall is an immutable Fe execution boundary that authenticates a
venue, rejects every non-canonical or selector-disallowed batch before the
first external call, and forwards admitted calls with bounded memory, reserved
gas, and an exact per-call success bitmap.

## Repository and candidate identity

- Repository: `https://github.com/jaooli-cyber/calldata-firewall`
- Project ID: `FE-014`
- Navigation tag: `fe-014-submission-v2`
- Authoritative identity: the full 40-character commit SHA entered in the
  official submission form. The tag must point to that same commit.

## Exact Fe toolchain version

`fe 26.5.0 (3dab95f)`, release commit
`3dab95f8eebdccf9a2382bb59a33f7bbd03540ca`. Official Linux binary SHA-256:
`3732fbe8a6e9d2ea3925d02d0e3a1478bc1e01d742c2be75d3ea7300c46c45f0`.

## Fe-specific technical highlight

The raw receiver inspects the original message through
`ArrayView<CallData, Bytes>` and `BytesView` instead of decoding an owned
`bytes[]` allocation. Fe immutable fields pin the authorized caller, target,
and selector policy with no administration path; `TSlot<bool>` supplies a
Cancun transient reentrancy guard; and `raw_call` reuses a fixed 64-byte output
buffer while still reporting full returndata length. A backwards suffix-reserve
recurrence composes with Fe's minimum-gas helper so each admitted call leaves
bounded work for the remaining suffix and final ABI encoding. Because the
receiver deliberately bypasses typed decoding, the repository also builds and
verifies an exact ABI companion for independent consumers.

## Demo or reproducible example

Clone the public repository, check out the full commit SHA supplied in the
submission, and run `make demo` from the repository root on Linux with Node.js
20 or later and npm. The command downloads and verifies the official Fe 26.5.0
binary, builds the Fe-generated initcode, installs locked demo dependencies,
and runs it in EthereumJS VM. Expected happy path:
`hit / fail / hit -> attempted 3, succeeded 2, failed 1, bitmap 0b101`. It also
proves three policy rejections with zero nested target calls and confirms that
the same initcode is rejected on Shanghai because EIP-1153 is unavailable.
Run `make verify` for formatting, semantic checks, release builds, all 14 Fe
tests, exact trace oracles, byte-identical metadata reconstruction, ABI
verification, and the Cancun/Shanghai demo.

## Pre-existing work, reused code, and AI assistance

Before the build window, work was limited to research, specification,
non-compilable pseudocode, test planning, threat modelling, and Red Team
analysis kept outside this repository. No precontest implementation or
pseudocode was copied into the entry. All executable Fe code, tests,
verification scripts, and demo work in this repository were created after
November 3, 2026 at 00:00 UTC. No existing project implementation or copied
application code was reused; the project uses the official Fe 26.5.0
compiler/standard library and locked Ethers and EthereumJS dependencies for
its independent demo. AI assisted research, architecture and security review,
implementation support, test planning, documentation, and Red Team analysis.
Every technical claim is covered by reproducible tests or traces, and the
human entrant remains responsible for the submission.
