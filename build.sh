#!/bin/zsh
# Builds build/Revive the Touchbar.app: a universal (Apple silicon + Intel), ad-hoc signed app.
# Requires Xcode or the Command Line Tools.
# Set SIGN_IDENTITY to a "Developer ID Application: ..." identity to sign for distribution
# (hardened runtime + timestamp); otherwise the app is ad-hoc signed.
set -euo pipefail
cd "$(dirname "$0")"
APP="build/Revive the Touchbar.app"
rm -rf "$APP" build/arm64 build/x86_64
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/arm64 build/x86_64

for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 ${DEBUG_BUILD:+-DDEBUG} -target "$arch-apple-macos13.0" \
    -import-objc-header Sources/Bridging.h Sources/*.swift -o "build/$arch/ReviveTheTouchbar"
done
lipo -create build/arm64/ReviveTheTouchbar build/x86_64/ReviveTheTouchbar -output "$APP/Contents/MacOS/ReviveTheTouchbar"

cp Info.plist "$APP/Contents/Info.plist"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/"
[ -d Resources/lproj ] && cp -R Resources/lproj/*.lproj "$APP/Contents/Resources/" 2>/dev/null || true
if [ -n "${SIGN_IDENTITY:-}" ]; then
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
else
  codesign --force --sign - "$APP"
fi
echo "Built $PWD/$APP"
