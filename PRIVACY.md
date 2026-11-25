# Privacy

Blink does not collect anything. This is not a policy statement, it is a description of what the code does.

## What Blink never does

- **No camera.** There is no `AVCaptureSession` anywhere in the source. The training is visually guided: a dot moves, your eyes follow it. Nothing needs to be observed. Your camera indicator light will never turn on because of Blink.
- **No microphone.** No audio APIs are imported.
- **No screen capture.** No `CGWindowListCreateImage`, no `ScreenCaptureKit`, no screen recording permission request.
- **No eye or gaze tracking.** No Vision framework request for face or eye landmarks. The routine advances on a timer, not on what your eyes are doing.
- **No network.** Blink makes no HTTP requests. It has no analytics SDK, no crash reporter, no update checker, no account system.
- **No clipboard, no contacts, no location, no files outside its own preferences.**

## What stays on your Mac

Only these, in `UserDefaults` under `com.lizhiwei.blink`:

- interval and break length
- whether reminders are paused
- today's break count and rest seconds
- total sessions, total seconds, streak, program counts
- the last quote shown
- your language choice

Deleting the app removes the preference file. There is nothing to delete on a server, because there is no server.

## Permissions

Blink requests none at install or at runtime. It does not need Accessibility, Screen Recording, Camera, Microphone, Automation, or Full Disk Access.

It reads one thing from the system, and only to decide whether you are at the computer: the timestamp of your last keyboard or mouse event, via `CGEventSource.secondsSinceLastEventType`. That returns a number of seconds — it does not reveal what you typed, clicked, or opened.

## Verifying this yourself

The whole thing is open source. The claims above map to code:

- `Sources/Blink/TrainingController.swift` — advances stages on a 0.05s timer
- `Sources/Blink/ReminderEngine.swift` — the only place that reads the idle timestamp
- `Sources/Blink/AppState.swift` — everything persisted
- `Sources/Blink/AppDelegate.swift` — what gets started at launch

---

# 隐私

Blink 不采集任何东西。下面不是政策声明，是对代码行为的描述。

## 不会做的事

- **不用摄像头。** 源码里没有任何 `AVCaptureSession`。训练是视觉引导：光点动，你的眼睛跟着走，不需要被观测。摄像头指示灯不会因为 Blink 亮起。
- **不用麦克风。** 没有引入任何音频接口。
- **不录屏。** 没有 `CGWindowListCreateImage`，没有 `ScreenCaptureKit`，不会申请屏幕录制权限。
- **不做眼动追踪。** 不调用 Vision 的人脸或眼部关键点。动作按时间推进，不看你眼睛在做什么。
- **不联网。** 没有任何 HTTP 请求，没有统计 SDK、崩溃上报、更新检查、账号体系。
- **不碰剪贴板、通讯录、定位，不读偏好文件以外的任何文件。**

## 留在你 Mac 上的东西

只有 `UserDefaults`（`com.lizhiwei.blink`）里这些：

- 提醒间隔与休息时长
- 是否暂停
- 今日休息次数与累计秒数
- 总训练次数、总时长、连续天数、各课程完成数
- 上一次显示的反馈文案
- 语言选择

删掉应用，偏好文件就没了。服务器上没有可删的东西，因为没有服务器。

## 权限

安装和运行时都不申请任何权限：不需要辅助功能、屏幕录制、摄像头、麦克风、自动化、完全磁盘访问。

它只从系统读一样东西，而且只用来判断你在不在电脑前：最后一次键鼠事件的时间戳（`CGEventSource.secondsSinceLastEventType`）。返回的是一个秒数，不包含你敲了什么、点了什么、打开了什么。

## 自己核对

全部开源。上面的说法都能落到代码：

- `Sources/Blink/TrainingController.swift` —— 0.05 秒一次的计时推进
- `Sources/Blink/ReminderEngine.swift` —— 唯一读取空闲时间戳的地方
- `Sources/Blink/AppState.swift` —— 所有被持久化的内容
- `Sources/Blink/AppDelegate.swift` —— 启动时到底启动了哪些模块
