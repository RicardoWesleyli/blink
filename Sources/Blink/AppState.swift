import Foundation
import Combine

enum DateKey {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static var today: String { formatter.string(from: Date()) }
}

enum ReminderStyle: String, Codable, CaseIterable, Identifiable {
    case subtle
    case hud

    var id: String { rawValue }

    var title: String {
        switch self {
        case .subtle: return L10n.s("仅图标", "Icon only")
        case .hud: return L10n.s("轻提醒", "Light card")
        }
    }

    var detail: String {
        switch self {
        case .subtle: return L10n.s("菜单栏图标轻微呼吸，不弹任何窗口",
                                    "The menu bar icon breathes. No window at all")
        case .hud: return L10n.s("屏幕角落浮出小卡片，不抢焦点",
                                 "A small card slides down from the menu bar. Never steals focus")
        }
    }
}

struct DayStats: Codable {
    var day: String
    var breaksCompleted: Int
    var restSeconds: Int
    var exercisesCompleted: Int

    static func empty() -> DayStats {
        DayStats(day: DateKey.today, breaksCompleted: 0, restSeconds: 0, exercisesCompleted: 0)
    }
}

/// 训练的长期进度。训练类产品的留存靠这个，不是靠分数。
struct TrainingProgress: Codable {
    var totalSessions: Int = 0
    var totalSeconds: Int = 0
    var lastDay: String = ""
    var streak: Int = 0
    var weekKey: String = ""
    var weekSeconds: Int = 0
    var programCounts: [String: Int] = [:]
}

final class AppState: ObservableObject {
    private let defaults = UserDefaults.standard

    private enum Key {
        static let interval = "blink.intervalMinutes"
        static let duration = "blink.breakSeconds"
        static let style = "blink.reminderStyle"
        static let stats = "blink.dayStats"
        static let paused = "blink.isPaused"
        static let breathing = "blink.iconBreathing"
        static let progress = "blink.trainingProgress"
        static let lastQuote = "blink.lastQuote"
        static let language = "blink.language"
    }

    // MARK: User settings

    @Published var intervalMinutes: Int {
        didSet {
            defaults.set(intervalMinutes, forKey: Key.interval)
            NotificationCenter.default.post(name: .blinkSettingsChanged, object: nil)
        }
    }

    @Published var breakSeconds: Int {
        didSet {
            defaults.set(breakSeconds, forKey: Key.duration)
            NotificationCenter.default.post(name: .blinkSettingsChanged, object: nil)
        }
    }

    @Published var reminderStyle: ReminderStyle {
        didSet { defaults.set(reminderStyle.rawValue, forKey: Key.style) }
    }

    @Published var isPaused: Bool {
        didSet { defaults.set(isPaused, forKey: Key.paused) }
    }

