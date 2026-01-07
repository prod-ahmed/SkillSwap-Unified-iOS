import SwiftUI

@MainActor
struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @ObservedObject var callManager = CallManager.shared

    init(startInList: Bool = false, initialThreadId: String? = nil) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(startInList: startInList, initialThreadId: initialThreadId))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground).ignoresSafeArea()
            if let activeThread = viewModel.selectedThread {
                ChatThreadDetailView(viewModel: viewModel, thread: activeThread)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                ChatThreadListView(viewModel: viewModel)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .task {
            await viewModel.loadThreads(reset: true)
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 10) {
                if let toast = viewModel.toastMessage {
                    ToastPill(message: toast)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error) {
                        viewModel.dismissError()
                    }
                    .transition(.opacity)
                }
            }
            .padding()
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.toastMessage)
            .animation(.easeInOut, value: viewModel.errorMessage)
        }
        .fullScreenCover(isPresented: Binding(
            get: { viewModel.isPresentingStartConversation },
            set: { value in viewModel.isPresentingStartConversation = value }
        )) {
            StartConversationSheet(viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $callManager.isCallActive) {
            ActiveCallView()
        }
        .navigationBarHidden(true)
    }
}

private struct ChatThreadListView: View {
    @ObservedObject var viewModel: ChatViewModel
    @StateObject private var localization = LocalizationManager.shared

    var body: some View {
        VStack(spacing: 0) {
            header
            searchField
            startConversationButton
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.filteredThreads()) { thread in
                        Button {
                            Task { await viewModel.open(thread: thread) }
                        } label: {
                            ThreadRow(thread: thread, viewModel: viewModel)
                        }
                        .buttonStyle(.plain)
                        .task {
                            await viewModel.loadMoreIfNeeded(current: thread)
                        }
                    }

                    if viewModel.isLoadingThreads && viewModel.threads.isEmpty {
                        ProgressView(localization.localized(.loading))
                            .padding(.vertical, 32)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 20)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localization.localized(.messages))
                .font(.title.bold())
                .foregroundColor(.white)
            Text(viewModel.threads.isEmpty ? localization.localized(.noConversations) : localization.localized(.chooseConversation))
                .foregroundColor(Color.white.opacity(0.85))
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 30)
        .background(
            LinearGradient(colors: [Color(hex: "#FF6B35"), Color(hex: "#FFB347")], startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                .padding(.bottom, -40)
        )
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField(localization.localized(.searchMentor), text: $viewModel.searchQuery)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)))
        .padding(.horizontal)
        .padding(.top)
    }

    private var startConversationButton: some View {
        Button {
            viewModel.presentStartConversationSheet()
        } label: {
            Label(localization.localized(.startConversation), systemImage: "bubble.left.and.bubble.right.fill")
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                )
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.top, 12)
    }
}

private struct ThreadRow: View {
    let thread: ChatThread
    let viewModel: ChatViewModel

    var body: some View {
        HStack(spacing: 16) {
            avatar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(viewModel.displayName(for: thread))
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(viewModel.relativeTime(for: thread))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(thread.previewText())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            if thread.unreadCount > 0 {
                Text("\(thread.unreadCount)")
                    .font(.caption.bold())
                    .padding(8)
                    .background(Circle().fill(Color(hex: "#FF6B35")))
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#FF6B35").opacity(0.15))
                .frame(width: 56, height: 56)
            Text(viewModel.partnerInitials(for: thread))
                .font(.headline)
                .foregroundColor(Color(hex: "#FF6B35"))
        }
    }
}

private struct ChatThreadDetailView: View {
    @ObservedObject var viewModel: ChatViewModel
    let thread: ChatThread
    @StateObject private var localization = LocalizationManager.shared

    var body: some View {
        VStack(spacing: 0) {
            header
            messagesList
            composer
        }
    }

