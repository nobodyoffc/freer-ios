#!/bin/sh
# Build Freer for the iOS simulator and print only what went wrong.
#
#   tools/build.sh [derived-data-dir]
#
# Prints each distinct compiler error once, then the verdict. The full log
# is left beside the derived data as build.log.
set -u
cd "$(dirname "$0")/.."
DD="${1:-${TMPDIR:-/tmp}/freer-ios-build}"
mkdir -p "$DD"
xcodebuild -project Freer.xcodeproj -scheme Freer \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$DD" build > "$DD/build.log" 2>&1
grep -E '^/.*: error' "$DD/build.log" | sed "s|^$(pwd)/||" | sort -u
grep -E 'BUILD (SUCCEEDED|FAILED)|xcodebuild: error' "$DD/build.log"
