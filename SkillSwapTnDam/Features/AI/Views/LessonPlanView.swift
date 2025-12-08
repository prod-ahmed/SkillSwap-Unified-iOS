import SwiftUI

struct LessonPlanView: View {
    let sessionId: String
    let isTeacher: Bool
    
    @StateObject private var viewModel = LessonPlanViewModel()
    @State private var selectedTab = 0
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                if viewModel.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Génération du plan de cours...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else if let plan = viewModel.lessonPlan {
                    VStack(spacing: 0) {
                        // Header Card
                        lessonPlanHeaderCard(plan: plan)
                            .padding(.horizontal)
                            .padding(.top)
                        
                        // Tabs
                        lessonPlanTabs
                        
                        // Content
                        TabView(selection: $selectedTab) {
                            LessonPlanOutlineView(plan: plan.plan)
                                .tag(0)
                            
                            LessonPlanChecklistView(
                                checklist: plan.checklist,
                                progress: plan.progress,
                                sessionId: sessionId,
                                viewModel: viewModel
                            )
                            .tag(1)
                            
                            LessonPlanResourcesView(resources: plan.resources)
                                .tag(2)
                            
                            LessonPlanHomeworkView(homework: plan.homework)
                                .tag(3)
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                    }
                } else {
                    // No plan - show generate button
                    VStack(spacing: 24) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("Aucun plan de cours")
                            .font(.title2)
                            .foregroundColor(.gray)
                        
                        Button {
                            Task {
                                await viewModel.generateLessonPlan(sessionId: sessionId)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Générer le plan de cours")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color.orange))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                }
            }
            .navigationTitle("Plan de cours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.primary)
                    }
                }
                
                if isTeacher, viewModel.lessonPlan != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            Task {
                                await viewModel.regenerateLessonPlan(sessionId: sessionId)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                Text("Régénérer")
                            }
                            .font(.subheadline)
                            .foregroundColor(.orange)
                        }
                    }
                }
            }
            .alert("Erreur", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.clearMessage()
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .alert("Succès", isPresented: .constant(viewModel.successMessage != nil)) {
                Button("OK") {
                    viewModel.clearMessage()
                }
            } message: {
                Text(viewModel.successMessage ?? "")
            }
            .task {
                await viewModel.loadLessonPlan(sessionId: sessionId)
            }
        }
    }
    
    // MARK: - Header Card
    private func lessonPlanHeaderCard(plan: LessonPlan) -> some View {
        HStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.2))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: "sparkles")
                        .foregroundColor(.orange)
                        .font(.title3)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Plan de cours IA")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let createdAt = plan.createdAt,
                   let date = parseDate(createdAt) {
                    Text("Généré le \(formatDate(date))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Tabs
    private var lessonPlanTabs: some View {
        HStack(spacing: 0) {
            ForEach(0..<4) { index in
                tabButton(for: index)
            }
        }
        .background(Color.white)
        .cornerRadius(16, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: -2)
    }
    
    private func tabButton(for index: Int) -> some View {
        let isSelected = selectedTab == index
        let iconColor = isSelected ? Color.orange : Color.gray
        let textColor = isSelected ? Color.orange : Color.gray
        let backgroundColor = isSelected ? Color.orange.opacity(0.1) : Color.clear
        let underlineColor = isSelected ? Color.orange : Color.clear
        
        return Button {
            withAnimation {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: tabIcon(for: index))
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
                
                Text(tabTitle(for: index))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(textColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                Rectangle()
                    .fill(backgroundColor)
            )
            .overlay(
                Rectangle()
                    .fill(underlineColor)
                    .frame(height: 3),
                alignment: .bottom
            )
        }
        .buttonStyle(.plain)
    }
    
    private func tabIcon(for index: Int) -> String {
        switch index {
        case 0: return "list.bullet"
        case 1: return "checkmark.circle"
        case 2: return "folder"
        case 3: return "graduationcap"
        default: return "circle"
        }
    }
    
    private func tabTitle(for index: Int) -> String {
        switch index {
        case 0: return "Plan"
        case 1: return "Étapes"
        case 2: return "Ressources"
        case 3: return "Devoirs"
        default: return ""
        }
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: dateString)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: date)
    }
}

// MARK: - Plan Outline View
struct LessonPlanOutlineView: View {
    let plan: String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(plan)
                    .font(.body)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Checklist View
struct LessonPlanChecklistView: View {
    let checklist: [String]
    let progress: [String: Bool]
    let sessionId: String
    @ObservedObject var viewModel: LessonPlanViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Objectifs de la session")
                        .font(.headline)
                }
                .padding(.horizontal)
                .padding(.top)
                
                ForEach(Array(checklist.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 12) {
                        Button {
                            Task {
                                let newValue = !(progress["\(index)"] ?? false)
                                await viewModel.updateProgress(
                                    sessionId: sessionId,
                                    checklistIndex: index,
                                    completed: newValue
                                )
                            }
                        } label: {
                            Image(systemName: progress["\(index)"] == true ? "checkmark.square.fill" : "square")
                                .font(.title3)
                                .foregroundColor(progress["\(index)"] == true ? .green : .gray)
                        }
                        .buttonStyle(.plain)
                        
                        Text("\(index + 1). \(item)")
                            .font(.body)
                            .foregroundColor(.primary)
                            .strikethrough(progress["\(index)"] == true)
                            .opacity(progress["\(index)"] == true ? 0.6 : 1.0)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Resources View
struct LessonPlanResourcesView: View {
    let resources: [String]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.orange)
                    Text("Ressources")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top)
                
                ForEach(resources, id: \.self) { resource in
                    if let url = URL(string: resource) {
                        Link(destination: url) {
                            HStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.orange.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Image(systemName: "link")
                                            .foregroundColor(.orange)
                                    )
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(resource)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                        .lineLimit(2)
                                    Text("LINK")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundColor(.orange)
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Homework View
struct LessonPlanHomeworkView: View {
    let homework: String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "graduationcap.fill")
                        .foregroundColor(.orange)
                    Text("Devoirs")
                        .font(.headline)
                }
                .padding(.horizontal)
                .padding(.top)
                
                Text(homework)
                    .font(.body)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal)
            }
            .padding(.bottom)
        }
        .background(Color(.systemGroupedBackground))
    }
}

