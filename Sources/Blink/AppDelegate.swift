import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state = AppState()
    private let reminder = ReminderEngine()
    private let hud = HUDController()
    private let welcome = WelcomeWindowController()
    private lazy var overlay = OverlayController(state: state)
    private lazy var training = TrainingController(state: state)
    private let camouflage = CamouflageController()
    private var status: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if ProcessInfo.processInfo.environment["BLINK_SNAPSHOT"] == "1" {
            let dir = ProcessInfo.processInfo.environment["BLINK_SNAPSHOT_DIR"] ?? "/tmp/blink-shot"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                SnapshotTool.captureAll(to: dir)
                NSApp.terminate(nil)
            }
            return
        }

        let actions = MenuActions(
            startBreak: { [weak self] in self?.beginBreak() },
            startTraining: { [weak self] program in self?.beginTraining(program: program) },
            showWelcome: { [weak self] in self?.welcome.show() },
            quit: { NSApp.terminate(nil) }
        )

        status = StatusItemController(state: state, actions: actions)

        reminder.attach(state: state)
        reminder.onRemind = { [weak self] in self?.fireReminder() }
        reminder.start()

        // 双击启动后不能什么都不发生——第一次给一个明确的落地面
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.welcome.showIfNeeded()
        }
    }

    private func beginBreak() {
        state.pendingReminder = false
        hud.dismiss()
        overlay.startRest { [weak self] completed in
            guard let self, completed else { return }
            self.reminder.resetCycle()
            self.state.noteShortBreak()
            self.state.recordBreak(seconds: self.state.breakSeconds)
        }
    }

    private func beginTraining(program: TrainingProgram) {
        state.pendingReminder = false
        hud.dismiss()
        training.start(program: program,
                       completion: { [weak self] completed in
                           if completed { self?.reminder.resetCycle() }
                       },
                       onLeave: { [weak self] in
                           self?.leaveToCamouflage()
                       })
    }

    /// 训练完了，用户想离开一会儿：屏幕装成正在更新，人走开安心
    private func leaveToCamouflage() {
        let wasPaused = state.isPaused
        state.isPaused = true
        // 训练页正在淡出，等它收干净再铺伪装页，避免两层面板打架
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) { [weak self] in
            guard let self else { return }
            self.camouflage.show { [weak self] in
                self?.state.isPaused = wasPaused
            }
        }
    }

    private func fireReminder() {
        let willTrain = state.shouldTrainThisCycle
        let program = state.recommendedProgram

        hud.showPre(
            anchor: status?.anchorButton,
            seconds: 10,
            title: willTrain
                ? L10n.s("10 秒后开始「\(program.title)」", "\(program.title) starts in 10s")
                : L10n.s("10 秒后进入休息", "Break in 10s"),
            subtitle: willTrain
                ? program.subtitle
                : L10n.s("望向 6 米以外，让睫状肌松开。", "Look 20 feet out. Let your eyes loosen.")
        ) { [weak self] in
            guard let self else { return }
            if willTrain {
                self.beginTraining(program: program)
            } else {
                self.beginBreak()
            }
        } onLater: { [weak self] in
            guard let self else { return }
            self.state.pendingReminder = false
            self.reminder.snooze(minutes: 5)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
