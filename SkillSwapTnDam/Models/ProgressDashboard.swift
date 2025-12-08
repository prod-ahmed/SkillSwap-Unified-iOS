import Foundation

struct ProgressDashboardResponse: Codable {
    let stats: ProgressStats
    var goals: [ProgressGoalItem]
    let weeklyActivity: [WeeklyActivityPoint]
    let skillProgress: [SkillProgressItem]
    let badges: [BadgeItem]
    let xpSummary: XPSummary
}

struct ProgressStats: Codable {
    let weeklyHours: Double
    let skillsCount: Int
}

struct ProgressGoalItem: Codable, Identifiable {
    let id: String
    let title: String
    let targetHours: Double
    let currentHours: Double
    let period: String
    let status: String
    let dueDate: Date?
    let progressPercent: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case legacyId = "_id"
        case title, targetHours, currentHours, period, status, dueDate, progressPercent
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try container.decodeIfPresent(String.self, forKey: .id) {
            id = value
        } else if let legacy = try container.decodeIfPresent(String.self, forKey: .legacyId) {
            id = legacy
        } else {
            throw DecodingError.keyNotFound(CodingKeys.id, .init(codingPath: decoder.codingPath, debugDescription: "Goal id missing"))
        }
        title = try container.decode(String.self, forKey: .title)
        targetHours = try container.decode(Double.self, forKey: .targetHours)
        currentHours = try container.decode(Double.self, forKey: .currentHours)
        period = try container.decode(String.self, forKey: .period)
        status = try container.decode(String.self, forKey: .status)
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        progressPercent = try container.decodeIfPresent(Int.self, forKey: .progressPercent)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(targetHours, forKey: .targetHours)
        try container.encode(currentHours, forKey: .currentHours)
        try container.encode(period, forKey: .period)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(dueDate, forKey: .dueDate)
        try container.encodeIfPresent(progressPercent, forKey: .progressPercent)
    }
}

struct WeeklyActivityPoint: Codable, Identifiable {
    let id = UUID()
    let day: String
    let hours: Double

    private enum CodingKeys: String, CodingKey { case day, hours }

    init(day: String, hours: Double) {
        self.day = day
        self.hours = hours
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        day = try container.decode(String.self, forKey: .day)
        hours = try container.decode(Double.self, forKey: .hours)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(day, forKey: .day)
        try container.encode(hours, forKey: .hours)
    }
}

struct SkillProgressItem: Codable, Identifiable {
    let id = UUID()
    let skill: String
    let hours: Double
    let level: String
    let progress: Int

    private enum CodingKeys: String, CodingKey { case skill, hours, level, progress }

    init(skill: String, hours: Double, level: String, progress: Int) {
        self.skill = skill
        self.hours = hours
        self.level = level
        self.progress = progress
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        skill = try container.decode(String.self, forKey: .skill)
        hours = try container.decode(Double.self, forKey: .hours)
        level = try container.decode(String.self, forKey: .level)
        progress = try container.decode(Int.self, forKey: .progress)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(skill, forKey: .skill)
        try container.encode(hours, forKey: .hours)
        try container.encode(level, forKey: .level)
        try container.encode(progress, forKey: .progress)
    }
}

struct BadgeItem: Codable, Identifiable {
    let id = UUID()
    let tier: String
    let title: String
    let description: String
    let iconKey: String
    let icon: String
    let color: String
    let threshold: Int
    let unlocked: Bool

    private enum CodingKeys: String, CodingKey {
        case tier, title, description, iconKey, icon, color, threshold, unlocked
    }

    init(tier: String, title: String, description: String, iconKey: String, icon: String, color: String, threshold: Int, unlocked: Bool) {
        self.tier = tier
        self.title = title
        self.description = description
        self.iconKey = iconKey
        self.icon = icon
        self.color = color
        self.threshold = threshold
        self.unlocked = unlocked
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tier = try container.decode(String.self, forKey: .tier)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        iconKey = try container.decode(String.self, forKey: .iconKey)
        icon = try container.decode(String.self, forKey: .icon)
        color = try container.decode(String.self, forKey: .color)
        threshold = try container.decode(Int.self, forKey: .threshold)
        unlocked = try container.decode(Bool.self, forKey: .unlocked)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tier, forKey: .tier)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(iconKey, forKey: .iconKey)
        try container.encode(icon, forKey: .icon)
        try container.encode(color, forKey: .color)
        try container.encode(threshold, forKey: .threshold)
        try container.encode(unlocked, forKey: .unlocked)
    }

    var displayName: String { title }

    var displayIcon: String {
        if !icon.isEmpty, icon != iconKey { return icon }
        switch iconKey {
        case "badge-iron": return "🛡️"
        case "badge-bronze": return "🥉"
        case "badge-silver": return "🥈"
        case "badge-gold": return "🥇"
        default: return "🎖️"
        }
    }
}

struct XPSummary: Codable {
    let xp: Int
    let referralCount: Int
    let nextBadge: NextBadgeInfo?
}

struct NextBadgeInfo: Codable {
    let tier: String
    let title: String
    let threshold: Int
}

extension ProgressGoalItem {
    var normalizedProgressPercent: Int {
        if let progressPercent = progressPercent { return progressPercent }
        guard targetHours > 0 else { return 0 }
        let ratio = currentHours / targetHours
        return min(100, max(0, Int(round(ratio * 100))))
    }

    var progressRatio: Double {
        Double(normalizedProgressPercent) / 100
    }
}
