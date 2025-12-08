import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject private var auth: AuthenticationManager
    @StateObject private var localization = LocalizationManager.shared
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("appLanguage") private var appLanguage: String = "fr"
    @State private var isLoginPresented = false
    @State private var isLoading = false
    @State private var localError: String?
    @State private var rewards: RewardsSummary?
    @State private var rewardsError: String?
    @State private var isRewardsLoading = false
    @State private var showReferralModal = false
    @State private var showSettings = false
    @State private var showSessionsPourVous = false
    @State private var showWeeklyObjective = false
    @State private var showLanguagePicker = false
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var isUploadingAvatar = false
    @State private var avatarUploadError: String?
    
    // Moderation State
    @State private var showModerationAlert = false
    @State private var moderationMessage = ""

    private let userService = UserService()
    private let moderationService = ModerationService()

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                if let u = auth.currentUser {
                    ScrollView {
                        profileContent(u)
                    }
                } else if !auth.isAuthenticated {
                    VStack(spacing: 16) {
                        Spacer()
                        Text("Vous n'êtes pas connecté.")
                            .foregroundColor(.secondary)
                        Button {
                            isLoginPresented = true
                        } label: {
                            Text("Se connecter")
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                        }
                        Spacer()
                    }
                } else if isLoading {
                    ProgressView("Chargement du profil…")
                } else if let localError {
                    Text(localError).foregroundColor(.red)
                }
            }
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await ensureUserLoaded()
                await loadRewards()
            }
            .onChange(of: avatarPickerItem) { item in
                let _ = Task<Void, Never> {
                    await handleAvatarChange(item)
                }
            }
            .sheet(isPresented: $isLoginPresented) {
                LoginView(onSuccess: {
                    let _ = Task<Void, Never> {
                        await handleLoginSuccess()
                    }
                })
                .environmentObject(auth)
            }
            .sheet(isPresented: $showReferralModal) {
                ReferralModalView(rewards: rewards)
                    .environmentObject(auth)
            }
            .sheet(isPresented: $showSettings) {
                ProfileSettingsView()
                    .environmentObject(auth)
            }
            .sheet(isPresented: $showSessionsPourVous) {
                SessionsPourVousView()
            }
            .sheet(isPresented: $showWeeklyObjective) {
                WeeklyObjectiveView()
            }
            .sheet(isPresented: $showLanguagePicker) {
                LanguagePickerView(selectedLanguage: $appLanguage)
            }
            .alert("Contenu inapproprié", isPresented: $showModerationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(moderationMessage)
            }
        }
    }
    
    private var currentLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguage) ?? .french
    }

    private func ensureUserLoaded() async {
        guard auth.isAuthenticated else { return }
        if isLoading { return }
        isLoading = true
        localError = nil
        defer { isLoading = false }
        do {
            try await auth.refreshCurrentUser()
        } catch {
            localError = error.localizedDescription
        }
    }

    private func loadRewards() async {
        guard auth.isAuthenticated else { return }
        let token = await MainActor.run { auth.accessToken }
        guard let token else { return }
        isRewardsLoading = true
        rewardsError = nil
        defer { isRewardsLoading = false }
        do {
            let summary = try await userService.fetchRewards(accessToken: token)
            await MainActor.run {
                rewards = summary
            }
        } catch {
            rewardsError = error.localizedDescription
        }
    }

    private func uploadAvatar(from item: PhotosPickerItem?) async {
        guard let item else { return }
        if isUploadingAvatar { return }
        guard auth.isAuthenticated, let token = auth.accessToken else {
            await MainActor.run {
                avatarUploadError = "Connexion requise pour changer la photo."
            }
            return
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                return
            }

            await MainActor.run {
                isUploadingAvatar = true
                avatarUploadError = nil
            }
            
            // 🔍 Moderation Check
            print("🔍 Checking avatar for inappropriate content...")
            let moderationResult = try await moderationService.checkImage(imageData: data, accessToken: token)
            
            if !moderationResult.safe {
                await MainActor.run {
                    isUploadingAvatar = false
                    avatarPickerItem = nil // Reset picker
                    let categories = moderationResult.categories?.joined(separator: ", ") ?? "contenu inapproprié"
                    moderationMessage = "Votre photo de profil contient du contenu non autorisé: \(categories). Veuillez en choisir une autre."
                    showModerationAlert = true
                }
                return
            }

            let updated = try await userService.uploadProfileImage(
                accessToken: token,
                imageData: data,
                filename: "avatar.jpg"
            )

            await MainActor.run {
                auth.saveCurrentUser(updated)
            }
        } catch {
            await MainActor.run {
                avatarUploadError = error.localizedDescription
                // Also show alert for moderation errors if it was a moderation failure
                if error.localizedDescription.contains("moderation") {
                     moderationMessage = "Erreur lors de la vérification de l'image. Veuillez réessayer."
                     showModerationAlert = true
                }
            }
        }

        await MainActor.run {
            isUploadingAvatar = false
            avatarPickerItem = nil
        }
    }
    
    private func handleAvatarChange(_ item: PhotosPickerItem?) async {
        await uploadAvatar(from: item)
    }
    
    private func handleLoginSuccess() async {
        await ensureUserLoaded()
        await loadRewards()
    }
}

