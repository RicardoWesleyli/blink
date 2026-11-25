import AppKit
import SwiftUI

/// 开发期用：把 SwiftUI 界面离屏渲染成 PNG，方便在没有屏幕录制权限的环境里检查排版。
enum SnapshotTool {
    static func captureAll(to directory: String) {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: directory, withIntermediateDirectories: true)

        // BLINK_SNAPSHOT_LANG=en 可以渲染英文版截图，用于国际渠道的素材
        let langEnv = ProcessInfo.processInfo.environment["BLINK_SNAPSHOT_LANG"] ?? ""
        let lang: AppLanguage = langEnv.hasPrefix("en") ? .english
            : (langEnv.hasPrefix("zh") ? .chinese : .system)
        L10n.language = lang

        let state = AppState()
        state.language = lang
        state.stats = DayStats(day: DateKey.today, breaksCompleted: 3, restSeconds: 75, exercisesCompleted: 3)
        state.secondsUntilNext = 12 * 60 + 34

        let actions = MenuActions(startBreak: {}, startTraining: { _ in }, showWelcome: {}, quit: {})

        render(AnyView(
            MenuPanel(state: state, actions: actions)
                .background(Color(nsColor: .windowBackgroundColor))
        ), size: NSSize(width: 340, height: 560), path: "\(directory)/01-menu.png")

        let session = BreakSession(total: 20)
        session.remaining = 14.2
        render(AnyView(BreakScene(session: session)),
               size: NSSize(width: 1280, height: 800), path: "\(directory)/02-break.png")

        let intro = TrainingSession(program: .screenTime)
        render(AnyView(TrainingScene(session: intro, onStart: {})),
               size: NSSize(width: 1280, height: 800), path: "\(directory)/03-training-intro.png")

        let training = TrainingSession(program: .screenTime)
        training.stageIndex = 1
        training.stageElapsed = 6
        training.stageStart = Date().addingTimeInterval(-6)
        training.isStarted = true
        render(AnyView(TrainingScene(session: training, onStart: {})),
               size: NSSize(width: 1280, height: 800), path: "\(directory)/04-training.png")

        render(AnyView(
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                Image(nsImage: EyeIcon.statusBar(height: 40))
                    .resizable()
                    .frame(width: 46, height: 40)
            }
            .frame(width: 120, height: 80)
        ), size: NSSize(width: 120, height: 80), path: "\(directory)/05-statusicon.png")

        render(AnyView(
            ZStack {
                Color(white: 0.30)
                ReminderCard(dark: true, onRest: {}, onLater: {})
            }
            .frame(width: 360, height: 170)
        ), size: NSSize(width: 360, height: 170), path: "\(directory)/06-card-dark.png", dark: true)

        render(AnyView(
            ZStack {
                Color(white: 0.72)
                ReminderCard(dark: false, onRest: {}, onLater: {})
            }
            .frame(width: 360, height: 170)
        ), size: NSSize(width: 360, height: 170), path: "\(directory)/07-card-light.png")

        let finish = TrainingSession(program: .screenTime)
        finish.isStarted = true
        finish.isFinished = true
        finish.finishCount = 3
        finish.finishWeekText = L10n.s("14 分钟", "14 min")
        finish.quote = TrainingQuotes.all[0]
        render(AnyView(TrainingScene(session: finish, onStart: {})),
               size: NSSize(width: 1280, height: 800), path: "\(directory)/08-training-finish.png")

        render(AnyView(CamouflageScene(session: CamouflageSession(), onExit: {})),
               size: NSSize(width: 1280, height: 800), path: "\(directory)/09-camouflage.png")

        for stage in EyeStage.allCases {
            let session = TrainingSession(program: .screenTime)
            session.isStarted = true
            session.stageIndex = stage.rawValue
            session.stageElapsed = 5
            session.stageStart = Date().addingTimeInterval(-5)
            render(AnyView(TrainingScene(session: session, onStart: {})),
                   size: NSSize(width: 1280, height: 800),
                   path: "\(directory)/stage-\(stage.rawValue).png")
        }

        print("snapshots -> \(directory)")
    }

    private static func render(_ view: AnyView, size: NSSize, path: String, dark: Bool = false) {
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(origin: .zero, size: size)
        host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        host.wantsLayer = true
        host.layoutSubtreeIfNeeded()

        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            print("bitmap failed for \(path)")
            return
        }
        host.cacheDisplay(in: host.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: URL(fileURLWithPath: path))
    }
}
