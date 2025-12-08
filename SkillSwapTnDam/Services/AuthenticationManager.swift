import Foundation
import SwiftUI

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?

    static let shared = AuthenticationManager()

    private let tokenKey = "authToken"
    private let userKey  = "currentUser"
    private let userService = UserService()
    
    // Shared App Group for widget
    private let sharedDefaults = UserDefaults(suiteName: "group.com.skillswaptn.app")

    /// Read-only access to the stored token
    var accessToken: String? {
        UserDefaults.standard.string(forKey: tokenKey)
    }

    private init() {
        print("🔐 [AuthManager] Initializing...")
        if let token = accessToken {
            print("🔐 [AuthManager] Found existing token: \(token.prefix(20))...")
            isAuthenticated = true
            loadCurrentUserFromDisk()
            
            // Sync token to shared defaults for widget
            syncTokenToWidget(token)
            
            // Refresh token on startup
            Task {
                do {
                    let authService = AuthService()
                    let newToken = try await authService.refreshToken(token: token)
                    print("🔐 [AuthManager] Token refreshed successfully")
                    UserDefaults.standard.set(newToken, forKey: tokenKey)
                    syncTokenToWidget(newToken)
                    
                    // Refresh user profile
                    try await refreshCurrentUser()
                } catch {
                    print("🔐 [AuthManager] Failed to refresh token: \(error)")
                    let nsError = error as NSError
                    print("🔐 [AuthManager] Error code: \(nsError.code), domain: \(nsError.domain)")
                    
                    // Sign out on any auth-related error (401, 403) or if token is truly invalid
                    if nsError.code == 401 || nsError.code == 403 {
                        print("🔐 [AuthManager] Auth error - Signing out")
                        signOut()
                    } else {
                        print("🔐 [AuthManager] Non-auth error (\(nsError.code)) - Keeping local session")
                    }
                }
            }
        } else {
            print("🔐 [AuthManager] No token found, user needs to sign in")
        }
    }

    // Save token + user from a sign-in response
    func signIn(with response: SignInResponse) {
        print("🔐 [AuthManager] ====== SIGN IN ======")
        print("🔐 [AuthManager] User: \(response.user.username) (ID: \(response.user.id))")
        UserDefaults.standard.set(response.accessToken, forKey: tokenKey)
        syncTokenToWidget(response.accessToken)
        isAuthenticated = true
        saveCurrentUser(response.user)
        print("🔐 [AuthManager] isAuthenticated = true")
        print("🔐 [AuthManager] ====== SIGN IN COMPLETE ======")
    }

    func signOut() {
        print("🔐 [AuthManager] ====== SIGN OUT ======")
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)
        sharedDefaults?.removeObject(forKey: "accessToken")
        isAuthenticated = false
        currentUser = nil
        SocketService.shared.disconnect()
        ChatSocketService.shared.disconnect()
        print("🔐 [AuthManager] ====== SIGN OUT COMPLETE ======")
    }

    func saveCurrentUser(_ user: User) {
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: userKey)
            currentUser = user
        }
    }

    private func loadCurrentUserFromDisk() {
        if let data = UserDefaults.standard.data(forKey: userKey),
           let user = try? JSONDecoder().decode(User.self, from: data) {
            currentUser = user
        }
    }
    
    /// Sync token to shared App Group for widget access
    private func syncTokenToWidget(_ token: String) {
        sharedDefaults?.set(token, forKey: "accessToken")
        sharedDefaults?.set(NetworkConfig.baseURL, forKey: "baseURL")
    }

    /// Fetch fresh /users/me and persist it
    func refreshCurrentUser() async throws {
        guard let token = accessToken else { return }
        let me = try await userService.fetchCurrentUser(accessToken: token)
        saveCurrentUser(me)
    }
}
