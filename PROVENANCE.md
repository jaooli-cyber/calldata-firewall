# Provenance

## Contest boundary

The Fe Builders Challenge 2026 build window opened at
`2026-11-03T00:00:00Z`. This repository and all executable Fe work in it were
created after that boundary. The first implementation work began only after
the isolated Calldata Firewall gate opened at `2026-11-03T07:30:07Z`.

Precontest work consisted of research, specification, non-compilable
pseudocode, test planning, and Red Team analysis. It remains separate. No
precontest implementation or pseudocode was copied into this repository.

## Toolchain

- Fe release: 26.5.0
- Fe commit: `3dab95f8eebdccf9a2382bb59a33f7bbd03540ca`
- Linux binary SHA-256:
  `3732fbe8a6e9d2ea3925d02d0e3a1478bc1e01d742c2be75d3ea7300c46c45f0`

## Private history normalization

Before the first remote was created, the 12-commit local history was
normalized to replace a machine-local absolute project root in the historical
runbook with a repository-root expression. Fe source, tests, fixtures, ABI
data, authorship, timestamps, commit messages, and commit topology were
preserved. No unrelated candidate name was present in the history.

The evaluated technical baseline is the normalized commit
`3830b36a0df35bc3a0fb567e8a2d408261c217e0`, tree
`c56e477e704dfbf500038848339a84214a56574f`.

A recoverable pre-normalization snapshot is retained only in an ignored local
Git bundle. Its SHA-256 is
`3492355cb72006cd221d9a19eb7645771f810ca69dd6e477e2780958e590155e`.
The bundle and old-to-new commit map are not part of the submission.

## Evidence policy

The historical gate archive was generated before normalization and remains
private. Its digests document the technical gate but are not a substitute for
submission evidence. Build products, traces, metrics, and demo evidence for
judging will be regenerated from the exact submitted commit by tracked scripts
and CI.

AI assistance is disclosed for research, design review, Red Team analysis,
implementation support, test planning, documentation, and review. All claims
