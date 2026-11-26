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

struct AppleFruitMark: View {
    var size: CGFloat = 52
    var opacity: Double = 0.88

    /// 白色苹果剪影，从资源包加载（不是自绘，也不是 Apple 商标里那个带咬口的标志）
    private static let mark: NSImage? = {
        guard let url = Bundle.module.url(forResource: "apple-mark", withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }()

    var body: some View {
        Group {
            if let mark = Self.mark {
                Image(nsImage: mark)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: size * 1.08, height: size * 1.10)
                    .opacity(opacity)
            }
        }
    }
}

struct CamouflageScene: View {
    @ObservedObject var session: CamouflageSession
    var onExit: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                AppleFruitMark(size: 88)
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
