#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Blink"
BUILD_DIR="build"
BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
STAGE="${BUILD_DIR}/dmg-stage"

echo "▸ 编译 (release)"
swift build -c release

echo "▸ 组装 .app"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp ".build/release/${APP_NAME}" "$BUNDLE/Contents/MacOS/${APP_NAME}"
cp "Resources/Info.plist" "$BUNDLE/Contents/Info.plist"
if [ -f "Resources/AppIcon.icns" ]; then
  cp "Resources/AppIcon.icns" "$BUNDLE/Contents/Resources/AppIcon.icns"
fi
printf 'APPL????' > "$BUNDLE/Contents/PkgInfo"

echo "▸ Ad-hoc 签名"
codesign --force --deep --sign - "$BUNDLE"
codesign -dv "$BUNDLE" 2>&1 | grep -E "Identifier|Signature" || true

# 清掉构建产物可能带上的隔离标记
xattr -dr com.apple.quarantine "$BUNDLE" 2>/dev/null || true

echo "▸ 准备 dmg 内容（app + Applications 链接 + 一键安装脚本）"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$BUNDLE" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp "Resources/安装 Blink.command" "$STAGE/安装 Blink.command"
chmod +x "$STAGE/安装 Blink.command"
xattr -cr "$STAGE" 2>/dev/null || true

echo "▸ 打包 dmg"
rm -f "${BUILD_DIR}/${APP_NAME}.dmg"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO \
  "${BUILD_DIR}/${APP_NAME}.dmg" > /dev/null

echo "▸ 校验"
hdiutil verify "${BUILD_DIR}/${APP_NAME}.dmg" > /dev/null 2>&1 && echo "  dmg checksum OK"

echo ""
echo "完成："
du -sh "$BUNDLE" "${BUILD_DIR}/${APP_NAME}.dmg"
