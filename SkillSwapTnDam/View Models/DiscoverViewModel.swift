import SwiftUI
import Foundation

@MainActor
final class DiscoverViewModel: ObservableObject {

    enum Segment {
        case profils
        case annonces
        case promos
    }

    // MARK: - UI State

    @Published var segment: Segment = .profils

    // Profils
    @Published var users: [DiscoverProfile] = []
    @Published var currentIndex: Int = 0
    
    // Swipe tracking
    @Published var likedUserIds: Set<String> = []
    @Published var declinedUserIds: Set<String> = []
    @Published var matchedUser: DiscoverProfile? = nil
    @Published var showMatchPopup: Bool = false

    // Annonces
    @Published var annonces: [Annonce] = []

    // Promos
    @Published var promos: [Promo] = []

    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Services

    private let userService = UserService()
    private let annonceService = AnnonceService()
    private let promoService = PromoService()
    private let chatService = ChatService()

    // MARK: - Computed

    var currentUser: DiscoverProfile? {
        guard users.indices.contains(currentIndex) else { return nil }
        return users[currentIndex]
    }

    // MARK: - Actions

    func startConversation(with userId: String) async -> Bool {
        guard let token = AuthenticationManager.shared.accessToken else { return false }
        do {
            _ = try await chatService.createThread(participantId: userId, accessToken: token)
            return true
        } catch {
            print("Error creating conversation: \(error)")
            return false
        }
    }
    
    func startConversationAndGetThreadId(with userId: String) async -> String? {
        guard let token = AuthenticationManager.shared.accessToken else { return nil }
        do {
            let thread = try await chatService.createThread(participantId: userId, accessToken: token)
            return thread.id
        } catch {
            print("Error creating conversation: \(error)")
            return nil
        }
    }
    
    // MARK: - Swipe Actions
    
    func likeUser() async {
        guard let user = currentUser else { return }
        likedUserIds.insert(user.id)
        
        // Check for match - in real app this would be an API call
        // For now, simulate match check (random 30% chance or based on backend)
        let isMatch = await checkForMatch(userId: user.id)
        
        if isMatch {
            matchedUser = user
            showMatchPopup = true
        }
        
        goToNextUser()
    }
    
    func declineUser() {
        guard let user = currentUser else { return }
        declinedUserIds.insert(user.id)
        goToNextUser()
    }
    
    private func goToNextUser() {
        if currentIndex + 1 < users.count {
            currentIndex += 1
        } else {
            // All users processed - reload declined users
            reloadDeclinedUsers()
        }
    }
    
    private func reloadDeclinedUsers() {
        guard !declinedUserIds.isEmpty else { return }
        
        // Filter users to only show previously declined ones
        let declinedUsers = users.filter { declinedUserIds.contains($0.id) }
        
        if !declinedUsers.isEmpty {
            users = declinedUsers
            declinedUserIds.removeAll()
            currentIndex = 0
        }
    }
    
    private func checkForMatch(userId: String) async -> Bool {
        // In a real implementation, this would call the backend to check if the other user also liked us
        // For demo purposes, simulate a 30% match rate
        // You can replace this with actual API call
        guard let token = AuthenticationManager.shared.accessToken else { return false }
        
        do {
            let isMatch = try await userService.checkMatch(userId: userId, accessToken: token)
            return isMatch
        } catch {
            // Fallback: simulate match (30% chance)
            return Int.random(in: 1...10) <= 3
        }
    }
    
    func dismissMatch() {
        showMatchPopup = false
        matchedUser = nil
    }

    // MARK: - Loading

    /// Call this from the view depending on the selected segment
    func loadForCurrentSegment() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            switch segment {
            case .profils:
                try await loadUsers()
            case .annonces:
                try await loadAnnonces()
            case .promos:
                try await loadPromos()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadUsers() async throws {
        let token = AuthenticationManager.shared.accessToken
        let fetched = try await userService.fetchUsers(accessToken: token)
        
        // Filter out already liked users
        let filteredUsers = fetched.filter { !likedUserIds.contains($0.id) }
        
        users = filteredUsers.map { u in
            DiscoverProfile(
                id: u.id,
                name: u.username,
                age: 20,
                city: u.locationDisplay ?? "Unknown",
                description: "Crédits: \(u.credits ?? 0), Rôle: \(u.role)",
                teaches: u.skillsTeach ?? [],
                learns: u.skillsLearn ?? [],
                matchScore: Int((u.ratingAvg ?? 0) * 10),
                distance: "5 km",
                isOnline: u.isVerified ?? false,
                image: u.imageURL?.absoluteString
            )
        }
        currentIndex = 0
    }

    private func loadAnnonces() async throws {
        annonces = try await annonceService.fetchAll()
    }

    private func loadPromos() async throws {
        promos = try await promoService.fetchAll()
    }

    // MARK: - Navigation between profiles (legacy - kept for compatibility)

    func goNext() {
        declineUser()
    }

    func goPrev() {
        if currentIndex > 0 {
            currentIndex -= 1
        }
    }
}
