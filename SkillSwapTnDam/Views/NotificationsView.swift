import SwiftUI
import UIKit

@MainActor
struct NotificationsView: View {
    @StateObject private var viewModel: NotificationsViewModel

    init(viewModel: NotificationsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(.systemGroupedBackground).ignoresSafeArea()
                VStack(spacing: 0) {
                    header
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.notifications) { notification in
                                NotificationCardView(
                                    item: notification,
                                    isResponding: viewModel.respondingNotificationIDs.contains(notification.id),
                                    isMarkingRead: viewModel.markingReadIDs.contains(notification.id),
                                    onMarkRead: {
                                        Task { await viewModel.markAsRead(notification) }
                                    },
                                    onRespond: { accepted in
                                        Task { await viewModel.respond(to: notification, accepted: accepted) }
                                    }
                                )
                                .task {
                                    await viewModel.loadMoreIfNeeded(current: notification)
                                }
                            }

                            if viewModel.isLoading && viewModel.notifications.isEmpty {
                                ProgressView("Chargement…")
                                    .padding(.vertical, 32)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                    }
                    .refreshable {
                        await viewModel.load()
                    }
                }
            }
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { markAllButton } }
            .navigationTitle("Notifications")
            .task {
                await viewModel.load()
            }
            .overlay(alignment: .bottom) {
                VStack(spacing: 10) {
                    if let toast = viewModel.toastMessage {
                        ToastBanner(message: toast)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    if let error = viewModel.errorMessage {
                        ErrorBanner(message: error)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding()
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.toastMessage)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.errorMessage)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notifications")
                .font(.title2.bold())
                .foregroundColor(.white)
            Text(viewModel.unreadCount > 0 ? "\(viewModel.unreadCount) nouvelles" : "Aucune nouvelle notification")
                .foregroundColor(Color.white.opacity(0.8))
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            LinearGradient(colors: [Color(hex: "#FF6B35"), Color(hex: "#FFB347")], startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .padding(.bottom, -32)
        )
    }

    private var markAllButton: some View {
        Button {
            Task { await viewModel.markAllAsRead() }
        } label: {
            if viewModel.isMarkingAll {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.8)
            } else {
                Text("Tout marquer lu")
            }
        }
        .disabled(viewModel.unreadCount == 0 || viewModel.isMarkingAll)
    }
}

private struct NotificationCardView: View {
    let item: NotificationItem
    var isResponding: Bool = false
    var isMarkingRead: Bool = false
    var onMarkRead: () -> Void
    var onRespond: (Bool) -> Void

    private let calendarFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .full
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(item.accentColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                    .overlay(Image(systemName: item.iconName).foregroundColor(item.accentColor))

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.title)
                            .font(.headline)
                            .foregroundColor(item.read ? .primary : item.accentColor)
                        Spacer()
                        if !item.read { Circle().fill(Color(hex: "#FF6B35")).frame(width: 8, height: 8) }
                    }
                    Text(item.message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(item.relativeDateString)
                        .font(.caption)
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                }
            }

            if let payload = item.payload, item.type == .reschedule_request {
                VStack(alignment: .leading, spacing: 8) {
                    if let name = payload.requesterName {
                        Label(name, systemImage: "person.circle")
                            .font(.footnote.weight(.medium))
                    }
                    if let date = payload.parsedNewDate {
                        Label(calendarFormatter.string(from: date), systemImage: "calendar")
                            .font(.footnote.weight(.medium))
                    }
                    if let newTime = payload.newTime {
                        Label(newTime, systemImage: "clock")
                            .font(.footnote)
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.08))
                .cornerRadius(16)
            }

            if let link = item.meetingLinkValue {
                HStack {
                    Label(link, systemImage: "video")
                        .lineLimit(1)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = link
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                }
                .font(.footnote)
                .padding()
                .background(Color(hex: "#00A8A8").opacity(0.1))
                .cornerRadius(16)
            }

            if item.actionable && !item.responded {
                if isResponding {
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(.circular)
                        Spacer()
                    }
                    .padding(.vertical, 6)
                } else {
                    HStack(spacing: 12) {
                        Button {
                            onRespond(true)
                        } label: {
                            Label("Accepter", systemImage: "checkmark")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 8)
                        .background(LinearGradient(colors: [.green, Color.green.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                        .foregroundColor(.white)
                        .cornerRadius(20)

                        Button {
                            onRespond(false)
                        } label: {
                            Label("Refuser", systemImage: "xmark")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(20)
                    }
                    .disabled(isResponding)
                }
            } else if let badge = item.badgeText {
                Text(badge)
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(20)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        .onTapGesture {
            guard !item.read, !isMarkingRead else { return }
            onMarkRead()
        }
    }
}

private struct ToastBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline.weight(.medium))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(LinearGradient(colors: [Color(hex: "#FF6B35"), Color(hex: "#FFB347")], startPoint: .leading, endPoint: .trailing))
            )
    }
}

private struct ErrorBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.footnote)
            .foregroundColor(.red)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.red.opacity(0.1))
            .cornerRadius(16)
    }
}

#Preview {
    NotificationsView(viewModel: NotificationsViewModel())
        .environmentObject(AuthenticationManager.shared)
}
