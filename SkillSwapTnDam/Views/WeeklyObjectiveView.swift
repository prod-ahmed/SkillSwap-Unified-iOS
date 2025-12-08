import SwiftUI

struct WeeklyObjectiveView: View {
    @StateObject private var viewModel = WeeklyObjectiveViewModel()
    @ObservedObject private var localization = LocalizationManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if viewModel.isLoading && viewModel.currentObjective == nil {
                        loadingView
                    } else if let objective = viewModel.currentObjective {
                        currentObjectiveCard(objective)
                    } else {
                        emptyStateView
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(localization.localized(.weeklyObjectiveTitle))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            viewModel.showHistory = true
                        } label: {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                        
                        if !viewModel.hasActiveObjective {
                            Button {
                                viewModel.presentCreateForm()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                            }
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.loadCurrentObjective()
            }
            .task {
                await viewModel.loadCurrentObjective()
            }
            .sheet(isPresented: $viewModel.showCreateForm) {
                CreateWeeklyObjectiveView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showHistory) {
                WeeklyObjectiveHistoryView(viewModel: viewModel)
            }
            .alert(localization.localized(.error), isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { _ in viewModel.errorMessage = nil }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text(localization.localized(.loading))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "target")
                .font(.system(size: 60))
                .foregroundColor(Color(hex: "#00A8A8"))
            
            Text(localization.localized(.noActiveObjective))
                .font(.title2.bold())
            
            Text(localization.localized(.createObjectivePrompt))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                viewModel.presentCreateForm()
            } label: {
                Label(localization.localized(.createObjective), systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(colors: [Color(hex: "#00A8A8"), Color(hex: "#00B8B8")], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(16)
            }
        }
        .padding(30)
        .background(Color(.systemBackground))
        .cornerRadius(24)
    }
    
    // MARK: - Current Objective Card
    
    private func currentObjectiveCard(_ objective: WeeklyObjective) -> some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(objective.title)
                            .font(.title2.bold())
                        
                        Text("\(objective.completedTasksCount)/7 \(localization.localized(.tasksCompleted))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Status badge
                    if objective.status == .completed {
                        Label(localization.localized(.completed), systemImage: "checkmark.seal.fill")
                            .font(.caption.bold())
                            .foregroundColor(.green)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.15))
                            .cornerRadius(12)
                    }
                }
                
                // Progress bar
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(String(format: "%.1fh / %dh", objective.completedHours, objective.targetHours))
                            .font(.subheadline.bold())
                        Spacer()
                        Text("\(objective.progressPercent)%")
                            .font(.subheadline.bold())
                            .foregroundColor(Color(hex: "#FF6B35"))
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(.systemGray5))
                                .frame(height: 10)
                            
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#FF6B35"), Color(hex: "#FFB347")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * CGFloat(objective.progressPercent) / 100, height: 10)
                        }
                    }
                    .frame(height: 10)
                }
            }
            .padding()
            .background(
                LinearGradient(colors: [Color(hex: "#00A8A8"), Color(hex: "#00B8B8")], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .foregroundColor(.white)
            .cornerRadius(20)
            
            // Today's Task Highlight
            if let todayTask = objective.todayTask {
                todayTaskCard(todayTask, index: objective.todayTaskIndex)
            }
            
            // Daily Tasks List
            VStack(alignment: .leading, spacing: 12) {
                Text(localization.localized(.dailyTasks))
                    .font(.headline)
                    .padding(.horizontal)
                
                ForEach(Array(objective.dailyTasks.enumerated()), id: \.offset) { index, task in
                    dailyTaskRow(task, index: index, isToday: index == objective.todayTaskIndex)
                }
            }
            .padding(.vertical)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            
            // Delete button
            Button(role: .destructive) {
                Task {
                    await viewModel.deleteObjective()
                }
            } label: {
                Label(localization.localized(.deleteObjective), systemImage: "trash")
                    .font(.subheadline)
            }
            .padding(.top, 10)
        }
    }
    
    // MARK: - Today's Task Card
    
    private func todayTaskCard(_ task: DailyTask, index: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "calendar.circle.fill")
                .font(.title)
                .foregroundColor(task.isCompleted ? .green : Color(hex: "#FF6B35"))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(localization.localized(.todayTask))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(task.task)
                    .font(.subheadline.bold())
                    .strikethrough(task.isCompleted)
            }
            
            Spacer()
            
            Button {
                Task {
                    await viewModel.toggleTask(at: index)
                }
            } label: {
                Image(systemName: task.isCompleted ? "arrow.uturn.backward.circle" : "checkmark.circle")
                    .font(.title2)
                    .foregroundColor(task.isCompleted ? .orange : .green)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(task.isCompleted ? Color.green.opacity(0.1) : Color(hex: "#FF6B35").opacity(0.1))
        )
    }
    
    // MARK: - Daily Task Row
    
    private func dailyTaskRow(_ task: DailyTask, index: Int, isToday: Bool) -> some View {
        HStack(spacing: 12) {
            Button {
                Task {
                    await viewModel.toggleTask(at: index)
                }
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(task.isCompleted ? .green : .gray)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.day)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(task.task)
                    .font(.subheadline)
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
            }
            
            Spacer()
            
            if isToday {
                Text(localization.localized(.today))
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#FF6B35"))
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(isToday ? Color(hex: "#FF6B35").opacity(0.05) : Color.clear)
    }
}

