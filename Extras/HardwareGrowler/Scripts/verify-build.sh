#!/bin/zsh
set -euo pipefail

# Local build gate for HardwareGrowler. It intentionally uses ad-hoc signing so
# contributors can verify the app without an Apple Developer account.
ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
PROJECT="$ROOT_DIR/Extras/HardwareGrowler/HardwareGrowler.xcodeproj"
DERIVED_TESTS="$ROOT_DIR/.xcode-derived-data-tests"
DERIVED_UNIVERSAL="$ROOT_DIR/.xcode-derived-data-universal"
PRODUCTS_DIR="$DERIVED_UNIVERSAL/Build/Products/Release"
APP="$PRODUCTS_DIR/HardwareGrowler.app"
BUILD_LOG="$DERIVED_UNIVERSAL/hardwaregrowler-release-build.log"

log() {
	printf '\n==> %s\n' "$1"
}

fail() {
	printf 'error: %s\n' "$1" >&2
	exit 1
}

require_archs() {
	local binary="$1"
	local label="$2"
	[[ -f "$binary" ]] || fail "$label binary not found at $binary"
	local archs
	archs="$(lipo -archs "$binary")"
	printf '%s: %s\n' "$label" "$archs"
	[[ " $archs " == *" arm64 "* ]] || fail "$label is missing arm64"
	[[ " $archs " == *" x86_64 "* ]] || fail "$label is missing x86_64"
}

log "Running HardwareGrowler tests"
xcodebuild \
	-project "$PROJECT" \
	-scheme HardwareGrowlerTests \
	-configuration Debug \
	-destination platform=macOS \
	-derivedDataPath "$DERIVED_TESTS" \
	CODE_SIGN_IDENTITY=- \
	CODE_SIGNING_ALLOWED=YES \
	test

log "Building Release Universal 2 app"
xcodebuild \
	-project "$PROJECT" \
	-scheme HardwareGrowler \
	-configuration Release \
	-destination generic/platform=macOS \
	-derivedDataPath "$DERIVED_UNIVERSAL" \
	ARCHS="arm64 x86_64" \
	ONLY_ACTIVE_ARCH=NO \
	CODE_SIGN_IDENTITY=- \
	CODE_SIGNING_ALLOWED=YES \
	build 2>&1 | tee "$BUILD_LOG"

log "Scanning build log for compiler and deprecation warnings"
if grep -Ei "warning:|will be removed|is deprecated" "$BUILD_LOG"; then
	fail "Build log contains compiler/deprecation warnings"
fi

log "Checking app, helper, and plug-in architectures"
require_archs "$APP/Contents/MacOS/HardwareGrowler" "HardwareGrowler"
require_archs "$APP/Contents/Library/LoginItems/HardwareGrowlerLauncher.app/Contents/MacOS/HardwareGrowlerLauncher" "HardwareGrowlerLauncher"

plugin_count=0
for binary in "$APP"/Contents/PlugIns/*.hwgrowlmonitor/Contents/MacOS/*; do
	[[ -f "$binary" ]] || continue
	plugin_count=$((plugin_count + 1))
	require_archs "$binary" "$(basename "$binary")"
done
[[ "$plugin_count" -gt 0 ]] || fail "No shipped HardwareGrowler plug-ins found"

log "Checking built app for removed Growl artifacts"
# HardwareGrowler now uses native UserNotifications; the built app should not
# accidentally re-embed old Growl frameworks, XPC services, or view bundles.
if find "$APP" \( \
	-name Growl.framework -o \
	-name GrowlPlugins.framework -o \
	-name GrowlLauncher.app -o \
	-name 'com.company.application.GNTPClientService.xpc' -o \
	-name '*.growlView' \
	\) -print | grep -q .; then
	fail "Built app contains removed Growl artifacts"
fi

log "Checking project file for stale Growl project/proxy references"
# The Xcode project used to reference the parent Growl project. Keep this check
# so future project edits do not reintroduce stale proxy products.
if grep -E "Growl\\.xcodeproj|GrowlPlugins\\.framework|Growl\\.app|GrowlLauncher|GNTPClientService|PBXReferenceProxy|projectReferences" "$PROJECT/project.pbxproj"; then
	fail "Project contains stale Growl project/proxy references"
fi

log "Verifying ad-hoc/local code signature"
codesign --verify --deep --strict --verbose=2 "$APP"

log "HardwareGrowler build verification passed"
