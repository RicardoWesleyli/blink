import AppKit
import SwiftUI

@MainActor
final class TrainingController {
    private let state: AppState
    private let overlay = ScreenOverlay()
    private var session: TrainingSession?
    private var keyMonitor: Any?
    private var timer: Timer?
    private var isActive = false
    private var completion: ((Bool) -> Void)?
    private var onLeave: (() -> Void)?
    private var finishTimer: Timer?

    init(state: AppState) {
        self.state = state
    }

    func start(program: TrainingProgram,
               completion: ((Bool) -> Void)? = nil,
               onLeave: (() -> Void)? = nil) {
        guard !isActive else { return }
        isActive = true
        state.isTraining = true
        state.pendingReminder = false

        let session = TrainingSession(program: program)
        session.stageStart = Date()
        self.session = session
        self.completion = completion
        self.onLeave = onLeave

        overlay.show({ _ in
            NSHostingView(rootView: TrainingScene(session: session, onStart: { [weak self] in
                Task { @MainActor in self?.begin() }
            }, onLeave: { [weak self] in
                Task { @MainActor in self?.leaveToCamouflage() }
            }))
        }, onKeyDown: {})

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53 { // Esc
                self.finish(completed: false)
                return nil
            }
            if !session.isStarted, event.keyCode == 49 || event.keyCode == 36 { // 空格 / 回车
                self.begin()
                return nil
            }
            return event
        }

        let ticker = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(ticker, forMode: .common)
        timer = ticker
    }

    /// 引导页确认后开始计时
    private func begin() {
        guard let session, !session.isStarted else { return }
        session.stageElapsed = 0
        session.stageStart = Date()
        session.isStarted = true
    }

    private func tick() {
        guard let session, session.isStarted else { return }
        let stage = session.current

        if session.stageElapsed < stage.seconds {
            session.stageElapsed += 0.05
        }

        if session.stageElapsed >= stage.seconds {
            if session.stageIndex + 1 < session.stages.count {
                session.stageIndex += 1
                session.stageElapsed = 0
                session.stageStart = Date()
            } else {
                finish(completed: true)
            }
        }
    }

    private func finish(completed: Bool) {
        guard isActive else { return }
        isActive = false

        timer?.invalidate()
        timer = nil

        if completed, let session {
            state.recordExercise(program: session.program)
            session.finishCount = state.stats.exercisesCompleted
            session.finishWeekText = state.weekMinutesText
            session.quote = state.nextQuote()
            session.isFinished = true
        } else if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }

        // 完成页停留五秒：够读完反馈，也够点到「我要走开」
        let delay: Double = completed ? 5.0 : 0.0
        finishTimer?.invalidate()
        let timer = Timer(timeInterval: max(0.02, delay), repeats: false) { [weak self] _ in
            self?.teardown(completed: completed)
        }
        RunLoop.main.add(timer, forMode: .common)
        finishTimer = timer
    }

    private func teardown(completed: Bool) {
        finishTimer?.invalidate()
        finishTimer = nil
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        overlay.hide()
        session = nil
        state.isTraining = false
        let callback = completion
        completion = nil
        callback?(completed)
    }

    /// 用户选择离开：先把训练页收掉，再交给外层铺伪装页
    private func leaveToCamouflage() {
        guard isActive else { return }
        isActive = false
        timer?.invalidate()
        timer = nil
        finishTimer?.invalidate()
        finishTimer = nil
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        overlay.hide()
        session = nil
        state.isTraining = false

        let callback = completion
        completion = nil
        callback?(true)

        let leave = onLeave
        onLeave = nil
        leave?()
    }

    func forceStop() {
        finish(completed: false)
    }
}
