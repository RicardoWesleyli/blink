#!/bin/bash
# 双击运行即可安装 Blink
set -e
cd "$(dirname "$0")"

DEST="/Applications/Blink.app"

echo "▸ 正在安装 Blink…"

osascript -e 'quit app "Blink"' 2>/dev/null || true
pkill -f "Blink.app/Contents/MacOS/Blink" 2>/dev/null || true

rm -rf "$DEST"
cp -R "Blink.app" "$DEST"

# 清掉可能存在的隔离标记，避免 Gatekeeper 再拦一次
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

open "$DEST"

echo ""
echo "装好了。菜单栏右侧会多出一只眼睛，Dock 里不会有图标。"
echo "Installed. Look for the eye in the menu bar. No Dock icon."
echo ""
echo "它不申请摄像头或麦克风，不录屏，也不联网。"
echo "No camera, no microphone, no screen capture, no network."
echo ""
sleep 2
