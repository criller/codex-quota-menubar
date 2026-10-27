#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p .build/module-cache
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
swiftc -swift-version 5 -module-cache-path "$CLANG_MODULE_CACHE_PATH" Sources/Quota.swift Tests/QuotaTests.swift -o .build/quota-tests
.build/quota-tests
app="$PWD/dist/Codex Quota.app"
mkdir -p "$app/Contents/MacOS"
swiftc -swift-version 5 -O -module-cache-path "$CLANG_MODULE_CACHE_PATH" -target arm64-apple-macosx14.0 Sources/Quota.swift Sources/App.swift -framework AppKit -framework ServiceManagement -o "$app/Contents/MacOS/CodexQuota"
cp Info.plist "$app/Contents/Info.plist"
codesign --force --sign - "$app"
codesign --verify --strict "$app"
printf 'Built: %s\n' "$app"
