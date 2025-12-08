import SwiftUI

// MARK: - Deep Link Handler
class DeepLinkHandler: ObservableObject {
    static let shared = DeepLinkHandler()
    
    @Published var googleAuthCallback: Bool = false
    
    func handleURL(_ url: URL) {
        guard url.scheme == "skillswaptn" else { return }
        
        if url.host == "google" && url.path == "/callback" {
            // Google OAuth callback
            googleAuthCallback = true
            NotificationCenter.default.post(name: .googleAuthCallback, object: nil)
        }
    }
}

extension Notification.Name {
    static let googleAuthCallback = Notification.Name("googleAuthCallback")
}
