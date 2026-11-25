import AppKit
import SwiftUI

final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// 负责在每一块屏幕上铺一层面板，压住全屏 App，并统一处理淡入淡出。
@MainActor
final class ScreenOverlay {
    private var panels: [OverlayPanel] = []

    var isShowing: Bool { !panels.isEmpty }

    func show(_ makeView: (NSScreen) -> NSView,
              onKeyDown: @escaping () -> Void) {
        hideImmediately()

        for screen in NSScreen.screens {
            let panel = OverlayPanel(contentRect: screen.frame,
                                     styleMask: [.borderless],
                                     backing: .buffered,
                                     defer: false)
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary,
                                        .stationary, .ignoresCycle]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.isReleasedWhenClosed = false
            panel.hidesOnDeactivate = false
            panel.ignoresMouseEvents = false

            let view = makeView(screen)
            view.frame = NSRect(origin: .zero, size: screen.frame.size)
            view.autoresizingMask = [.width, .height]
            panel.contentView = view

            panel.setFrame(screen.frame, display: true)
            panel.alphaValue = 0
            panels.append(panel)
        }

        NSApp.activate(ignoringOtherApps: true)
        for panel in panels {
            panel.makeKeyAndOrderFront(nil)
            panel.orderFrontRegardless()
            panel.animator().alphaValue = 1
        }

        if let key = panels.first(where: { $0.isKeyWindow }) ?? panels.first {
            key.makeKey()
        }
    }

    func hide() {
        let closing = panels
        panels = []
        for panel in closing {
            panel.animator().alphaValue = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            for panel in closing {
                panel.orderOut(nil)
                panel.contentView = nil
            }
        }
    }

    func hideImmediately() {
        for panel in panels {
            panel.orderOut(nil)
            panel.contentView = nil
        }
        panels = []
    }
}

@MainActor
final class OverlayController {
    private let state: AppState
    private let overlay = ScreenOverlay()
    private var session: BreakSession?
    private var ticker: Timer?
    private var keyMonitor: Any?
    private var completion: ((Bool) -> Void)?

    init(state: AppState) {
        self.state = state
    }

    func startRest(seconds: Int? = nil, completion: ((Bool) -> Void)? = nil) {
        guard !overlay.isShowing else { return }

        let duration = Double(seconds ?? state.breakSeconds)
        let session = BreakSession(total: duration)
        self.session = session
        self.completion = completion
        state.isBreaking = true
        state.pendingReminder = false

        overlay.show({ _ in
            NSHostingView(rootView: BreakScene(session: session))
        }, onKeyDown: { [weak self] in
            self?.finish(completed: false)
        })

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard event.type == .keyDown else { return event }
            self?.finish(completed: false)
            return nil
        }

        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let s = self.session else { return }
            s.remaining = max(0, s.remaining - 0.05)
            if s.remaining <= 0.0001 {
                self.finish(completed: true)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func finish(completed: Bool) {
        ticker?.invalidate()
        ticker = nil
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        overlay.hide()

        let seconds = Int((session?.total ?? 0).rounded())
        session = nil
        state.isBreaking = false

        if completed {
            state.recordBreak(seconds: seconds)
        }

        let cb = completion
        completion = nil
        cb?(completed)
    }

    func forceStop() {
        finish(completed: false)
    }
}
