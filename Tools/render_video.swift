import AppKit
import AVFoundation
import CoreVideo

// 把 Blink 的两个全屏界面按真实动画逐帧画出来，编码成 mp4。
// 用法：swift Tools/render_video.swift train|break <输出路径>

let W: CGFloat = 1280
let H: CGFloat = 800
let FPS = 30

let accent = NSColor(srgbRed: 0.42, green: 0.72, blue: 1.0, alpha: 1)

func roundedFont(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    if let descriptor = base.fontDescriptor.withDesign(.rounded),
       let font = NSFont(descriptor: descriptor, size: size) {
        return font
    }
    return base
}

func monoFont(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
    NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
}

/// 以「距离顶部 topY」的语义画一行居中文字
func drawText(_ text: String,
              font: NSFont,
              color: NSColor,
              centerX: CGFloat = W / 2,
              topY: CGFloat,
              width: CGFloat = 1200) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]
    let lineHeight = font.ascender - font.descender + font.leading
    let rect = NSRect(x: centerX - width / 2,
                      y: H - topY - lineHeight,
                      width: width,
                      height: lineHeight)
    (text as NSString).draw(in: rect, withAttributes: attrs)
}

// MARK: - 眼部训练

struct Stage {
    let title: String
    let hint: String
    let duration: Double
}

// 语言开关：第四个参数传 en 则输出英文版
let isEN = CommandLine.arguments.count >= 4 && CommandLine.arguments[3] == "en"

let stages = isEN ? [
    Stage(title: "Follow the dot", hint: "Move your eyes, keep your head still", duration: 24),
    Stage(title: "Go around", hint: "Let your gaze travel slowly around the circle", duration: 18),
    Stage(title: "Far, then near", hint: "Hold the center, feel the focus shift", duration: 16),
    Stage(title: "Just close them", hint: "Close your eyes, nothing to do", duration: 12)
] : [
    Stage(title: "跟随移动", hint: "眼睛跟着光点走，头保持不动", duration: 24),
    Stage(title: "环绕放松", hint: "让视线绕着圈慢慢转，不用追速度", duration: 18),
    Stage(title: "远近交替", hint: "盯住中心，感受焦距在远近之间切换", duration: 16),
    Stage(title: "闭眼歇一会", hint: "轻轻闭上眼睛，什么都不用做", duration: 12)
]

let totalDuration = stages.reduce(0) { $0 + $1.duration }

func stageIndex(at t: Double, short: Bool = false) -> (index: Int, elapsed: Double, overall: Double) {
    if short {
        let perStage = 6.0
        let total = perStage * Double(stages.count)
        let i = min(stages.count - 1, Int(t / perStage))
        return (i, t - Double(i) * perStage, min(1, t / total))
    }
    var acc = 0.0
    for (i, s) in stages.enumerated() {
        if t < acc + s.duration {
            return (i, t - acc, min(1, t / totalDuration))
        }
        acc += s.duration
    }
    let last = stages.count - 1
    return (last, stages[last].duration, 1)
}

func followPoint(_ t: Double, center: CGPoint, radius: CGFloat) -> CGPoint {
    let slots: [(CGFloat, CGFloat)] = [
        (0, -1), (1, -1), (1, 0), (1, 1),
        (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, 0)
    ]
    let cycle = 2.6
    let index = Int(t / cycle) % slots.count
    let next = (index + 1) % slots.count
    let local = (t / cycle).truncatingRemainder(dividingBy: 1.0)

    let moveStart = 0.60
    let raw: Double = local < moveStart ? 0 : (local - moveStart) / (1 - moveStart)
    let eased = raw * raw * (3 - 2 * raw)

    let a = slots[index]
    let b = slots[next]
    return CGPoint(x: center.x + (a.0 + (b.0 - a.0) * CGFloat(eased)) * radius,
                   y: center.y + (a.1 + (b.1 - a.1) * CGFloat(eased)) * radius * 0.60)
}

func circlePoint(_ t: Double, center: CGPoint, radius: CGFloat) -> CGPoint {
    let angle = t / 7.0 * 2 * Double.pi - Double.pi / 2
    return CGPoint(x: center.x + cos(angle) * radius * 1.05,
                   y: center.y + sin(angle) * radius * 0.62)
}

func fillCircle(_ ctx: CGContext, center: CGPoint, radius: CGFloat, color: NSColor) {
    ctx.setFillColor(color.cgColor)
    ctx.fillEllipse(in: CGRect(x: center.x - radius, y: H - center.y - radius,
                               width: radius * 2, height: radius * 2))
}

