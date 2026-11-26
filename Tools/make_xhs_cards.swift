import AppKit

// 生成小红书用的 3:4 竖版卡片（1080×1440）
// 用法：swift Tools/make_xhs_cards.swift <输出目录>

let W: CGFloat = 1080
let H: CGFloat = 1440

let bgTop = NSColor(srgbRed: 0.043, green: 0.055, blue: 0.078, alpha: 1)
let bgBottom = NSColor(srgbRed: 0.098, green: 0.114, blue: 0.145, alpha: 1)
let accent = NSColor(srgbRed: 0.42, green: 0.72, blue: 1.0, alpha: 1)

func rounded(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    if let d = base.fontDescriptor.withDesign(.rounded), let f = NSFont(descriptor: d, size: size) { return f }
    return base
}

final class Canvas {
    let rep: NSBitmapImageRep
    let ctx: CGContext

    init() {
        rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        ctx = NSGraphicsContext.current!.cgContext

        let colors = [bgTop.cgColor, bgBottom.cgColor] as CFArray
        let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
        ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: H), end: CGPoint(x: 0, y: 0), options: [])

        // 右上角柔光
        let glowColors = [accent.withAlphaComponent(0.10).cgColor,
                          accent.withAlphaComponent(0.0).cgColor] as CFArray
        let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glowColors, locations: [0, 1])!
        ctx.drawRadialGradient(glow,
                              startCenter: CGPoint(x: W * 0.95, y: H * 0.92), startRadius: 0,
                              endCenter: CGPoint(x: W * 0.95, y: H * 0.92), endRadius: 620,
                              options: [])
    }

    /// topY 是距顶部的距离，行高自动
    func text(_ s: String, font: NSFont, color: NSColor, x: CGFloat, topY: CGFloat,
              width: CGFloat, lineGap: CGFloat = 0, align: NSTextAlignment = .left) {
        let p = NSMutableParagraphStyle()
        p.alignment = align
        p.lineBreakMode = .byWordWrapping
        p.lineSpacing = lineGap
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: p]
        let lineHeight = font.ascender - font.descender + font.leading + lineGap
        let rect = NSRect(x: x, y: H - topY - lineHeight * 4, width: width, height: lineHeight * 4)
        (s as NSString).draw(in: rect, withAttributes: attrs)
    }

    func image(_ path: String, at rect: NSRect) {
        guard let img = NSImage(contentsOfFile: path) else {
            print("missing \(path)")
            return
        }
        img.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
    }

    /// 只取原图的一部分贴进来，用来把全屏截图里的核心区域放大
    func image(_ path: String, from source: NSRect, at rect: NSRect) {
        guard let img = NSImage(contentsOfFile: path) else {
            print("missing \(path)")
            return
        }
        img.draw(in: rect, from: source, operation: .sourceOver, fraction: 1)
    }

    func card(_ rect: NSRect, radius: CGFloat = 28, fill: NSColor = NSColor.white.withAlphaComponent(0.06)) {
        fill.setFill()
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
    }

    func clipCard(_ rect: NSRect, radius: CGFloat, _ body: () -> Void) {
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
        body()
        NSGraphicsContext.restoreGraphicsState()
    }

    func dot(_ center: CGPoint, radius: CGFloat) {
        accent.setFill()
        let path = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: H - center.y - radius,
                                               width: radius * 2, height: radius * 2))
        path.fill()
    }

    func save(_ path: String) {
        NSGraphicsContext.restoreGraphicsState()
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: URL(fileURLWithPath: path))
        print("-> \(path)")
    }

    /// 左上角品牌行
    func brand(_ text: String) {
        self.text(text, font: .systemFont(ofSize: 24, weight: .medium),
                  color: NSColor.white.withAlphaComponent(0.45), x: 88, topY: 74, width: 700)
    }

    /// 底部小字
    func footer(_ text: String) {
        self.text(text, font: .systemFont(ofSize: 22, weight: .regular),
                  color: NSColor.white.withAlphaComponent(0.35), x: 88, topY: H - 92, width: 900)
    }
}

let outDir = CommandLine.arguments.count >= 2 ? CommandLine.arguments[1] : "xhs"
let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().path

