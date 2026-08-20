#!/bin/zsh

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
version="${1:?usage: release-macos.sh VERSION BUILD}"
build="${2:?usage: release-macos.sh VERSION BUILD}"
tag="v$version"
updates_dir="$repo_root/dist/updates"
archive_name="Bren-$version.zip"
archive="$updates_dir/$archive_name"
notes="$repo_root/docs/releases/$version.md"
sparkle_bin="$repo_root/platforms/macos/.build/vendor/bin"

if [[ ! "$version" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
    echo "version must use MAJOR.MINOR.PATCH" >&2
    exit 1
fi
if [[ ! "$build" =~ '^[1-9][0-9]*$' ]]; then
    echo "build must be a positive integer" >&2
    exit 1
fi
if [[ ! -f "$notes" ]]; then
    echo "missing release notes: $notes" >&2
    exit 1
fi

rm -rf "$updates_dir"
mkdir -p "$updates_dir"
BREN_VERSION="$version" BREN_BUILD="$build" "$repo_root/platforms/macos/Scripts/build-app.sh"
ditto -c -k --sequesterRsrc --keepParent "$repo_root/dist/Bren.app" "$archive"
cp "$notes" "$updates_dir/Bren-$version.md"

generate_options=(
    --download-url-prefix "https://github.com/WilletJiang/Bren/releases/download/$tag/"
    --link "https://github.com/WilletJiang/Bren"
    --embed-release-notes
    --maximum-versions 1
    --maximum-deltas 0
    "$updates_dir"
)

if [[ -n "${SPARKLE_PRIVATE_KEY_FILE:-}" ]]; then
    "$sparkle_bin/generate_appcast" \
        --ed-key-file "$SPARKLE_PRIVATE_KEY_FILE" \
        "${generate_options[@]}"
elif [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
    print -r -- "$SPARKLE_PRIVATE_KEY" \
        | "$sparkle_bin/generate_appcast" --ed-key-file - "${generate_options[@]}"
else
    "$sparkle_bin/generate_appcast" "${generate_options[@]}"
fi

rm "$updates_dir/Bren-$version.md"
codesign --verify --deep --strict "$repo_root/dist/Bren.app"
echo "$archive"
echo "$updates_dir/appcast.xml"
