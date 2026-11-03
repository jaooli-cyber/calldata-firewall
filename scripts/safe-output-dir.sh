#!/usr/bin/env bash
set -euo pipefail

reset=0
if [[ "${1:-}" == "--reset" ]]; then
    reset=1
    shift
fi
relative="${1:?usage: scripts/safe-output-dir.sh [--reset] build[/SUBDIR]}"
relative="${relative#./}"

case "$relative" in
    build|build/*) ;;
    *)
        echo "output path must be build or a child of build: $relative" >&2
        exit 1
        ;;
esac
case "/$relative/" in
    *"/../"*|*"/./"*)
        echo "output path contains a traversal component: $relative" >&2
        exit 1
        ;;
esac

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
current="$repo_root"
IFS='/' read -r -a components <<<"$relative"
for component in "${components[@]}"; do
    current="$current/$component"
    if [[ -L "$current" ]]; then
        echo "output path contains a symlink: $current" >&2
        exit 1
    fi
    if [[ -e "$current" && ! -d "$current" ]]; then
        echo "output path component is not a directory: $current" >&2
        exit 1
    fi
done

target="$repo_root/$relative"
resolved="$(realpath -m -- "$target")"
case "$resolved" in
    "$repo_root/build"|"$repo_root/build"/*) ;;
    *)
        echo "resolved output escaped repository build directory: $resolved" >&2
        exit 1
        ;;
esac

if [[ "$reset" == "1" ]]; then
    if [[ "$relative" == "build" ]]; then
        echo "refusing to reset the complete build directory" >&2
        exit 1
    fi
    rm -rf -- "$resolved"
fi
mkdir -p -- "$resolved"
printf '%s\n' "$resolved"
