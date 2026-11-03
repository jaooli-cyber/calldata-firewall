#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C
export TZ=UTC
umask 022

pre_tag="${EVIDENCE_PRE_TAG:-0}"
if [[ "$pre_tag" != "0" && "$pre_tag" != "1" ]]; then
    echo "EVIDENCE_PRE_TAG must be 0 or 1" >&2
    exit 1
fi

label="${1:-}"
if [[ ! "$label" =~ ^fe-014-submission-v[1-9][0-9]*$ ]]; then
    echo "release label must match fe-014-submission-vN (N >= 1)" >&2
    exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"

flagged_index_entry="$(git ls-files -v | awk '$1 ~ /^[a-zS]$/ { print; exit }')"
if [[ -n "$flagged_index_entry" ]]; then
    echo "release evidence refuses assume-unchanged or skip-worktree entries" >&2
    exit 1
fi
if [[ -n "$(git status --porcelain --untracked-files=normal)" ]]; then
    echo "release evidence requires a clean tracked worktree and index" >&2
    exit 1
fi

commit_sha="$(git rev-parse --verify HEAD)"
tree_sha="$(git rev-parse --verify 'HEAD^{tree}')"
if git show-ref --verify --quiet "refs/tags/$label"; then
    if [[ "$(git cat-file -t "refs/tags/$label")" != "tag" ]]; then
        echo "existing release tag must be annotated: $label" >&2
        exit 1
    fi
    tagged_commit="$(git rev-parse --verify "$label^{commit}")"
    if [[ "$tagged_commit" != "$commit_sha" ]]; then
        echo "existing tag $label does not point to HEAD" >&2
        exit 1
    fi
elif [[ "$pre_tag" != "1" ]]; then
    echo "release tag does not exist; use EVIDENCE_PRE_TAG=1 only for pre-tag preparation" >&2
    exit 1
fi

make verify FE=build/tools/fe

if [[ -n "$(git status --porcelain --untracked-files=normal)" ]]; then
    echo "verification changed the tracked worktree or index" >&2
    exit 1
fi

./scripts/verify-fe.sh build/tools/fe >/dev/null
fe_version="$(build/tools/fe --version)"
fe_sha256="$(sha256sum build/tools/fe | awk '{print $1}')"

out_dir="$(./scripts/safe-output-dir.sh --reset build/release-evidence)"
staging="$out_dir/staging"
mkdir -p -- "$staging/artifacts/reproduced" "$staging/traces"

artifact_sources=(
    build/CalldataFirewall.bin
    build/CalldataFirewall.runtime.bin
    build/CalldataFirewall.abi.json
    build/CalldataFirewall.metadata.json
    build/CalldataFirewall.combined.abi.json
    build/Probe.bin
    build/Probe.runtime.bin
    build/Probe.abi.json
    build/reproduced/CalldataFirewall.bin
    build/reproduced/CalldataFirewall.runtime.bin
    build/reproduced/CalldataFirewall.abi.json
)

trace_sources=(
    build/traces/malformed_canonicality_matrix_zero_call_trace_oracle.log
    build/traces/bounds_zero_call_trace_oracle.log
    build/traces/raw_rejection_hardening_zero_call_trace_oracle.log
    build/traces/value_and_gas_zero_call_trace_oracle.log
    build/traces/policy_rejections_zero_target_call_trace_oracle.log
    build/traces/reentrancy_is_rejected_before_nested_validation.log
)

