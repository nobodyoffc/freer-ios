#!/bin/sh
# Rebuild the Mac-derived part of the Chinese string table.
#
#   tools/sync-localization.sh [path-to-freer-mac]
#
# Keeps everything above the "from the Mac app's table" line in
# Freer/Localization/zh-Hans.lproj/Localizable.strings — the iOS-only
# entries — and replaces what follows with the Mac's current table, "this
# Mac" reworded as "this device" in keys and values.
set -eu
cd "$(dirname "$0")/.."
MAC="${1:-../../MacApp/FreerForMac}"
SRC="$MAC/Sources/FreerForMac/Localization/zh-Hans.lproj/Localizable.strings"
OUT="Freer/Localization/zh-Hans.lproj/Localizable.strings"
MARK='/* ---- from the Mac app'"'"'s table ---- */'
TMP="$(mktemp)"
awk -v mark="$MARK" '{print} $0 == mark {print ""; exit}' "$OUT" > "$TMP"
sed -e 's/this Mac/this device/g' -e 's/your Mac/your device/g' \
    -e 's/这台 Mac \([^ -~]\)/这台设备\1/g' -e 's/这台 Mac/这台设备/g' -e 's/本 Mac/本设备/g' -e 's/你的 Mac/你的设备/g' "$SRC" >> "$TMP"
mv "$TMP" "$OUT"
plutil -lint "$OUT"
