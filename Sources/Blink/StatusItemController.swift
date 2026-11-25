import AppKit
import SwiftUI
import Combine

struct MenuActions {
    var startBreak: () -> Void
    var startTraining: (TrainingProgram) -> Void
    var showWelcome: () -> Void
    var quit: () -> Void
}

@MainActor
final class StatusItemController: NSObject {
    private let state: AppState
    private let actions: MenuActions

    private let statusItem: NSStatusItem

    /// 菜单栏那只眼睛本身，交给 popover 当锚点，位置由系统负责
    var anchorButton: NSStatusBarButton? {
        statusItem.button
    }
    private let popover = NSPopover()
    private var cancellables = Set<AnyCancellable>()

    private var breathingTimer: Timer?
    private var breathPhase: Double = 0

    /// 面板展开后挂上去的关闭监听，收起来时要清掉，避免叠加
    private var escMonitor: Any?
    private var popoverWindow: NSWindow?

    init(state: AppState, actions: MenuActions) {
        self.state = state
        self.actions = actions
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        configureButton()
        configurePopover()
        observeState()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.image = EyeIcon.statusBar()
        button.imagePosition = .imageOnly
        button.toolTip = L10n.s("Blink — 让眼睛喘口气", "Blink — let your eyes breathe")
        button.target = self
        button.action = #selector(handleClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 340, height: 560)
        let root = MenuPanel(state: state, actions: actions)
        popover.contentViewController = NSHostingController(rootView: root)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(popoverDidClose),
                                               name: NSPopover.didCloseNotification,
                                               object: popover)
    }

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            installDismissObservers()
        }
    }

    // MARK: 自动收起
    //
    // .transient 本身只在「点击其他 app」时才收，点桌面空白、切 Space、用键盘都容易留在屏上。
    // 这里补三种情况：本 app 失去激活、面板窗口丢 key、按 Esc。

    private func installDismissObservers() {
        teardownDismissObservers()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appDidResignActive),
                                               name: NSApplication.didResignActiveNotification,
                                               object: nil)

        if let window = popover.contentViewController?.view.window {
            popoverWindow = window
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(popoverWindowDidResignKey),
                                                   name: NSWindow.didResignKeyNotification,
                                                   object: window)
        }

        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53, self.popover.isShown {
                self.popover.performClose(nil)
                return nil
            }
            return event
        }
    }

    private func teardownDismissObservers() {
        NSObject.cancelPreviousPerformRequests(withTarget: self,
                                               selector: #selector(checkCloseAfterKeyChange),
                                               object: nil)
        NotificationCenter.default.removeObserver(self,
                                                  name: NSApplication.didResignActiveNotification,
                                                  object: nil)
        if let window = popoverWindow {
            NotificationCenter.default.removeObserver(self,
                                                      name: NSWindow.didResignKeyNotification,
                                                      object: window)
        }
        popoverWindow = nil
        if let monitor = escMonitor {
            NSEvent.removeMonitor(monitor)
            escMonitor = nil
        }
    }

    @objc private func popoverDidClose() {
        teardownDismissObservers()
    }

    @objc private func appDidResignActive() {
        guard popover.isShown else { return }
        popover.performClose(nil)
    }

    @objc private func popoverWindowDidResignKey() {
        NSObject.cancelPreviousPerformRequests(withTarget: self,
                                               selector: #selector(checkCloseAfterKeyChange),
                                               object: nil)
        perform(#selector(checkCloseAfterKeyChange), with: nil, afterDelay: 0.25)
    }

    /// 丢 key 之后等一小会儿再看：key 被下拉菜单或输入框拿走时不能收面板，
    /// 真的没人接手（点了桌面、切了 Space）才收。
    @objc private func checkCloseAfterKeyChange() {
        guard popover.isShown else { return }
        if NSApp.keyWindow != nil { return }
        popover.performClose(nil)
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: state.isPaused ? L10n.s("恢复提醒", "Resume reminders")
                                      : L10n.s("暂停提醒", "Pause reminders"),
                     action: #selector(togglePause), keyEquivalent: "")
            .target = self
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: L10n.s("现在休息 20 秒", "Break now (20s)"),
                     action: #selector(startBreak), keyEquivalent: "")
            .target = self
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: L10n.s("退出 Blink", "Quit Blink"),
                     action: #selector(quit), keyEquivalent: "q")
            .target = self
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func togglePause() {
        state.isPaused.toggle()
    }

    @objc private func startBreak() {
        actions.startBreak()
    }

    @objc private func quit() {
        actions.quit()
    }

    // MARK: 待提醒时让图标缓慢呼吸，不抢注意力但能感知到

    private func observeState() {
        state.$pendingReminder
            .receive(on: RunLoop.main)
            .sink { [weak self] pending in
                guard let self else { return }
                if pending {
                    self.startBreathing()
                } else {
                    self.stopBreathing()
                }
            }
            .store(in: &cancellables)
    }

    private func startBreathing() {
        guard breathingTimer == nil else { return }
        breathPhase = 0
        let timer = Timer(timeInterval: 0.12, repeats: true) { [weak self] _ in
            guard let self, let button = self.statusItem.button else { return }
            self.breathPhase += 0.12
            let alpha = 0.55 + 0.45 * (0.5 + 0.5 * sin(self.breathPhase * .pi / 2.4))
            button.alphaValue = alpha
        }
        RunLoop.main.add(timer, forMode: .common)
        breathingTimer = timer
    }

    private func stopBreathing() {
        breathingTimer?.invalidate()
        breathingTimer = nil
        statusItem.button?.alphaValue = 1.0
    }
}