    private var partner: ChatParticipant? {
        thread.partner(for: viewModel.currentUserId)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Button {
                withAnimation {
                    viewModel.closeThread()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 48, height: 48)
                Text(viewModel.partnerInitials(for: thread))
                    .foregroundColor(.white)
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(partner?.displayName ?? "Discussion")
                    .font(.headline)
                    .foregroundColor(.white)
                Text(localization.localized(.online))
                    .font(.footnote)
                    .foregroundColor(Color.white.opacity(0.8))
            }

            Spacer()

            HStack(spacing: 12) {
                Button {
                    viewModel.initiateVideoCall()
                } label: {
                    CircleIcon(systemName: "video.fill")
                }
                
                Button {
                    viewModel.initiateVoiceCall()
                } label: {
                    CircleIcon(systemName: "phone.fill")
                }
                
                CircleIcon(systemName: "ellipsis")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            LinearGradient(colors: [Color(hex: "#FF6B35"), Color(hex: "#FFB347")], startPoint: .leading, endPoint: .trailing)
        )
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.messages) { message in
                        ChatBubble(
                            message: message,
                            isOwn: viewModel.isOwnMessage(message),
                            timeText: viewModel.bubbleTime(for: message),
                            onReply: { msg in
                                withAnimation { viewModel.setReplyTo(msg) }
                            },
                            onReact: { msg, emoji in
                                Task { await viewModel.react(to: msg, emoji: emoji) }
                            },
                            onDelete: { msg in
                                Task { await viewModel.delete(message: msg) }
                            }
                        )
                            .id(message.id)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground))
            .onChange(of: viewModel.messages.count) { _ in
                if let lastId = viewModel.messages.last?.id {
                    withAnimation {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                if let lastId = viewModel.messages.last?.id {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var composer: some View {
        VStack(spacing: 0) {
            // Reply Preview
            if let reply = viewModel.replyToMessage {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localization.localized(.replyTo))
                            .font(.caption)
                            .foregroundColor(Color(hex: "#FF6B35"))
                        Text(reply.content)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button {
                        withAnimation {
                            viewModel.cancelReply()
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Button(action: {}) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(hex: "#FF6B35"))
                            .frame(width: 44, height: 44)
                            .background(Color(hex: "#FF6B35").opacity(0.12))
                            .clipShape(Circle())
                    }

                    ZStack(alignment: .trailing) {
                        TextField(localization.localized(.writeMessage), text: $viewModel.composerText, axis: .vertical)
                            .textFieldStyle(.plain)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 18)
                            .background(RoundedRectangle(cornerRadius: 28).fill(Color(.systemGray6)))
                        Button(action: {}) {
                            Image(systemName: "face.smiling")
                                .foregroundColor(.secondary)
                                .padding(.trailing, 20)
                        }
                    }

                    Button {
                        Task { await viewModel.sendCurrentMessage() }
                    } label: {
                        Group {
                            if viewModel.isSending {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            } else {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                        }
                        .frame(width: 52, height: 52)
                        .background(
                            Group {
                                if viewModel.composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Color.gray.opacity(0.3)
                                } else {
                                    LinearGradient(colors: [Color(hex: "#FF6B35"), Color(hex: "#FFB347")], startPoint: .topLeading, endPoint: .bottomTrailing)
                                }
                            }
                        )
                        .foregroundColor(.white)
                        .clipShape(Circle())
                    }
                    .disabled(viewModel.composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
                }

                Button {
                    viewModel.planSessionTapped()
                } label: {
                    Text(localization.localized(.planSession))
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(24)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: -4)
        }
    }
}

private struct ChatBubble: View {
    let message: ChatMessage
    let isOwn: Bool
    let timeText: String
    var onReply: ((ChatMessage) -> Void)?
    var onReact: ((ChatMessage, String) -> Void)?
    var onDelete: ((ChatMessage) -> Void)?

    @State private var dragOffset: CGFloat = 0
    @StateObject private var localization = LocalizationManager.shared

    var body: some View {
        ZStack(alignment: .leading) {
            // Reply Indicator
            Image(systemName: "arrowshape.turn.up.left.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color(hex: "#FF6B35"))
                .scaleEffect(dragOffset > 40 ? 1.0 : 0.5)
                .opacity(dragOffset > 10 ? Double(min(dragOffset / 50, 1)) : 0)
                .offset(x: 16)
            
            HStack(alignment: .bottom, spacing: 8) {
                if isOwn { Spacer(minLength: 40) }
                
                VStack(alignment: isOwn ? .trailing : .leading, spacing: 4) {
                    // Reply Context
                    if let replyTo = message.replyTo {
                        HStack {
                            Rectangle()
                                .fill(Color(hex: "#FF6B35"))
                                .frame(width: 2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(localization.localized(.reply))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(replyTo.content)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.bottom, 2)
                    }
                    
                    // Message Content
                    VStack(alignment: isOwn ? .trailing : .leading, spacing: 6) {
                        // Image attachment
                        if let attachmentUrl = message.attachmentUrl, !attachmentUrl.isEmpty,
                           message.type == .attachment || attachmentUrl.contains("image") || attachmentUrl.hasSuffix(".jpg") || attachmentUrl.hasSuffix(".jpeg") || attachmentUrl.hasSuffix(".png") || attachmentUrl.hasSuffix(".gif") {
                            let imageURL: URL? = {
                                if attachmentUrl.hasPrefix("http") {
                                    return URL(string: attachmentUrl)
                                } else if attachmentUrl.hasPrefix("/uploads") {
                                    return URL(string: "\(NetworkConfig.baseURL)\(attachmentUrl)")
                                } else {
                                    return URL(string: "\(NetworkConfig.baseURL)/uploads/chat/\(attachmentUrl)")
                                }
                            }()
                            
                            if let url = imageURL {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                            .frame(width: 200, height: 150)
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(maxWidth: 200, maxHeight: 250)
                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                    case .failure:
                                        Image(systemName: "photo")
                                            .font(.largeTitle)
                                            .foregroundColor(.gray)
                                            .frame(width: 200, height: 150)
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            }
                        }
                        
                        // Text content (show if not empty or if no attachment)
                        if !message.content.isEmpty || message.attachmentUrl == nil {
                            Text(message.isDeleted == true ? localization.localized(.messageDeleted) : message.content)
                                .font(.subheadline)
                                .italic(message.isDeleted == true)
                                .foregroundColor(isOwn ? .white : .primary)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 14)
                                .background(bubbleBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        }
                        
                        // Reactions
                        if let reactions = message.reactions, !reactions.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(reactions.keys.sorted(), id: \.self) { emoji in
                                    if let userIds = reactions[emoji], !userIds.isEmpty {
                                        Text("\(emoji) \(userIds.count)")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color(.systemGray5))
                                            .cornerRadius(10)
                                    }
                                }
                            }
                        }
                        
                        Text(timeText)
                            .font(.caption)
                            .foregroundColor(isOwn ? .white.opacity(0.8) : .secondary)
                    }
                }
                .contextMenu {
                    if message.isDeleted != true {
                        // Removed "Répondre" as requested, replaced by swipe
                        
                        Menu(localization.localized(.react)) {
                            ForEach(["👍", "❤️", "😂", "😮", "😢", "👏"], id: \.self) { emoji in
                                Button(emoji) {
                                    onReact?(message, emoji)
                                }
                            }
                        }
                        
                        if isOwn {
                            Button(role: .destructive) {
                                onDelete?(message)
                            } label: {
                                Label(localization.localized(.delete), systemImage: "trash")
                            }
                        }
                    }
                }
                
                if !isOwn { Spacer(minLength: 40) }
            }
            .offset(x: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Only allow dragging right
                        if value.translation.width > 0 {
                            // Resistance effect
                            dragOffset = log(value.translation.width + 1) * 15
                        }
                    }
                    .onEnded { value in
                        if dragOffset > 40 {
                            // Trigger reply
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            onReply?(message)
                        }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            dragOffset = 0
                        }
                    }
            )
        }
        .transition(.opacity)
    }

