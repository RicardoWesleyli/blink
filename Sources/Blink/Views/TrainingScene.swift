import SwiftUI

/// 参考 Blink 的做法：不是数眨眼，而是用移动的注视目标带做眼球体操。
/// Mac 无法可靠做瞳孔追踪，所以改成「视觉引导 + 节奏推进」，
/// 用户用眼睛跟着光点走，不需要盯着屏幕文字。
enum EyeStage: Int, CaseIterable, Identifiable {
    case follow
    case circle
    case focus
    case rest

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .follow: return "跟随移动"
        case .circle: return "环绕放松"
        case .focus:  return "远近交替"
        case .rest:   return "闭眼歇一会"
        }
    }

    var hint: String {
        switch self {
        case .follow: return "眼睛跟着光点走，头保持不动"
        case .circle: return "让视线绕着圈慢慢转，不用追速度"
        case .focus:  return "盯住中心，感受焦距在远近之间切换"
        case .rest:   return "轻轻闭上眼睛，什么都不用做"
        }
    }

    var duration: TimeInterval {
        switch self {
        case .follow: return 24
        case .circle: return 18
        case .focus:  return 16
        case .rest:   return 12
        }
    }
}

final class TrainingSession: ObservableObject {
    let program: TrainingProgram
    let stages: [StageSpec]

    /// 引导页看完、点了开始之后才为 true，此时计时器才推进
    @Published var isStarted = false
    /// 四段走完之后停在完成页，给一次正向反馈再关闭
    @Published var isFinished = false

    @Published var stageIndex = 0
    @Published var stageElapsed: TimeInterval = 0
    @Published var stageStart = Date()

    @Published var finishCount = 0
    @Published var finishWeekText = ""
    @Published var quote = ""

    init(program: TrainingProgram) {
        self.program = program
        self.stages = program.stages
    }

    var current: StageSpec {
        stages[min(max(stageIndex, 0), stages.count - 1)]
    }

    var totalDuration: Double {
        stages.reduce(0) { $0 + $1.seconds }
    }

    var overallProgress: Double {
        guard totalDuration > 0 else { return 0 }
        var done: Double = 0
        for index in 0..<min(stageIndex, stages.count) {
            done += stages[index].seconds
        }
        return min(1, (done + stageElapsed) / totalDuration)
    }

    var stageRemaining: Double {
        max(0, current.seconds - stageElapsed)
    }
}

struct TrainingScene: View {
    @ObservedObject var session: TrainingSession
    var onStart: () -> Void
    /// 训练做完了但还想离开电脑一会儿：把屏幕交给伪装层
    var onLeave: () -> Void = {}

    private let accent = Color(red: 0.42, green: 0.72, blue: 1.0)

