#!/bin/zsh
set -euo pipefail

# Creates unsigned/ad-hoc artifacts from the verified Release build. These can
# be shared, but Gatekeeper-friendly public releases need Developer ID notarization.
ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
PRODUCTS_DIR="$ROOT_DIR/.xcode-derived-data-universal/Build/Products/Release"
APP="$PRODUCTS_DIR/HardwareGrowler.app"
DIST_DIR="$ROOT_DIR/build/dist"
DMG_ROOT="$ROOT_DIR/build/dmg-root"
ARTIFACT_NAME="HardwareGrowler-Universal2"
FORMAT="${1:-zip}"

log() {
	printf '\n==> %s\n' "$1"
}

fail() {
	printf 'error: %s\n' "$1" >&2
	exit 1
}

usage() {
	cat <<EOF
Usage: $0 [zip|dmg|all]

Creates local HardwareGrowler release artifacts from:
  $APP

Run Extras/HardwareGrowler/Scripts/verify-build.sh first.
EOF
}

[[ -d "$APP" ]] || fail "Built app not found. Run Extras/HardwareGrowler/Scripts/verify-build.sh first."

case "$FORMAT" in
	zip|dmg|all) ;;
	-h|--help)
		usage
		exit 0
		;;
	*)
		usage
		fail "Unknown package format: $FORMAT"
		;;
esac

mkdir -p "$DIST_DIR"

if [[ "$FORMAT" == "zip" || "$FORMAT" == "all" ]]; then
	log "Creating ZIP"
	ditto -c -k --keepParent "$APP" "$DIST_DIR/$ARTIFACT_NAME.zip"
	printf '%s\n' "$DIST_DIR/$ARTIFACT_NAME.zip"
fi

if [[ "$FORMAT" == "dmg" || "$FORMAT" == "all" ]]; then
	log "Creating DMG"
	rm -rf "$DMG_ROOT"
	mkdir -p "$DMG_ROOT"
	ditto "$APP" "$DMG_ROOT/HardwareGrowler.app"
	hdiutil create \
		-volname HardwareGrowler \
		-srcfolder "$DMG_ROOT" \
		-ov \
		-format UDZO \
		"$DIST_DIR/$ARTIFACT_NAME.dmg"
	printf '%s\n' "$DIST_DIR/$ARTIFACT_NAME.dmg"
fi

log "Local package creation complete"