    private var bubbleBackground: some View {
        Group {
            if isOwn {
                LinearGradient(colors: [Color(hex: "#FF6B35"), Color(hex: "#FFB347")], startPoint: .leading, endPoint: .trailing)
            } else {
                Color(.systemGray5)
            }
        }
    }
}

private struct CircleIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 40, height: 40)
            .background(Color.white.opacity(0.15))
            .clipShape(Circle())
    }
}

private struct StartConversationSheet: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var email: String = ""
    @State private var topic: String = ""
    @FocusState private var focusedField: Field?
    @State private var userSuggestions: [UserSearchResult] = []
    @State private var isSearching: Bool = false
    @State private var showSuggestions: Bool = false
    @StateObject private var localization = LocalizationManager.shared

    private enum Field: Hashable {
        case email
        case topic
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(localization.localized(.recipient)) {
                    VStack(alignment: .leading, spacing: 0) {
                        TextField(localization.localized(.emailOrUsername), text: $email)
                            .keyboardType(.default)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .focused($focusedField, equals: .email)
                            .onChange(of: email) { newValue in
                                Task { await searchUsers(query: newValue) }
                            }
                        
                        if showSuggestions && !userSuggestions.isEmpty {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(userSuggestions.prefix(5), id: \.id) { user in
                                        Button {
                                            email = user.username ?? user.email ?? ""
                                            showSuggestions = false
                                            focusedField = .topic
                                        } label: {
                                            HStack(spacing: 12) {
                                                Circle()
                                                    .fill(Color(hex: "#FF6B35").opacity(0.15))
                                                    .frame(width: 36, height: 36)
                                                    .overlay(
                                                        Text(user.initials)
                                                            .font(.caption.bold())
                                                            .foregroundColor(Color(hex: "#FF6B35"))
                                                    )
                                                
                                                VStack(alignment: .leading, spacing: 2) {
                                                    if let username = user.username {
                                                        Text(username)
                                                            .font(.subheadline.weight(.medium))
                                                            .foregroundColor(.primary)
                                                    }
                                                    if let email = user.email {
                                                        Text(email)
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                    }
                                                }
                                                
                                                Spacer()
                                                
                                                Image(systemName: "chevron.right")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 12)
                                            .background(Color(.secondarySystemGroupedBackground))
                                        }
                                        .buttonStyle(.plain)
                                        
                                        if user.id != userSuggestions.prefix(5).last?.id {
                                            Divider()
                                        }
                                    }
                                }
                            }
                            .frame(maxHeight: 200)
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(8)
                            .padding(.top, 4)
                        }
                        
                        if isSearching {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text(localization.localized(.searching))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 4)
                        }
                    }
                }

                Section(localization.localized(.subject)) {
                    TextField(localization.localized(.subject), text: $topic)
                        .focused($focusedField, equals: .topic)
                }

                if viewModel.isCreatingThread {
                    Section {
                        ProgressView(localization.localized(.creating))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle(localization.localized(.newConversation))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localization.localized(.cancel)) {
                        viewModel.dismissStartConversationSheet()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: submit) {
                        if viewModel.isCreatingThread {
                            ProgressView()
                        } else {
                            Text(localization.localized(.create))
                        }
                    }
                    .disabled(!canSubmit)
                }
            }
        }
        .onAppear {
            focusedField = .email
        }
        .onDisappear {
            resetFields()
        }
    }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isCreatingThread
    }

    private func searchUsers(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            await MainActor.run {
                userSuggestions = []
                showSuggestions = false
            }
            return
        }
        
        await MainActor.run {
            isSearching = true
            showSuggestions = true
        }
        
        do {
            let userService = UserService()
            guard let token = AuthenticationManager.shared.accessToken else { return }
            let users = try await userService.fetchUsers(accessToken: token)
            
            // Filter users based on query
            let filtered = users.filter { user in
                let lowercasedQuery = trimmed.lowercased()
                let usernameMatch = user.username.lowercased().contains(lowercasedQuery)
                let emailMatch = user.email.lowercased().contains(lowercasedQuery)
                return usernameMatch || emailMatch
            }
            
            await MainActor.run {
                userSuggestions = filtered.map { UserSearchResult(from: $0) }
                isSearching = false
            }
        } catch {
            await MainActor.run {
                userSuggestions = []
                isSearching = false
            }
        }
    }

    private func submit() {
        let topicValue = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            await viewModel.startConversation(withEmail: email, topic: topicValue.isEmpty ? nil : topicValue)
        }
    }

    private func resetFields() {
        email = ""
        topic = ""
        userSuggestions = []
        showSuggestions = false
    }
}

// Helper struct for user search results
private struct UserSearchResult: Identifiable {
    let id: String
    let username: String?
    let email: String?
    
    init(from user: User) {
        self.id = user.id
        self.username = user.username
        self.email = user.email
    }
    
    var initials: String {
        if let username = username, !username.isEmpty {
            let components = username.split(separator: " ")
            let letters = components.compactMap { $0.first }.prefix(2)
            return letters.map { String($0) }.joined().uppercased()
        }
        if let email = email, let first = email.first {
            return String(first).uppercased()
        }
        return "?"
    }
}

private struct ToastPill: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.footnote.weight(.medium))
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(LinearGradient(colors: [Color(hex: "#FF6B35"), Color(hex: "#FFB347")], startPoint: .leading, endPoint: .trailing))
            )
    }
}

private struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.footnote)
                .foregroundColor(.primary)
                .lineLimit(2)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)))
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
        .padding(.horizontal)
    }
}

#Preview {
    ChatView()
        .environmentObject(AuthenticationManager.shared)
}
