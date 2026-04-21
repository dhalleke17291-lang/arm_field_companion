#!/usr/bin/env bash
#
# Builds a release artifact with build identity baked in (git SHA, date,
# channel) so the About screen and "Share device info" report can display
# what's actually running on the device.
#
# Usage:
#   tool/build_release.sh ios                    # build iOS release
#   tool/build_release.sh apk                    # build Android APK release
#   tool/build_release.sh appbundle              # build Android App Bundle
#   CHANNEL=beta tool/build_release.sh ios       # override channel label
#
# Falls back to "release" channel if CHANNEL is not set.
set -euo pipefail

cd "$(dirname "$0")/.."

TARGET="${1:-apk}"
CHANNEL="${CHANNEL:-release}"
GIT_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
BUILD_DATE="$(date +%Y-%m-%d)"

DEFINES=(
  --dart-define=GIT_SHA="$GIT_SHA"
  --dart-define=BUILD_DATE="$BUILD_DATE"
  --dart-define=BUILD_CHANNEL="$CHANNEL"
)

echo "==> Building $TARGET (sha=$GIT_SHA date=$BUILD_DATE channel=$CHANNEL)"

case "$TARGET" in
  ios)
    flutter build ios --release "${DEFINES[@]}" "$@"
    ;;
  apk)
    flutter build apk --release "${DEFINES[@]}"
    ;;
  appbundle)
    flutter build appbundle --release "${DEFINES[@]}"
    ;;
  *)
    echo "Unknown target: $TARGET (expected: ios | apk | appbundle)" >&2
    exit 2
    ;;
esac