    var body: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)
            let center = CGPoint(x: w / 2, y: h * 0.53)
            let radius = min(w, h) * 0.30

            ZStack {
                ScrimBackground()

                if session.isFinished {
                    finishLayer
                        .position(x: w / 2, y: h / 2)
                } else if session.isStarted {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
                        let elapsed = ctx.date.timeIntervalSince(session.stageStart)
                        targetLayer(elapsed: elapsed, center: center, radius: radius)
                    }

                    stageHeader
                        .position(x: w / 2, y: h * 0.16)

                    stageFooter
                        .position(x: w / 2, y: h - 96)

                    Text(L10n.s("按 Esc 结束", "Esc to end"))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.42))
                        .position(x: w / 2, y: h - 38)
                } else {
                    introLayer(h: h)
                        .position(x: w / 2, y: h / 2)

                    Text(L10n.s("按 Esc 取消 · 空格开始", "Esc to cancel · Space to start"))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.42))
                        .position(x: w / 2, y: h - 38)
                }
            }
            .frame(width: w, height: h)
        }
        .ignoresSafeArea()
    }

    // MARK: 完成页

    private var finishLayer: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .stroke(accent.opacity(0.30), lineWidth: 1)
                    .frame(width: 62, height: 62)
                Image(systemName: "checkmark")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(accent)
            }
            .padding(.bottom, 22)

            Text(L10n.s("完成", "Done"))
                .font(.system(size: 27, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.94))

            Text(L10n.s("今天第 \(session.finishCount) 次 · 本周累计 \(session.finishWeekText)",
                  "\(session.finishCount) today · \(session.finishWeekText) this week"))
                .font(.system(size: 12.5))
                .monospacedDigit()
                .foregroundStyle(Color.white.opacity(0.55))
                .padding(.top, 10)

            Text(session.quote)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.76))
                .multilineTextAlignment(.center)
                .frame(width: 460)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 26)

            Button(action: onLeave) {
                Text(L10n.s("我要走开 · 屏幕装成在更新", "I'm stepping away · pretend it's updating"))
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .padding(.horizontal, 15)
                    .frame(height: 28)
                    .background(
                        Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 30)
        }
        .frame(width: 480, height: 366)
    }

    // MARK: 开始前的引导页

    private func introLayer(h: CGFloat) -> some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 62, height: 62)
                Circle()
                    .stroke(accent.opacity(0.26), lineWidth: 1)
                    .frame(width: 62, height: 62)
                Image(systemName: "eye")
                    .font(.system(size: 23, weight: .light))
                    .foregroundStyle(accent)
            }
            .padding(.bottom, 20)

            Text(session.program.title)
                .font(.system(size: 29, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.94))

            Text(L10n.s("\(session.program.subtitle) · 约 \(session.program.minutesHint)",
                        "\(session.program.subtitle) · about \(session.program.minutesHint)"))
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.60))
                .multilineTextAlignment(.center)
                .frame(width: 440)
                .padding(.top, 9)

            VStack(alignment: .leading, spacing: 11) {
                privacyRow(icon: "video.slash",
                           text: L10n.s("不申请摄像头、麦克风或任何硬件权限，不会亮起指示灯",
                                       "No camera, mic, or hardware permissions. No indicator light"))
                privacyRow(icon: "eye.slash",
                           text: L10n.s("不采集眼动、注视点或任何画面，训练只按时间推进",
                                       "No eye tracking, no gaze data, no screen capture. Timing is fixed"))
                privacyRow(icon: "wifi.slash",
                           text: L10n.s("全程离线，不联网、不上传；统计只写在本机",
                                       "Fully offline. Nothing leaves this Mac; stats stay local"))
            }
            .padding(18)
            .frame(width: 452, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .padding(.top, 28)

            Button(action: onStart) {
                Text(L10n.s("开始训练", "Start"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white)
                    .frame(width: 136, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 19, style: .continuous)
                            .fill(accent)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 28)

            Text(L10n.s("数据只存在这台 Mac 上，卸载即清空",
                     "Stored on this Mac. Deleting the app clears it"))
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.40))
                .padding(.top, 12)
        }
        .frame(width: 460, height: 372)
    }

    private func privacyRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(accent.opacity(0.8))
                .frame(width: 16, alignment: .center)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // MARK: 注视目标

    @ViewBuilder
    private func targetLayer(elapsed: Double, center: CGPoint, radius: CGFloat) -> some View {
        switch session.current.kind {
        case .follow:
            dot
                .position(followPoint(elapsed: elapsed, center: center, radius: radius))

        case .circle:
            dot
                .position(circlePoint(elapsed: elapsed, center: center, radius: radius))

        case .focus:
            dot
                .scaleEffect(focusScale(elapsed: elapsed))
                .position(center)

        case .rest:
            Circle()
                .stroke(accent.opacity(0.22), lineWidth: 1.4)
                .frame(width: 120, height: 120)
                .scaleEffect(1.0 + 0.06 * sin(elapsed / 3.0 * 2 * .pi))
                .position(center)
        }
    }

    private var dot: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.14))
                .frame(width: 68, height: 68)
            Circle()
                .stroke(accent.opacity(0.30), lineWidth: 1)
                .frame(width: 42, height: 42)
            Circle()
                .fill(accent)
                .frame(width: 13, height: 13)
        }
    }

    /// 8 个方向 + 回到中心，依次停留再平滑滑过去
    private func followPoint(elapsed: Double, center: CGPoint, radius: CGFloat) -> CGPoint {
        let slots: [(CGFloat, CGFloat)] = [
            (0, -1), (1, -1), (1, 0), (1, 1),
            (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, 0)
        ]
        let cycle = 2.6
        let index = Int(elapsed / cycle) % slots.count
        let next = (index + 1) % slots.count
        let local = (elapsed / cycle).truncatingRemainder(dividingBy: 1.0)

        let moveStart = 0.60
        let raw: Double = local < moveStart ? 0 : (local - moveStart) / (1 - moveStart)
        let eased = raw * raw * (3 - 2 * raw)

        let a = slots[index]
        let b = slots[next]
        let x = center.x + (a.0 + (b.0 - a.0) * CGFloat(eased)) * radius
        let y = center.y + (a.1 + (b.1 - a.1) * CGFloat(eased)) * radius * 0.60
        return CGPoint(x: x, y: y)
    }

    /// 椭圆轨迹，顺时针一圈 7 秒
    private func circlePoint(elapsed: Double, center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = elapsed / 7.0 * 2 * .pi - .pi / 2
        return CGPoint(
            x: center.x + cos(angle) * radius * 1.05,
            y: center.y + sin(angle) * radius * 0.62
        )
    }

    /// 远近交替：目标周期放大缩小，模拟焦距来回切换
    private func focusScale(elapsed: Double) -> CGFloat {
        let phase = sin(elapsed / 2.4 * 2 * .pi)
        return 0.42 + 0.58 * CGFloat(0.5 + 0.5 * phase)
    }

    // MARK: 顶部阶段说明

    private var stageHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(0..<session.stages.count, id: \.self) { index in
                    Capsule()
                        .fill(index == session.stageIndex
                              ? accent
                              : Color.white.opacity(index < session.stageIndex ? 0.30 : 0.12))
                        .frame(width: index == session.stageIndex ? 20 : 6, height: 4)
                        .animation(.easeOut(duration: 0.25), value: session.stageIndex)
                }
            }
            .padding(.bottom, 4)

            Text(session.current.title)
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.92))

            Text(session.current.hint)
                .font(.system(size: 12.5))
                .foregroundStyle(Color.white.opacity(0.42))
        }
    }

    // MARK: 底部进度

    private var stageFooter: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 240, height: 3)
                Capsule()
                    .fill(accent)
                    .frame(width: 240 * session.overallProgress, height: 3)
            }

            HStack(spacing: 8) {
                Text(L10n.s("\(Int(ceil(session.stageRemaining))) 秒",
                               "\(Int(ceil(session.stageRemaining)))s"))
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Color.white.opacity(0.55))
                Text("·")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.24))
                Text(L10n.s("第 \(session.stageIndex + 1) / \(session.stages.count) 段",
                               "\(session.stageIndex + 1) / \(session.stages.count)"))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.34))
            }
        }
    }
}
