import AppKit
import SwiftUI

/// 把屏幕装成 macOS 正在安装更新。
/// 用户主动点了「我要走开」才出现，给离开电脑一个体面的理由。
/// 刻意做成静态推进：人已经走了，画面上不需要任何抢注意力的动效。
final class CamouflageSession: ObservableObject {
    @Published var progress: Double = 0.12
    @Published var minutesLeft = 19

    /// 每九秒挪一格，永远到不了头——真更新也是这个脾气
    func advance() {
        progress = min(0.93, progress + 0.015)
        minutesLeft = max(4, minutesLeft - 1)
    }
}

/// 一个完整的苹果：没有咬口，也就不是 Apple 的标志。
/// 用一条连续的手绘轮廓，顶部中间下凹（果梗的位置），两侧圆润，底部收拢，
/// 比并集一堆椭圆更容易做出"苹果"的体感。
struct AppleFruitShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height

        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * w, y: rect.minY + y * h)
        }

        p.move(to: pt(0.50, 0.17))
        p.addCurve(to: pt(0.86, 0.40), control1: pt(0.70, 0.11), control2: pt(0.85, 0.23))
        p.addCurve(to: pt(0.92, 0.68), control1: pt(0.96, 0.48), control2: pt(0.98, 0.58))
        p.addCurve(to: pt(0.50, 0.99), control1: pt(0.90, 0.88), control2: pt(0.68, 1.00))
        p.addCurve(to: pt(0.08, 0.68), control1: pt(0.32, 1.00), control2: pt(0.10, 0.88))
        p.addCurve(to: pt(0.14, 0.40), control1: pt(0.02, 0.58), control2: pt(0.04, 0.48))
        p.addCurve(to: pt(0.50, 0.17), control1: pt(0.15, 0.23), control2: pt(0.30, 0.11))
        return p
    }
}

/// 一片两头尖的叶子，比椭圆更像叶，不会堆成菠萝冠。
struct AppleLeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        p.move(to: pt(0.02, 0.55))
        p.addQuadCurve(to: pt(0.98, 0.08), control: pt(0.34, -0.04))
        p.addQuadCurve(to: pt(0.02, 0.55), control: pt(0.42, 0.78))
        return p
    }
}

struct AppleFruitMark: View {
    var size: CGFloat = 52
    var tint: Color = Color.white.opacity(0.88)

    var body: some View {
        ZStack {
            AppleFruitShape()
                .fill(tint)
                .frame(width: size * 0.96, height: size * 1.02)
                .offset(y: size * 0.12)

            // 梗
            Capsule()
                .fill(tint)
                .frame(width: size * 0.058, height: size * 0.20)
                .rotationEffect(.degrees(10))
                .offset(x: size * 0.02, y: -size * 0.315)

            // 叶
            AppleLeafShape()
                .fill(tint)
                .frame(width: size * 0.50, height: size * 0.22)
                .rotationEffect(.degrees(-22))
                .offset(x: size * 0.225, y: -size * 0.36)
        }
        .frame(width: size * 1.1, height: size * 1.45)
    }
}

struct CamouflageScene: View {
    @ObservedObject var session: CamouflageSession
    var onExit: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                AppleFruitMark(size: 78)
                    .padding(.bottom, 30)

                Text(L10n.s("正在安装系统更新…", "Installing system update…"))
                    .font(.system(size: 15))
                    .foregroundStyle(Color.white.opacity(0.90))
                    .padding(.bottom, 24)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.12))
                        Capsule().fill(Color.white.opacity(0.70))
                            .frame(width: max(2, geo.size.width * session.progress))
                            .animation(.linear(duration: 9), value: session.progress)
                    }
                }
                .frame(width: 300, height: 5)

                Text(L10n.s("大约还有 \(session.minutesLeft) 分钟",
                                      "About \(session.minutesLeft) minutes remaining"))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .padding(.top, 18)
            }
            .offset(y: -24)

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text(L10n.s("Blink · 点任意处返回", "Blink · click anywhere to return"))
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.18))
                        .padding(22)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onExit() }
    }
}

@MainActor
final class CamouflageController {
    private let overlay = ScreenOverlay()
    private var keyMonitor: Any?
    private var progressTimer: Timer?
    private var autoEndTimer: Timer?
    private var onEnd: (() -> Void)?

    var isShowing: Bool { overlay.isShowing }

    func show(onEnd: (() -> Void)? = nil) {
        guard !overlay.isShowing else { return }
        let session = CamouflageSession()
        self.onEnd = onEnd

        overlay.show({ _ in
            NSHostingView(rootView: CamouflageScene(session: session, onExit: { [weak self] in
                self?.hide()
            }))
        }, onKeyDown: { [weak self] in
            self?.hide()
        })

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] _ in
            self?.hide()
            return nil
        }

        let ticker = Timer(timeInterval: 9, repeats: true) { _ in
            session.advance()
        }
        RunLoop.main.add(ticker, forMode: .common)
        progressTimer = ticker

        // 兜底：用户忘了自己开着这个，第二天看到还在更新就麻烦了
        let autoEnd = Timer(timeInterval: 180, repeats: false) { [weak self] _ in
            self?.hide()
        }
        RunLoop.main.add(autoEnd, forMode: .common)
        autoEndTimer = autoEnd
    }

    func hide() {
        guard overlay.isShowing else { return }
        progressTimer?.invalidate()
        progressTimer = nil
        autoEndTimer?.invalidate()
        autoEndTimer = nil
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        overlay.hide()

        let callback = onEnd
        onEnd = nil
        callback?()
    }
}
