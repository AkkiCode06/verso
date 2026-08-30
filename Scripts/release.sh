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

# The background has to live on the image itself, in a hidden folder, because
# Finder stores only a relative reference to it in the window's .DS_Store.
mkdir -p "$MOUNT/.background"
cp "$ROOT/docs/dmg/background.tiff" "$MOUNT/.background/background.tiff"

# Icon positions and the window size are written into the volume's .DS_Store
# by Finder itself; there is no way to set them from the command line, so the
# layout has to be driven through AppleScript while the image is mounted.
osascript <<APPLESCRIPT >/dev/null 2>&1 || echo "!! Could not set the window layout (needs Finder automation permission)" >&2
tell application "Finder"
    tell disk "$APP_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        -- 640x420 of content; the window frame adds the title bar on top.
        set the bounds of container window to {200, 160, 840, 600}
        set opts to the icon view options of container window
        set arrangement of opts to not arranged
        set icon size of opts to 112
        set text size of opts to 12
        set background picture of opts to file ".background:background.tiff"
        -- y=217 is the centre of the artwork's caption-and-arrow block,
        -- measured off the image: the caption runs y 188-207 and the arrow
        -- y 228-245.
        set position of item "$APP_NAME.app" of container window to {150, 217}
        set position of item "Applications" of container window to {490, 217}
        update without registering applications
        delay 2
        close
    end tell
end tell
APPLESCRIPT

# Finder writes .DS_Store lazily; without this the image is often detached
# before the layout has actually been flushed to it.
sync
sleep 2

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
