# Toolchain

- Downloaded after H0 from the official Fe v26.5.0 release asset fe_linux_amd64.
- Tag commit: 3dab95f8eebdccf9a2382bb59a33f7bbd03540ca.
- Size: 54195184 bytes.
- SHA-256: 3732fbe8a6e9d2ea3925d02d0e3a1478bc1e01d742c2be75d3ea7300c46c45f0.
- Version output: fe 26.5.0 (3dab95f).

## Reproducible entry point

`make verify` downloads Fe from the official v26.5.0 release only when the
default binary is absent. On every invocation it requires the configured
binary to resolve inside this repository and verifies both the SHA-256 and
exact version above. It then runs format, semantic check, clean release build,
all tests, exact trace oracles, metadata recompilation, ABI comparison, and the
Cancun/Shanghai demo.

The external demo is locked by `demo/package-lock.json`. CI pins Node.js
20.19.5, npm 10.8.2, and commit SHAs for checkout and Node setup. Direct demo
dependencies are Ethers 6.17.0 and EthereumJS `common`, `util`, and `vm`
10.1.3.
