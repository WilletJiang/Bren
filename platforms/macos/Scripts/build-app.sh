#!/bin/zsh

set -euo pipefail

platform_dir="$(cd "$(dirname "$0")/.." && pwd)"
repo_root="$(cd "$platform_dir/../.." && pwd)"
core_dir="$repo_root/core"
app_dir="$repo_root/dist/Bren.app"
contents_dir="$app_dir/Contents"
sparkle_framework="$platform_dir/.build/vendor/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"

"$platform_dir/Scripts/fetch-sparkle.sh"
mkdir -p "$contents_dir/MacOS" "$contents_dir/Helpers" "$contents_dir/Frameworks" "$contents_dir/Resources"

(
    cd "$core_dir"
    go build -trimpath -ldflags="-s -w" -o "$platform_dir/.build/bren-core" ./cmd/bren-core
)
swift build --package-path "$platform_dir" -c release

install -m 755 "$platform_dir/.build/release/Bren" "$contents_dir/MacOS/Bren"
install -m 755 "$platform_dir/.build/bren-core" "$contents_dir/Helpers/bren-core"
install -m 644 "$platform_dir/Resources/Info.plist" "$contents_dir/Info.plist"
for bundle in "$contents_dir/Resources"/*.bundle(N); do
    rm -rf "$bundle"
done
for bundle in "$platform_dir/.build/release"/*.bundle(N); do
    ditto "$bundle" "$contents_dir/Resources/${bundle:t}"
done
rm -rf "$contents_dir/Frameworks/Sparkle.framework"
ditto "$sparkle_framework" "$contents_dir/Frameworks/Sparkle.framework"

if [[ -n "${BREN_VERSION:-}" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $BREN_VERSION" "$contents_dir/Info.plist"
fi
if [[ -n "${BREN_BUILD:-}" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BREN_BUILD" "$contents_dir/Info.plist"
fi

codesign --force --deep --sign - "$app_dir"
echo "$app_dir"
