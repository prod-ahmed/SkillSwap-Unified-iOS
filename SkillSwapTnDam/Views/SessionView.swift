import SwiftUI

struct SessionsView: View {
    @StateObject private var viewModel = SessionsViewModel()
    @StateObject private var localization = LocalizationManager.shared
    @State private var selectedFilter: Int = 0
    @State private var showCreateSession: Bool = false
    @State private var timeFilter: Int = 0 // 0 = Toutes, 1 = Cette semaine
    @State private var rescheduleSession: Session?
    @State private var rescheduleDate: Date = Date()
    @State private var rescheduleTime: Date = Date()
    @State private var rescheduleNote: String = ""
    @State private var ratingSession: Session?
    @State private var showNotifications = false
    @State private var selectedSessionForPlan: Session?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                header
                gradientSummaryCard
                segmentedTabs
                
                // Time filter for upcoming sessions
                if selectedFilter == 0 {
                    timeFilterView
                }

                if viewModel.isLoading {
                    ProgressView("Chargement...")
                        .padding(.top, 50)
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            ForEach(filteredSessions) { session in
                                let isCreator = session.safeTeacher.id == currentUserId
                                SessionCardView(
                                    session: session,
                                    avatarColor: .orange,
                                    name: session.safeTeacher.username.capitalized,
                                    title: session.title.isEmpty ? "Session sans titre" : session.title,
                                    date: formattedDate(session.date),
                                    time: formattedTime(session.date),
                                    duration: "\(session.duration) min",
                                    isCreator: isCreator,
                                    currentUserId: currentUserId,
                                    onPostpone: {
                                        Task {
                                            await viewModel.postponeSession(sessionId: session.id)
                                        }
                                    },
                                    onProposeReschedule: {
                                        rescheduleSession = session
                                        rescheduleDate = session.date
                                        rescheduleTime = session.date
                                        rescheduleNote = ""
                                    },
                                    onRespondReschedule: { decision in
                                        Task {
                                            await viewModel.respondToReschedule(sessionId: session.id, decision: decision)
                                        }
                                    },
                                    onRate: {
                                        ratingSession = session
                                    },
                                    onShowPlan: {
                                        selectedSessionForPlan = session
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                    }
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .sheet(isPresented: $showCreateSession) {
                CreateSessionView()
            }
            .sheet(item: $rescheduleSession) { session in
                RescheduleProposalView(
                    session: session,
                    initialDate: rescheduleDate,
                    initialTime: rescheduleTime,
                    initialNote: rescheduleNote
                ) { date, time, note in
                    Task {
                        await viewModel.proposeReschedule(sessionId: session.id, newDate: date, newTime: time, note: note.isEmpty ? nil : note)
                        rescheduleSession = nil
                    }
                }
            }
            .sheet(isPresented: $showNotifications) {
                NotificationsView(viewModel: NotificationsViewModel())
            }
            .sheet(item: $selectedSessionForPlan) { session in
                LessonPlanView(
                    sessionId: session.id,
                    isTeacher: session.safeTeacher.id == currentUserId
                )
            }
            .sheet(item: $ratingSession) { session in
                if let ratedUser = getRatedUser(for: session) {
                    RatingView(
                        sessionId: session.id,
                        ratedUser: ratedUser,
                        skill: session.skill
                    )
                }
            }
            .task {
                await viewModel.loadSessions()
            }
        }
    }
    
    private var currentUserId: String? {
        AuthenticationManager.shared.currentUser?.id
    }

    // MARK: - Filtered Sessions
    private var filteredSessions: [Session] {
        var sessions: [Session]
        
        switch selectedFilter {
        case 0:
            sessions = viewModel.sessions.filter { $0.status == "upcoming" }
        case 1:
            sessions = viewModel.sessions.filter { $0.status == "completed" }
        case 2:
            sessions = viewModel.sessions.filter { $0.status == "reportee" || $0.status == "postponed" }
        default:
            sessions = viewModel.sessions
        }
        
        // Apply time filter for upcoming sessions
        if selectedFilter == 0 && timeFilter == 1 {
            sessions = filterThisWeek(sessions: sessions)
        }
        
        return sessions
    }
    
    // MARK: - This Week Filter
    private func filterThisWeek(sessions: [Session]) -> [Session] {
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start,
              let weekEnd = calendar.dateInterval(of: .weekOfYear, for: now)?.end else {
            return sessions
        }
        
        return sessions.filter { session in
            session.date >= weekStart && session.date < weekEnd
        }
    }
    
    // MARK: - Time Filter View
    private var timeFilterView: some View {
        HStack(spacing: 10) {
            timeFilterButton(localization.localized(.all), index: 0)
            timeFilterButton(localization.localized(.thisWeek), index: 1)
        }
        .padding(.horizontal)
    }
    
    private func timeFilterButton(_ title: String, index: Int) -> some View {
        Button {
            timeFilter = index
        } label: {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(timeFilter == index ? .orange : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(timeFilter == index ? Color.orange.opacity(0.1) : Color(.systemGray6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(timeFilter == index ? Color.orange : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - UI Components
    private var header: some View {
        HStack {
            Text(localization.localized(.mySessions))
                .font(.title3.bold())
            Spacer()
            Button {
                showNotifications = true
            } label: {
                Image(systemName: "bell")
                    .font(.title3)
                    .foregroundColor(.primary)
            }
            .buttonStyle(.plain)
            Button {
                showCreateSession = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text(localization.localized(.newSession))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(colors: [.orange, Color(red: 1.0, green: 0.6, blue: 0.3)], startPoint: .leading, endPoint: .trailing))
                )
                .foregroundColor(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var gradientSummaryCard: some View {
        HStack {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white.opacity(0.15))
                    .frame(width: 64, height: 64)
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading) {
                Text(selectedFilter == 0 ? localization.localized(.upcoming) : selectedFilter == 1 ? localization.localized(.completed) : localization.localized(.postponed))
                    .foregroundColor(.white.opacity(0.9))
                    .font(.subheadline)
                Text("\(filteredSessions.count) " + localization.localized(.sessions).lowercased())
                    .foregroundColor(.white)
                    .font(.headline)
            }
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.55, blue: 0.2), .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .padding(.horizontal)
    }

    private var segmentedTabs: some View {
        HStack(spacing: 0) {
            segmentButton(localization.localized(.upcoming), index: 0)
            segmentButton(localization.localized(.completed), index: 1)
            segmentButton(localization.localized(.postponed), index: 2)
        }
        .padding(4)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func segmentButton(_ title: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedFilter = index
            }
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(selectedFilter == index ? .orange : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(selectedFilter == index ? .white : Color.clear)
                        .shadow(color: selectedFilter == index ? .black.opacity(0.1) : .clear, radius: 2, x: 0, y: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Format Helpers
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        formatter.locale = Locale(identifier: LocalizationManager.shared.currentLanguage.rawValue)
        return formatter.string(from: date)
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func getRatedUser(for session: Session) -> SessionUserSummary? {
        guard let currentUserId = currentUserId else { return nil }
        
        // If current user is teacher, rate the student
        if session.safeTeacher.id == currentUserId {
            return session.student ?? session.students?.first
        } else {
            // If current user is student, rate the teacher
            return session.teacher
        }
    }
}

private struct SessionCardView: View {
    let session: Session
    var avatarColor: Color
    var name: String
    var title: String
    var date: String
    var time: String
    var duration: String
    var isCreator: Bool
    var currentUserId: String?
    var onPostpone: () -> Void
    var onProposeReschedule: () -> Void
    var onRespondReschedule: (RescheduleDecision) -> Void
    var onRate: () -> Void
    var onShowPlan: (() -> Void)?
    
    @State private var showPostponeAlert = false
    @StateObject private var localization = LocalizationManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header: Avatar + Name + Title
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(avatarColor.opacity(0.2))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text(String(name.prefix(1)))
                            .font(.title3.bold())
                            .foregroundColor(avatarColor)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    if let onShowPlan = onShowPlan {
                        Button {
                            onShowPlan()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.text")
                                    .font(.caption)
                                Text(localization.localized(.plan))
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundColor(.orange)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.orange.opacity(0.1))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Menu {
                        if session.status == "upcoming" {
                            Button(role: .destructive) {
                                showPostponeAlert = true
                            } label: {
                                Label(localization.localized(.postpone), systemImage: "arrow.right.circle")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .padding(8)
                            .contentShape(Rectangle())
                    }
                }
            }

            Divider()

            // Info Row: Date, Time, Duration
            HStack(spacing: 20) {
                Label {
                    Text(date)
                        .font(.subheadline.weight(.medium))
                } icon: {
                    Image(systemName: "calendar")
                        .foregroundColor(.orange)
                }
                
                Label {
                    Text(time)
                        .font(.subheadline.weight(.medium))
                } icon: {
                    Image(systemName: "clock")
                        .foregroundColor(.orange)
                }
                
                Label {
                    Text(duration)
                        .font(.subheadline.weight(.medium))
                } icon: {
                    Image(systemName: "hourglass")
                        .foregroundColor(.orange)
                }
            }
            .foregroundColor(.primary)
            
            // Location if available
            if let location = session.location, !location.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.orange)
                    Text(location)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // Action Buttons
            HStack(spacing: 12) {
                if session.status == "completed" {
                    Button {
                        onRate()
                    } label: {
                        Text(localization.localized(.leaveReview))
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.orange)
                            )
                    }
                    .buttonStyle(.plain)
                } else {
                    joinButton
                    
                    if session.status == "upcoming" {
                        Button {
                            showPostponeAlert = true
                        } label: {
                            Image(systemName: "arrow.right.circle")
                                .font(.title3)
                                .foregroundColor(.orange)
                                .padding(10)
                                .background(Color.orange.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            if let request = session.rescheduleRequest {
                rescheduleStatusView(request: request)
            }
            
            if isCreator {
                proposeButton
            } else if shouldShowResponseButtons {
                responseButtons
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        .alert(localization.localized(.confirmPostpone), isPresented: $showPostponeAlert) {
            Button(localization.localized(.cancel), role: .cancel) { }
            Button(localization.localized(.postpone), role: .destructive) {
                onPostpone()
            }
        } message: {
            Text(localization.localized(.areYouSurePostpone))
        }
    }

    private var joinButton: some View {
        Button {} label: {
            HStack {
                Image(systemName: "video.fill")
                Text(localization.localized(.join))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 14).fill(.orange))
        }
        .buttonStyle(.plain)
    }

    private var postponeButton: some View {
        Button {
            showPostponeAlert = true
        } label: {
            Text(localization.localized(.postpone))
                .foregroundColor(.primary)
                .frame(width: 120)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 14).stroke(Color(.systemGray4)))
        }
        .buttonStyle(.plain)
    }
    
    private var proposeButton: some View {
        Button {
            onProposeReschedule()
        } label: {
            HStack {
                Image(systemName: "calendar.badge.plus")
                Text(localization.localized(.proposeNewTime))
            }
            .font(.subheadline.bold())
            .foregroundColor(.orange)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.orange, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var shouldShowResponseButtons: Bool {
        guard let request = session.rescheduleRequest else { return false }
        guard request.isActive ?? false else { return false }
        guard let userId = currentUserId else { return false }
        guard session.students?.contains(where: { $0.id == userId }) ?? false else { return false }
        return request.responses?.contains(where: { $0.userId == userId }) == false
    }
    
    private var userResponse: RescheduleVote? {
        guard let userId = currentUserId else { return nil }
        return session.rescheduleRequest?.responses?.first(where: { $0.userId == userId })
    }
    
    private func rescheduleStatusView(request: RescheduleStatus) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar.badge.exclamationmark")
                    .foregroundColor(.orange)
                Text(localization.localized(.rescheduleProposal))
                    .font(.subheadline.bold())
            }
            
            if let proposedDate = request.proposedDate {
                Text("\(formatDate(proposedDate)) • \(request.proposedTime ?? formattedTime(from: proposedDate))")
                    .font(.subheadline)
            }
            
            if let note = request.note, !note.isEmpty {
                Text("Note: \(note)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            if let responses = request.responses, !responses.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(responses) { vote in
                        HStack {
                            Image(systemName: vote.answer == "yes" ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(vote.answer == "yes" ? .green : .red)
                            Text(responseLabel(for: vote))
                                .font(.caption)
                            Spacer()
                            if vote.userId == currentUserId {
                                Text("Vous")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(Color(.systemGray6))
                                    )
                            }
                        }
                    }
                }
            } else {
                Text(localization.localized(.waitingForResponses))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let vote = userResponse {
                Text(String(format: localization.localized(.youResponded), vote.answer == "yes" ? localization.localized(.yes) : localization.localized(.no)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemGray6)))
    }
    
    private var responseButtons: some View {
        HStack {
            Button {
                onRespondReschedule(.no)
            } label: {
                Text(localization.localized(.decline))
                    .font(.subheadline.bold())
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red.opacity(0.5), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            
            Button {
                onRespondReschedule(.yes)
            } label: {
                Text(localization.localized(.accept))
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.green)
                    )
            }
            .buttonStyle(.plain)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: LocalizationManager.shared.currentLanguage.rawValue)
        formatter.dateFormat = "EEEE d MMMM"
        return formatter.string(from: date).capitalized
    }
    
    private func formattedTime(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func responseLabel(for vote: RescheduleVote) -> String {
        let answer = vote.answer == "yes" ? localization.localized(.yes) : localization.localized(.no)
        if let respondedAt = vote.respondedAt {
            return "\(answer) • \(formattedTime(from: respondedAt))"
        }
        return answer
    }
}

struct SessionsView_Previews: PreviewProvider {
    static var previews: some View {
        SessionsView()
    }
}

private struct RescheduleProposalView: View {
    let session: Session
    @State private var selectedDate: Date
    @State private var selectedTime: Date
    @State private var note: String
    let onSubmit: (Date, Date, String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var localization = LocalizationManager.shared
    
    init(session: Session, initialDate: Date, initialTime: Date, initialNote: String, onSubmit: @escaping (Date, Date, String) -> Void) {
        self.session = session
        _selectedDate = State(initialValue: initialDate)
        _selectedTime = State(initialValue: initialTime)
        _note = State(initialValue: initialNote)
        self.onSubmit = onSubmit
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(localization.localized(.newDate)) {
                    DatePicker(localization.localized(.date), selection: $selectedDate, displayedComponents: .date)
                    DatePicker(localization.localized(.time), selection: $selectedTime, displayedComponents: .hourAndMinute)
                }
                
                Section(localization.localized(.messageToMembers)) {
                    TextEditor(text: $note)
                        .frame(minHeight: 80)
                }
                
                Section {
                    Button {
                        onSubmit(selectedDate, selectedTime, note)
                        dismiss()
                    } label: {
                        Text(localization.localized(.sendProposal))
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle(String(format: localization.localized(.rescheduleSession), session.title))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localization.localized(.close)) {
                        dismiss()
                    }
                }
            }
        }
    }
}




