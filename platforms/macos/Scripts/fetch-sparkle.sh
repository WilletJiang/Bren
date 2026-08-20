#!/bin/zsh

set -euo pipefail

platform_dir="$(cd "$(dirname "$0")/.." && pwd)"
version="2.9.6"
checksum="8d5fb41d960b43f4a68aa14126bf62b098544ec8d191cdcc73eb14e63a8e7606"
url="https://github.com/sparkle-project/Sparkle/releases/download/$version/Sparkle-for-Swift-Package-Manager.zip"
cache_dir="$platform_dir/.build/cache"
vendor_dir="$platform_dir/.build/vendor"
archive="$cache_dir/Sparkle-$version.zip"
framework="$vendor_dir/Sparkle.xcframework"

if [[ -d "$framework" && -x "$vendor_dir/bin/generate_keys" ]]; then
    exit 0
fi

mkdir -p "$cache_dir" "$vendor_dir"
if [[ ! -f "$archive" ]]; then
    curl --fail --location --retry 3 --output "$archive.part" "$url"
    mv "$archive.part" "$archive"
fi

actual_checksum="$(shasum -a 256 "$archive" | awk '{print $1}')"
if [[ "$actual_checksum" != "$checksum" ]]; then
    echo "Sparkle checksum mismatch: got $actual_checksum" >&2
    exit 1
fi

extract_dir="$(mktemp -d "${TMPDIR:-/tmp}/bren-sparkle.XXXXXX")"
trap 'rm -rf "$extract_dir"' EXIT
ditto -x -k "$archive" "$extract_dir"
ditto "$extract_dir/Sparkle.xcframework" "$framework"
ditto "$extract_dir/bin" "$vendor_dir/bin"