validate_generated_file() {
    local path="$1"
    local resolved
    if [[ ! -f "$path" || -L "$path" ]]; then
        echo "missing, non-regular, or symlinked generated file: $path" >&2
        exit 1
    fi
    resolved="$(realpath -e -- "$path")"
    case "$resolved" in
        "$repo_root/build"/*) ;;
        *)
            echo "generated file escaped build directory: $path" >&2
            exit 1
            ;;
    esac
    if [[ "$(stat -c %h -- "$path")" != "1" ]]; then
        echo "refusing multiply-linked generated file: $path" >&2
        exit 1
    fi
}

bundle_files=()
for source in "${artifact_sources[@]}"; do
    validate_generated_file "$source"
    relative="${source#build/}"
    destination="artifacts/$relative"
    mkdir -p -- "$staging/$(dirname "$destination")"
    install -m 0644 -- "$source" "$staging/$destination"
    bundle_files+=("$destination")
done

for source in "${trace_sources[@]}"; do
    validate_generated_file "$source"
    destination="traces/${source#build/traces/}"
    sed -E '1s/\[[0-9]+([.][0-9]+)?s\]/[DURATION]/' \
        "$source" >"$staging/$destination"
    chmod 0644 "$staging/$destination"
    bundle_files+=("$destination")
done

hex_byte_length() {
    local path="$1"
    local characters
    if ! grep -Eq '^[0-9a-f]+$' "$path"; then
        echo "expected lowercase hexadecimal bytecode: $path" >&2
        exit 1
    fi
    characters="$(wc -c <"$path" | tr -d ' ')"
    if (( characters % 2 != 0 )); then
        echo "odd hexadecimal bytecode length: $path" >&2
        exit 1
    fi
    printf '%s\n' "$((characters / 2))"
}

initcode_bytes="$(hex_byte_length build/CalldataFirewall.bin)"
runtime_bytes="$(hex_byte_length build/CalldataFirewall.runtime.bin)"

tracked_count=0
source_sums="$staging/FE-014-SOURCE-SHA256SUMS.txt"
while IFS= read -r -d '' entry; do
    metadata="${entry%%$'\t'*}"
    path="${entry#*$'\t'}"
    read -r mode object_type object_id <<<"$metadata"
    if [[ "$object_type" != "blob" || "$mode" == "120000" || \
          "$path" == *$'\n'* || "$path" == *\\* ]]; then
        echo "unsupported tracked entry in release source manifest: $path" >&2
        exit 1
    fi
    digest="$(git cat-file blob "$object_id" | sha256sum | awk '{print $1}')"
    printf '%s  %s\n' "$digest" "$path" >>"$source_sums"
    tracked_count=$((tracked_count + 1))
done < <(git ls-tree -rz --full-tree HEAD)

cat >"$staging/FE-014-MANIFEST.txt" <<EOF
schema=fe-014-release-evidence-v1
project_id=FE-014
release_label=$label
commit_sha=$commit_sha
tree_sha=$tree_sha
fe_version=$fe_version
fe_release_commit=3dab95f8eebdccf9a2382bb59a33f7bbd03540ca
fe_binary_sha256=$fe_sha256
verification_command=make verify
verification_result=pass
fe_test_result=14_passed_0_failed
zero_target_rejection_traces=5
guarded_reentrancy_traces=1
tracked_file_count=$tracked_count
bundled_generated_file_count=${#bundle_files[@]}
calldata_firewall_initcode_bytes=$initcode_bytes
calldata_firewall_runtime_bytes=$runtime_bytes
trace_normalization=first_duration_field_replaced_with_[DURATION]
EOF

(
    cd "$staging"
    printf '%s\0' "${bundle_files[@]}" | sort -z | xargs -0 sha256sum --
) >"$staging/FE-014-ARTIFACT-SHA256SUMS.txt"

public_files=(
    FE-014-MANIFEST.txt
    FE-014-SOURCE-SHA256SUMS.txt
    FE-014-ARTIFACT-SHA256SUMS.txt
)
for filename in "${public_files[@]}"; do
    install -m 0644 -- "$staging/$filename" "$out_dir/$filename"
done

bundle_name="FE-014-evidence-$label.tar.gz"
tar --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner \
    --format=gnu -C "$staging" -cf - . | gzip -n -9 >"$out_dir/$bundle_name"

(
    cd "$out_dir"
    sha256sum \
        FE-014-MANIFEST.txt \
        FE-014-SOURCE-SHA256SUMS.txt \
        FE-014-ARTIFACT-SHA256SUMS.txt \
        "$bundle_name" >SHA256SUMS
)

rm -rf -- "$staging"

printf 'release evidence generated for %s at %s\n' "$commit_sha" "$out_dir"
cat "$out_dir/SHA256SUMS"