func strokeCircle(_ ctx: CGContext, center: CGPoint, radius: CGFloat,
                  color: NSColor, lineWidth: CGFloat) {
    ctx.setStrokeColor(color.cgColor)
    ctx.setLineWidth(lineWidth)
    ctx.strokeEllipse(in: CGRect(x: center.x - radius, y: H - center.y - radius,
                                 width: radius * 2, height: radius * 2))
}

func drawTrainingDot(_ ctx: CGContext, at point: CGPoint, scale: CGFloat) {
    fillCircle(ctx, center: point, radius: 34 * scale, color: accent.withAlphaComponent(0.14))
    strokeCircle(ctx, center: point, radius: 21 * scale, color: accent.withAlphaComponent(0.30), lineWidth: 1)
    fillCircle(ctx, center: point, radius: 6.5 * scale, color: accent)
}

func drawTrainingFrame(_ ctx: CGContext, t: Double, short: Bool = false) {
    // 背景
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))

    let (index, elapsed, overall) = stageIndex(at: t, short: short)
    let stage = stages[index]
    let center = CGPoint(x: W / 2, y: H * 0.53)
    let radius = min(W, H) * 0.30

    // 注视目标
    switch index {
    case 0:
        drawTrainingDot(ctx, at: followPoint(elapsed, center: center, radius: radius), scale: 1)
    case 1:
        drawTrainingDot(ctx, at: circlePoint(elapsed, center: center, radius: radius), scale: 1)
    case 2:
        let phase = sin(elapsed / 2.4 * 2 * Double.pi)
        let scale = 0.42 + 0.58 * CGFloat(0.5 + 0.5 * phase)
        drawTrainingDot(ctx, at: center, scale: scale)
    default:
        let breath = 1.0 + 0.06 * CGFloat(sin(elapsed / 3.0 * 2 * Double.pi))
        strokeCircle(ctx, center: center, radius: 60 * breath,
                     color: accent.withAlphaComponent(0.22), lineWidth: 1.4)
    }

    // 顶部进度点
    let dotY: CGFloat = 98
    let widths: [CGFloat] = (0..<stages.count).map { index == $0 ? 20 : 6 }
    let gap: CGFloat = 6
    let totalWidth = widths.reduce(0, +) + gap * CGFloat(stages.count - 1)
    var x = (W - totalWidth) / 2
    for i in 0..<stages.count {
        let alpha: CGFloat = i == index ? 1.0 : (i < index ? 0.30 : 0.12)
        ctx.setFillColor((i == index ? accent : NSColor.white).withAlphaComponent(alpha).cgColor)
        let rect = CGRect(x: x, y: H - dotY - 2, width: widths[i], height: 4)
        let path = CGPath(roundedRect: rect, cornerWidth: 2, cornerHeight: 2, transform: nil)
        ctx.addPath(path)
        ctx.fillPath()
        x += widths[i] + gap
    }

    drawText(stage.title, font: roundedFont(22, .medium),
             color: NSColor.white.withAlphaComponent(0.92), topY: 132)
    drawText(stage.hint, font: .systemFont(ofSize: 12.5),
             color: NSColor.white.withAlphaComponent(0.42), topY: 164)

    // 底部总进度
    let barWidth: CGFloat = 240
    let barY: CGFloat = 690
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.12).cgColor)
    ctx.fill(CGRect(x: (W - barWidth) / 2, y: H - barY - 3, width: barWidth, height: 3))
    ctx.setFillColor(accent.cgColor)
    ctx.fill(CGRect(x: (W - barWidth) / 2, y: H - barY - 3,
                    width: barWidth * CGFloat(overall), height: 3))

    let remaining = Int(ceil(stage.duration - elapsed))
    let counter = isEN
        ? "\(remaining)s · \(index + 1) of \(stages.count)"
        : "\(remaining) 秒 · 第 \(index + 1) / \(stages.count) 段"
    drawText(counter,
             font: monoFont(12, .medium),
             color: NSColor.white.withAlphaComponent(0.55), topY: 704)

    drawText(isEN ? "Press Esc to finish" : "按 Esc 结束", font: .systemFont(ofSize: 11),
             color: NSColor.white.withAlphaComponent(0.26), topY: 758)
}

// MARK: - 休息倒计时

