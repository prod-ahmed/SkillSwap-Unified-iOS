import SwiftUI

@MainActor
struct MainTabView: View {
    @StateObject private var localization = LocalizationManager.shared
    @State private var selectedTab: AppTab = .discover
    @State private var showNotificationsSheet = false
    @State private var showProfileSheet = false
    @State private var showChatSheet = false
    @StateObject private var notificationsViewModel = NotificationsViewModel()

    @State private var isKeyboardVisible = false

    var body: some View {
        VStack(spacing: 0) {
            MainTopBar(
                title: selectedTab.title,
                unreadCount: notificationsViewModel.unreadCount,
                onNotificationsTap: { showNotificationsSheet = true },
                onProfileTap: { showProfileSheet = true },
                showChatSheet: $showChatSheet
            )
            Divider()
            Group {
                switch selectedTab {
                case .promos:
                    DiscoverView(initialSegment: .promos, showHeader: false)
                case .annonces:
                    DiscoverView(initialSegment: .annonces, showHeader: false)
                case .discover:
                    DiscoverView(initialSegment: .profils, showHeader: false)
                case .progress:
                    ProgressDashboardView()
                case .sessions:
                    SessionsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !isKeyboardVisible {
                AppTabBar(selected: $selectedTab)
                    .transition(.move(edge: .bottom))
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .sheet(isPresented: $showNotificationsSheet) {
            NotificationsView(viewModel: notificationsViewModel)
        }
        .sheet(isPresented: $showProfileSheet) {
            ProfileView()
        }
        .sheet(isPresented: $showChatSheet) {
            ChatView()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                isKeyboardVisible = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                isKeyboardVisible = false
            }
        }
        .task {
            print("📱 [MainTabView] ====== TASK STARTED ======")
            await notificationsViewModel.load()
            
            // Connect socket for calls
            if let userId = AuthenticationManager.shared.currentUser?.id {
                print("📱 [MainTabView] User ID found: \(userId)")
                
                // CRITICAL: Ensure CallManager is initialized BEFORE connecting socket
                // This registers the socket event handlers
                let _ = CallManager.shared
                print("📱 [MainTabView] CallManager.shared accessed - handlers should be registered")
                
                // Small delay to ensure handlers are registered
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                
                // Now connect the socket (will replay pending handlers)
                SocketService.shared.connect(userId: userId)
                print("📱 [MainTabView] Socket connect() called")
                print("📱 [MainTabView] ====== TASK COMPLETED ======")
            } else {
                print("📱 [MainTabView] ⚠️ No user ID found, cannot connect socket")
            }
        }
    }
}

private struct PlaceholderTabView: View {
    let title: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "hammer.fill")
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            Text("L'écran \(title) est en construction")
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}

private struct MainTopBar: View {
    let title: String
    let unreadCount: Int
    let onNotificationsTap: () -> Void
    let onProfileTap: () -> Void
    let showChatSheet: Binding<Bool>

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SkillSwap TN")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.title2.bold())
            }
            Spacer()
            HStack(spacing: 12) {
                topIconButton(systemName: "message.fill", showBadge: false, badgeValue: 0, action: { showChatSheet.wrappedValue = true })
                topIconButton(systemName: "bell.fill", showBadge: unreadCount > 0, badgeValue: unreadCount, action: onNotificationsTap)
                topIconButton(systemName: "person.crop.circle", showBadge: false, badgeValue: 0, action: onProfileTap)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color(.systemBackground).ignoresSafeArea(edges: .top))
    }

    private func topIconButton(systemName: String, showBadge: Bool, badgeValue: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: systemName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                    )
                if showBadge {
                    Text(badgeValue > 9 ? "9+" : "\(badgeValue)" )
                        .font(.caption2.bold())
                        .padding(4)
                        .background(Circle().fill(Color.red))
                        .foregroundColor(.white)
                        .offset(x: 6, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
