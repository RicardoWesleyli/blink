import AppKit

// 生成 1600×900 主视觉卡片（README 首屏 / X / 小红书通用）
// 用法：swift Tools/make_x_card.swift screenshots/en/menu.png screenshots/en/x-hero.png en
//       swift Tools/make_x_card.swift screenshots/zh/menu.png screenshots/zh/x-hero.png zh

let W: CGFloat = 1600
let H: CGFloat = 900

func roundedFont(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    if let d = base.fontDescriptor.withDesign(.rounded), let f = NSFont(descriptor: d, size: size) {
        return f
    }
    return base
}

func draw(_ text: String, font: NSFont, color: NSColor, x: CGFloat, topY: CGFloat,
          width: CGFloat, spacing: CGFloat = 0) {
    let p = NSMutableParagraphStyle()
    p.lineBreakMode = .byWordWrapping
    var attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: p
    ]
    if spacing > 0 { attrs[.kern] = spacing }
    let lineHeight = font.ascender - font.descender + font.leading
    let rect = NSRect(x: x, y: H - topY - lineHeight, width: width, height: lineHeight * 1.6)
    (text as NSString).draw(in: rect, withAttributes: attrs)
}

let args = CommandLine.arguments
guard args.count >= 3 else {
    print("usage: make_x_card.swift <panel.png> <out.png>")
    exit(1)
}
let panelPath = args[1]
let outPath = args[2]

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

// 背景：垂直线性渐变
let colors = [
    NSColor(srgbRed: 0.043, green: 0.055, blue: 0.075, alpha: 1).cgColor,
    NSColor(srgbRed: 0.086, green: 0.102, blue: 0.133, alpha: 1).cgColor
] as CFArray
let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: H), options: [])

// 面板背后的柔光
let glowColors = [
    NSColor(srgbRed: 0.42, green: 0.72, blue: 1.0, alpha: 0.16).cgColor,
    NSColor(srgbRed: 0.42, green: 0.72, blue: 1.0, alpha: 0.0).cgColor
] as CFArray
let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glowColors, locations: [0, 1])!
ctx.drawRadialGradient(glow,
                      startCenter: CGPoint(x: 355, y: 450), startRadius: 0,
                      endCenter: CGPoint(x: 355, y: 450), endRadius: 460,
                      options: [])

// 面板截图：高 760，保持比例
guard let panel = NSImage(contentsOfFile: panelPath) else {
    print("cannot load \(panelPath)")
    exit(1)
}
let panelH: CGFloat = 760
let panelW = panelH * panel.size.width / panel.size.height
let px = 130.0
let py = (H - panelH) / 2

// 阴影 + 圆角卡片
let cardRect = NSRect(x: px, y: py, width: panelW, height: panelH)
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.55)
shadow.shadowBlurRadius = 48
shadow.shadowOffset = NSSize(width: 0, height: -14)
shadow.set()
NSColor(srgbRed: 0.11, green: 0.12, blue: 0.15, alpha: 1).setFill()
NSBezierPath(roundedRect: cardRect.insetBy(dx: -1, dy: -1), xRadius: 26, yRadius: 26).fill()
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.saveGraphicsState()
NSBezierPath(roundedRect: cardRect, xRadius: 25, yRadius: 25).addClip()
panel.draw(in: cardRect, from: .zero, operation: .sourceOver, fraction: 1)
NSGraphicsContext.restoreGraphicsState()

// 右侧文案
let lang = args.count >= 4 ? args[3] : "en"
let zh = lang == "zh"

let tx: CGFloat = 640.0
let textW: CGFloat = 900.0

draw("Blink", font: roundedFont(100, .semibold),
     color: .white, x: tx, topY: 250, width: textW, spacing: -1.5)

draw(zh ? "眼睛的休息，就在菜单栏里。" : "Eye breaks in the menu bar.",
     font: roundedFont(zh ? 38 : 34, .medium),
     color: NSColor.white.withAlphaComponent(0.88), x: tx, topY: zh ? 366 : 372, width: textW)

let bullets: [(String, String)] = zh ? [
    ("引导式训练", "四套课程，每套 60–90 秒，跟着光点走"),
    ("全屏模糊休息", "屏幕柔和暗下，不是弹一个窗"),
    ("不碰摄像头，不联网", "全程零网络请求，数据只在本机")
] : [
    ("Guided routines", "Four routines, 60–90 seconds each"),
    ("Blurred full-screen break", "The screen goes soft, not a popup"),
    ("No camera, no telemetry", "It never opens a network connection")
]
var y: CGFloat = 462
for (title, sub) in bullets {
    draw(title, font: .systemFont(ofSize: zh ? 27 : 25, weight: .medium),
         color: NSColor.white.withAlphaComponent(0.92), x: tx, topY: y, width: textW)
    draw(sub, font: .systemFont(ofSize: 18, weight: .regular),
         color: NSColor.white.withAlphaComponent(0.42), x: tx, topY: y + 38, width: textW)
    y += 96
}

// 底栏标签
draw(zh ? "MIT 开源   ·   macOS 13+   ·   中 / 英 双语   ·   免费" : "MIT licensed   ·   macOS 13+   ·   English / 中文   ·   free",
     font: .systemFont(ofSize: 17, weight: .regular),
     color: NSColor.white.withAlphaComponent(0.30), x: tx, topY: 812, width: textW, spacing: 0.4)

NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else { exit(1) }
try! data.write(to: URL(fileURLWithPath: outPath))
print("done -> \(outPath)")
