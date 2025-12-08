import Foundation
import SwiftUI

@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published var notifications: [NotificationItem] = []
    @Published var unreadCount: Int = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var toastMessage: String?
    @Published private(set) var respondingNotificationIDs: Set<String> = []
    @Published private(set) var markingReadIDs: Set<String> = []
    @Published var isMarkingAll: Bool = false

    private let service = NotificationService()
    private var currentPage: Int = 1
    private var hasNextPage: Bool = false

    func load(reset: Bool = true) async {
        guard let token = AuthenticationManager.shared.accessToken else { return }
        if reset {
            currentPage = 1
            hasNextPage = false
            notifications = []
        }
        isLoading = true
        errorMessage = nil
        do {
            let page = try await service.fetchNotifications(status: .all, page: currentPage, limit: 20, accessToken: token)
            if reset {
                notifications = page.items
            } else {
                notifications.append(contentsOf: page.items)
            }
            hasNextPage = page.hasNextPage
            unreadCount = try await service.fetchUnreadCount(accessToken: token)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadMoreIfNeeded(current item: NotificationItem) async {
        guard hasNextPage, let last = notifications.last, last.id == item.id, !isLoading else { return }
        currentPage += 1
        await load(reset: false)
    }

    func markAllAsRead() async {
        guard let token = AuthenticationManager.shared.accessToken else { return }
        guard !isMarkingAll else { return }
        isMarkingAll = true
        errorMessage = nil
        defer { isMarkingAll = false }
        do {
            let unread = try await service.markAllRead(accessToken: token)
            let now = Date()
            notifications = notifications.map { $0.updating(read: true, readAt: now) }
            unreadCount = unread
            presentToast("Toutes les notifications sont lues")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func respond(to notification: NotificationItem, accepted: Bool) async {
        guard let token = AuthenticationManager.shared.accessToken else { return }
        guard !respondingNotificationIDs.contains(notification.id) else { return }
        respondingNotificationIDs.insert(notification.id)
        errorMessage = nil
        defer { respondingNotificationIDs.remove(notification.id) }
        do {
            let updated = try await service.respond(notificationId: notification.id, accepted: accepted, accessToken: token)
            if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                notifications[index] = updated
            }
            if !notification.read {
                unreadCount = max(unreadCount - 1, 0)
            }
            presentToast(accepted ? "Report accepté" : "Report refusé")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markAsRead(_ notification: NotificationItem) async {
        guard !notification.read,
              let token = AuthenticationManager.shared.accessToken,
              !markingReadIDs.contains(notification.id) else { return }
        markingReadIDs.insert(notification.id)
        errorMessage = nil
        defer { markingReadIDs.remove(notification.id) }
        do {
            unreadCount = try await service.markRead(ids: [notification.id], accessToken: token)
            if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                notifications[index] = notification.updating(read: true, readAt: Date())
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func presentToast(_ message: String) {
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
}
