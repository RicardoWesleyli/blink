import AppKit

/// 菜单栏那只眼睛。用 NSBezierPath 手绘，走 template image 通道，
/// 系统会自动处理深色/浅色模式和强调色。
enum EyeIcon {
    static func statusBar(height: CGFloat = 18) -> NSImage {
        let width = height * 1.16
        let img = NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
            let cx = rect.midX
            let cy = rect.midY
            let halfW = rect.width * 0.42
            let lid = rect.height * 0.30

            let outline = NSBezierPath()
            outline.move(to: NSPoint(x: cx - halfW, y: cy))
            outline.curve(to: NSPoint(x: cx + halfW, y: cy),
                          controlPoint1: NSPoint(x: cx - halfW * 0.42, y: cy + lid * 1.62),
                          controlPoint2: NSPoint(x: cx + halfW * 0.42, y: cy + lid * 1.62))
            outline.curve(to: NSPoint(x: cx - halfW, y: cy),
                          controlPoint1: NSPoint(x: cx + halfW * 0.42, y: cy - lid * 1.62),
                          controlPoint2: NSPoint(x: cx - halfW * 0.42, y: cy - lid * 1.62))
            outline.lineWidth = max(1.2, height * 0.085)
            outline.lineCapStyle = .round
            NSColor.black.setStroke()
            outline.stroke()

            let irisRadius = rect.height * 0.155
            let iris = NSBezierPath(ovalIn: NSRect(x: cx - irisRadius,
                                                   y: cy - irisRadius,
                                                   width: irisRadius * 2,
                                                   height: irisRadius * 2))
            NSColor.black.setFill()
            iris.fill()

            return true
        }
        img.isTemplate = true
        return img
    }

    /// 用于 App 图标的彩色版本（非 template）。
    static func appIcon(size: CGFloat) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let radius = size * 0.2237

            // 底：深靛蓝到近黑的斜向渐变
            let bgPath = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.045, dy: size * 0.045),
                                      xRadius: radius, yRadius: radius)
            let gradient = NSGradient(colors: [
                NSColor(srgbRed: 0.10, green: 0.16, blue: 0.30, alpha: 1),
                NSColor(srgbRed: 0.03, green: 0.05, blue: 0.10, alpha: 1)
            ])
            gradient?.draw(in: bgPath, angle: -90)

            // 顶部柔光
            let glowRect = NSRect(x: rect.midX - size * 0.34, y: rect.midY - size * 0.10,
                                  width: size * 0.68, height: size * 0.62)
            let glow = NSGradient(colors: [
                NSColor(srgbRed: 0.38, green: 0.66, blue: 1.0, alpha: 0.55),
                NSColor(srgbRed: 0.38, green: 0.66, blue: 1.0, alpha: 0.0)
            ])
            glow?.draw(in: NSBezierPath(ovalIn: glowRect), relativeCenterPosition: .zero)

            // 眼睛轮廓
            let cx = rect.midX
            let cy = rect.midY - size * 0.01
            let halfW = size * 0.265
            let lid = size * 0.115

            let stroke = NSBezierPath()
            stroke.move(to: NSPoint(x: cx - halfW, y: cy))
            stroke.curve(to: NSPoint(x: cx + halfW, y: cy),
                         controlPoint1: NSPoint(x: cx - halfW * 0.40, y: cy + lid * 1.75),
                         controlPoint2: NSPoint(x: cx + halfW * 0.40, y: cy + lid * 1.75))
            stroke.curve(to: NSPoint(x: cx - halfW, y: cy),
                         controlPoint1: NSPoint(x: cx + halfW * 0.40, y: cy - lid * 1.75),
                         controlPoint2: NSPoint(x: cx - halfW * 0.40, y: cy - lid * 1.75))
            stroke.lineWidth = size * 0.052
            stroke.lineCapStyle = .round
            NSColor(srgbRed: 0.86, green: 0.92, blue: 1.0, alpha: 1).setStroke()
            stroke.stroke()

            // 瞳孔
            let irisR = size * 0.072
            let iris = NSBezierPath(ovalIn: NSRect(x: cx - irisR, y: cy - irisR,
                                                   width: irisR * 2, height: irisR * 2))
            NSColor(srgbRed: 0.72, green: 0.88, blue: 1.0, alpha: 1).setFill()
            iris.fill()

            // 高光
            let spec = NSBezierPath(ovalIn: NSRect(x: cx - irisR * 0.75, y: cy + irisR * 0.15,
                                                   width: irisR * 0.55, height: irisR * 0.55))
            NSColor.white.withAlphaComponent(0.85).setFill()
            spec.fill()

            return true
        }
    }
}
