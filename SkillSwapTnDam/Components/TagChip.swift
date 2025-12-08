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
struct ChipFlowLayout<Content: View>: View {
    var spacing: CGFloat
    @ViewBuilder var content: Content

    init(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        var width: CGFloat = 0
        var height: CGFloat = 0

        return GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                content
                    .alignmentGuide(.leading) { d in
                        if abs(width - d.width) > geometry.size.width {
                            width = 0
                            height -= d.height + spacing
                        }
                        let result = width
                        if d.width != 0 { width -= d.width + spacing }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if height != 0 { }
                        return result
                    }
            }
        }
        .frame(minHeight: 0)
        .fixedSize(horizontal: false, vertical: true)
    }
}


