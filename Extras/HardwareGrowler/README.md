# HardwareGrowler

HardwareGrowler is a macOS menu-bar utility that watches hardware and system events and posts native macOS notifications.

This fork modernizes the original Growl-era application so it can be built on current macOS versions, including Apple Silicon. The app bundle contains:

- `HardwareGrowler.app`
- the built-in monitor plug-ins in `Contents/PlugIns`
- the login helper in `Contents/Library/LoginItems/HardwareGrowlerLauncher.app`

The main app, helper, and every plug-in must be built for compatible architectures. An arm64 app can only load arm64 plug-ins. A Universal 2 app should ship Universal 2 plug-ins.

The app currently ships the actively supported monitors: USB, Bluetooth, Volume, Network, Power, Keyboard, Thunderbolt, TimeMachine, and FireWire. The legacy Phone monitor remains in the source tree, but is not embedded in the app by default. FireWire is hidden at runtime on Macs that do not expose FireWire IORegistry services.

Network Monitor is enabled by default because network changes are one of HardwareGrowler's core use cases. It can monitor generic IP address, VPN, and network interface changes without Location permission. Location permission is only requested when a Wi-Fi/AirPort notification path needs the current SSID/BSSID.

## Requirements

Required:

- macOS 13 Ventura or later
- Xcode from the Mac App Store
- Xcode command-line tools
- Git

Provided by macOS/Xcode and used by the build or packaging steps:

- `xcodebuild`
- `codesign`
- `lipo`
- `ditto`
- `hdiutil`
- `security`
- `/usr/bin/ruby`

No paid Apple Developer Program membership is required to build and run the app on your own Mac. A paid membership is only needed for Developer ID signing and notarization if you want to distribute the app to other people in the normal Gatekeeper-friendly way.

## Install Build Tools

Install Xcode from the Mac App Store, then select it as the active developer directory:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Accept the Xcode license:

```sh
sudo xcodebuild -license accept
```

Install the command-line tools if they are not already installed:

```sh
xcode-select --install
```

Verify the tools:

```sh
xcodebuild -version
git --version
codesign --version
ruby --version
```

## Build

From the repository root:

```sh
cd /path/to/growl
```

List the available HardwareGrowler targets and schemes:

```sh
xcodebuild -list -project Extras/HardwareGrowler/HardwareGrowler.xcodeproj
```

### Personal Apple Silicon Build

This builds for the current Mac architecture. On Apple Silicon, that is normally `arm64`.

```sh
xcodebuild \
  -project Extras/HardwareGrowler/HardwareGrowler.xcodeproj \
  -scheme HardwareGrowler \
  -configuration Release \
  -derivedDataPath .xcode-derived-data \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_ALLOWED=YES \
  build
```

The built app will be at:

```text
.xcode-derived-data/Build/Products/Release/HardwareGrowler.app
```

### Universal 2 Build

This builds the main app, login helper, and plug-ins for both `arm64` and `x86_64`:

```sh
xcodebuild \
  -project Extras/HardwareGrowler/HardwareGrowler.xcodeproj \
  -scheme HardwareGrowler \
  -configuration Release \
  -destination generic/platform=macOS \
  -derivedDataPath .xcode-derived-data-universal \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_ALLOWED=YES \
  build
```

The built app will be at:

```text
.xcode-derived-data-universal/Build/Products/Release/HardwareGrowler.app
```

## Verify Architectures

Verify the main app:

```sh
lipo -archs .xcode-derived-data-universal/Build/Products/Release/HardwareGrowler.app/Contents/MacOS/HardwareGrowler
```

Expected for a Universal 2 build:

```text
x86_64 arm64
```

Verify the login helper:

```sh
lipo -archs .xcode-derived-data-universal/Build/Products/Release/HardwareGrowler.app/Contents/Library/LoginItems/HardwareGrowlerLauncher.app/Contents/MacOS/HardwareGrowlerLauncher
```

Verify every built-in monitor plug-in:

```sh
for bin in .xcode-derived-data-universal/Build/Products/Release/HardwareGrowler.app/Contents/PlugIns/*.hwgrowlmonitor/Contents/MacOS/*; do
  printf '%s: ' "$bin"
  lipo -archs "$bin"
done
```

Every line should include the same architecture family as the app. For Universal 2, every line should include:

```text
x86_64 arm64
```

## Run Full Verification

For the complete local build check, run:

```sh
Extras/HardwareGrowler/Scripts/verify-build.sh
```

