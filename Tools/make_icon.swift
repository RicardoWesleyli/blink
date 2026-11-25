import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("build/icon.iconset")
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func drawIcon(px: Int) -> Data? {
    let size = CGFloat(px)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    ) else { return nil }
    rep.size = NSSize(width: size, height: size)

    guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let inset = size * 0.075
    let content = rect.insetBy(dx: inset, dy: inset)
    let radius = content.width * 0.2237

    // 底板：纯黑
    let bg = NSBezierPath(roundedRect: content, xRadius: radius, yRadius: radius)
    NSColor.black.setFill()
    bg.fill()

    // 眼睛轮廓
    let cx = content.midX
    let cy = content.midY + content.height * 0.035
    let halfW = content.width * 0.265
    let lid = content.height * 0.112

    let stroke = NSBezierPath()
    stroke.move(to: NSPoint(x: cx - halfW, y: cy))
    stroke.curve(to: NSPoint(x: cx + halfW, y: cy),
                 controlPoint1: NSPoint(x: cx - halfW * 0.40, y: cy + lid * 1.75),
                 controlPoint2: NSPoint(x: cx + halfW * 0.40, y: cy + lid * 1.75))
    stroke.curve(to: NSPoint(x: cx - halfW, y: cy),
                 controlPoint1: NSPoint(x: cx + halfW * 0.40, y: cy - lid * 1.75),
                 controlPoint2: NSPoint(x: cx - halfW * 0.40, y: cy - lid * 1.75))
    stroke.lineWidth = content.width * 0.048
    stroke.lineCapStyle = .round
    NSColor(srgbRed: 0.87, green: 0.93, blue: 1.0, alpha: 1).setStroke()
    stroke.stroke()

    // 瞳孔
    let irisR = content.width * 0.072
    let iris = NSBezierPath(ovalIn: NSRect(x: cx - irisR, y: cy - irisR,
                                           width: irisR * 2, height: irisR * 2))
    NSColor(srgbRed: 0.64, green: 0.84, blue: 1.0, alpha: 1).setFill()
    iris.fill()

    // 高光
    let specR = irisR * 0.52
    let spec = NSBezierPath(ovalIn: NSRect(x: cx - irisR * 0.66, y: cy + irisR * 0.10,
                                           width: specR, height: specR))
    NSColor.white.withAlphaComponent(0.9).setFill()
    spec.fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

let variants: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024)
]

for (name, px) in variants {
    guard let data = drawIcon(px: px) else {
        print("failed: \(name)")
        continue
    }
    try data.write(to: iconset.appendingPathComponent("\(name).png"))
}

print("iconset ready at \(iconset.path)")