extension ProfileView {
    @ViewBuilder
    private func avatarImage(for user: User) -> some View {
        if let url = user.imageURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 128, height: 128)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 128, height: 128)
                case .failure:
                    placeholderAvatar
                        .frame(width: 128, height: 128)
                @unknown default:
                    placeholderAvatar
                        .frame(width: 128, height: 128)
                }
            }
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
        } else {
            placeholderAvatar
                .frame(width: 128, height: 128)
        }
    }

    private var placeholderAvatar: some View {
        Image(systemName: "person.crop.circle.fill")
            .resizable()
            .scaledToFit()
            .foregroundColor(Color(hex: "#FF6B35"))
    }
    
    @ViewBuilder
    private func profileContent(_ u: User) -> some View {
        VStack(spacing: 0) {
            // Gradient Header
            ZStack(alignment: .top) {
                LinearGradient(
                    colors: [Color(hex: "#FF6B35"), Color(hex: "#FFB347")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 200)
                
                HStack {
                    Spacer()
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 20))
                            .padding()
                    }
                }
            }
            
            VStack(spacing: 24) {
                // Avatar with Edit Button
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: 136, height: 136)
                        .overlay(avatarImage(for: u))
                    
                    PhotosPicker(selection: $avatarPickerItem, matching: .images) {
                        Circle()
                            .fill(Color(hex: "#FF6B35"))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "pencil")
                                    .foregroundColor(.white)
                                    .font(.system(size: 16))
                            )
                            .shadow(radius: 4)
                    }
                    .disabled(isUploadingAvatar)
                }
                .offset(y: -64)
                .padding(.bottom, -64)
                .overlay(alignment: .bottom) {
                    if isUploadingAvatar {
                        ProgressView()
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .offset(y: 16)
                    }
                }
                
                // Profile Info
                VStack(spacing: 8) {
                    Text(u.username)
                        .font(.title2.bold())
                    
                    if let location = u.locationDisplay, !location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.caption)
                            Text(location)
                                .font(.subheadline)
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 12) {
                        if let rating = u.ratingAvg, rating > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(Color(hex: "#FFD700"))
                                    .font(.caption)
                                Text(String(format: "%.1f", rating))
                                    .font(.subheadline)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color(hex: "#FFD700").opacity(0.2))
                            )
                        }
                        
                        if let xp = u.xp, xp > 0 {
                            Text("\(xp) XP")
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color(.secondarySystemBackground))
                                )
                        }
                    }
                    .padding(.top, 8)
                }
                
                // Stats Cards
                HStack(spacing: 12) {
                    if let xp = u.xp {
                        ProfileStatCard(value: "\(xp)", label: "XP")
                    }
                    if let credits = u.credits {
                        ProfileStatCard(value: "\(credits)", label: "Crédits")
                    }
                    if let rating = u.ratingAvg, rating > 0 {
                        ProfileStatCard(value: String(format: "%.1f", rating), label: "Note")
                    }
                }
                .padding(.horizontal)
                
                VStack(spacing: 16) {
                    if let avatarUploadError {
                        Text(avatarUploadError)
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                    // Skills to Teach
                    if let skillsTeach = u.skillsTeach, !skillsTeach.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Compétences enseignées")
                                .font(.headline)
                            
                            ChipFlowLayout(spacing: 8) {
                                ForEach(skillsTeach, id: \.self) { skill in
                                    Text(skill)
                                        .font(.subheadline)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(Color(hex: "#FF6B35").opacity(0.1))
                                        )
                                        .foregroundColor(Color(hex: "#FF6B35"))
                                        .overlay(
                                            Capsule()
                                                .stroke(Color(hex: "#FF6B35").opacity(0.2), lineWidth: 1)
                                        )
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 28)
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                        )
                    }
                    
                    // Skills to Learn
                    if let skillsLearn = u.skillsLearn, !skillsLearn.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Compétences en apprentissage")
                                .font(.headline)
                            
                            ChipFlowLayout(spacing: 8) {
                                ForEach(skillsLearn, id: \.self) { skill in
                                    Text(skill)
                                        .font(.subheadline)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(Color(hex: "#40E0D0").opacity(0.1))
                                        )
                                        .foregroundColor(Color(hex: "#40E0D0"))
                                        .overlay(
                                            Capsule()
                                                .stroke(Color(hex: "#40E0D0").opacity(0.2), lineWidth: 1)
                                        )
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 28)
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                        )
                    }
                    
                    // Badges
                    if let badges = u.badges, !badges.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Badges obtenus")
                                .font(.headline)
                            
                            ChipFlowLayout(spacing: 8) {
                                ForEach(badges, id: \.self) { badge in
                                    HStack(spacing: 4) {
                                        Text("⭐")
                                        Text(badge.rawValue.capitalized)
                                    }
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(Color(hex: "#FFD700").opacity(0.1))
                                    )
                                    .foregroundColor(Color(hex: "#FFD700"))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color(hex: "#FFD700").opacity(0.3), lineWidth: 1)
                                    )
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 28)
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                        )
                    }

                    // MARK: - Action Buttons Section
                    VStack(spacing: 12) {
                        // Dark Mode Toggle
                        ProfileActionButton(
                            icon: isDarkMode ? "moon.fill" : "sun.max.fill",
                            title: localization.localized(.darkMode),
                            iconColor: isDarkMode ? .purple : .orange,
                            showToggle: true,
                            isToggleOn: $isDarkMode
                        )
                        
                        // Language Selector
                        ProfileActionButton(
                            icon: "globe",
                            title: localization.localized(.language),
                            iconColor: .cyan,
                            showChevron: true,
                            trailingText: currentLanguage.flag + " " + currentLanguage.displayName
                        ) {
                            showLanguagePicker = true
                        }
                        
                        // Weekly Objective
                        ProfileActionButton(
                            icon: "target",
                            title: localization.localized(.weeklyObjectiveTitle),
                            iconColor: Color(hex: "#00A8A8"),
                            showChevron: true
                        ) {
                            showWeeklyObjective = true
                        }
                        
                        // Sessions pour vous
                        ProfileActionButton(
                            icon: "sparkles",
                            title: localization.localized(.sessionsForYou),
                            iconColor: .orange,
                            showChevron: true
                        ) {
                            showSessionsPourVous = true
                        }
                        
                        // Referral
                        ProfileActionButton(
                            icon: "gift.fill",
                            title: localization.localized(.referFriend),
                            iconColor: Color(hex: "#FF6B35"),
                            showChevron: true
                        ) {
                            showReferralModal = true
                        }
                        
                        // Share Profile
                        ShareLink(item: "Rejoins-moi sur SkillSwapTN !") {
                            ProfileActionButtonLabel(
                                icon: "square.and.arrow.up",
                                title: localization.localized(.shareProfile),
                                iconColor: .blue,
                                showChevron: true
                            )
                        }
                        
                        // My Annonces
                        NavigationLink {
                            MyAnnoncesView()
                                .environmentObject(auth)
                        } label: {
                            ProfileActionButtonLabel(
                                icon: "megaphone.fill",
                                title: localization.localized(.myAnnouncements),
                                iconColor: .green,
                                showChevron: true
                            )
                        }
                        
                        // My Promos
                        NavigationLink {
                            MyPromosView()
                                .environmentObject(auth)
                        } label: {
                            ProfileActionButtonLabel(
                                icon: "tag.fill",
                                title: localization.localized(.myPromos),
                                iconColor: .pink,
                                showChevron: true
                            )
                        }
                        
                        // Settings
                        ProfileActionButton(
                            icon: "gearshape.fill",
                            title: localization.localized(.settings),
                            iconColor: .gray,
                            showChevron: true
                        ) {
                            showSettings = true
                        }
                    }
                    
                    // Logout Button
                    Button(role: .destructive) {
                        auth.signOut()
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.title3)
                            Text(localization.localized(.logout))
                                .font(.headline)
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.red.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
    }
}

