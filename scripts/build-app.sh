#!/bin/bash
# Builds a universal, ad-hoc signed "Chojema OptSwitch.app" and a release zip in build/.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(cat VERSION)
BUILD=$(git rev-list --count HEAD 2>/dev/null || echo 1)
APP="build/Chojema OptSwitch.app"
ZIP="Chojema-OptSwitch-$VERSION.zip"
# Map the local checkout path to a neutral one so it never lands in the binary.
FLAGS=(-c release --arch arm64 --arch x86_64 -Xswiftc -file-prefix-map -Xswiftc "$PWD=/OptSwitch")
swift build "${FLAGS[@]}"

rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
cp "$(swift build "${FLAGS[@]}" --show-bin-path)/OptSwitch" "$APP/Contents/MacOS/OptSwitch"
strip -S -x "$APP/Contents/MacOS/OptSwitch"  # also drops object-file paths kept for debugging
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" Resources/Info.plist > "$APP/Contents/Info.plist"

if strings - "$APP/Contents/MacOS/OptSwitch" | grep -qF "$PWD"; then
    echo "error: binary still contains the build path" >&2
    exit 1
fi

codesign --force --sign - --options runtime "$APP"
ditto -c -k --norsrc --noextattr --keepParent "$APP" "build/$ZIP"
(cd build && shasum -a 256 "$ZIP" > "$ZIP.sha256")
echo "Built build/$ZIP (version $VERSION, build $BUILD)"
