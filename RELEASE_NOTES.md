# v1.0.0 — first public build

**A break you actually take, not one you wait out.**

Blink sits in the menu bar, interrupts long screen sessions, and then does something with the break: a dot moves, your eyes follow it off-center, around a slow circle, far then near, and finally closed. 60 to 90 seconds, nothing to read.

## Install

Download `Blink.dmg` below, open it, and **double-click「安装 Blink.command」** inside the window — don't drag the app into Applications.

Blink is ad-hoc signed but not notarized, so Gatekeeper blocks a plain drag-and-drop. The script clears the quarantine flag and installs to `/Applications`. Manual route:

```bash
xattr -cr /Applications/Blink.app
open /Applications/Blink.app
```

macOS 13+, Apple silicon or Intel.

## What's in this build

- Menu bar app, no Dock icon, 340 pt panel
- Reminder interval 5–240 min (presets 20 / 30 / 40 / 45 / 60 / 90 / 120)
- Break length 10 s–10 min (presets 20 s / 30 s / 45 s / 1 / 3 / 5 / 10 min)
- Full-screen break: Gaussian blur behind, ring fills clockwise, countdown in the middle, hover the ring to pause
- Four eye routines — Screen break, Morning wake, Dry eyes, Before sleep
- Finishing a routine offers "step away": the screen becomes a system update screen, click anywhere to return, auto-exits after 3 minutes
- Stats: streak, minutes this week, rests today
- English and 简体中文, switchable in the panel, applied without restart
- Reminders pause themselves when you're away from the keyboard or in a full-screen app

## Privacy

No camera, no microphone, no screen capture, no eye tracking, no network. Stats live in `UserDefaults` and vanish when you delete the app. PRIVACY.md（仓库内）

## Known limitations

- Ad-hoc signed. Fine locally, but a downloaded copy needs the installer script or `xattr` — that's the main friction right now.
- No gaze tracking. Macs have no TrueDepth camera and Vision only exposes eyelid landmarks, so the routine is fixed rather than adaptive.
- Not on the Mac App Store. That needs a Developer ID and notarization; this release is to find out whether people keep it installed first.

Found a bug or want something? Open an issue.

---

# v1.0.0 — 第一个公开版本

**休息是要做的，不是要熬的。**

Blink 住在菜单栏，打断长时间用眼，然后真的用掉这段休息：一个光点开始动，你的眼睛跟着它离开中心、绕一个慢圈、看远再看近，最后闭上。60 到 90 秒，画面上没有字要读。

## 安装

下载下面的 `Blink.dmg`，打开后**双击「安装 Blink.command」**，不要拖拽。

Blink 是 ad-hoc 签名、尚未公证，直接拖进 Applications 会被 Gatekeeper 拦。脚本会清掉隔离标记并装到 `/Applications`。手动装：

```bash
xattr -cr /Applications/Blink.app
open /Applications/Blink.app
```

要求 macOS 13 以上，Apple 芯片与 Intel 都可以。

## 这个版本有什么

- 菜单栏应用，没有 Dock 图标，面板 340pt
- 提醒间隔 5–240 分钟（预设 20 / 30 / 40 / 45 / 60 / 90 / 120）
- 休息时长 10 秒–10 分钟（预设 20 秒 / 30 秒 / 45 秒 / 1 / 3 / 5 / 10 分钟）
- 全屏休息：背景高斯模糊，圆环顺时针长满，中间倒计时，鼠标移入圆环可暂停
- 四套眼部训练——屏幕间歇、晨间唤醒、干眼舒缓、睡前放松
- 训练结束后可选「我要走开」：屏幕变成系统更新界面，点任意处返回，3 分钟自动退出
- 统计：连续训练、本周时长、今日休息
- 中文与 English，面板内切换，不用重启
- 键盘离开或前台应用全屏时，提醒自动暂停计时

## 隐私

不用摄像头、麦克风，不录屏，不做眼动追踪，不联网。统计存在 `UserDefaults`，删掉应用就没了。详见 PRIVACY.md。

## 已知限制

- ad-hoc 签名。本机没问题，但别人下载要跑安装脚本或用 `xattr`——这是目前最大的摩擦
- 不做注视点追踪。Mac 没有 TrueDepth，Vision 只给眼睑关键点，所以动作是固定的，不是自适应的
- 未上架 Mac App Store。那需要 Developer ID 和公证，这一版先看看有多少人真的留着它