// MARK: - Create Weekly Objective View

struct CreateWeeklyObjectiveView: View {
    @ObservedObject var viewModel: WeeklyObjectiveViewModel
    @ObservedObject private var localization = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                // AI Generation Section
                Section(header: Text("🤖 AI-Powered Planning")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Enter your learning goal and let AI create a weekly plan for you")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("e.g., Learn SwiftUI, Master Python basics...", text: $viewModel.userGoalPrompt)
                            .textFieldStyle(.roundedBorder)
                        
                        Button {
                            Task {
                                await viewModel.generateWithAI()
                            }
                        } label: {
                            HStack {
                                if viewModel.isGeneratingAI {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "wand.and.stars")
                                }
                                Text(viewModel.isGeneratingAI ? "Generating..." : "Generate with AI")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(colors: [Color(hex: "#00A8A8"), Color(hex: "#00B8B8")], startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(viewModel.isGeneratingAI || viewModel.userGoalPrompt.trimmingCharacters(in: .whitespaces).isEmpty)
                        
                        if !viewModel.aiSuggestion.isEmpty {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.yellow)
                                Text(viewModel.aiSuggestion)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(10)
                            .background(Color.yellow.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                
                Section(header: Text(localization.localized(.objectiveDetails))) {
                    TextField(localization.localized(.objectiveTitlePlaceholder), text: $viewModel.formTitle)
                    
                    Stepper(value: $viewModel.formTargetHours, in: 1...50) {
                        HStack {
                            Text(localization.localized(.targetHours))
                            Spacer()
                            Text("\(viewModel.formTargetHours)h")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text(localization.localized(.dates))) {
                    DatePicker(localization.localized(.startDate), selection: $viewModel.formStartDate, displayedComponents: .date)
                    DatePicker(localization.localized(.endDate), selection: $viewModel.formEndDate, displayedComponents: .date)
                }
                
                Section(header: Text(localization.localized(.dailyTasks7))) {
                    ForEach(0..<7, id: \.self) { index in
                        HStack(alignment: .top, spacing: 8) {
                            Text("Day \(index + 1)")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(hex: "#00A8A8"))
                                .cornerRadius(6)
                                .frame(width: 55)
                            
                            Text(viewModel.formTasks[index].isEmpty ? "Not generated yet" : viewModel.formTasks[index])
                                .font(.subheadline)
                                .foregroundColor(viewModel.formTasks[index].isEmpty ? .secondary : .primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle(localization.localized(.newObjective))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localization.localized(.cancel)) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await viewModel.createObjective()
                        }
                    } label: {
                        if viewModel.isCreating {
                            ProgressView()
                        } else {
                            Text(localization.localized(.create))
                        }
                    }
                    .disabled(viewModel.isCreating || viewModel.formTitle.isEmpty || !allTasksGenerated)
                }
            }
        }
    }
    
    private var allTasksGenerated: Bool {
        viewModel.formTasks.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }
}

// MARK: - History View

struct WeeklyObjectiveHistoryView: View {
    @ObservedObject var viewModel: WeeklyObjectiveViewModel
    @ObservedObject private var localization = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.historyObjectives.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.historyObjectives.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.badge.questionmark")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text(localization.localized(.noHistory))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(viewModel.historyObjectives) { objective in
                        historyCard(objective)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(localization.localized(.history))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localization.localized(.done)) {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.loadHistory()
            }
        }
    }
    
    private func historyCard(_ objective: WeeklyObjective) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(objective.title)
                    .font(.headline)
                
                Spacer()
                
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
            }
            
            HStack {
                Label(String(format: "%.1fh / %dh", objective.completedHours, objective.targetHours), systemImage: "clock")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Label("\(objective.completedTasksCount)/7", systemImage: "checklist")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 6)
                    
                    Capsule()
                        .fill(Color.green)
                        .frame(width: geometry.size.width * CGFloat(objective.progressPercent) / 100, height: 6)
                }
            }
            .frame(height: 6)
            
            Text(formatDateRange(objective.startDate, objective.endDate))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
    
    private func formatDateRange(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}

#Preview {
    WeeklyObjectiveView()
        .environmentObject(AuthenticationManager.shared)
}
