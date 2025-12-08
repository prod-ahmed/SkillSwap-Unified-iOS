import Foundation
import SwiftUI

enum NotificationKind: String, Codable {
    case match
    case message
    case reminder
    case suggestion
    case reschedule_request
    case reschedule_accepted
    case member_added
    case new_meeting_link
}

struct NotificationPayload: Codable {
    let newDate: String?
    let newTime: String?
    let requesterId: String?
    let requesterName: String?
    let meetingLink: String?
    let newStatus: String?
    let responseMessage: String?
    let responded: Bool?

    var parsedNewDate: Date? {
        guard let newDate else { return nil }
        return ISO8601DateFormatter.full.date(from: newDate)
    }
}

struct NotificationItem: Codable, Identifiable {
    let id: String
    let type: NotificationKind
    let title: String
    let message: String
    let payload: NotificationPayload?
    let session: String?
    let meetingUrl: String?
    let actionable: Bool
    let responded: Bool
    let read: Bool
    let readAt: Date?
    let actionResult: String?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case type, title, message, payload, session
        case meetingUrl, actionable, responded, read, readAt, actionResult
        case createdAt, updatedAt
    }

    var iconName: String {
        switch type {
        case .match: return "heart.fill"
        case .message: return "bubble.left.and.bubble.right.fill"
        case .reminder: return "bell.fill"
        case .suggestion: return "sparkles"
        case .reschedule_request: return "calendar.badge.clock"
        case .reschedule_accepted: return "checkmark.circle.fill"
        case .member_added: return "person.crop.circle.badge.plus"
        case .new_meeting_link: return "video.fill"
        }
    }

    var accentColor: Color {
        switch type {
        case .match: return Color(hex: "#FF6B35")
        case .message: return Color(hex: "#00A8A8")
        case .reminder: return Color(hex: "#FFD166")
        case .suggestion: return Color.purple
        case .reschedule_request: return Color.orange
        case .reschedule_accepted: return Color.green
        case .member_added: return Color.blue
        case .new_meeting_link: return Color(hex: "#00A8A8")
        }
    }

    var badgeText: String? {
        guard responded else { return nil }
        switch actionResult {
        case "accepted": return "Répondu"
        case "declined": return "Refusé"
        default: return "Répondu"
        }
    }

    var relativeDateString: String {
        guard let createdAt else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }

    var meetingLinkValue: String? {
        meetingUrl ?? payload?.meetingLink
    }
}

extension NotificationItem {
    func updating(
        read: Bool? = nil,
        readAt: Date? = nil,
        responded: Bool? = nil,
        actionResult: String? = nil
    ) -> NotificationItem {
        NotificationItem(
            id: id,
            type: type,
            title: title,
            message: message,
            payload: payload,
            session: session,
            meetingUrl: meetingUrl,
            actionable: actionable,
            responded: responded ?? self.responded,
            read: read ?? self.read,
            readAt: readAt ?? self.readAt,
            actionResult: actionResult ?? self.actionResult,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

struct NotificationPage: Codable {
    let items: [NotificationItem]
    let page: Int
    let limit: Int
    let total: Int
    let hasNextPage: Bool
}

extension ISO8601DateFormatter {
    static let full: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

extension Color {
    init(hex: String) {
        let clean = hex.replacingOccurrences(of: "#", with: "")
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let r, g, b: UInt64
        if clean.count == 6 {
            r = (int >> 16) & 0xFF
            g = (int >> 8) & 0xFF
            b = int & 0xFF
        } else {
            r = 255
            g = 255
            b = 255
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: 1)
    }
}
