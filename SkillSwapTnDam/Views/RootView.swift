import SwiftUI

struct RootView: View {
    @EnvironmentObject private var auth: AuthenticationManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @ObservedObject private var callManager = CallManager.shared

    private var needsProfileSetup: Bool {
        guard let user = auth.currentUser else { return false }
        // Check if essential fields are missing
        let hasSkills = (user.skillsTeach?.isEmpty == false) || (user.skillsLearn?.isEmpty == false)
        let hasLocation = user.location != nil
        return !hasSkills || !hasLocation
    }

    var body: some View {
        let _ = print("📱 [RootView] body evaluated - isAuthenticated: \(auth.isAuthenticated), isCallActive: \(callManager.isCallActive)")
        
        ZStack {
            NavigationStack {
                  Group {
                    if !hasCompletedOnboarding {
                        let _ = print("📱 [RootView] Showing: OnboardingView")
                        OnboardingView(onFinish: { 
                            print("📱 [RootView] Onboarding completed")
                            hasCompletedOnboarding = true 
                        })
                    } else if !auth.isAuthenticated {
                        let _ = print("📱 [RootView] Showing: AuthGatewayView")
                        AuthGatewayView(onSuccess: {
                            print("📱 [RootView] Auth success callback")
                        })
                    } else if needsProfileSetup {
                        let _ = print("📱 [RootView] Showing: ProfileSetupView")
                        ProfileSetupView(onContinue: { 
                            print("📱 [RootView] Profile setup completed")
                            // Force refresh user to update the view state
                            Task {
                                try? await auth.refreshCurrentUser()
                            }
                        })
                    } else {
                        let _ = print("📱 [RootView] Showing: MainTabView")
                        MainTabView()
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
            }
            
            // Global Call Overlay
            if callManager.isCallActive {
                let _ = print("📱 [RootView] 📞 Showing ActiveCallView overlay!")
                ActiveCallView()
                    .transition(.move(edge: .bottom))
                    .zIndex(100)
            }
        }
        .onAppear {
            print("📱 [RootView] onAppear - CallManager.shared initialized")
            LocalNotificationManager.shared.requestAuthorizationIfNeeded()
        }
        .onChange(of: callManager.isCallActive) { newValue in
            print("📱 [RootView] 🔔 isCallActive changed to: \(newValue)")
        }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView().environmentObject(AuthenticationManager.shared)
    }
}