// MARK: 1 封面
do {
    let c = Canvas()
    c.brand("Blink · macOS 菜单栏")

    c.text("眼睛累了，", font: rounded(112, .bold), color: .white, x: 88, topY: 250, width: 920)
    c.text("才休息。", font: rounded(112, .bold), color: accent, x: 88, topY: 400, width: 920)

    c.text("全屏模糊 + 四套眼部动作\n不开摄像头，不做眼动追踪，不联网",
           font: .systemFont(ofSize: 34, weight: .regular),
           color: NSColor.white.withAlphaComponent(0.62), x: 88, topY: 560, width: 920, lineGap: 12)

    c.text("免费分享 · 开源 · MIT", font: .systemFont(ofSize: 26, weight: .regular),
           color: accent.withAlphaComponent(0.75), x: 88, topY: 700, width: 920)

    // 面板从底部浮出，底部裁掉
    let panelW: CGFloat = 440
    let panelH: CGFloat = panelW * 1120 / 680
    let rect = NSRect(x: (W - panelW) / 2, y: -80, width: panelW, height: panelH)
    c.card(rect.insetBy(dx: -3, dy: -3), radius: 34, fill: NSColor.black.withAlphaComponent(0.35))
    c.clipCard(rect, radius: 32) {
        c.image("\(repo)/screenshots/panel-training.png", at: rect)
    }

    c.save("\(outDir)/01-cover.png")
}

// MARK: 2 痛点
do {
    let c = Canvas()
    c.brand("为什么大多数提醒没用")

    c.text("20 秒以后，", font: rounded(104, .semibold), color: .white, x: 88, topY: 250, width: 920)
    c.text("你还是同一个姿势", font: rounded(104, .semibold), color: .white, x: 88, topY: 396, width: 920)

    let lines = ["所有休息软件都说「看远处 20 秒」。",
                 "你看完，回头继续盯着同一个角落，",
                 "肩没动、眼没动、焦距没变。"]
    var y: CGFloat = 556
    for line in lines {
        c.text(line, font: .systemFont(ofSize: 36, weight: .regular),
               color: NSColor.white.withAlphaComponent(0.60), x: 88, topY: y, width: 900)
        y += 72
    }

    let imgW: CGFloat = 820
    let imgH: CGFloat = 560
    let rect = NSRect(x: (W - imgW) / 2, y: 118, width: imgW, height: imgH)
    c.card(rect.insetBy(dx: -3, dy: -3), radius: 26, fill: .black)
    c.clipCard(rect, radius: 24) {
        c.image("\(repo)/screenshots/break.png",
                from: NSRect(x: 290, y: 130, width: 700, height: 480),
                at: rect)
    }

    c.footer("Blink 把休息当成要「做」的事，不是要「熬」的时间")
    c.save("\(outDir)/02-problem.png")
}

// MARK: 3 反常识
do {
    let c = Canvas()
    c.brand("一个技术上的坏消息")

    c.text("Mac 上", font: rounded(120, .bold), color: .white, x: 88, topY: 230, width: 920)
    c.text("做不了", font: rounded(120, .bold), color: accent, x: 88, topY: 384, width: 920)
    c.text("眼动追踪", font: rounded(120, .bold), color: accent, x: 88, topY: 538, width: 920)

    let items = [
        ("没有 TrueDepth", "ARKit 的人脸追踪只在 iPhone / iPad 上有，Mac 上根本没有"),
        ("拿不到瞳孔位置", "Vision 只能给眼睑轮廓，你知道脸朝哪，不知道眼睛看哪"),
        ("权限一弹就劝退", "护眼 App 要摄像头权限，第一秒就失去信任")
    ]
    var y: CGFloat = 760
    for (title, sub) in items {
        c.dot(CGPoint(x: 104, y: y + 26), radius: 9)
        c.text(title, font: .systemFont(ofSize: 40, weight: .semibold),
               color: .white, x: 140, topY: y, width: 820)
        c.text(sub, font: .systemFont(ofSize: 28, weight: .regular),
               color: NSColor.white.withAlphaComponent(0.50), x: 140, topY: y + 58, width: 820)
        y += 168
    }

    c.text("所以最后没做追踪，做了一套引导动作。",
           font: .systemFont(ofSize: 34, weight: .medium),
           color: NSColor.white.withAlphaComponent(0.85), x: 88, topY: 1268, width: 900)
    c.footer("Blink · 没有摄像头权限，也不需要")
    c.save("\(outDir)/03-no-eye-tracking.png")
}

