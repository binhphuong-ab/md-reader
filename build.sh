#!/bin/bash
# Builds "MD Reader.app" from the Swift package.
#   ./build.sh               build + install to /Applications
#   ./build.sh --no-install  build only (./MD Reader.app)
set -euo pipefail
cd "$(dirname "$0")"
APP_NAME="MD Reader"
EXEC_NAME="MDReader"
BUNDLE_ID="com.binhphuong-ab.mdreader"
BUNDLE="$APP_NAME.app"
VERSION="1.0.0"

echo "==> swift build"
swift build -c release 2>&1 | grep -v "search path .* not found" || true
[ -x ".build/release/$EXEC_NAME" ] || { echo "build failed"; exit 1; }

echo "==> icon"
rm -rf build/AppIcon.iconset && mkdir -p build
swift tools/make-icon.swift build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns

echo "==> bundle"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp ".build/release/$EXEC_NAME" "$BUNDLE/Contents/MacOS/$EXEC_NAME"
cp build/AppIcon.icns "$BUNDLE/Contents/Resources/AppIcon.icns"
cp -R Web "$BUNDLE/Contents/Resources/web"

cat > "$BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>                 <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>          <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>           <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>              <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>   <string>$VERSION</string>
    <key>CFBundlePackageType</key>          <string>APPL</string>
    <key>CFBundleExecutable</key>           <string>$EXEC_NAME</string>
    <key>CFBundleIconFile</key>             <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>       <string>14.0</string>
    <key>NSHighResolutionCapable</key>      <true/>
    <key>NSRequiresAquaSystemAppearance</key><false/>
    <key>LSApplicationCategoryType</key>    <string>public.app-category.productivity</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>     <string>Markdown Document</string>
            <key>CFBundleTypeRole</key>     <string>Viewer</string>
            <key>LSHandlerRank</key>        <string>Alternate</string>
            <key>NSDocumentClass</key>      <string>MarkdownDocument</string>
            <key>LSItemContentTypes</key>   <array><string>net.daringfireball.markdown</string></array>
        </dict>
        <dict>
            <key>CFBundleTypeName</key>     <string>Plain Text</string>
            <key>CFBundleTypeRole</key>     <string>Viewer</string>
            <key>LSHandlerRank</key>        <string>None</string>
            <key>NSDocumentClass</key>      <string>MarkdownDocument</string>
            <key>LSItemContentTypes</key>   <array><string>public.plain-text</string></array>
        </dict>
    </array>
    <key>UTImportedTypeDeclarations</key>
    <array><dict>
        <key>UTTypeIdentifier</key>         <string>net.daringfireball.markdown</string>
        <key>UTTypeDescription</key>        <string>Markdown Document</string>
        <key>UTTypeConformsTo</key>         <array><string>public.plain-text</string></array>
        <key>UTTypeTagSpecification</key>
        <dict><key>public.filename-extension</key>
            <array><string>md</string><string>markdown</string><string>mdown</string><string>mkd</string><string>mkdn</string></array>
        </dict>
    </dict></array>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$BUNDLE"
echo "==> built $BUNDLE"

if [[ "${1:-}" != "--no-install" ]]; then
    osascript -e "quit app \"$APP_NAME\"" 2>/dev/null || true
    rm -rf "/Applications/$BUNDLE"
    cp -R "$BUNDLE" /Applications/
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Applications/$BUNDLE"
    echo "==> installed /Applications/$BUNDLE"
fi
