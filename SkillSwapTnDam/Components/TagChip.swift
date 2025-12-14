import SwiftUI

struct TagChip: View {
    let text: String
    var color: Color = .orange
    var removable: Bool = true
    var onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(color)
            if removable, let onRemove {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundColor(color)
                    .padding(4)
                    .background(Circle().fill(color.opacity(0.1)))
                    .onTapGesture { onRemove() }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(color.opacity(0.12))
        )
    }
}

struct SkillChipsEditor: View {
    @Binding var skills: [String]
    var color: Color = .orange

    @State private var newSkill: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ChipFlowLayout(spacing: 8) {
                ForEach(skills, id: \.self) { skill in
                    TagChip(text: skill, color: color, removable: true) {
                        skills.removeAll { $0 == skill }
                    }
                }
            }
            HStack(spacing: 8) {
                TextField("Ajouter une compétence", text: $newSkill)
                    .appField()
                Button(action: addSkill) {
                    Image(systemName: "plus")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                        .background(RoundedRectangle(cornerRadius: 12).fill(color))
                        .foregroundColor(.white)
                }
                .disabled(newSkill.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func addSkill() {
        let trimmed = newSkill.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !skills.contains(trimmed) else { return }
        skills.append(trimmed)
        newSkill = ""
    }
}

// Simple flow layout for chips
struct ChipFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = flow(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = flow(proposal: proposal, subviews: subviews)
        for (index, point) in result.points.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private func flow(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
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


