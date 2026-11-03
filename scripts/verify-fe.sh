#!/usr/bin/env bash
set -euo pipefail

binary="${1:?usage: scripts/verify-fe.sh PATH_TO_FE}"
expected_sha256="3732fbe8a6e9d2ea3925d02d0e3a1478bc1e01d742c2be75d3ea7300c46c45f0"
expected_version="fe 26.5.0 (3dab95f)"

if [[ ! -f "$binary" || ! -x "$binary" ]]; then
    echo "Fe binary is missing or not executable: $binary" >&2
    exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
resolved_binary="$(realpath -e -- "$binary")"
case "$resolved_binary" in
    "$repo_root"/*) ;;
    *)
        echo "Fe binary must resolve inside the repository: $resolved_binary" >&2
        exit 1
        ;;
esac

actual_sha256="$(sha256sum "$resolved_binary" | awk '{print $1}')"
if [[ "$actual_sha256" != "$expected_sha256" ]]; then
    echo "Fe SHA-256 mismatch: expected=$expected_sha256 actual=$actual_sha256" >&2
    exit 1
fi

actual_version="$("$resolved_binary" --version)"
if [[ "$actual_version" != "$expected_version" ]]; then
    echo "Fe version mismatch: expected='$expected_version' actual='$actual_version'" >&2
    exit 1
fi

printf 'verified %s sha256=%s\n' "$actual_version" "$actual_sha256"