    /// 界面语言。切换后所有持有本对象的视图会立即重算，不需要重启。
    @Published var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: Key.language)
            L10n.language = language
        }
    }

    // MARK: Runtime

    @Published var stats: DayStats
    @Published var trainingProgress: TrainingProgress
    /// 距离上次完整训练之间已经做了几次短休息，攒到 3 次就换成一次训练
    @Published var shortBreaksSinceTraining: Int = 0
    @Published var lastQuote: String?
    @Published var secondsUntilNext: Int = 0
    @Published var isBreaking = false
    @Published var isTraining = false
    @Published var pendingReminder = false

    init() {
        let d = UserDefaults.standard
        let interval = d.object(forKey: Key.interval) as? Int ?? 20
        let duration = d.object(forKey: Key.duration) as? Int ?? 20
        let paused = d.bool(forKey: Key.paused)

        self.intervalMinutes = min(max(interval, 5), 240)
        self.breakSeconds = min(max(duration, 10), 600)
        // 只保留轻提醒这一种方式
        self.reminderStyle = .hud
        self.isPaused = paused

        let lang = AppLanguage(rawValue: d.string(forKey: Key.language) ?? "") ?? .system
        self.language = lang
        L10n.language = lang

        if let data = d.data(forKey: Key.stats),
           let decoded = try? JSONDecoder().decode(DayStats.self, from: data),
           decoded.day == DateKey.today {
            self.stats = decoded
        } else {
            self.stats = .empty()
        }

        if let data = d.data(forKey: Key.progress),
           let decoded = try? JSONDecoder().decode(TrainingProgress.self, from: data) {
            self.trainingProgress = decoded
        } else {
            self.trainingProgress = TrainingProgress()
        }

        self.lastQuote = d.string(forKey: Key.lastQuote)
        self.secondsUntilNext = self.intervalMinutes * 60
    }

    // MARK: Stats

    private func rolloverIfNeeded() {
        if stats.day != DateKey.today {
            stats = .empty()
        }
    }

    func recordBreak(seconds: Int) {
        rolloverIfNeeded()
        stats.breaksCompleted += 1
        stats.restSeconds += seconds
        persistStats()
    }

    func recordExercise(program: TrainingProgram) {
        rolloverIfNeeded()
        stats.exercisesCompleted += 1
        persistStats()

        var p = trainingProgress
        let seconds = Int(program.stages.reduce(0) { $0 + $1.seconds })

        p.totalSessions += 1
        p.totalSeconds += seconds
        p.programCounts[program.rawValue, default: 0] += 1

        let today = DateKey.today
        if p.lastDay != today {
            p.streak = Self.isYesterday(p.lastDay) ? max(1, p.streak + 1) : 1
            p.lastDay = today
        } else if p.streak == 0 {
            p.streak = 1
        }

        let wk = Self.weekKey()
        if p.weekKey != wk {
            p.weekKey = wk
            p.weekSeconds = 0
        }
        p.weekSeconds += seconds

        trainingProgress = p
        persistProgress()

        // 一轮完整训练结束，短休息计数重新开始
        shortBreaksSinceTraining = 0
    }

    /// 完成一次短休息，攒够 3 次下次自动换成完整训练
    func noteShortBreak() {
        shortBreaksSinceTraining += 1
    }

    var shouldTrainThisCycle: Bool {
        shortBreaksSinceTraining >= 3
    }

    /// 按时间和今日状态挑一套训练
    var recommendedProgram: TrainingProgram {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 22 || hour < 6 { return .night }
        if hour >= 6 && hour < 10 { return .morning }
        if stats.exercisesCompleted >= 2 { return .dryEye }
        return .screenTime
    }

    func nextQuote() -> String {
        let quote = TrainingQuotes.random(excluding: lastQuote)
        lastQuote = quote
        defaults.set(quote, forKey: Key.lastQuote)
        return quote
    }

    /// 今天一共放松了几次：短休息 + 完整训练
    var todayRestCount: Int {
        stats.breaksCompleted + stats.exercisesCompleted
    }

    var streakText: String { L10n.days(trainingProgress.streak) }

    var weekMinutesText: String {
        let m = trainingProgress.weekSeconds / 60
        if m > 0 { return L10n.s("\(m) 分钟", "\(m) min") }
        return trainingProgress.weekSeconds > 0
            ? L10n.s("\(trainingProgress.weekSeconds) 秒", "\(trainingProgress.weekSeconds) s")
            : L10n.s("0 分钟", "0 min")
    }

    private func persistProgress() {
        if let data = try? JSONEncoder().encode(trainingProgress) {
            defaults.set(data, forKey: Key.progress)
        }
    }

    private static func isYesterday(_ day: String) -> Bool {
        guard !day.isEmpty else { return false }
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: day) else { return false }
        return Calendar.current.isDateInYesterday(date)
    }

    private static func weekKey() -> String {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return "\(comps.yearForWeekOfYear ?? 0)-W\(comps.weekOfYear ?? 0)"
    }

    private func persistStats() {
        if let data = try? JSONEncoder().encode(stats) {
            defaults.set(data, forKey: Key.stats)
        }
    }

    var todayRestText: String {
        let total = stats.restSeconds
        let minutes = total / 60
        let seconds = total % 60
        if minutes >= 60 {
            return L10n.s(String(format: "%d 小时 %d 分", minutes / 60, minutes % 60),
                          String(format: "%dh %dm", minutes / 60, minutes % 60))
        }
        if minutes > 0 {
            if seconds == 0 { return L10n.s("\(minutes) 分钟", "\(minutes) min") }
            return L10n.s("\(minutes) 分 \(seconds) 秒", "\(minutes)m \(seconds)s")
        }
        return L10n.s("\(seconds) 秒", "\(seconds) s")
    }
}

extension Notification.Name {
    static let blinkSettingsChanged = Notification.Name("blink.settings.changed")
}
