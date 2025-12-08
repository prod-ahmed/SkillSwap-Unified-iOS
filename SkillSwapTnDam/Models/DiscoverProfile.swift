import Foundation

/// Lightweight UI model for your Discover screen
struct DiscoverProfile: Identifiable, Equatable {
    let id: String
    let name: String
    let age: Int
    let city: String
    let description: String
    let teaches: [String]
    let learns: [String]
    let matchScore: Int
    let distance: String
    let isOnline: Bool
    let image: String?
}

