import SwiftUI

struct AnnonceDetailView: View {
    let annonce: Annonce
    @State private var showChat = false
    @State private var showBooking = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerImage
                VStack(alignment: .leading, spacing: 16) {
                    Text(annonce.title)
                        .font(.title3.bold())
                    Text(annonce.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                metaGrid
                if let created = annonce.createdAtDate {
                    timelineSection(created: created, updated: annonce.updatedAtDate)
                }
                EntityCTASection(
                    primaryLabel: "Envoyer un message",
                    secondaryLabel: "Réserver une session",
                    onPrimary: { showChat = true },
                    onSecondary: { showBooking = true }
                )
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Annonce")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showChat) {
            NavigationStack { ChatView(startInList: true) }
        }
        .sheet(isPresented: $showBooking) {
            SessionBookingSheet(defaultTopic: annonce.title, preferredMentor: annonce.category)
        }
    }

    private var headerImage: some View {
        Group {
            if let image = AnnonceImageStore.shared.loadImage(for: annonce.id) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let urlString = annonce.imageUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        placeholder
                    case .empty:
                        ProgressView().frame(maxWidth: .infinity, minHeight: 160)
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 8) {
                if let cat = annonce.category, !cat.isEmpty {
                    EntityBadge(text: cat, icon: "tag.fill")
                }
                if annonce.isNew {
                    EntityBadge(text: "Nouveau", icon: "sparkles", gradient: [.orange, .pink])
                }
            }
            .padding(16)
        }
        .overlay(alignment: .bottomLeading) {
            if let city = annonce.city, !city.isEmpty {
                EntityBadge(text: city, icon: "mappin.and.ellipse", gradient: [.white.opacity(0.9), .white.opacity(0.85)], textColor: .black)
                    .padding(16)
            }
        }
    }

    private var placeholder: some View {
        Color(.systemGray5)
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .overlay {
                Image(systemName: "photo")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(.secondary)
            }
    }

    private var metaGrid: some View {
        VStack(spacing: 12) {
            HStack {
                infoTile(title: "Ville", value: annonce.city ?? "—", icon: "building.2.fill")
                infoTile(title: "Catégorie", value: annonce.category ?? "—", icon: "square.grid.2x2")
            }
            HStack {
                infoTile(title: "Auteur", value: annonce.user?.username ?? "Communauté", icon: "person.crop.circle")
                infoTile(title: "Identifiant", value: annonce.id.prefix(6) + "…", icon: "number")
            }
        }
    }

    private func infoTile(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.footnote)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func timelineSection(created: Date, updated: Date?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Historique", systemImage: "clock.fill")
                .font(.subheadline.bold())
            Text("Créée le \(formatted(date: created))")
                .foregroundColor(.secondary)
            if let updated {
                Text("Mise à jour le \(formatted(date: updated))")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func formatted(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct PromoDetailView: View {
    let promo: Promo
    @State private var showChat = false
    @State private var showBooking = false
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                promoImage
                VStack(alignment: .leading, spacing: 12) {
                    Text(promo.title)
                        .font(.title3.bold())
                    Text(promo.description)
                        .foregroundColor(.secondary)
                }
                promoHighlight
                if let code = promo.promoCode {
                    promoCodeCard(code: code)
                }
                EntityCTASection(
                    primaryLabel: "Envoyer un message",
                    secondaryLabel: "Réserver une session",
                    onPrimary: { showChat = true },
                    onSecondary: { showBooking = true }
                )
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Promotion")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showChat) {
            NavigationStack { ChatView(startInList: true) }
        }
        .sheet(isPresented: $showBooking) {
            SessionBookingSheet(defaultTopic: promo.title, preferredMentor: nil)
        }
        .overlay(alignment: .bottom) {
            if copied {
                CopyToast(message: "Code copié !")
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { copied = false }
                        }
                    }
            }
        }
    }

    private var promoImage: some View {
        Group {
            if let image = PromoImageStore.shared.loadImage(for: promo.id) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let urlString = promo.imageUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Color(.systemGray5)
                    case .empty:
                        ProgressView().frame(maxWidth: .infinity, minHeight: 160)
                    @unknown default:
                        Color(.systemGray5)
                    }
                }
            } else {
                Color(.systemGray5)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(alignment: .topTrailing) {
            discountBadge
        }
    }

    private var discountBadge: some View {
        VStack(alignment: .trailing) {
            Text("-\(promo.discount)%")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color(hex: "#FF6B35"))
                )
        }
        .padding(16)
    }

    private var promoHighlight: some View {
        VStack(spacing: 16) {
            HStack {
                Label("Catégorie", systemImage: "tag")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(promo.validUntilDate.map { relativeExpiry(from: $0) } ?? "Bientôt")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }
            HStack(spacing: 16) {
                detailChip(title: "Réduction", value: "-\(promo.discount)%", icon: "percent")
                detailChip(title: "Valide jusqu’au", value: formattedDate(), icon: "calendar")
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func promoCodeCard(code: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Code promotionnel")
                .font(.subheadline.bold())
            HStack {
                Text(code)
                    .font(.title3.monospacedDigit())
                Spacer()
                Button {
                    UIPasteboard.general.string = code
                    withAnimation { copied = true }
                } label: {
                    Label("Copier", systemImage: "doc.on.doc")
                        .font(.callout.bold())
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private func detailChip(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.footnote)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formattedDate() -> String {
        if let valid = promo.validUntilDate {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "fr_FR")
            formatter.dateStyle = .medium
            return formatter.string(from: valid)
        }
        return promo.validUntil
    }

    private func relativeExpiry(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct ProfileDetailView: View {
    let profile: DiscoverProfile
    @State private var showChat = false
    @State private var showBooking = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                VStack(alignment: .leading, spacing: 12) {
                    Text("À propos")
                        .font(.headline)
                    Text(profile.description)
                        .foregroundColor(.secondary)
                }
                skillsSection
                meta
                EntityCTASection(
                    primaryLabel: "Envoyer un message",
                    secondaryLabel: "Réserver une session",
                    onPrimary: { showChat = true },
                    onSecondary: { showBooking = true }
                )
            }
            .padding()
        }
        .navigationTitle(profile.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showChat) {
            NavigationStack { ChatView(startInList: true) }
        }
        .sheet(isPresented: $showBooking) {
            SessionBookingSheet(defaultTopic: profile.teaches.first ?? profile.description, preferredMentor: profile.name)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#FF6B35").opacity(0.15))
                        .frame(width: 68, height: 68)
                    Text(profile.name.split(separator: " ").compactMap { $0.first }.prefix(2).map(String.init).joined())
                        .font(.title2.bold())
                        .foregroundColor(Color(hex: "#FF6B35"))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(profile.name)
                        .font(.title3.bold())
                    Text("\(profile.age) ans • \(profile.city)")
                        .foregroundColor(.secondary)
                    Label("Score de compatibilité : \(profile.matchScore)%", systemImage: "sparkles")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(profile.distance)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Label(profile.isOnline ? "En ligne" : "Hors ligne", systemImage: profile.isOnline ? "circle.fill" : "circle")
                        .font(.caption)
                        .foregroundColor(profile.isOnline ? .green : .secondary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var skillsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Compétences enseignées")
                .font(.headline)
            if profile.teaches.isEmpty {
                Text("Aucune compétence déclarée.")
                    .foregroundColor(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                    ForEach(profile.teaches, id: \.self) { skill in
                        Text(skill)
                            .font(.footnote.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(Color(hex: "#FF6B35").opacity(0.12))
                            )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var meta: some View {
        VStack(spacing: 12) {
            HStack {
                infoTile(title: "Disponible", value: profile.isOnline ? "Maintenant" : "Plus tard", icon: "clock")
                infoTile(title: "Ville", value: profile.city, icon: "mappin.and.ellipse")
            }
        }
    }

    private func infoTile(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.footnote)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

/*
// SessionDetailView commented out due to Session model changes
struct SessionDetailView: View {
    let session: Session
    @EnvironmentObject private var sessionsViewModel: SessionsViewModel
    @State private var showChat = false
    @State private var showBooking = false
    @State private var showReschedule = false
    @State private var toastMessage: String?
    @State private var showActionError = false
    @State private var actionErrorMessage: String?
    @State private var isPerformingStatusUpdate = false

    private var currentSession: Session {
        sessionsViewModel.session(withId: session.id) ?? session
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statusHeader
                scheduleCard
                participantsCard
                if let notes = currentSession.notes, !notes.isEmpty {
                    notesCard(notes: notes)
                }
                EntityCTASection(
                    primaryLabel: "Envoyer un message",
                    secondaryLabel: currentSession.status.allowsReschedule ? "Proposer un report" : "Réserver encore",
                    secondaryIcon: currentSession.status.allowsReschedule ? "calendar.badge.clock" : "calendar.badge.plus",
                    onPrimary: { showChat = true },
                    onSecondary: {
                        if currentSession.status.allowsReschedule {
                            showReschedule = true
                        } else {
                            showBooking = true
                        }
                    }
                )
            }
            .padding()
        }
        .navigationTitle(currentSession.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if currentSession.status != "completed" {
                        Button {
                            handleStatusChange(.completed)
                        } label: {
                            Label("Marquer terminée", systemImage: "checkmark.circle")
                        }
                    }
                    if currentSession.status != "cancelled" {
                        Button(role: .destructive) {
                            handleStatusChange(.cancelled)
                        } label: {
                            Label("Annuler la session", systemImage: "xmark.circle")
                        }
                    }
                    if currentSession.status == .postponed {
                        Button {
                            handleStatusChange(.upcoming)
                        } label: {
                            Label("Revenir à À venir", systemImage: "arrow.uturn.backward")
                        }
                    }
                } label: {
                    if isPerformingStatusUpdate {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showChat) {
            NavigationStack { ChatView(startInList: true) }
        }
        .sheet(isPresented: $showBooking) {
            SessionBookingSheet(
                defaultTopic: currentSession.skill,
                preferredMentor: currentSession.mentorName
            ) {
                await sessionsViewModel.loadSessions(showLoader: false)
                await MainActor.run {
                    presentToast("Session planifiée")
                }
            }
        }
        .sheet(isPresented: $showReschedule) {
            SessionRescheduleSheet(session: currentSession) { newDate, meetingLink, message in
                try await sessionsViewModel.requestReschedule(
                    for: currentSession,
                    newDate: newDate,
                    meetingLink: meetingLink,
                    message: message
                )
                await MainActor.run { presentToast("Demande envoyée") }
            }
        }
        .overlay(alignment: .bottom) {
            if let toastMessage {
                CopyToast(message: toastMessage)
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: toastMessage)
        .alert("Action impossible", isPresented: $showActionError, presenting: actionErrorMessage) { _ in
            Button("OK", role: .cancel) {
                actionErrorMessage = nil
            }
        } message: { message in
            Text(message)
        }
    }

    private var statusHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            Circle()
                .fill(Color(hex: currentSession.statusColor).opacity(0.15))
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: iconName(for: currentSession.status))
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(Color(hex: currentSession.statusColor))
                }
            VStack(alignment: .leading, spacing: 6) {
                Text(currentSession.statusLabel)
                    .font(.headline)
                Text(currentSession.skill)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(currentSession.durationText)
                .font(.subheadline.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(Color(.systemGray6))
                )
        }
    }

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Date & heure", systemImage: "calendar")
                .font(.subheadline.bold())
            Text(currentSession.formattedSchedule)
                .font(.title3)
            HStack {
                Label(currentSession.durationText, systemImage: "clock")
                Spacer()
                Label(currentSession.location ?? "En ligne", systemImage: "location")
            }
            .font(.footnote)
            .foregroundColor(.secondary)
            if let link = currentSession.meetingLink, !link.isEmpty, let url = URL(string: link) {
                Link(destination: url) {
                    Label("Rejoindre la réunion", systemImage: "video.fill")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(LinearGradient(colors: [Color(hex: "#FF6B35"), Color(hex: "#FFB347")], startPoint: .leading, endPoint: .trailing))
                        )
                        .foregroundColor(.white)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var participantsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Participants")
                .font(.headline)
            participantRow(name: currentSession.mentorName, role: "Mentor", systemIcon: "person.crop.circle.fill")
            participantRow(name: currentSession.learnerName, role: "Apprenant", systemIcon: "person.crop.circle")
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 24).fill(Color(.systemBackground)))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }

    private func participantRow(name: String, role: String, systemIcon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemIcon)
                .font(.title2)
                .foregroundColor(Color(hex: "#FF6B35"))
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color(hex: "#FF6B35").opacity(0.12)))
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.headline)
                Text(role)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    private func notesCard(notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes partagées")
                .font(.headline)
            Text(notes)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 24).fill(Color(.systemGray6)))
    }

    private func iconName(for status: String) -> String {
        switch status {
        case "upcoming": return "calendar"
        case "completed": return "checkmark.circle.fill"
        case "cancelled": return "xmark.circle.fill"
        case "postponed", "reportee": return "clock.arrow.circlepath"
        default: return "circle"
        }
    }

    private func handleStatusChange(_ status: SessionStatus) {
        guard !isPerformingStatusUpdate, currentSession.status != status.rawValue else { return }
        isPerformingStatusUpdate = true
        Task {
            do {
                try await sessionsViewModel.updateStatus(for: currentSession, to: status)
                await MainActor.run { presentToast("Statut mis à jour") }
            } catch {
                actionErrorMessage = error.localizedDescription
                showActionError = true
            }
            isPerformingStatusUpdate = false
        }
    }

    private func presentToast(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                if toastMessage == message {
                    toastMessage = nil
                }
            }
        }
    }
}

*/

private struct EntityCTASection: View {
    let primaryLabel: String
    let secondaryLabel: String
    let secondaryIcon: String
    let onPrimary: () -> Void
    let onSecondary: () -> Void

    init(
        primaryLabel: String,
        secondaryLabel: String,
        secondaryIcon: String = "calendar.badge.plus",
        onPrimary: @escaping () -> Void,
        onSecondary: @escaping () -> Void
    ) {
        self.primaryLabel = primaryLabel
        self.secondaryLabel = secondaryLabel
        self.secondaryIcon = secondaryIcon
        self.onPrimary = onPrimary
        self.onSecondary = onSecondary
    }

    var body: some View {
        VStack(spacing: 12) {
            Button(action: onPrimary) {
                Label(primaryLabel, systemImage: "paperplane.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(LinearGradient(colors: [Color(hex: "#FF6B35"), Color(hex: "#FFB347")], startPoint: .leading, endPoint: .trailing))
                    )
                    .foregroundColor(.white)
            }
            Button(action: onSecondary) {
                Label(secondaryLabel, systemImage: secondaryIcon)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color(.systemGray6))
                    )
            }
        }
    }
}

private struct EntityBadge: View {
    let text: String
    let icon: String
    var gradient: [Color] = [Color.black.opacity(0.6), Color.black.opacity(0.3)]
    var textColor: Color = .white

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing))
            )
            .foregroundColor(textColor)
    }
}

private struct CopyToast: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.footnote.bold())
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(LinearGradient(colors: [Color(hex: "#FF6B35"), Color(hex: "#FFB347")], startPoint: .leading, endPoint: .trailing))
            )
            .foregroundColor(.white)
    }
}

