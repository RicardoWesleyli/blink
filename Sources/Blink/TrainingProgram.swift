import Foundation

/// 一段训练动作的描述：动作类型 + 时长 + 文案。
/// 动作类型复用 EyeStage，课程只负责决定顺序和节奏，不新增动作原语。
struct StageSpec {
    let kind: EyeStage
    let seconds: Double
    let title: String
    let hint: String
}

/// 一套完整训练。四套课程共用同一组动作原语（跟随 / 环绕 / 远近 / 闭眼），
/// 差别在顺序、时长和文案——这就是「内容」，也是和提醒类产品的分界线。
enum TrainingProgram: String, CaseIterable, Identifiable, Codable {
    case screenTime
    case morning
    case dryEye
    case night

    var id: String { rawValue }

    var title: String {
        switch self {
        case .screenTime: return L10n.s("屏幕间歇", "Screen break")
        case .morning:    return L10n.s("晨间唤醒", "Morning wake")
        case .dryEye:     return L10n.s("干眼舒缓", "Dry eyes")
        case .night:      return L10n.s("睡前放松", "Before sleep")
        }
    }

    var subtitle: String {
        switch self {
        case .screenTime:
            return L10n.s("盯屏幕久了，让目光跟着光点走一圈",
                          "After a long stretch at the screen, follow the dot around")
        case .morning:
            return L10n.s("刚醒眼睛还没对焦，动作慢一点就好",
                          "Your eyes aren't focused yet. Slow is fine")
        case .dryEye:
            return L10n.s("眼睛发涩的时候，多闭一会儿眼",
                          "When they feel scratchy, keep them closed longer")
        case .night:
            return L10n.s("关灯之前，让眼睛先松下来",
                          "Let your eyes loosen before the lights go out")
        }
    }

    var minutesHint: String {
        let total = Int(stages.reduce(0) { $0 + $1.seconds })
        return L10n.s("\(total) 秒", "\(total)s")
    }

    var stages: [StageSpec] {
        switch self {
        case .screenTime:
            return [
                StageSpec(kind: .follow, seconds: 24,
                          title: L10n.s("跟着光点走", "Follow the dot"),
                          hint: L10n.s("光点不快，眼睛跟上就行，头不用动",
                                       "It's slow. Move your eyes, not your head")),
                StageSpec(kind: .circle, seconds: 18,
                          title: L10n.s("绕个圈", "Go around"),
                          hint: L10n.s("慢慢转，圈不用很大",
                                       "Slowly. No need for a wide circle")),
                StageSpec(kind: .focus, seconds: 16,
                          title: L10n.s("看远，再看近", "Far, then near"),
                          hint: L10n.s("盯住中间，视线在远处和近处来回",
                                       "Hold the center. Eyes go far, then back")),
                StageSpec(kind: .rest, seconds: 12,
                          title: L10n.s("闭眼歇一会儿", "Just close them"),
                          hint: L10n.s("轻轻闭上，什么都不用做",
                                       "Gently shut. Nothing else to do"))
            ]

        case .morning:
            return [
                StageSpec(kind: .focus, seconds: 20,
                          title: L10n.s("看远，再看近", "Far, then near"),
                          hint: L10n.s("刚醒，先慢慢找找远近",
                                       "Just woke up. Find far and near slowly")),
                StageSpec(kind: .circle, seconds: 20,
                          title: L10n.s("绕个圈", "Go around"),
                          hint: L10n.s("轻轻转，不用睁得很大",
                                       "Easy circles. No need to open wide")),
                StageSpec(kind: .follow, seconds: 12,
                          title: L10n.s("跟着光点走", "Follow the dot"),
                          hint: L10n.s("光点走得很慢，跟上就好",
                                       "The dot is slow. Just keep up")),
                StageSpec(kind: .rest, seconds: 8,
                          title: L10n.s("闭眼歇一会儿", "Just close them"),
                          hint: L10n.s("再闭一会儿，然后开始今天",
                                       "One more pause, then start the day"))
            ]

        case .dryEye:
            return [
                StageSpec(kind: .rest, seconds: 20,
                          title: L10n.s("闭眼歇一会儿", "Just close them"),
                          hint: L10n.s("闭上眼，让它自己润一润",
                                       "Close them. Let them re-wet themselves")),
                StageSpec(kind: .follow, seconds: 20,
                          title: L10n.s("跟着光点走", "Follow the dot"),
                          hint: L10n.s("比平时更慢，别用力",
                                       "Slower than usual. Don't force it")),
                StageSpec(kind: .circle, seconds: 16,
                          title: L10n.s("绕个圈", "Go around"),
                          hint: L10n.s("幅度小一点就好",
                                       "A smaller circle is enough")),
                StageSpec(kind: .rest, seconds: 34,
                          title: L10n.s("闭眼歇一会儿", "Just close them"),
                          hint: L10n.s("这次闭久一点，眼睛会舒服很多",
                                       "Longer this time. It'll feel much better"))
            ]

        case .night:
            return [
                StageSpec(kind: .circle, seconds: 22,
                          title: L10n.s("绕个圈", "Go around"),
                          hint: L10n.s("比白天慢一半就好",
                                       "Half the speed of daytime")),
                StageSpec(kind: .focus, seconds: 14,
                          title: L10n.s("看远，再看近", "Far, then near"),
                          hint: L10n.s("看向房间最远的地方，再回到眼前",
                                       "Look at the farthest thing in the room, then back")),
                StageSpec(kind: .rest, seconds: 24,
                          title: L10n.s("闭眼歇一会儿", "Just close them"),
                          hint: L10n.s("闭上眼，让呼吸慢下来",
                                       "Eyes closed. Let the breathing slow down"))
            ]
        }
    }
}

/// 训练完成后的正向反馈。
/// 中文来自用户给的语料里谈休息与节奏的条目；英文不是直译，
/// 而是按同一语气重写——短句、不下判断、不喊口号。
enum TrainingQuotes {
    static var all: [String] {
        if L10n.isEnglish {
            return [
                "What carries you through a day isn't willpower. It's recovery.",
                "A break isn't a reward. It's the precondition for the next stretch.",
                "Eyes have no switch, only rhythm.",
                "Look away for a moment. The world won't stop.",
                "Breathe. Walk a little. Look at the sky.",
                "Go all in when you work. Don't think about work when you rest.",
                "Close your eyes, listen to one song, step out of the machine.",
                "The longer you look, the less you see.",
                "Give your eyes a stretch of time each day with nothing to look at.",
                "Releasing the ciliary muscle once beats straining for ten minutes.",
                "You don't need to see sharper. You need to see longer.",
                "Push your limits. But respect recovery."
            ]
        }
        return [
            "真正能撑住一整天的，不是意志力，是恢复。",
            "休息不是奖励，是下一段工作的前提。",
            "眼睛没有开关，只有节奏。",
            "把目光移开一会儿，世界不会因此停下来。",
            "深呼吸十分钟，出去走一走，看看天空。",
            "工作时全力以赴，休息时完全不想工作。",
            "闭上眼睛，听一首歌，把自己从机械里抽离出来。",
            "看得越久，越看不清。",
            "每天给眼睛留一小段什么都不看的时间。",
            "让睫状肌松开一次，比硬撑十分钟管用。",
            "你不需要看得更清楚，只需要看得更久。",
            "挑战极限，也重视恢复。"
        ]
    }

    static func random(excluding last: String?) -> String {
        let pool = all.filter { $0 != last }
        return pool.randomElement() ?? all[0]
    }
}