// MARK: - Supporting Views

struct ProfileStatCard: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2.bold())
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}


struct ReferralModalView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var auth: AuthenticationManager
    let rewards: RewardsSummary?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                if let user = auth.currentUser {
                    VStack(spacing: 16) {
                        Text("Votre code de parrainage")
                            .font(.headline)
                        
                        // Use rewards code if available, otherwise use user's code
                        if let code = rewards?.codeParainnage ?? user.codeParainnage {
                            Text(code)
                                .font(.system(.title, design: .monospaced))
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color(hex: "#FF6B35"), lineWidth: 2)
                                )
                            
                            if let rewards = rewards {
                                Text("Invitations restantes: \(rewards.remainingSlots)/\(rewards.maxParannaige)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } else if let nombreParainnage = user.nombreParainnage,
                                      let maxParannaige = user.maxParannaige {
                                Text("Invitations restantes: \(maxParannaige - nombreParainnage)/\(maxParannaige)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            ShareLink(
                                item: "Rejoins-moi sur SkillSwapTN avec le code \(code) et gagne 10 XP !"
                            ) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Partager mon code")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "#FF6B35"), Color(hex: "#FFB347")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                            }
                        } else {
                            Text("Code de parrainage non disponible")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                } else {
                    Text("Veuillez vous connecter pour voir votre code de parrainage")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Parrainage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Profile Action Button
struct ProfileActionButton: View {
    let icon: String
    let title: String
    let iconColor: Color
    var showChevron: Bool = false
    var showToggle: Bool = false
    var trailingText: String? = nil
    @Binding var isToggleOn: Bool
    var action: (() -> Void)?
    
    init(icon: String, title: String, iconColor: Color, showChevron: Bool = false, showToggle: Bool = false, trailingText: String? = nil, isToggleOn: Binding<Bool> = .constant(false), action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.iconColor = iconColor
        self.showChevron = showChevron
        self.showToggle = showToggle
        self.trailingText = trailingText
        self._isToggleOn = isToggleOn
        self.action = action
    }
    
    var body: some View {
        Button {
            if showToggle {
                isToggleOn.toggle()
            } else {
                action?()
            }
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if let trailingText = trailingText {
                    Text(trailingText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if showToggle {
                    Toggle("", isOn: $isToggleOn)
                        .labelsHidden()
                        .tint(Color(hex: "#FF6B35"))
                } else if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Profile Action Button Label (for NavigationLink/ShareLink)
struct ProfileActionButtonLabel: View {
    let icon: String
    let title: String
    let iconColor: Color
    var showChevron: Bool = false
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            Text(title)
                .font(.body.weight(.medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Language Picker View
struct LanguagePickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedLanguage: String
    @StateObject private var localization = LocalizationManager.shared
    
    var body: some View {
        NavigationView {
            List {
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        selectedLanguage = language.rawValue
                        localization.currentLanguage = language
                        dismiss()
                    } label: {
                        HStack(spacing: 16) {
                            Text(language.flag)
                                .font(.title)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(language.displayName)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(languageSubtitle(for: language))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedLanguage == language.rawValue {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color(hex: "#FF6B35"))
                                    .font(.title2)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(localization.localized(.language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localization.localized(.close)) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func languageSubtitle(for language: AppLanguage) -> String {
        switch language {
        case .french: return "French"
        case .english: return "Anglais"
        case .arabic: return "Arabic / عربي"
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthenticationManager.shared)
}
