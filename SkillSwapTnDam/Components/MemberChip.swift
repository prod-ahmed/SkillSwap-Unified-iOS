import SwiftUI

struct MemberChip: View {
    let member: UserSuggestion
    let availabilityStatus: AvailabilityStatus?
    let onRemove: () -> Void
    
    enum AvailabilityStatus {
        case available
        case busy
        case unknown
    }
    
    init(member: UserSuggestion, availabilityStatus: AvailabilityStatus? = nil, onRemove: @escaping () -> Void) {
        self.member = member
        self.availabilityStatus = availabilityStatus
        self.onRemove = onRemove
    }
    
    var body: some View {
        HStack(spacing: 8) {
            avatar
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(member.username)
                    .font(.caption.bold())
                Text(member.email)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if let status = availabilityStatus {
                Circle()
                    .fill(status == .available ? Color.green : (status == .busy ? Color.red : Color.gray))
                    .frame(width: 8, height: 8)
            }
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color(.systemGray6))
        )
        .onTapGesture {
            onRemove()
        }
    }
    
    @ViewBuilder
    private var avatar: some View {
        if let urlString = member.displayImage, let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .overlay(ProgressView().scaleEffect(0.6))
            }
            .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.orange.opacity(0.2))
                .overlay(
                    Text(member.initials.uppercased())
                        .font(.caption.bold())
                        .foregroundColor(.orange)
                )
        }
    }
}