private struct SessionBookingSheet: View {
    @Environment(\.dismiss) private var dismiss
    let preferredMentor: String?
    let onSuccess: (() async -> Void)?

    @State private var topic: String
    @State private var scheduledDate = Date().addingTimeInterval(3600 * 24)
    @State private var duration = 60
    @State private var message: String
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let sessionService = SessionService.shared
    private let notificationManager = LocalNotificationManager.shared

    init(defaultTopic: String?, preferredMentor: String?, onSuccess: (() async -> Void)? = nil) {
        self.preferredMentor = preferredMentor
        self.onSuccess = onSuccess
        _topic = State(initialValue: defaultTopic ?? "Session SkillSwap")
        let greeting = preferredMentor ?? "mentor"
        _message = State(initialValue: "Bonjour \(greeting), j’aimerais planifier une session.")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Session") {
                    TextField("Sujet", text: $topic)
                    DatePicker("Date", selection: $scheduledDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    Stepper(value: $duration, in: 30...120, step: 15) {
                        Text("Durée : \(duration) min")
                    }
                }
                Section("Message pour \(preferredMentor ?? "le mentor")") {
                    TextEditor(text: $message)
                        .frame(minHeight: 120)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Réserver")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("Envoyer")
                        }
                    }
                    .disabled(isSubmitting)
                }
            }
        }
    }

    @MainActor
    private func submit() async {
        guard !isSubmitting else { return }

        guard let token = AuthenticationManager.shared.accessToken else {
            errorMessage = "Connectez-vous pour réserver une session."
            return
        }

        guard let email = AuthenticationManager.shared.currentUser?.email else {
            errorMessage = "Adresse e-mail introuvable."
            return
        }

        isSubmitting = true
        errorMessage = nil

        let trimmedTopic = sanitized(topic) ?? "Session SkillSwap"
        let newSession = NewSession(
            title: trimmedTopic,
            skill: trimmedTopic,
            date: isoString(from: scheduledDate),
            duration: duration,
            status: "upcoming",
            meetingLink: nil,
            location: nil,
            notes: composedNotes(),
            studentEmail: email,
            studentEmails: nil
        )

        do {
            _ = try await sessionService.createSession(session: newSession, token: token)
            if let onSuccess {
                await onSuccess()
            }
            notificationManager.presentInAppNotification(
                title: "Session réservée",
                body: "\(trimmedTopic) · \(formattedScheduleDescription(for: scheduledDate))"
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }

    private func sanitized(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func composedNotes() -> String? {
        var parts: [String] = []
        if let message = sanitized(message) {
            parts.append(message)
        }
        if let mentor = preferredMentor {
            parts.append("Mentor souhaité : \(mentor)")
        }
        let combined = parts.joined(separator: "\n\n")
        return combined.isEmpty ? nil : combined
    }

    private func isoString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private func formattedScheduleDescription(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private struct SessionRescheduleSheet: View {
    @Environment(\.dismiss) private var dismiss
    let session: Session
    let onSubmit: (Date, String?, String?) async throws -> Void

    @State private var proposedDate: Date
    @State private var meetingLink: String
    @State private var message: String
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    init(session: Session, onSubmit: @escaping (Date, String?, String?) async throws -> Void) {
        self.session = session
        self.onSubmit = onSubmit
        _proposedDate = State(initialValue: session.scheduledDate ?? Date().addingTimeInterval(3600))
        _meetingLink = State(initialValue: session.meetingLink ?? "")
        _message = State(initialValue: "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nouvelle plage") {
                    DatePicker(
                        "Date",
                        selection: $proposedDate,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
                Section("Lien de réunion (optionnel)") {
                    TextField("https://", text: $meetingLink)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }
                Section("Message") {
                    TextEditor(text: $message)
                        .frame(minHeight: 120)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Proposer un report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Envoyer") { Task { await submit() } }
                        .disabled(isSubmitting)
                }
            }
        }
    }

    private func submit() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            try await onSubmit(proposedDate, meetingLink, message)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}
