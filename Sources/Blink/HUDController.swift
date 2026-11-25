import AppKit
import SwiftUI

struct ReminderCard: View {
    let dark: Bool
    let onRest: () -> Void
    let onLater: () -> Void

    private var primary: Color { dark ? Color(white: 0.94) : Color(white: 0.09) }
    private var secondary: Color { dark ? Color(white: 0.56) : Color(white: 0.42) }
    private var surface: Color { dark ? Color(white: 0.115) : Color(white: 0.99) }
    private var hairline: Color {
        dark ? Color.white.opacity(0.10) : Color.black.opacity(0.10)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            EyeMark(size: 22)

            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.s("该让眼睛歇一下了", "Time for your eyes"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(primary)
                Text(L10n.s("已经连续用眼一阵子，望向 6 米外，让睫状肌松开。",
                             "You've been at it a while. Look 20 feet out and let your eyes loosen."))
                    .font(.system(size: 11))
                    .foregroundStyle(secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(1)
                HStack(spacing: 8) {
                    Button(L10n.s("现在休息", "Rest now"), action: onRest)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    Button(L10n.s("稍后", "Later"), action: onLater)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(hairline, lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(dark ? 0.45 : 0.18), radius: 18, x: 0, y: 8)
        .padding(6)
    }
}

/// 预告卡片的倒计时状态，交给 SwiftUI 绑定
final class PreAlertModel: ObservableObject {
    @Published var seconds: Int
    init(seconds: Int) { self.seconds = seconds }
}

/// 开始前 10 秒的预告：给用户一个反应窗口，避免全屏突然盖上来
struct PreAlertCard: View {
    let dark: Bool
    @ObservedObject var model: PreAlertModel
    let title: String
    let subtitle: String
    let onStart: () -> Void
    let onLater: () -> Void

    private let accent = Color(red: 0.42, green: 0.72, blue: 1.0)
    private var primary: Color { dark ? Color(white: 0.94) : Color(white: 0.09) }
    private var secondary: Color { dark ? Color(white: 0.56) : Color(white: 0.42) }
    private var surface: Color { dark ? Color(white: 0.115) : Color(white: 0.99) }
    private var hairline: Color {
        dark ? Color.white.opacity(0.10) : Color.black.opacity(0.10)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.13))
                    .frame(width: 36, height: 36)
                Text("\(max(0, model.seconds))")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(primary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(1)
                HStack(spacing: 8) {
                    Button(L10n.s("现在开始", "Start now"), action: onStart)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    Button(L10n.s("稍后", "Later"), action: onLater)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(hairline, lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(dark ? 0.45 : 0.18), radius: 18, x: 0, y: 8)
        .padding(6)
    }
}

/// 从菜单栏图标正下方升起的轻提醒。
/// 不用 NSPopover：它的 vibrancy 材质会跟着窗口是否 key 重新渲染，
/// 应用在后台时会先显示成浅色，点一下才变深。这里自绘卡片，
/// 颜色在弹出那一刻按系统外观定好，之后不再变。
@MainActor
final class HUDController {
    private var panel: NSPanel?
    private var timer: Timer?

    func show(anchor: NSStatusBarButton?,
              onRest: @escaping () -> Void,
              onLater: @escaping () -> Void) {
        dismiss()

        let appearance = NSApp.effectiveAppearance
        let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        let card = ReminderCard(
            dark: dark,
            onRest: { [weak self] in
                self?.dismiss()
                onRest()
            },
            onLater: { [weak self] in
                self?.dismiss()
                onLater()
            }
        )

        let width: CGFloat = 336
        let host = NSHostingView(rootView: card)
        host.frame = NSRect(x: 0, y: 0, width: width, height: 200)
        host.appearance = appearance
        host.layoutSubtreeIfNeeded()

        // 量不到合理高度就退回固定值，避免被压成一条线
        let measured = host.fittingSize.height
        let height: CGFloat = (measured >= 80 && measured <= 240) ? measured : 132
        let size = NSSize(width: width, height: height)
        host.frame = NSRect(origin: .zero, size: size)

        let origin = originFor(anchor: anchor, size: size)

        let panel = NSPanel(contentRect: NSRect(origin: origin, size: size),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered,
                            defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.appearance = appearance
        panel.contentView = host

        panel.alphaValue = 0
        panel.setFrameOrigin(NSPoint(x: origin.x, y: origin.y + 8))
        panel.orderFrontRegardless()
        panel.animator().alphaValue = 1
        panel.animator().setFrameOrigin(origin)
        self.panel = panel

        let t = Timer(timeInterval: 14, repeats: false) { [weak self] _ in
            self?.dismiss()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// 开始前的 10 秒预告，倒计时归零自动开始
    func showPre(anchor: NSStatusBarButton?,
                 seconds: Int,
                 title: String,
                 subtitle: String,
                 onStart: @escaping () -> Void,
                 onLater: @escaping () -> Void) {
        dismiss()

        let appearance = NSApp.effectiveAppearance
        let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let model = PreAlertModel(seconds: seconds)

        let card = PreAlertCard(
            dark: dark,
            model: model,
            title: title,
            subtitle: subtitle,
            onStart: { [weak self] in
                self?.dismiss()
                onStart()
            },
            onLater: { [weak self] in
                self?.dismiss()
                onLater()
            }
        )

        let width: CGFloat = 336
        let host = NSHostingView(rootView: card)
        host.frame = NSRect(x: 0, y: 0, width: width, height: 118)
        host.appearance = appearance
        host.layoutSubtreeIfNeeded()

        let measured = host.fittingSize.height
        let height: CGFloat = (measured >= 80 && measured <= 200) ? measured : 118
        let size = NSSize(width: width, height: height)
        host.frame = NSRect(origin: .zero, size: size)

        let origin = originFor(anchor: anchor, size: size)

        let panel = NSPanel(contentRect: NSRect(origin: origin, size: size),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered,
                            defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.appearance = appearance
        panel.contentView = host

        panel.alphaValue = 0
        panel.setFrameOrigin(NSPoint(x: origin.x, y: origin.y + 8))
        panel.orderFrontRegardless()
        panel.animator().alphaValue = 1
        panel.animator().setFrameOrigin(origin)
        self.panel = panel

        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            model.seconds -= 1
            if model.seconds <= 0 {
                self.dismiss()
                onStart()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// 卡片顶边贴在菜单栏图标底边下方，水平以图标居中
    private func originFor(anchor: NSStatusBarButton?, size: NSSize) -> NSPoint {
        var anchorRect = NSRect.zero
        if let anchor, let window = anchor.window {
            let inWindow = anchor.convert(anchor.bounds, to: nil)
            anchorRect = window.convertToScreen(inWindow)
        }

        let screen = NSScreen.screens.first { $0.frame.intersects(anchorRect) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else { return .zero }
        let visible = screen.visibleFrame

        var x = visible.maxX - size.width - 16
        var y = visible.maxY - size.height - 8

        if anchorRect.width > 0 {
            x = anchorRect.midX - size.width / 2
            y = anchorRect.minY - size.height - 6
        }

        x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)
        return NSPoint(x: x, y: y)
    }

    func dismiss() {
        timer?.invalidate()
        timer = nil
        guard let panel else { return }
        self.panel = nil
        panel.animator().alphaValue = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            panel.orderOut(nil)
            panel.contentView = nil
        }
    }
}
