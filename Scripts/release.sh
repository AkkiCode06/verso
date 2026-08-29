#!/bin/bash
#
# Builds Verso and packages it as a drag-and-drop disk image.
#
# The result is unsigned beyond an ad-hoc signature, which is why the README
# has to explain Gatekeeper to everyone who downloads it. Signing this
# properly needs a paid Apple Developer account; see NOTARIZING below.
#
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
DIST="$ROOT/dist"
STAGE="$DIST/stage"
APP_NAME="Verso"

VERSION=$(grep 'CFBundleShortVersionString:' project.yml | awk '{print $2}')
DMG="$DIST/$APP_NAME-$VERSION.dmg"

echo "==> Verso $VERSION"

# The .xcodeproj is generated, not committed, so a clean checkout needs this.
if ! command -v xcodegen >/dev/null 2>&1; then
    echo "!! xcodegen not found. Install it with: brew install xcodegen" >&2
    exit 1
fi
echo "==> Generating project"
xcodegen generate >/dev/null

echo "==> Building (Release)"
rm -rf "$DIST"
mkdir -p "$STAGE"

# Built outside the repo, in a path with no spaces: Xcode's build database
# has been seen to fail with a disk I/O error under the project directory.
BUILD_DIR="/tmp/verso-release-build"
rm -rf "$BUILD_DIR"

# PIPESTATUS, not the pipeline's status: piping into grep would otherwise
# report grep's success and mask a failed build. An earlier version of this
# script swallowed a real failure and shipped a disk image anyway.
set +e
xcodebuild \
    -project "$APP_NAME.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    build 2>&1 | grep -E "error:|BUILD"
STATUS=${PIPESTATUS[0]}
set -e
[ "$STATUS" -eq 0 ] || { echo "!! Build failed (status $STATUS). Nothing packaged." >&2; exit 1; }

APP="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"
[ -d "$APP" ] || { echo "!! Build produced no app bundle" >&2; exit 1; }

# The shaders are compiled separately from the Swift, and a metallib that
# failed to build leaves an app that launches to a black screen. Cheaper to
# catch here than in someone's download.
EFFECTS=$(strings "$APP/Contents/Resources/default.metallib" 2>/dev/null \
    | grep -oE '^wl[A-Za-z]+$' | sort -u | wc -l | tr -d ' ')
[ "$EFFECTS" -ge 25 ] || { echo "!! Expected 25 shader effects, found $EFFECTS" >&2; exit 1; }
echo "    $EFFECTS shader effects present"

echo "==> Staging"
cp -R "$APP" "$STAGE/"
# The symlink is what makes the window a drag-and-drop target: the user drags
# the app onto it and macOS installs into the real /Applications.
ln -s /Applications "$STAGE/Applications"

# A short README on the image itself, because the Gatekeeper warning appears
# before anyone has reason to go back to the GitHub page.
cat > "$STAGE/Read me first.txt" <<'TXT'
Verso
==========

1. Drag Verso onto the Applications folder.

2. The first time you open it, macOS will refuse, saying Apple could not
   verify it is free of malware. This is expected. Verso is not signed
   with a paid Apple Developer certificate, and macOS distrusts any app that
   is not, regardless of what it does.

   To open it anyway:

     - Open Applications, right-click (or Control-click) Verso,
       and choose Open.
     - Click Open in the dialog that appears.

   You only have to do this once.

   If the Open option does not appear, go to System Settings > Privacy &
   Security, scroll to Security, and click "Open Anyway" next to the
   message about Verso.

3. Verso will ask permission to control Music. It needs this to read
   what is playing and where you are in the track. Nothing leaves your Mac.

4. It runs in the menu bar -- look for the waveform icon. There is no
   window; your desktop is the window.

Source, and a fuller explanation of the security warning:
https://github.com/AkkiCode06/verso
TXT

echo "==> Building disk image"
# Built read-write first so the volume icon can be set, then compressed.
# A volume icon has to be written *inside* the mounted image and flagged
# there; it cannot be added to a finished read-only dmg.
RW="$DIST/rw.dmg"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDRW "$RW" >/dev/null
MOUNT=$(hdiutil attach "$RW" -nobrowse -noverify -noautoopen | grep -o '/Volumes/.*$' | head -1)

cp "$APP/Contents/Resources/AppIcon.icns" "$MOUNT/.VolumeIcon.icns"
# The custom-icon bit is what makes Finder read .VolumeIcon.icns at all.
SetFile -a C "$MOUNT" 2>/dev/null || true

hdiutil detach "$MOUNT" -quiet
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
rm -f "$RW"

rm -rf "$STAGE" "$BUILD_DIR"

echo
echo "==> Done: $DMG"
echo "    $(du -h "$DMG" | cut -f1)"
echo
echo "NOTARIZING (optional, needs a paid Apple Developer account):"
echo "  Without it every downloader sees the Gatekeeper warning above."
echo "  1. Set DEVELOPMENT_TEAM and CODE_SIGN_IDENTITY in project.yml,"
echo "     and ENABLE_HARDENED_RUNTIME: true"
echo "  2. xcrun notarytool submit \"$DMG\" --apple-id <you> \\"
echo "       --team-id <team> --password <app-specific-password> --wait"
echo "  3. xcrun stapler staple \"$DMG\""
