import SwiftUI
import UIKit

// MARK: - Theme Colors
// MARK: - Theme Colors
extension Color {
    static let skillCoral = Color(hex: "FF6B6B")
    static let skillCoralLight = Color(hex: "FF8E8E")
    static let skillTurquoise = Color(hex: "4ECDC4")
    static let skillGold = Color(hex: "FFD166")
}

struct DiscoverView: View {
    @StateObject private var vm = DiscoverViewModel()
    @StateObject private var localization = LocalizationManager.shared
    
    enum ActiveSheet: Identifiable {
        case annonce
        case promo
        
        var id: Int {
            switch self {
            case .annonce: return 0
            case .promo: return 1
            }
        }
    }
    
    @State private var activeSheet: ActiveSheet?
    @State private var selectedAnnonce: Annonce?
    @State private var selectedPromo: Promo?
    @State private var selectedProfile: DiscoverProfile?
    @State private var showChatWithThreadId: String?
    
    // MARK: - Promos search & filters
    @State private var searchPromos: String = ""
    @State private var showOnlyActivePromos: Bool = false
    @State private var minDiscountPromos: Int = 0
    @State private var sortPromos: PromoSortOption = .endDateAsc

    // MARK: - Annonces search & filters
    @State private var searchAnnonces: String = ""
    @State private var selectedAnnonceCategory: String?
    @State private var selectedAnnonceCity: String?
    @State private var withImageOnlyAnnonces: Bool = false
    @State private var sortAnnonces: AnnonceSortOption = .titleAsc

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Gradient Header
                headerView
                
