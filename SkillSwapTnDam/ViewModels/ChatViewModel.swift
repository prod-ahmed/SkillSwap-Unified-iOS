import Foundation
import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var threads: [ChatThread] = []
    @Published var messages: [ChatMessage] = []
    @Published var selectedThread: ChatThread?
    @Published var composerText: String = ""
    @Published var searchQuery: String = ""
    @Published var isLoadingThreads: Bool = false
    @Published var isLoadingMessages: Bool = false
    @Published var isSending: Bool = false
    @Published var errorMessage: String?
    @Published var toastMessage: String?
    @Published var isPresentingStartConversation: Bool = false
    @Published var isCreatingThread: Bool = false
    @Published var replyToMessage: ChatMessage?

    private let service = ChatService()
    private let notificationManager = LocalNotificationManager.shared
    private let socketService = SocketService.shared
    private let chatSocketService = ChatSocketService.shared
    private var skip: Int = 0
    private var hasNextPage: Bool = false
    private var isFetchingMore: Bool = false
    private var lastKnownThreadMessageIds: [String: String] = [:]
    private var hasRecordedThreadSnapshot = false
    private let shouldAutoSelectFirstThread: Bool
    private var pendingThreadId: String?

    private var token: String? {
        AuthenticationManager.shared.accessToken
    }

    var currentUserId: String? {
        AuthenticationManager.shared.currentUser?.id
    }

    init(startInList: Bool = false, initialThreadId: String? = nil) {
        shouldAutoSelectFirstThread = !startInList
        pendingThreadId = initialThreadId
        
        // Connect socket when user is authenticated
        if let userId = currentUserId {
            socketService.connect(userId: userId)
            chatSocketService.setupSocket()
            chatSocketService.connect()
        }
        
        setupSocketListeners()
    }
    
    private func setupSocketListeners() {
        chatSocketService.onMessageReceived = { [weak self] message in
            Task { @MainActor [weak self] in
                self?.handleIncomingMessage(message)
            }
        }
        
        // Listen for reactions
        chatSocketService.onMessageReaction { [weak self] dict in
            guard let self = self,
                  let messageId = dict["messageId"] as? String,
                  let reactions = dict["reactions"] as? [String: [String]] else { return }
            
            Task { @MainActor in
                if let index = self.messages.firstIndex(where: { $0.id == messageId }) {
                    var updatedMessage = self.messages[index]
                    updatedMessage.reactions = reactions
                    self.messages[index] = updatedMessage
                }
            }
        }
        
        // Listen for deletions
        chatSocketService.onMessageDeleted { [weak self] dict in
            guard let self = self,
                  let messageId = dict["messageId"] as? String else { return }
            
            Task { @MainActor in
                if let index = self.messages.firstIndex(where: { $0.id == messageId }) {
                    var updatedMessage = self.messages[index]
                    updatedMessage.isDeleted = true
                    updatedMessage.content = "🚫 Ce message a été supprimé"
                    self.messages[index] = updatedMessage
                }
            }
        }
    }
    
    // Helper to refresh a single message (or we could just patch it if we add a helper)
    func refreshMessage(messageId: String) {
        // Since we don't have a fetchSingleMessage endpoint easily available in service (we could add one),
        // let's just reload the messages for the thread or try to find it
        // Actually, for reactions/deletions, the payload usually contains the full updated object or we can construct it
        // For now, let's just reload the visible messages to be safe and simple
        Task {
            await self.refreshMessages()
        }
    }
    
    private func handleIncomingMessage(_ message: ChatMessage) {
        // If message belongs to current thread, append it
        if let selectedThread = selectedThread, message.threadId == selectedThread.id {
            // Avoid duplicates
            if !messages.contains(where: { $0.id == message.id }) {
                messages.append(message)
                
                // Mark as read immediately if we are in the thread
                Task {
                    await self.markSelectedThreadAsRead()
                }
            }
        }
        
        // Update thread list
        if let index = threads.firstIndex(where: { $0.id == message.threadId }) {
            var thread = threads[index]
            thread.lastMessage = message
            thread.lastMessageAt = message.createdAt
            
            // Move to top
            threads.remove(at: index)
            threads.insert(thread, at: 0)
            
            // Increment unread count if not in this thread
            if selectedThread?.id != message.threadId {
                // We would need to increment unread count here locally or fetch threads again
                // For now, let's just move it to top
                var updatedThread = threads[0]
                updatedThread.unreadCount += 1
                threads[0] = updatedThread
            }
        } else {
            // New thread? Reload threads
            Task { await loadThreads(reset: true) }
        }
    }

    func loadThreads(reset: Bool = true) async {
        guard let token else { return }
        if isLoadingThreads { return }
        if reset {
            skip = 0
            hasNextPage = false
        }
        isLoadingThreads = true
        defer { isLoadingThreads = false }
        do {
            let page = try await service.fetchThreads(limit: 20, skip: reset ? 0 : skip, accessToken: token)
            if reset {
                threads = page.items
            } else {
                let newOnes = page.items.filter { candidate in
                    !threads.contains(where: { $0.id == candidate.id })
                }
                threads.append(contentsOf: newOnes)
            }
            skip = threads.count
            hasNextPage = page.hasNextPage
            handleThreadSnapshotChange()
            if let targetId = pendingThreadId, let target = threads.first(where: { $0.id == targetId }) {
                pendingThreadId = nil
                await open(thread: target, markAsRead: false)
            } else if shouldAutoSelectFirstThread, selectedThread == nil, let first = threads.first {
                await open(thread: first, markAsRead: false)
            } else {
                syncSelectedThread()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMoreIfNeeded(current thread: ChatThread) async {
        guard hasNextPage, !isFetchingMore else { return }
        if threads.last?.id == thread.id {
            isFetchingMore = true
            await loadThreads(reset: false)
            isFetchingMore = false
        }
    }

    func open(thread: ChatThread, markAsRead: Bool = true) async {
        // Leave previous thread if any
        if let previousThread = selectedThread {
            chatSocketService.leaveThread(threadId: previousThread.id)
        }
        
        selectedThread = thread
        messages = []
        replyToMessage = nil
        
        // Join socket room BEFORE loading messages to ensure we don't miss anything
        chatSocketService.joinThread(threadId: thread.id)
        
        await loadMessages(for: thread)
        if markAsRead {
            await markSelectedThreadAsRead()
        }
    }

    func closeThread() {
        if let thread = selectedThread {
            chatSocketService.leaveThread(threadId: thread.id)
        }
        
        selectedThread = nil
        messages = []
        composerText = ""
        replyToMessage = nil
        
        // Refresh threads list to update unread counts/last messages
        Task {
            await loadThreads(reset: true)
        }
    }

    func refreshMessages() async {
        guard let thread = selectedThread else { return }
        await loadMessages(for: thread)
    }

    private func loadMessages(for thread: ChatThread) async {
        guard let token else { return }
        if isLoadingMessages { return }
        isLoadingMessages = true
        defer { isLoadingMessages = false }
        do {
            let previousIds = Set(messages.map { $0.id })
            let response = try await service.fetchMessages(threadId: thread.id, accessToken: token)
            messages = response.items
            let incoming = response.items.filter { !previousIds.contains($0.id) && $0.senderId != currentUserId }
            if !incoming.isEmpty && !previousIds.isEmpty, let latest = incoming.last {
                notifyIncomingMessage(thread: thread, message: latest)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendCurrentMessage() async {
        let trimmed = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let token, let activeThread = selectedThread, !trimmed.isEmpty, !isSending else { return }
        isSending = true
        defer { isSending = false }
        do {
            let message = try await service.sendMessage(
                threadId: activeThread.id,
                content: trimmed,
                replyToId: replyToMessage?.id,
                accessToken: token
            )
            messages.append(message)
            composerText = ""
            replyToMessage = nil
            await markSelectedThreadAsRead()
            Task { await self.loadThreads(reset: true) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func react(to message: ChatMessage, emoji: String) async {
        guard let token else { return }
        
        // Optimistic update (or at least update with result)
        do {
            let updatedMessage = try await service.react(to: message.id, emoji: emoji, accessToken: token)
            
            // Update local state immediately with the server response
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                messages[index] = updatedMessage
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func delete(message: ChatMessage) async {
        guard let token else { return }
        do {
            let updatedMessage = try await service.delete(messageId: message.id, accessToken: token)
            
            // Update local state immediately
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                messages[index] = updatedMessage
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func setReplyTo(_ message: ChatMessage) {
        replyToMessage = message
    }
    
    func cancelReply() {
        replyToMessage = nil
    }

    func markSelectedThreadAsRead() async {
        guard let token, let thread = selectedThread else { return }
        _ = try? await service.markThreadRead(threadId: thread.id, accessToken: token)
    }

    func planSessionTapped() {
        presentToast("Bientôt disponible — planifiez via l'onglet Sessions.")
    }

    func presentStartConversationSheet() {
        isPresentingStartConversation = true
    }

    func dismissStartConversationSheet() {
        isPresentingStartConversation = false
    }

    func startConversation(withEmail email: String, topic: String?) async {
        guard let token else { return }
        guard let sanitizedEmail = sanitizeEmail(email), !isCreatingThread else { return }
        isCreatingThread = true
        errorMessage = nil
        defer { isCreatingThread = false }
        do {
            // Fetch the user profile by email or username
            let userService = UserService()
            let targetUser = try await userService.fetchUserByEmail(sanitizedEmail, accessToken: token)
            
            // Create the thread with the fetched user's ID
            let thread = try await service.createThread(
                participantId: targetUser.id,
                participantEmail: nil,
                sessionId: nil,
                topic: sanitizeTopic(topic),
                accessToken: token
            )
            upsert(thread: thread)
            pendingThreadId = thread.id
            isPresentingStartConversation = false
            await open(thread: thread, markAsRead: false)
            presentToast("Conversation prête")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func displayName(for thread: ChatThread) -> String {
        thread.partner(for: currentUserId)?.displayName ?? "Conversation"
    }

    func partnerInitials(for thread: ChatThread) -> String {
        thread.partner(for: currentUserId)?.initials ?? "?"
    }

    func isOwnMessage(_ message: ChatMessage) -> Bool {
        message.senderId == currentUserId
    }

    func bubbleTime(for message: ChatMessage) -> String {
        guard let created = message.createdAt else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: created)
    }

    func relativeTime(for thread: ChatThread) -> String {
        guard let date = thread.lastMessageAt ?? thread.lastMessage?.createdAt else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    func filteredThreads() -> [ChatThread] {
        guard !searchQuery.isEmpty else { return threads }
        let lowered = searchQuery.lowercased()
        return threads.filter { thread in
            displayName(for: thread).lowercased().contains(lowered)
            || (thread.topic?.lowercased().contains(lowered) ?? false)
        }
    }

    func presentToast(_ message: String) {
        toastMessage = message
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                if self?.toastMessage == message {
                    self?.toastMessage = nil
                }
            }
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    private func syncSelectedThread() {
        guard let selectedThread else { return }
        if let updated = threads.first(where: { $0.id == selectedThread.id }) {
            self.selectedThread = updated
        }
    }

    private func notifyIncomingMessage(thread: ChatThread, message: ChatMessage) {
        notificationManager.presentInAppNotification(
            identifier: message.id,
            title: displayName(for: thread),
            body: message.content
        )
    }

    private func handleThreadSnapshotChange() {
        defer {
            lastKnownThreadMessageIds = snapshot(from: threads)
            hasRecordedThreadSnapshot = true
        }
        guard hasRecordedThreadSnapshot else { return }
        for thread in threads {
            guard let latest = thread.lastMessage, latest.senderId != currentUserId else { continue }
            if lastKnownThreadMessageIds[thread.id] != latest.id {
                notifyIncomingMessage(thread: thread, message: latest)
            }
        }
    }

    private func upsert(thread: ChatThread) {
        threads.removeAll { $0.id == thread.id }
        threads.insert(thread, at: 0)
        skip = threads.count
    }

    private func sanitizeEmail(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty ? nil : trimmed
    }

    private func sanitizeTopic(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func snapshot(from threads: [ChatThread]) -> [String: String] {
        threads.reduce(into: [:]) { partialResult, thread in
            if let id = thread.lastMessage?.id {
                partialResult[thread.id] = id
            }
        }
    }
    
    // MARK: - Calling Methods
    
    func initiateVoiceCall() {
        guard let thread = selectedThread,
              let partner = thread.partner(for: currentUserId),
              socketService.isConnected else {
            presentToast("Impossible d'initier l'appel")
            return
        }
        
        CallManager.shared.startCall(recipientId: partner.id, recipientName: partner.username ?? "User")
    }
    
    func initiateVideoCall() {
        guard let thread = selectedThread,
              let partner = thread.partner(for: currentUserId),
              socketService.isConnected else {
            presentToast("Impossible d'initier l'appel")
            return
        }
        
        CallManager.shared.startCall(recipientId: partner.id, recipientName: partner.username ?? "User", isVideo: true)
    }
}

