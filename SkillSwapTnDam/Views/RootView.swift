import SwiftUI

struct RootView: View {
    @EnvironmentObject private var auth: AuthenticationManager
    @State private var hasCompletedOnboarding: Bool = false
    @State private var needsProfileSetup: Bool = true
    @ObservedObject private var callManager = CallManager.shared

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
                            needsProfileSetup = false 
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