This runs the test scheme, builds the Release Universal 2 app, scans for compiler/deprecation warnings, verifies app/helper/plug-in architectures, checks that Growl artifacts have not returned, and verifies the built app signature.

The GitHub Actions workflow at `.github/workflows/hardwaregrowler.yml` runs the same verifier on macOS for pull requests and pushes that touch HardwareGrowler-related files.

## Signing Options

### Option 1: Sign to Run Locally

The build commands above use:

```sh
CODE_SIGN_IDENTITY=-
```

That asks Xcode to use its local ad-hoc signing path. This is enough for local development and quick personal testing. It does not require a paid Apple Developer account.

For daily use, this can work, but macOS privacy and identity systems may behave better with a stable certificate. Notifications, Accessibility, Location, Bluetooth, login items, and Launch Services all care about app identity.

### Option 2: Self-Signed Local Certificate

For a more stable personal build, create a local code-signing certificate:

1. Open Keychain Access.
2. Choose Keychain Access > Certificate Assistant > Create a Certificate.
3. Name it something like `HardwareGrowler Local Code Signing`.
4. Set Identity Type to `Self Signed Root`.
5. Set Certificate Type to `Code Signing`.
6. Enable `Let me override defaults`.
7. Continue through the assistant.
8. In Keychain Access, find the certificate, open it, expand Trust, and set Code Signing to `Always Trust`.

Verify the identity:

```sh
security find-identity -v -p codesigning
```

Then build with that identity:

```sh
xcodebuild \
  -project Extras/HardwareGrowler/HardwareGrowler.xcodeproj \
  -scheme HardwareGrowler \
  -configuration Release \
  -destination generic/platform=macOS \
  -derivedDataPath .xcode-derived-data-universal \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY="HardwareGrowler Local Code Signing" \
  CODE_SIGNING_ALLOWED=YES \
  build
```

This still does not make the app trusted for public distribution. It is for your own Mac.

### Option 3: Developer ID for Public Distribution

To distribute outside the Mac App Store in the usual Gatekeeper-friendly way, use Developer ID signing and notarization. Apple Developer ID certificates require Apple Developer Program membership.

At a high level:

1. Join the Apple Developer Program.
2. Create a Developer ID Application certificate.
3. Build an archive or Release app with hardened runtime enabled.
4. Sign the app, nested helper, and plug-ins with the Developer ID identity.
5. Package the app as a ZIP, DMG, or PKG.
6. Submit the package for notarization with `xcrun notarytool`.
7. Staple the notarization ticket with `xcrun stapler`.
8. Verify with `spctl`.

Useful Apple documentation:

- [Developer ID](https://developer.apple.com/support/developer-id/)
- [Signing Mac software with Developer ID](https://developer.apple.com/developer-id/)
- [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)

## Install on Your Mac

Quit any running copy first:

```sh
osascript -e 'tell application "HardwareGrowler" to quit'
```

Copy the built app to `/Applications`:

```sh
ditto .xcode-derived-data-universal/Build/Products/Release/HardwareGrowler.app /Applications/HardwareGrowler.app
```

Refresh Launch Services:

```sh
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister \
  -f -R -trusted /Applications/HardwareGrowler.app
```

Launch it:

```sh
open /Applications/HardwareGrowler.app
```

If you have old copies in other locations, remove or rename them before testing. macOS may otherwise reopen an older bundle when a notification, login item, or Launch Services record points to it.

## First Launch Permissions

On first launch, macOS may ask for permissions depending on which modules are enabled. HardwareGrowler does not need every permission for every feature; macOS prompts are tied to the monitor that uses the protected API.

| Permission | Used By | Why It Is Needed | If You Deny It |
| --- | --- | --- | --- |
| Notifications | Main app | Required to show native macOS notifications through `UNUserNotificationCenter`. | Monitors can still detect events, but you will not see notification banners/alerts. |
| Location | Network Monitor | Modern macOS treats Wi-Fi network names and BSSIDs as location-sensitive. HardwareGrowler requests Location only so CoreWLAN can read the current Wi-Fi SSID/BSSID for Wi-Fi connect notifications. It does not use GPS tracking. | Generic network notifications may still work, but Wi-Fi notifications may show `Unknown` or omit the SSID/BSSID. |
| Bluetooth | Bluetooth Monitor | Required by macOS when using Bluetooth APIs to observe Bluetooth power and device connection changes. | Bluetooth notifications may not work. Other monitors are unaffected. |
| Accessibility | Keyboard Monitor | Needed only if the Keyboard Monitor is enabled and macOS requires accessibility access for observing keyboard state such as Caps Lock, Shift, or Fn. | Keyboard state notifications may not work. Other monitors are unaffected. |

The expected prompt timing is:

- Notification permission can appear when HardwareGrowler starts posting native notifications.
- Location permission should appear only when the enabled Network Monitor handles a Wi-Fi/AirPort event that needs SSID/BSSID access.
- Bluetooth permission should appear only when the Bluetooth Monitor is enabled or starts observing Bluetooth state.
- Accessibility permission should appear only after the Keyboard Monitor is enabled and starts observing keyboard state.

FireWire availability is checked with a read-only IOKit/IORegistry query and should not require a special privacy permission.

USB, Volume, Thunderbolt, Power, Time Machine, and FireWire monitoring should not need Location, Bluetooth, or Accessibility permission. Some of those monitors use system frameworks or IOKit, but they are not expected to trigger macOS privacy prompts beyond notification delivery.

Permissions are tied to the app's bundle identifier and code signature. If you rebuild with a different signature or run the app from a different path, macOS may treat it as a different app. For the least surprising behavior, install it consistently at:

```text
/Applications/HardwareGrowler.app
```

For clean permission testing during development, reset the relevant privacy decisions before launching the rebuilt app:

```sh
tccutil reset Location com.growl.hardwaregrowler
tccutil reset BluetoothAlways com.growl.hardwaregrowler
tccutil reset Accessibility com.growl.hardwaregrowler
```

Notification authorization is managed in System Settings > Notifications. If a `tccutil` service name is rejected on your macOS version, reset that category manually in System Settings > Privacy & Security.

## Package

Run the verifier first so the Release app exists and has already passed tests, architecture checks, warning checks, Growl artifact checks, and signature verification:

```sh
Extras/HardwareGrowler/Scripts/verify-build.sh
```

### ZIP

Create a ZIP suitable for local transfer:

```sh
Extras/HardwareGrowler/Scripts/package-local-release.sh zip
```

### DMG

Create a simple compressed DMG:

```sh
Extras/HardwareGrowler/Scripts/package-local-release.sh dmg
```

Create both local artifacts:

```sh
Extras/HardwareGrowler/Scripts/package-local-release.sh all
```

### Release Artifacts

GitHub releases publish both package formats:

- `HardwareGrowler-Universal2.zip` contains `HardwareGrowler.app` in a plain ZIP archive. This is usually the easiest artifact to download and unpack.
- `HardwareGrowler-Universal2.dmg` contains `HardwareGrowler.app` in a compressed disk image. Use this if you prefer a mountable macOS disk image.
- `HardwareGrowler-Universal2.sha256` contains SHA-256 checksums for the ZIP and DMG artifacts.

After downloading the checksum file and both artifacts, verify them locally:

```sh
shasum -a 256 -c HardwareGrowler-Universal2.sha256
```

The release workflow also generates GitHub artifact attestations for the ZIP and DMG artifacts. Users can verify the published artifacts with GitHub CLI:

```sh
gh attestation verify HardwareGrowler-Universal2.zip -R tdferreira/growl
gh attestation verify HardwareGrowler-Universal2.dmg -R tdferreira/growl
```

The release artifacts are ad-hoc signed by CI and are not Apple-notarized. They are suitable for open source distribution and local re-signing, but they will not have the same first-launch experience as a Developer ID signed and notarized app.

### Automated GitHub Releases

Push an annotated tag named `hardwaregrowler-v<version>` to build and publish a GitHub release. The release workflow uses this tag version for the built app, login helper, and bundled monitor plug-ins.

```sh
git tag -a hardwaregrowler-v3.0 -m "HardwareGrowler 3.0"
git push origin hardwaregrowler-v3.0
```

The release workflow:

1. Runs the HardwareGrowler verifier.
2. Packages ZIP and DMG artifacts.
3. Creates release notes from the commit messages since the previous `hardwaregrowler-v*` tag.
4. Adds a link to the full commit comparison.
5. Publishes the ZIP and DMG to the GitHub release.

You can also run the `HardwareGrowler Release` workflow manually for an existing `hardwaregrowler-v*` tag.

For normal Gatekeeper-friendly public distribution, notarize the ZIP, DMG, or PKG before sharing it.

## Using Downloaded Release Artifacts

Because the GitHub release artifacts are not notarized by Apple, macOS may warn when you open the downloaded app. You can re-sign the app for your own Mac with a trusted local code-signing certificate.

First create and trust a local code-signing certificate as described in [Option 2: Self-Signed Local Certificate](#option-2-self-signed-local-certificate). Then copy the downloaded app to a stable location:

```sh
ditto HardwareGrowler.app /Applications/HardwareGrowler.app
```

Re-sign the app with your local identity:

```sh
codesign \
  --force \
  --deep \
  --sign "HardwareGrowler Local Code Signing" \
  --timestamp=none \
  --preserve-metadata=entitlements \
  /Applications/HardwareGrowler.app
```

Verify the local signature:

```sh
codesign --verify --deep --strict --verbose=2 /Applications/HardwareGrowler.app
```

Check the local Gatekeeper assessment:

```sh
spctl --assess --type execute --verbose /Applications/HardwareGrowler.app
```

If the downloaded app still carries quarantine metadata from the browser, macOS may continue to treat it as an internet download. After you have inspected the artifact and decided to trust your local build, remove the quarantine attribute:

```sh
xattr -dr com.apple.quarantine /Applications/HardwareGrowler.app
```

This local self-signing process does not make the app trusted for other people. Each user would need to trust their own local certificate and re-sign locally. Developer ID signing and notarization are still required for the normal public macOS download experience.

## Verify Signing

Inspect the signature:

```sh
codesign -dv /Applications/HardwareGrowler.app
```

Verify nested code:

```sh
codesign --verify --deep --strict --verbose=2 /Applications/HardwareGrowler.app
```

Check Gatekeeper assessment:

```sh
spctl --assess --type execute --verbose /Applications/HardwareGrowler.app
```

For local or self-signed builds, `spctl` may reject the app for distribution even though it can run on your Mac. That is expected. Developer ID signing and notarization are what make `spctl` happy for normal outside-the-App-Store distribution.

## Troubleshooting

### xcodebuild tries to write outside the repository

Use `-derivedDataPath` as shown above. This keeps DerivedData under the repository:

```sh
-derivedDataPath .xcode-derived-data-universal
```

### Two HardwareGrowler instances are running

Find running copies:

```sh
pgrep -af HardwareGrowler
```

Quit the app normally if possible. If an old copy is stuck, terminate it:

```sh
kill <pid>
```

Then make sure only one copy exists in `/Applications` and refresh Launch Services with `lsregister`.

### Notifications do not appear

Check System Settings > Notifications > HardwareGrowler.

Also verify the app is signed and installed in a stable location:

```sh
codesign -dv /Applications/HardwareGrowler.app
```

### Wi-Fi SSID is empty

macOS requires Location permission for Wi-Fi SSID/BSSID access. Enable Location Services for HardwareGrowler in System Settings > Privacy & Security > Location Services. This permission is only used to read the current Wi-Fi network identity for network change notifications.

### Bluetooth device name is not the custom name

HardwareGrowler uses public `IOBluetooth` APIs for Bluetooth device names. If a Bluetooth notification shows a generic product name instead of the custom name shown in System Settings, enable temporary Bluetooth name diagnostics:

```sh
defaults write com.growl.hardwaregrowler HWGBluetoothNameDiagnostics -bool YES
```

Restart HardwareGrowler, reproduce the Bluetooth connect or disconnect event, then inspect the diagnostics file:

```sh
tail -f ~/Library/Logs/HardwareGrowler/BluetoothNameDiagnostics.log
```

The app currently also recognizes the older `com.growl.HardwareGrowler` preference domain as a temporary compatibility fallback, but new diagnostics should use the lowercase `com.growl.hardwaregrowler` bundle identifier. Disable the extra unified-log logging afterwards:

```sh
defaults delete com.growl.hardwaregrowler HWGBluetoothNameDiagnostics
```

### Keyboard Monitor asks for Accessibility

The Keyboard Monitor may require Accessibility access. Enable it in System Settings > Privacy & Security > Accessibility after enabling the Keyboard Monitor.

### Plug-ins fail to load

Check that the app and plug-ins were built for compatible architectures:

```sh
lipo -archs /Applications/HardwareGrowler.app/Contents/MacOS/HardwareGrowler
for bin in /Applications/HardwareGrowler.app/Contents/PlugIns/*.hwgrowlmonitor/Contents/MacOS/*; do
  printf '%s: ' "$bin"
  lipo -archs "$bin"
done
```

An arm64 app needs arm64 plug-ins. A Universal 2 app should include Universal 2 plug-ins.
