#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
scratch=$(mktemp -d "${TMPDIR:-/tmp}/taskpad-tests.XXXXXX")
trap 'python3 -c "import shutil,sys; shutil.rmtree(sys.argv[1])" "$scratch"' EXIT
export CLANG_MODULE_CACHE_PATH="$scratch/clang-modules"
export SWIFTPM_MODULECACHE_OVERRIDE="$scratch/swift-modules"
swift test --scratch-path "$scratch" -Xswiftc -module-cache-path -Xswiftc "$scratch/swift-modules" "$@"
