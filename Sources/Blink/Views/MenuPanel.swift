import AppKit
import SwiftUI

struct EyeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX
        let cy = rect.midY
        let halfW = rect.width * 0.46
        let lid = rect.height * 0.30

        p.move(to: CGPoint(x: cx - halfW, y: cy))
        p.addCurve(to: CGPoint(x: cx + halfW, y: cy),
                   control1: CGPoint(x: cx - halfW * 0.42, y: cy - lid * 1.70),
                   control2: CGPoint(x: cx + halfW * 0.42, y: cy - lid * 1.70))
        p.addCurve(to: CGPoint(x: cx - halfW, y: cy),
                   control1: CGPoint(x: cx + halfW * 0.42, y: cy + lid * 1.70),
                   control2: CGPoint(x: cx - halfW * 0.42, y: cy + lid * 1.70))
        return p
    }
}

struct EyeMark: View {
    var size: CGFloat = 26
    var tint: Color = Color(red: 0.42, green: 0.72, blue: 1.0)

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.12))
                .frame(width: size * 1.55, height: size * 1.55)
            EyeShape()
                .stroke(tint, style: StrokeStyle(lineWidth: size * 0.085, lineCap: .round))
                .frame(width: size, height: size * 0.84)
            Circle()
                .fill(tint)
                .frame(width: size * 0.28, height: size * 0.28)
        }
        .frame(width: size * 1.55, height: size * 1.55)
    }
}

struct MenuPanel: View {
    @ObservedObject var state: AppState
    let actions: MenuActions

    @State private var hoveringRing = false
    @State private var hoveredProgram: TrainingProgram?

