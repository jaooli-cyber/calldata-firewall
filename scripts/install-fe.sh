#!/usr/bin/env bash
set -euo pipefail

destination="${1:-build/tools/fe}"
version="26.5.0"
expected_sha256="3732fbe8a6e9d2ea3925d02d0e3a1478bc1e01d742c2be75d3ea7300c46c45f0"
url="https://github.com/argotorg/fe/releases/download/v${version}/fe_linux_amd64"

mkdir -p "$(dirname "$destination")"
temporary="$(mktemp "${destination}.download.XXXXXX")"
trap 'rm -f -- "$temporary"' EXIT

curl --fail --location --silent --show-error "$url" --output "$temporary"
printf '%s  %s\n' "$expected_sha256" "$temporary" | sha256sum --check --status
chmod 0755 "$temporary"
mv -- "$temporary" "$destination"
trap - EXIT

"$destination" --version
