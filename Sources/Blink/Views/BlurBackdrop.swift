import SwiftUI
import AppKit

/// 系统级高斯模糊底。
/// 用 NSVisualEffectView 的 `behindWindow` 混合模式，让系统直接把窗口后面的
/// 桌面/应用内容做实时模糊，不需要截屏、不需要屏幕录制权限。
struct BlurBackdrop: NSViewRepresentable {
    /// .hudWindow 是唯一能在 screenSaver 层级上真实采样窗口背后内容的材质，
    /// .fullScreenUI 在该层级下只会画一层不透明的灰。
    var material: NSVisualEffectView.Material = .hudWindow
    var darkening: Double = 0.0

    func makeNSView(context: Context) -> NSView {
        // 离屏渲染时窗口背后没有内容可采样，系统会把材质画成一块不透明的灰。
        // 快照模式直接给一个透明空视图，让下面的纯黑露出来，避免整张图蒙一层灰。
        if ProcessInfo.processInfo.environment["BLINK_SNAPSHOT"] == "1" {
            return NSView()
        }

        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = false
        view.autoresizingMask = [.width, .height]
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        guard let effect = view as? NSVisualEffectView else { return }
        effect.material = material
        effect.blendingMode = .behindWindow
        effect.state = .active
    }
}

/// 全屏场景的统一背景：模糊桌面 + 暗罩。
/// 最底下垫一层纯黑，万一外观视图在极高窗口层级不生效，会退化成原来的纯黑，
/// 不会出现透明白屏或白字看不清。
struct ScrimBackground: View {
    /// 暗罩强度，越大越接近纯黑，越小越能看出背后的模糊轮廓
    var darkness: Double = 0.62

    var body: some View {
        ZStack {
            Color.black
            BlurBackdrop()
            Color.black.opacity(darkness)
        }
        .ignoresSafeArea()
    }
}
