import Foundation

enum BadgeTier: String, Codable, CaseIterable, Identifiable {
    case iron = "Iron"
    case bronze = "Bronze"
    case silver = "Silver"
    case gold = "Gold"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var accentColorHex: String {
        switch self {
        case .iron: return "#6B7280"
        case .bronze: return "#B45309"
        case .silver: return "#9CA3AF"
        case .gold: return "#D97706"
        }
    }
}

struct RewardsSummary: Codable {
    let xp: Int
    let badges: [BadgeTier]
    let codeParainnage: String
    let nombreParainnage: Int
    let maxParannaige: Int
    let remainingSlots: Int
}