// MARK: 4 四套课程
do {
    let c = Canvas()
    c.brand("四套动作，按时段挑")

    c.text("60 到 90 秒，", font: rounded(96, .semibold), color: .white, x: 88, topY: 240, width: 920)
    c.text("画面上没有字要读", font: rounded(96, .semibold), color: .white, x: 88, topY: 380, width: 920)

    let courses = [
        ("屏幕间歇", "跟着光点走，先把视线从中心挪开", "70s"),
        ("晨间唤醒", "刚开机，眼睛还没对上焦，慢一点也行", "60s"),
        ("干眼舒缓", "眨眼、闭眼、绕圈，冲着干涩来的", "90s"),
        ("睡前放松", "闭眼时间最长的一套，配合呼吸", "60s")
    ]
    var y: CGFloat = 560
    for (name, desc, dur) in courses {
        let rect = NSRect(x: 88, y: H - y - 190, width: 904, height: 168)
        c.card(rect, radius: 24)
        c.text(name, font: .systemFont(ofSize: 42, weight: .semibold), color: .white,
               x: 128, topY: y + 34, width: 620)
        c.text(desc, font: .systemFont(ofSize: 26, weight: .regular),
               color: NSColor.white.withAlphaComponent(0.48), x: 128, topY: y + 96, width: 640)
        c.text(dur, font: .monospacedDigitSystemFont(ofSize: 30, weight: .medium),
               color: accent, x: 860, topY: y + 40, width: 110, align: .right)
        y += 196
    }

    c.footer("默认 20 分钟一次休息，时长可自己改")
    c.save("\(outDir)/04-routines.png")
}

// MARK: 5 走开一会儿
do {
    let c = Canvas()
    c.brand("需要离开一会儿")

    c.text("让它假装", font: rounded(104, .semibold), color: .white, x: 88, topY: 230, width: 920)
    c.text("正在更新系统", font: rounded(104, .semibold), color: .white, x: 88, topY: 376, width: 920)

    c.text("训练完点「我要走开」，屏幕切到系统更新界面，\n进度条慢慢走——同事看到不会多问一句。",
           font: .systemFont(ofSize: 32, weight: .regular),
           color: NSColor.white.withAlphaComponent(0.58), x: 88, topY: 530, width: 900, lineGap: 10)

    let imgW: CGFloat = 760
    let imgH: CGFloat = imgW * 800 / 1280
    let rect = NSRect(x: (W - imgW) / 2, y: 1440 - 700 - imgH, width: imgW, height: imgH)
    c.card(rect.insetBy(dx: -3, dy: -3), radius: 26, fill: .black)
    c.clipCard(rect, radius: 24) {
        c.image("\(repo)/screenshots/camouflage.png", at: rect)
    }

    c.text("实心苹果剪影，不带咬口，不是 Apple 商标。",
           font: .systemFont(ofSize: 24, weight: .regular),
           color: NSColor.white.withAlphaComponent(0.35), x: 88, topY: 1216, width: 900)
    c.footer("这个按钮是可选的，不点它也能正常结束训练")
    c.save("\(outDir)/05-step-away.png")
}

// MARK: 6 怎么装
do {
    let c = Canvas()
    c.brand("第一次打开会被拦一下")

    c.text("它没走公证，", font: rounded(96, .semibold), color: .white, x: 88, topY: 240, width: 920)
    c.text("所以会吓你一跳", font: rounded(96, .semibold), color: accent, x: 88, topY: 380, width: 920)

    c.text("没有 Apple 开发者账号，签名是临时的。第一次打开 macOS 会说「已损坏」——不是坏了。",
           font: .systemFont(ofSize: 32, weight: .regular),
           color: NSColor.white.withAlphaComponent(0.58), x: 88, topY: 530, width: 900, lineGap: 10)

    let steps = [
        ("1", "下载 Blink.dmg", "在 GitHub 的 Releases 页面，双击打开"),
        ("2", "拖进「应用程序」", "和普通 App 一样，别在 dmg 里直接运行"),
        ("3", "右键 → 打开", "第一次必须右键打开，以后双击就行")
    ]
    var y: CGFloat = 700
    for (num, title, sub) in steps {
        let rect = NSRect(x: 88, y: H - y - 170, width: 904, height: 150)
        c.card(rect, radius: 24)
        c.text(num, font: .monospacedDigitSystemFont(ofSize: 44, weight: .bold),
               color: accent, x: 128, topY: y + 46, width: 60)
        c.text(title, font: .systemFont(ofSize: 40, weight: .semibold),
               color: .white, x: 200, topY: y + 26, width: 700)
        c.text(sub, font: .systemFont(ofSize: 26, weight: .regular),
               color: NSColor.white.withAlphaComponent(0.48), x: 200, topY: y + 88, width: 700)
        y += 176
    }

    c.text("实在打不开：xattr -cr /Applications/Blink.app",
           font: .monospacedSystemFont(ofSize: 26, weight: .regular),
           color: NSColor.white.withAlphaComponent(0.55), x: 88, topY: 1240, width: 900)
    c.text("只有第一次需要这一步。要 macOS 13 以上。",
           font: .systemFont(ofSize: 26, weight: .regular),
           color: NSColor.white.withAlphaComponent(0.40), x: 88, topY: 1290, width: 900)
    c.footer("Blink · 免费 · github.com/RicardoWesleyli/blink")
    c.save("\(outDir)/06-install.png")
}

print("cards -> \(outDir)")