func drawBreakFrame(_ ctx: CGContext, t: Double, total: Double) {
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))

    let remaining = max(0, total - t)
    let progress = total <= 0 ? 1 : remaining / total

    let ringCenter = CGPoint(x: W / 2, y: H * 0.46 - 40)
    let ringRadius: CGFloat = 104

    strokeCircle(ctx, center: ringCenter, radius: ringRadius,
                 color: NSColor.white.withAlphaComponent(0.12), lineWidth: 1.4)

    // 从左数，顺时针，从 12 点方向开始
    ctx.setStrokeColor(accent.cgColor)
    ctx.setLineWidth(2.6)
    ctx.setLineCap(.round)
    let startAngle = CGFloat.pi / 2
    let endAngle = startAngle - CGFloat(2 * Double.pi) * CGFloat(progress)
    ctx.addArc(center: CGPoint(x: ringCenter.x, y: H - ringCenter.y),
               radius: ringRadius,
               startAngle: startAngle,
               endAngle: endAngle,
               clockwise: true)
    ctx.strokePath()

    drawText("\(Int(ceil(remaining)))", font: roundedFont(52, .light),
             color: NSColor.white.withAlphaComponent(0.94), topY: ringCenter.y - 40)
    if !isEN {
        drawText("秒", font: .systemFont(ofSize: 10),
                 color: NSColor.white.withAlphaComponent(0.34), topY: ringCenter.y + 28)
    }

    drawText(isEN ? "Look 20 feet away" : "望向 6 米以外", font: roundedFont(25, .medium),
             color: NSColor.white.withAlphaComponent(0.92), topY: ringCenter.y + 140)
    drawText(isEN ? "Let your ciliary muscle relax. Stop looking at the screen." : "让睫状肌松开，这一刻不用看屏幕",
             font: .systemFont(ofSize: 13),
             color: NSColor.white.withAlphaComponent(0.42), topY: ringCenter.y + 180)

    drawText(isEN ? "Press any key to end the break" : "按任意键 结束休息",
             font: .systemFont(ofSize: 11),
             color: NSColor.white.withAlphaComponent(0.30), topY: H - 38)
}

// MARK: - 编码

func renderVideo(to url: URL, seconds: Double, draw: (CGContext, Double) -> Void) throws {
    try? FileManager.default.removeItem(at: url)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                           withIntermediateDirectories: true)

    let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
    let settings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: Int(W),
        AVVideoHeightKey: Int(H),
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: 5_000_000,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            AVVideoMaxKeyFrameIntervalKey: 60
        ]
    ]
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
    input.expectsMediaDataInRealTime = false

    let attributes: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: Int(W),
        kCVPixelBufferHeightKey as String: Int(H),
        kCVPixelBufferCGImageCompatibilityKey as String: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
    ]
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input,
                                                      sourcePixelBufferAttributes: attributes)
    writer.add(input)
    writer.startWriting()
    writer.startSession(atSourceTime: .zero)

    let totalFrames = Int(seconds * Double(FPS))
    for frame in 0..<totalFrames {
        while !input.isReadyForMoreMediaData {
            usleep(2000)
        }
        guard let pool = adaptor.pixelBufferPool else { break }
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
        guard let pixelBuffer = buffer else { break }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        if let ctx = CGContext(data: CVPixelBufferGetBaseAddress(pixelBuffer),
                               width: Int(W), height: Int(H),
                               bitsPerComponent: 8,
                               bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                               space: CGColorSpaceCreateDeviceRGB(),
                               bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                                   | CGBitmapInfo.byteOrder32Little.rawValue) {

            let ns = NSGraphicsContext(cgContext: ctx, flipped: false)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = ns
            ctx.setShouldAntialias(true)
            draw(ctx, Double(frame) / Double(FPS))
            NSGraphicsContext.restoreGraphicsState()
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

        adaptor.append(pixelBuffer, withPresentationTime: CMTime(value: Int64(frame),
                                                                 timescale: Int32(FPS)))
    }

    input.markAsFinished()
    let semaphore = DispatchSemaphore(value: 0)
    writer.finishWriting { semaphore.signal() }
    semaphore.wait()
    if writer.status != .completed {
        throw NSError(domain: "render", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: writer.error?.localizedDescription ?? "encode failed"])
    }
}

// MARK: - 入口

let args = CommandLine.arguments
guard args.count >= 3 else {
    print("usage: render_video.swift train|break <output.mp4>")
    exit(1)
}
let mode = args[1]
let output = URL(fileURLWithPath: args[2])

let started = Date()
switch mode {
case "train":
    try renderVideo(to: output, seconds: totalDuration) { ctx, t in
        drawTrainingFrame(ctx, t: t)
    }
case "train-short":
    try renderVideo(to: output, seconds: 6.0 * Double(stages.count)) { ctx, t in
        drawTrainingFrame(ctx, t: t, short: true)
    }
case "break":
    try renderVideo(to: output, seconds: 30) { ctx, t in
        drawBreakFrame(ctx, t: t, total: 30)
    }
default:
    print("unknown mode")
    exit(1)
}
print("done -> \(output.path) in \(String(format: "%.1f", Date().timeIntervalSince(started)))s")
