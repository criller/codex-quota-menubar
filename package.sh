#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
bash build.sh
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)
name="Codex-Quota-v${version}-macos-arm64.zip"
payload=$(mktemp -d "$PWD/.build/release-payload.XXXXXX")
trap 'rm -rf "$payload"' EXIT
ditto --norsrc --noextattr "dist/Codex Quota.app" "$payload/Codex Quota.app"
mkdir -p "$payload/Codex Quota.app/Contents/Resources"
cp LICENSE "$payload/Codex Quota.app/Contents/Resources/LICENSE"
cp README.md "$payload/Codex Quota.app/Contents/Resources/README.md"
# The bundle now includes its license and documentation; sign the final payload.
codesign --force --sign - "$payload/Codex Quota.app"
codesign --verify --strict "$payload/Codex Quota.app"
ditto -c -k --norsrc --noextattr --keepParent "$payload/Codex Quota.app" "dist/$name"
(
    cd dist
    shasum -a 256 "$name" > SHA256SUMS.txt
)
printf 'Release package: %s/dist/%s\n' "$PWD" "$name"
