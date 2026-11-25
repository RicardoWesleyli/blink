import AppKit
import SwiftUI

struct WelcomeView: View {
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 18)

            EyeMark(size: 42)
                .padding(.bottom, 16)

            Text(L10n.s("Blink 已经在运行", "Blink is running"))
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .padding(.bottom, 8)

            Text(L10n.s("它住在菜单栏右侧，没有 Dock 图标。\n点那只眼睛就能看到计时、休息和眼部训练。",
                      "It lives in the menu bar — no Dock icon.\nClick the eye for the timer, breaks, and eye training."))
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.bottom, 22)

            HStack(spacing: 7) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(red: 0.42, green: 0.72, blue: 1.0))
                Text(L10n.s("在屏幕右上角，靠近时钟的地方", "Top right, near the clock"))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(Color.primary.opacity(0.06))
            )
            .padding(.bottom, 22)

            Button(L10n.s("知道了", "Got it"), action: onClose)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(Color(red: 0.42, green: 0.72, blue: 1.0))

            Spacer(minLength: 18)
        }
        .frame(width: 460, height: 330)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

@MainActor
final class WelcomeWindowController {
    private var window: NSWindow?

    private let seenKey = "blink.welcomeSeen.v1"

    func showIfNeeded() {
        if UserDefaults.standard.bool(forKey: seenKey) { return }
        UserDefaults.standard.set(true, forKey: seenKey)
        show()
    }

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let size = NSSize(width: 460, height: 330)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .fullSizeContentView],
                              backing: .buffered,
                              defer: false)
        window.title = "Blink"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: WelcomeView { [weak self] in
            self?.close()
        })
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window

        DispatchQueue.main.asyncAfter(deadline: .now() + 9) { [weak self] in
            self?.close()
        }
    }

    func close() {
        window?.orderOut(nil)
        window = nil
    }
}
