import Foundation
import CoreGraphics
import AppKit

/// 每分钟一跳的调度器。它不直接弹窗，只负责判断「现在该不该提醒」。
@MainActor
final class ReminderEngine {
    private weak var state: AppState?
    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var accumulated: TimeInterval = 0
    private var lastIntervalMinutes: Int = 0

    var onRemind: (() -> Void)?

    func attach(state: AppState) {
        self.state = state
        self.lastIntervalMinutes = state.intervalMinutes
        self.accumulated = 0
    }

    func start() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t

        // 合盖/休眠醒来后不该接着上一次的累计，否则一开机就弹提醒
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.resetCycle()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }
    }

    private func tick() {
        guard let state else { return }

        if state.intervalMinutes != lastIntervalMinutes {
            lastIntervalMinutes = state.intervalMinutes
            accumulated = 0
        }

        let total = Double(state.intervalMinutes * 60)

        if state.isPaused || state.isBreaking || state.isTraining {
            state.secondsUntilNext = Int(max(0, total - accumulated))
            return
        }

        // 人不在屏幕前时不该算作连续用眼。
        // 90 秒起暂停累计（离开期间既不推进、也不算用眼时间），
        // 5 分钟以上视为已经休息够了，整轮重新起算，回来不会立刻弹提醒。
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState,
                                                           eventType: CGEventType(rawValue: ~0)!)
        if idle > 90 {
            if idle > 300 {
                accumulated = 0
            }
            state.secondsUntilNext = Int(max(0, total - accumulated))
            return
        }

        if isFullscreenAppActive() {
            state.secondsUntilNext = Int(max(0, total - accumulated))
            return
        }

        accumulated += 1
        let remain = max(0, total - accumulated)
        state.secondsUntilNext = Int(remain)

        if remain <= 0 {
            accumulated = 0
            state.pendingReminder = true
            onRemind?()
        }
    }

    /// 前台 App 铺满整块屏幕时（全屏视频、演示、游戏）先不打扰
    private func isFullscreenAppActive() -> Bool {
        guard let front = NSWorkspace.shared.frontmostApplication,
              front.bundleIdentifier != Bundle.main.bundleIdentifier,
              let screen = NSScreen.main,
              let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                    kCGNullWindowID) as? [[String: Any]]
        else { return false }

        let screenSize = screen.frame.size
        let pid = front.processIdentifier

        for info in list {
            guard let owner = info[kCGWindowOwnerPID as String] as? Int, owner == Int(pid),
                  let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                  let bounds = info[kCGWindowBounds as String] as? [String: CGFloat]
            else { continue }

            let width = bounds["Width"] ?? 0
            let height = bounds["Height"] ?? 0
            if width >= screenSize.width * 0.95 && height >= screenSize.height * 0.92 {
                return true
            }
        }
        return false
    }

    /// 手动「稍后」：把累计回拨，让下次提醒往后推几分钟
    func snooze(minutes: Int) {
        guard let state else { return }
        let total = Double(state.intervalMinutes * 60)
        accumulated = max(0, total - Double(minutes * 60))
        state.secondsUntilNext = Int(max(0, total - accumulated))
    }

    /// 用户手动休息后，重新起算
    func resetCycle() {
        accumulated = 0
        if let state {
            state.secondsUntilNext = state.intervalMinutes * 60
        }
    }
}
