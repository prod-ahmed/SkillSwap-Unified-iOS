//
//  DiscoverViewModel.swift
//  SkillSwapTnDam
//
//  Created by Ahmed BT on 10/11/2025.
//

import SwiftUI
import Foundation

@MainActor
final class DiscoverViewModel: ObservableObject {
    @Published var users: [DiscoverProfile] = []
    @Published var currentIndex: Int = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let service = UserService()

    var currentUser: DiscoverProfile? {
        guard users.indices.contains(currentIndex) else { return nil }
        return users[currentIndex]
    }

    func loadUsers() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let token = AuthenticationManager.shared.accessToken
            let fetched = try await service.fetchUsers(accessToken: token)

            let profiles: [DiscoverProfile] = fetched.map { user in
                DiscoverProfile(
                    name: user.username,
                    age: 20, // map real age if available
                    city: user.locationDisplay ?? "Unknown",
                    description: "Crédits: \(user.credits ?? 0), Rôle: \(user.role)",
                    teaches: user.skillsTeach ?? [],
                    matchScore: Int((user.ratingAvg ?? 0.0) * 10),
                    distance: "5 km",
                    isOnline: user.isVerified ?? false
                )
            }

            self.users = profiles
            self.currentIndex = 0
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    // Optional helpers if your UI has swipe actions:
    func goNext() { if currentIndex + 1 < users.count { currentIndex += 1 } }
    func goPrev() { if currentIndex - 1 >= 0 { currentIndex -= 1 } }
}
