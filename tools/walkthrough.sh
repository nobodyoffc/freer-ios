#!/bin/sh
# Run the UI walkthrough on a simulator and collect its screenshots.
#
#   tools/walkthrough.sh <simulator-udid> <shots-dir> [derived-data-dir] [only-testing]
set -u
cd "$(dirname "$0")/.."
DEV="$1"; SHOTS="$2"; DD="${3:-${TMPDIR:-/tmp}/freer-ios-build}"
ONLY="${4:-FreerUITests/WalkthroughTests}"
mkdir -p "$SHOTS" "$DD"
TEST_RUNNER_SHOTS_DIR="$SHOTS" xcodebuild -project Freer.xcodeproj -scheme Freer \
    -destination "platform=iOS Simulator,id=$DEV" \
    -derivedDataPath "$DD" -only-testing:"$ONLY" test > "$DD/test.log" 2>&1
grep -E '^/.*: error|error: -\[|XCTAssert|Test Case .*(passed|failed)|\*\* TEST' "$DD/test.log" | sed "s|^$(pwd)/||" | sort -u
ls "$SHOTS"
