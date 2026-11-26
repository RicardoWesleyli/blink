import AVFoundation
import AppKit
import ImageIO
import UniformTypeIdentifiers

// 从 mp4 抽帧生成 README 用的循环 GIF
// 用法：swift Tools/make_gif.swift <in.mp4> <out.gif> [width] [fps]

let args = CommandLine.arguments
guard args.count >= 3 else {
    print("usage: make_gif.swift <in.mp4> <out.gif> [width=720] [fps=12]")
    exit(1)
}

let inPath = args[1]
let outPath = args[2]
let targetW = args.count >= 4 ? Double(args[3]) ?? 720 : 720
let fps = args.count >= 5 ? Double(args[4]) ?? 12 : 12

let asset = AVURLAsset(url: URL(fileURLWithPath: inPath))
let natural = asset.tracks(withMediaType: .video).first?.naturalSize ?? CGSize(width: 1280, height: 800)
let targetH = (targetW * natural.height / natural.width).rounded()

let gen = AVAssetImageGenerator(asset: asset)
gen.appliesPreferredTrackTransform = true
gen.requestedTimeToleranceBefore = .zero
gen.requestedTimeToleranceAfter = .zero
gen.maximumSize = CGSize(width: targetW, height: targetH)

// 24 秒的训练视频分四段，每段取前 2.75 秒，拼成 11 秒的循环
let stageDuration = 6.0
let slice = 2.75
var times: [Double] = []
for stage in 0..<4 {
    let start = Double(stage) * stageDuration
    let steps = Int(slice * fps)
    for s in 0..<steps {
        times.append(start + Double(s) / fps)
    }
}

var frames: [CGImage] = []
for t in times {
    do {
        let img = try gen.copyCGImage(at: CMTime(seconds: t, preferredTimescale: 600), actualTime: nil)
        frames.append(img)
    } catch {
        print("frame at \(t) failed: \(error)")
    }
}
print("captured \(frames.count) frames, \(Int(targetW))x\(Int(targetH))")

try? FileManager.default.removeItem(at: URL(fileURLWithPath: outPath))
guard let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: outPath) as CFURL,
                                                 UTType.gif.identifier as CFString,
                                                 frames.count, nil) else {
    print("cannot create gif destination")
    exit(1)
}

let fileProps: [CFString: Any] = [
    kCGImagePropertyGIFDictionary: [
        kCGImagePropertyGIFLoopCount: 0
    ]
]
CGImageDestinationSetProperties(dest, fileProps as CFDictionary)

let frameProps: [CFString: Any] = [
    kCGImagePropertyGIFDictionary: [
        kCGImagePropertyGIFDelayTime: 1.0 / fps
    ]
]
for img in frames {
    CGImageDestinationAddImage(dest, img, frameProps as CFDictionary)
}

guard CGImageDestinationFinalize(dest) else {
    print("finalize failed")
    exit(1)
}

let bytes = (try? FileManager.default.attributesOfItem(atPath: outPath)[.size] as? Int) ?? 0
print("done -> \(outPath) \(Int(bytes ?? 0) / 1024) KB")
