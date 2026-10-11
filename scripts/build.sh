#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
scratch=$(mktemp -d "${TMPDIR:-/tmp}/TaskPad-build.XXXXXX")
trap 'python3 -c "import shutil,sys; shutil.rmtree(sys.argv[1])" "$scratch"' EXIT
export CLANG_MODULE_CACHE_PATH="$scratch/clang-modules"
export SWIFTPM_MODULECACHE_OVERRIDE="$scratch/swift-modules"
swift build -c release --scratch-path "$scratch" -Xswiftc -module-cache-path -Xswiftc "$scratch/swift-modules"
app="$PWD/build/TaskPad.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$scratch/release/TaskPad" "$app/Contents/MacOS/TaskPad"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/TaskPad.icns "$app/Contents/Resources/TaskPad.icns"
codesign --force --sign - "$app"
# Refresh the bundle directory so Finder sees updated resources on rebuild.
touch "$app"
printf '%s\n' "$app"