    private let accent = Color(red: 0.42, green: 0.72, blue: 1.0)

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.bottom, 14)

            statsBlock
                .padding(.bottom, 22)

            countdownBlock
                .padding(.bottom, 18)

            Divider().opacity(0.3)
                .padding(.bottom, 12)

            trainingBlock
                .padding(.bottom, 12)

            Divider().opacity(0.3)
                .padding(.bottom, 12)

            settingsBlock

            Spacer(minLength: 10)

            footer
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(width: 340, height: 560, alignment: .top)
        .background(Color.clear)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 9) {
            EyeMark(size: 18)
            Text("Blink")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            Spacer()
            HStack(spacing: 5) {
                Circle()
                    .fill(state.isPaused ? Color.secondary.opacity(0.55) : accent)
                    .frame(width: 6, height: 6)
                Text(state.isPaused ? L10n.s("已暂停", "Paused") : L10n.s("守候中", "On watch"))
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: 统计

    private var statsBlock: some View {
        HStack(spacing: 0) {
            statCell(value: state.streakText, label: L10n.s("连续训练", "Streak"))
            statDivider
            statCell(value: state.weekMinutesText, label: L10n.s("本周训练", "This week"))
            statDivider
            statCell(value: L10n.times(state.todayRestCount), label: L10n.s("今日休息", "Today"))
        }
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.09))
            .frame(width: 1, height: 26)
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: 倒计时

    private var countdownBlock: some View {
        VStack(spacing: 16) {
            countdownRing

            Button {
                actions.startBreak()
            } label: {
                Text(L10n.s("立即休息", "Break now"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 18)
                    .frame(height: 27)
                    .background(
                        Capsule().stroke(accent.opacity(0.5), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    private var countdownRing: some View {
        let total = max(1, Double(state.intervalMinutes * 60))
        let remaining = max(0, Double(state.secondsUntilNext))
        let progress = min(1, max(0, remaining / total))

        return ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.07), lineWidth: 6)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .opacity(state.isPaused ? 0.3 : 1)
                .animation(.linear(duration: 1), value: progress)

            if hoveringRing {
                Image(systemName: state.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(accent)
            } else {
                VStack(spacing: 1) {
                    Text(timeString(remaining))
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(state.isPaused ? Color.secondary : Color.primary)
                        .contentTransition(.numericText())
                    Text(state.isPaused ? L10n.s("已暂停", "Paused") : L10n.s("距下次休息", "next break"))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 118, height: 118)
        .contentShape(Circle())
        .onHover { hoveringRing = $0 }
        .onTapGesture { state.isPaused.toggle() }
        .animation(.easeInOut(duration: 0.12), value: hoveringRing)
    }

    private func timeString(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    // MARK: 眼部训练

    private var trainingBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.s("眼部训练", "EYE TRAINING"))
                .font(.system(size: 10, weight: .medium))
                .tracking(1)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8),
                                GridItem(.flexible(), spacing: 8)],
                      spacing: 8) {
                ForEach(TrainingProgram.allCases) { program in
                    programTile(program)
                }
            }
        }
    }

    /// 点一下直接进这套课程的引导页，那里还能按 Esc 退出，不算误触
    private func programTile(_ program: TrainingProgram) -> some View {
        let hovered = hoveredProgram == program
        return Button {
            actions.startTraining(program)
        } label: {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(program.title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .lineLimit(1)
                    Text(program.minutesHint)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "play.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(accent.opacity(hovered ? 1 : 0.65))
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(hovered ? 0.11 : 0.055))
            )
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { inside in
            if inside {
                hoveredProgram = program
            } else if hoveredProgram == program {
                hoveredProgram = nil
            }
        }
        .animation(.easeOut(duration: 0.12), value: hovered)
    }

    // MARK: Settings

    private var settingsBlock: some View {
        VStack(spacing: 10) {
            optionRow(title: L10n.s("提醒间隔", "Every"),
                      current: L10n.s("\(state.intervalMinutes) 分钟", "\(state.intervalMinutes) min")) {
                ForEach(presetIntervals, id: \.self) { minutes in
                    Button {
                        state.intervalMinutes = minutes
                    } label: {
                        if minutes == state.intervalMinutes {
                            Label(L10n.s("\(minutes) 分钟", "\(minutes) min"), systemImage: "checkmark")
                        } else {
                            Text(L10n.s("\(minutes) 分钟", "\(minutes) min"))
                        }
                    }
                }
                Divider()
                Button(L10n.s("自定义…", "Custom…")) {
                    askCustom(title: L10n.s("提醒间隔", "Reminder interval"),
                              unit: L10n.s("分钟", "minutes"),
                              current: state.intervalMinutes, range: 5...240) {
                        state.intervalMinutes = $0
                    }
                }
            }

            optionRow(title: L10n.s("休息时长", "Break"),
                      current: durationLabel(state.breakSeconds)) {
                ForEach(presetDurations, id: \.self) { seconds in
                    Button {
                        state.breakSeconds = seconds
                    } label: {
                        if seconds == state.breakSeconds {
                            Label(durationLabel(seconds), systemImage: "checkmark")
                        } else {
                            Text(durationLabel(seconds))
                        }
                    }
                }
                Divider()
                Button(L10n.s("自定义…", "Custom…")) {
                    askCustom(title: L10n.s("休息时长", "Break duration"),
                              unit: L10n.s("秒", "seconds"),
                              current: state.breakSeconds, range: 10...600) {
                        state.breakSeconds = $0
                    }
                }
            }
        }
    }

    /// 可选预设，点一下直接生效，不用一格一格加减
    private let presetIntervals = [20, 30, 40, 45, 60, 90, 120]
    private let presetDurations = [20, 30, 45, 60, 180, 300, 600]

    /// 秒数转人话：不到一分钟说秒，整分钟说分钟
    private func durationLabel(_ seconds: Int) -> String {
        if seconds < 60 { return L10n.s("\(seconds) 秒", "\(seconds)s") }
        let minutes = seconds / 60
        let rest = seconds % 60
        if rest == 0 { return L10n.s("\(minutes) 分钟", "\(minutes) min") }
        return L10n.s("\(minutes) 分 \(rest) 秒", "\(minutes)m \(rest)s")
    }

    /// 自定义数值：用系统输入框问一次，非法值不落库
    private func askCustom(title: String,
                           unit: String,
                           current: Int,
                           range: ClosedRange<Int>,
                           apply: @escaping (Int) -> Void) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = L10n.s(
                "输入 \(range.lowerBound)–\(range.upperBound) 之间的\(unit)数",
                "Enter a number between \(range.lowerBound) and \(range.upperBound)"
            )
            alert.addButton(withTitle: L10n.s("确定", "OK"))
            alert.addButton(withTitle: L10n.s("取消", "Cancel"))

            let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 180, height: 24))
            field.stringValue = "\(current)"
            alert.accessoryView = field
            alert.window.initialFirstResponder = field

            NSApp.activate(ignoringOtherApps: true)

            while true {
                let response = alert.runModal()
                if response != .alertFirstButtonReturn { return }
                if let value = Int(field.stringValue), range.contains(value) {
                    apply(value)
                    return
                }
                alert.informativeText = L10n.s(
                    "请填 \(range.lowerBound)–\(range.upperBound) 之间的整数",
                    "Whole number between \(range.lowerBound) and \(range.upperBound), please"
                )
            }
        }
    }

    private func optionRow<Content: View>(title: String,
                                          current: String,
                                          @ViewBuilder items: () -> Content) -> some View {
        HStack(spacing: 0) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Menu {
                items()
            } label: {
                HStack(spacing: 5) {
                    Text(current)
                        .font(.system(size: 11.5, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 104, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 12) {
            languageMenu
            Spacer()
            Button(L10n.s("退出", "Quit")) {
                actions.quit()
            }
            .buttonStyle(.plain)
            .font(.system(size: 10.5))
            .foregroundStyle(.secondary)
        }
    }

    private var languageMenu: some View {
        Menu {
            ForEach(AppLanguage.allCases) { lang in
                Button {
                    state.language = lang
                } label: {
                    if lang == state.language {
                        Label(lang.title, systemImage: "checkmark")
                    } else {
                        Text(lang.title)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "globe")
                    .font(.system(size: 9))
                Text(L10n.isEnglish ? "EN" : "中文")
                    .font(.system(size: 10.5))
            }
            .foregroundStyle(.secondary)
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .fixedSize()
    }
}
