import SwiftUI

final class BreakSession: ObservableObject {
    @Published var remaining: Double
    let total: Double

    init(total: Double) {
        self.total = total
        self.remaining = total
    }

    /// 已经休息了多久，正计时
    var elapsed: Double {
        max(0, total - remaining)
    }

    /// 圆环按正计时增长：从空长到满，而不是从满回缩
    var progress: Double {
        total <= 0 ? 1 : max(0, min(1, elapsed / total))
    }

    /// 中间数字显示剩余时间（倒计时），但圆环按已用时间顺时针长满
    var timeText: String {
        let seconds = Int(ceil(remaining))
        guard total >= 60 else { return "\(seconds)" }
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

struct BreakScene: View {
    @ObservedObject var session: BreakSession

    private let accent = Color(red: 0.42, green: 0.72, blue: 1.0)

    var body: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)
            let centerY = h * 0.46

            ZStack {
                ScrimBackground()

                VStack(spacing: 26) {
                    ringView
                    VStack(spacing: 9) {
                        Text(L10n.s("望向 6 米以外", "Look 20 feet away"))
                            .font(.system(size: 25, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.92))
                        Text(L10n.s("让睫状肌松开，这一刻不用看屏幕",
                                  "Let the ciliary muscle release. Don't look at the screen"))
                            .font(.system(size: 13))
                            .foregroundStyle(Color.white.opacity(0.60))
                    }
                }
                .position(x: w / 2, y: centerY)

                HStack(spacing: 6) {
                    Text(L10n.s("按任意键", "Any key"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.50))
                    Text(L10n.s("结束休息", "ends the break"))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.40))
                }
                .position(x: w / 2, y: h - 38)
            }
            .frame(width: w, height: h)
        }
        .ignoresSafeArea()
    }

    private var ringView: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 1.4)
                .frame(width: 208, height: 208)

            Circle()
                .trim(from: 0, to: session.progress)
                .stroke(accent, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
                .frame(width: 208, height: 208)
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text(session.timeText)
                    .font(.system(size: 52, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.white.opacity(0.94))
                if session.total < 60 {
                    Text(L10n.s("秒", "sec"))
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.50))
                }
            }
        }
    }
}
