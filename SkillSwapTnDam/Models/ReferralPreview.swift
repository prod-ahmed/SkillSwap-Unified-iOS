import Foundation

struct ReferralPreview: Codable {
    let username: String
    let badges: [BadgeTier]
    let remainingSlots: Int
}
