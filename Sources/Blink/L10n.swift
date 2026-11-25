import Foundation

/// 应用内语言。system 表示跟随系统首选语言。
enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case system
    case chinese
    case english

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:  return L10n.s("跟随系统", "System")
        case .chinese: return "中文"
        case .english: return "English"
        }
    }
}

/// 文案集中层：调用点直接写「中文 / English」两版，不维护 key 表。
/// 好处是改文案时中英两版挨在一起，不会出现只改了一边的情况；
/// 也不用处理 .lproj 打包和系统语言缓存，切换即时生效。
enum L10n {
    static var language: AppLanguage = .system

    static var isEnglish: Bool {
        switch language {
        case .english: return true
        case .chinese: return false
        case .system:
            let code = Locale.preferredLanguages.first ?? "en"
            return !(code.hasPrefix("zh") || code.hasPrefix("yue"))
        }
    }

    static func s(_ zh: String, _ en: String) -> String {
        isEnglish ? en : zh
    }

    /// 天数
    static func days(_ n: Int) -> String {
        isEnglish ? "\(n) day\(n == 1 ? "" : "s")" : "\(n) 天"
    }

    /// 次数
    static func times(_ n: Int) -> String {
        isEnglish ? "\(n) time\(n == 1 ? "" : "s")" : "\(n) 次"
    }

    /// 秒数保留两位补零，用于倒计时
    static func clock(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