                // Content
                if vm.isLoading {
                    Spacer()
                    ProgressView("Chargement…")
                    Spacer()
                } else if let err = vm.errorMessage {
                    Spacer()
                    Text(err)
                        .foregroundColor(.red)
                        .padding()
                    Spacer()
                } else {
                    contentForCurrentSegment
                        .padding(.top, 16)
                }
            }
        }
        .navigationBarHidden(true) // Hide default nav bar to use custom header
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .annonce:
                CreateAnnonceView()
            case .promo:
                CreatePromoView { newPromo in
                    vm.promos.append(newPromo)
                }
            }
        }
        .sheet(item: $selectedAnnonce) { annonce in
            NavigationStack {
                AnnonceDetailView(annonce: annonce)
            }
        }
        .sheet(item: $selectedPromo) { promo in
            NavigationStack {
                PromoDetailView(promo: promo)
            }
        }
        .sheet(item: $selectedProfile) { profile in
            NavigationStack {
                ProfileDetailView(profile: profile)
            }
        }
        .sheet(isPresented: Binding(
            get: { showChatWithThreadId != nil },
            set: { if !$0 { showChatWithThreadId = nil } }
        )) {
            if let threadId = showChatWithThreadId {
                NavigationStack {
                    ChatView(startInList: false, initialThreadId: threadId)
                }
            }
        }
        .overlay {
            if vm.showMatchPopup, let matchedUser = vm.matchedUser {
                MatchPopupView(user: matchedUser) {
                    vm.dismissMatch()
                } onMessage: {
                    Task {
                        let threadId = await vm.startConversationAndGetThreadId(with: matchedUser.id)
                        vm.dismissMatch()
                        if let threadId = threadId {
                            showChatWithThreadId = threadId
                        }
                    }
                }
            }
        }
        .task {
            await vm.loadForCurrentSegment()
        }
        .onChange(of: vm.segment) { _ in
            Task { await vm.loadForCurrentSegment() }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 16) {
            // Top Bar
            HStack {
                Text(localization.localized(.discover))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Filter/Menu Button
                Menu {
                    if vm.segment == .annonces {
                        annoncesMenuContent
                    } else if vm.segment == .promos {
                        promosMenuContent
                    } else {
                        Text(localization.localized(.filtersComingSoon))
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
                
                if vm.segment != .profils {
                    Button {
                        activeSheet = vm.segment == .annonces ? .annonce : .promo
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.skillCoral)
                            .padding(10)
                            .background(Color.white)
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 60) // Safe area adjustment
            
            // Tabs
            HStack(spacing: 0) {
                tabButton(title: localization.localized(.profiles), segment: .profils, icon: "person.2.fill")
                tabButton(title: localization.localized(.announcements), segment: .annonces, icon: "megaphone.fill")
                tabButton(title: localization.localized(.promos), segment: .promos, icon: "tag.fill")
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(
            LinearGradient(
                colors: [.skillCoral, .skillCoralLight],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(32, corners: [.bottomLeft, .bottomRight])
        .edgesIgnoringSafeArea(.top)
    }
    
    private func tabButton(title: String, segment: DiscoverViewModel.Segment, icon: String) -> some View {
        Button {
            withAnimation {
                vm.segment = segment
            }
        } label: {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                    Text(title)
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(vm.segment == segment ? .white : .white.opacity(0.6))
                
                // Indicator
                Capsule()
                    .fill(vm.segment == segment ? .white : .clear)
                    .frame(height: 3)
                    .padding(.horizontal, 16)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Content
    
    @State private var offset: CGSize = .zero
    @State private var angle: Double = 0
    
    @ViewBuilder
    private var contentForCurrentSegment: some View {
        switch vm.segment {
        case .profils:
            if let user = vm.currentUser {
                VStack {
                    Spacer()
                    swipeProfileCard(user: user)
                        .offset(x: offset.width, y: 0)
                        .rotationEffect(.degrees(angle))
                        .gesture(
                            DragGesture()
                                .onChanged { gesture in
                                    offset = gesture.translation
                                    angle = Double(gesture.translation.width / 20)
                                }
                                .onEnded { gesture in
                                    if abs(gesture.translation.width) > 150 {
                                        let isLike = gesture.translation.width > 0
                                        let direction = isLike ? 1 : -1
                                        withAnimation(.easeIn(duration: 0.2)) {
                                            offset.width = CGFloat(direction * 500)
                                        }
                                        
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                            if isLike {
                                                Task { await vm.likeUser() }
                                            } else {
                                                vm.declineUser()
                                            }
                                            offset = .zero
                                            angle = 0
                                        }
                                    } else {
                                        withAnimation(.spring()) {
                                            offset = .zero
                                            angle = 0
                                        }
                                    }
                                }
                        )
                    Spacer()
                    actionButtons
                        .padding(.bottom, 30)
                }
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "person.slash.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.3))
                        .padding()
                    Text(localization.localized(.noProfiles))
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    if !vm.likedUserIds.isEmpty || !vm.declinedUserIds.isEmpty {
                        Button {
                            Task { await vm.loadForCurrentSegment() }
                        } label: {
                            Text(localization.localized(.reloadProfiles))
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.skillCoral)
                                .cornerRadius(12)
                        }
                        .padding(.top, 20)
                    }
                    Spacer()
                }
            }
            
        case .annonces:
            annoncesList
            
        case .promos:
            promosList
        }
    }
    
    // MARK: - Swipe Profile Card
    
    private func swipeProfileCard(user: DiscoverProfile) -> some View {
        VStack(spacing: 0) {
            // Image Section
            ZStack(alignment: .bottom) {
                // Profile Image
                GeometryReader { geo in
                    if let url = URL(string: user.image ?? "") {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Color.gray.opacity(0.2)
                        }
                    } else {
                        Color.gray.opacity(0.2)
                        Image(systemName: "person.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.gray)
                    }
                }
                .frame(height: 400)
                .clipped()
                
                // Overlays
                VStack {
                    HStack {
                        // Online Status
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text(localization.localized(.online))
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        
                        Spacer()
                        
                        // Distance
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundColor(.skillCoral)
                            Text("2.5km") // Mock data for now
                                .font(.caption.bold())
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.9))
                        .clipShape(Capsule())
                    }
                    .padding()
                    
                    Spacer()
                }
            }
            .frame(height: 400)
            
            // Info Section
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(user.name), \(user.age)")
                            .font(.title)
                            .bold()
                        Text(user.city)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Reliability Score
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.skillGold)
                        Text("98%") // Mock
                            .fontWeight(.bold)
                            .foregroundColor(.skillGold)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.skillGold.opacity(0.1))
                    .clipShape(Capsule())
                }
                
                // Bio
                Text(user.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                
                // Skills
                VStack(alignment: .leading, spacing: 12) {
                    // Teaches
                    VStack(alignment: .leading, spacing: 8) {
                        Text(localization.localized(.teaches))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        GridFlowLayout(spacing: 8) {
                            ForEach(user.teaches, id: \.self) { skill in
                                Text(skill)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.skillCoral.opacity(0.1))
                                    .foregroundColor(.skillCoral)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    
                    // Learns
                    VStack(alignment: .leading, spacing: 8) {
                        Text(localization.localized(.learns))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        GridFlowLayout(spacing: 8) {
                            ForEach(user.learns, id: \.self) { skill in
                                Text(skill)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.skillTurquoise.opacity(0.1))
                                    .foregroundColor(.skillTurquoise)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .padding(24)
            .background(Color.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        .padding(.horizontal)
        .onTapGesture {
            selectedProfile = user
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 30) {
            // Pass Button
            Button {
                withAnimation {
                    offset.width = -500
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    vm.declineUser()
                    offset = .zero
                    angle = 0
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.red)
                    .frame(width: 64, height: 64)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            }
            
            // Message Button
            Button {
                Task {
                    if let user = vm.currentUser {
                        let success = await vm.startConversation(with: user.id)
                        if success {
                            print("Conversation started with \(user.name)")
                        }
                    }
                }
            } label: {
                Image(systemName: "message.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.skillTurquoise)
                    .clipShape(Circle())
                    .shadow(color: .skillTurquoise.opacity(0.4), radius: 10, x: 0, y: 5)
            }
            
            // Like Button
            Button {
                withAnimation {
                    offset.width = 500
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    Task { await vm.likeUser() }
                    offset = .zero
                    angle = 0
                }
            } label: {
                Image(systemName: "heart.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 64, height: 64)
                    .background(
                        LinearGradient(
                            colors: [.skillCoral, .skillCoralLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                    .shadow(color: .skillCoral.opacity(0.4), radius: 10, x: 0, y: 5)
            }
        }
    }
    
    // MARK: - Annonces List
    
    private var annoncesList: some View {
        let items = displayedAnnonces
        return VStack(spacing: 12) {
            searchBar(text: $searchAnnonces, placeholder: localization.localized(.searchAnnouncement))
                .padding(.horizontal)
            
            if items.isEmpty {
                Spacer()
                Text(localization.localized(.noAnnouncements))
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(items) { annonce in
                            Button {
                                selectedAnnonce = annonce
                            } label: {
                                annonceCard(annonce)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
        }
    }
    
    // MARK: - Promos List
    
    private var promosList: some View {
        let items = displayedPromos
        return VStack(spacing: 12) {
            searchBar(text: $searchPromos, placeholder: localization.localized(.searchPromo))
                .padding(.horizontal)
            
            if items.isEmpty {
                Spacer()
                Text(localization.localized(.noPromos))
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(items) { promo in
                            Button {
                                selectedPromo = promo
                            } label: {
                                promoCard(promo)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
        }
    }
    
    // MARK: - Menus
    
    private var annoncesMenuContent: some View {
        Group {
            Section(localization.localized(.sort)) {
                Picker(localization.localized(.sort), selection: $sortAnnonces) {
                    Text("Titre (A→Z)").tag(AnnonceSortOption.titleAsc)
                    Text("Titre (Z→A)").tag(AnnonceSortOption.titleDesc)
                }
            }
            Section(localization.localized(.filters)) {
                Toggle(localization.localized(.withImageOnly), isOn: $withImageOnlyAnnonces)
                Picker(localization.localized(.category), selection: $selectedAnnonceCategory) {
                    Text("Toutes").tag(nil as String?)
                    ForEach(availableAnnonceCategories, id: \.self) { cat in
                        Text(cat).tag(Optional(cat))
                    }
                }
                Picker(localization.localized(.city), selection: $selectedAnnonceCity) {
                    Text("Toutes").tag(nil as String?)
                    ForEach(availableAnnonceCities, id: \.self) { city in
                        Text(city).tag(Optional(city))
                    }
                }
            }
            Button(localization.localized(.resetFilters)) {
                resetAnnonceFilters()
            }
        }
    }
    
    private var promosMenuContent: some View {
        Group {
            Section(localization.localized(.sort)) {
                Picker(localization.localized(.sort), selection: $sortPromos) {
                    Text("Date de fin (proche)").tag(PromoSortOption.endDateAsc)
                    Text("Date de fin (loin)").tag(PromoSortOption.endDateDesc)
                    Text("Réduction (max)").tag(PromoSortOption.discountDesc)
                }
            }
            Section(localization.localized(.filters)) {
                Toggle(localization.localized(.activeOnly), isOn: $showOnlyActivePromos)
                Picker(localization.localized(.minDiscount), selection: $minDiscountPromos) {
                    Text("Toutes").tag(0)
                    Text("≥ 10%").tag(10)
                    Text("≥ 20%").tag(20)
                    Text("≥ 30%").tag(30)
                    Text("≥ 40%").tag(40)
                    Text("≥ 50%").tag(50)
                    Text("≥ 60%").tag(60)
                    Text("≥ 70%").tag(70)
                    Text("≥ 80%").tag(80)
                    Text("≥ 90%").tag(90)
                }
            }
            Button(localization.localized(.resetFilters)) {
                resetPromoFilters()
            }
        }
    }
    
    // MARK: - Cards (Annonce & Promo)
    
    func annonceCard(_ annonce: Annonce) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Image
            if let url = annonce.imageURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Color.gray.opacity(0.1)
                    }
                }
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                Color.gray.opacity(0.1)
                    .frame(height: 120)
                    .cornerRadius(16)
            }

            Text(annonce.title)
                .font(.headline)

            Text(annonce.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)

            HStack {
                if let c = annonce.city, !c.isEmpty {
                    Label(c, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                }
                Spacer()
                if let cat = annonce.category, !cat.isEmpty {
                    Text(cat)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func promoCard(_ promo: Promo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Image
            if let url = promo.imageURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Color.gray.opacity(0.1)
                    }
                }
                .frame(height: 150)
                .clipped()
                .cornerRadius(16)
            } else {
                Color.gray.opacity(0.1)
                    .frame(height: 120)
                    .cornerRadius(16)
            }
            
            Text(promo.title)
                .font(.headline)
            
            Text(promo.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Text("-\(promo.discount)%")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .foregroundColor(.green)
                    .clipShape(Capsule())
                
                Spacer()
                
                Text(String(format: localization.localized(.until), formattedDate(for: promo)))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Helpers
    
    private func formattedDate(for promo: Promo) -> String {
        if let date = promo.validUntilDate {
            let f = DateFormatter()
            f.locale = Locale(identifier: LocalizationManager.shared.currentLanguage.rawValue)
            f.dateStyle = .medium
            f.timeStyle = .none
            return f.string(from: date)
        } else {
            return promo.validUntil
        }
    }

    private func searchBar(text: Binding<String>, placeholder: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
            if !text.wrappedValue.isEmpty {
                Button {
                    text.wrappedValue = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    // MARK: - Filter Logic (Same as before)

    private enum PromoSortOption: String, CaseIterable, Identifiable {
        case endDateAsc
        case endDateDesc
        case discountDesc
        var id: String { rawValue }
    }

    private var displayedPromos: [Promo] {
        var items = vm.promos
        if !searchPromos.isEmpty {
            let q = searchPromos.lowercased()
            items = items.filter {
                $0.title.lowercased().contains(q) || $0.description.lowercased().contains(q) || ($0.promoCode?.lowercased().contains(q) ?? false)
            }
        }
        if showOnlyActivePromos {
            let now = Date()
            items = items.filter { promo in
                if let d = promo.validUntilDate { return d >= now } else { return true }
            }
        }
        if minDiscountPromos > 0 {
            items = items.filter { $0.discount >= minDiscountPromos }
        }
        switch sortPromos {
            case .endDateAsc: items.sort { ($0.validUntilDate ?? .distantFuture) < ($1.validUntilDate ?? .distantFuture) }
            case .endDateDesc: items.sort { ($0.validUntilDate ?? .distantPast) > ($1.validUntilDate ?? .distantPast) }
            case .discountDesc: items.sort { $0.discount > $1.discount }
        }
        return items
    }

    private func resetPromoFilters() {
        searchPromos = ""; showOnlyActivePromos = false; minDiscountPromos = 0; sortPromos = .endDateAsc
    }

    private enum AnnonceSortOption: String, CaseIterable, Identifiable {
        case titleAsc, titleDesc
        var id: String { rawValue }
    }

    private var availableAnnonceCategories: [String] {
        let set = Set(vm.annonces.compactMap { $0.category?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        return Array(set).sorted()
    }

    private var availableAnnonceCities: [String] {
        let set = Set(vm.annonces.compactMap { $0.city?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        return Array(set).sorted()
    }

    private var displayedAnnonces: [Annonce] {
        var items = vm.annonces
        if !searchAnnonces.isEmpty {
            let q = searchAnnonces.lowercased()
            items = items.filter {
                $0.title.lowercased().contains(q) || $0.description.lowercased().contains(q) || ($0.city?.lowercased().contains(q) ?? false) || ($0.category?.lowercased().contains(q) ?? false)
            }
        }
        if let cat = selectedAnnonceCategory, !cat.isEmpty { items = items.filter { $0.category == cat } }
        if let city = selectedAnnonceCity, !city.isEmpty { items = items.filter { $0.city == city } }
        if withImageOnlyAnnonces {
            items = items.filter { ann in ann.imageURL != nil }
        }
        switch sortAnnonces {
        case .titleAsc: items.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .titleDesc: items.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }
        }
        return items
    }

    private func resetAnnonceFilters() {
        searchAnnonces = ""; selectedAnnonceCategory = nil; selectedAnnonceCity = nil; withImageOnlyAnnonces = false; sortAnnonces = .titleAsc
    }
}

// MARK: - Corner Radius Helper
struct CornerRadiusShape: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(CornerRadiusShape(radius: radius, corners: corners))
    }
}

// MARK: - Flow Layout Helper
struct GridFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = flow(proposal: proposal, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = flow(proposal: proposal, subviews: subviews, spacing: spacing)
        for (index, point) in result.points.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private func flow(proposal: ProposedViewSize, subviews: Subviews, spacing: CGFloat) -> (size: CGSize, points: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var points: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxWidthUsed: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            points.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxWidthUsed = max(maxWidthUsed, currentX)
        }

        return (CGSize(width: maxWidthUsed, height: currentY + lineHeight), points)
    }
}

// MARK: - Match Popup View
struct MatchPopupView: View {
    let user: DiscoverProfile
    let onDismiss: () -> Void
    let onMessage: () -> Void
    
    @State private var animateHearts = false
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            // Floating hearts animation
            ForEach(0..<12, id: \.self) { index in
                Image(systemName: "heart.fill")
                    .font(.system(size: CGFloat.random(in: 20...40)))
                    .foregroundColor([Color.skillCoral, Color.pink, Color.red].randomElement()!)
                    .offset(
                        x: CGFloat.random(in: -150...150),
                        y: animateHearts ? CGFloat.random(in: -400...(-200)) : 200
                    )
                    .opacity(animateHearts ? 0 : 1)
                    .animation(
                        .easeOut(duration: Double.random(in: 1.5...2.5))
                        .delay(Double(index) * 0.1),
                        value: animateHearts
                    )
            }
            
            VStack(spacing: 24) {
                // "It's a Match!" text
                Text(LocalizationManager.shared.localized(.itsAMatch) + " 🎉")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .skillCoral, radius: 10)
                
                Text(String(format: LocalizationManager.shared.localized(.youAndUserInterested), user.name))
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // User avatar
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.skillCoral, .skillCoralLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 140, height: 140)
                    
                    if let imageUrl = user.image, let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Image(systemName: "person.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.white)
                        }
                        .frame(width: 130, height: 130)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                    }
                }
                .shadow(color: .skillCoral.opacity(0.5), radius: 20)
                
                Text(user.name)
                    .font(.title2.bold())
                    .foregroundColor(.white)
                
                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        onMessage()
                    } label: {
                        HStack {
                            Image(systemName: "message.fill")
                            Text(LocalizationManager.shared.localized(.sendMessage))
                        }
                        .font(.headline)
                        .foregroundColor(.skillCoral)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(25)
                    }
                    
                    Button {
                        onDismiss()
                    } label: {
                        Text(LocalizationManager.shared.localized(.keepDiscovering))
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.9))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(25)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
            }
        }
        .onAppear {
            withAnimation {
                animateHearts = true
            }
        }
    }
}

#Preview {
    DiscoverView()
        .environmentObject(AuthenticationManager.shared)
}
