import SwiftUI
import MapKit
import AuthenticationServices

struct CreateSessionView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentStep: Int = 1
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var selectedSkills: Set<String> = []
    @State private var customSkills: [String] = []
    @State private var customSkillInput: String = ""
    
    @State private var selectedDate: Date = Date()
    @State private var startTime: Date = Date()
    @State private var duration: Int = 60
    
    @State private var sessionMode: Int = 0 // 0 = Online, 1 = In-person
    @State private var location: String = ""
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var showLocationPicker: Bool = false
    
    @State private var meetingLinkInput: String = ""
    
    @State private var emailInput: String = ""
    @State private var emailError: String?
    @State private var formError: String?
    @State private var isValidatingEmail = false
    @State private var isSubmitting = false
    
    @State private var selectedMembers: [UserSuggestion] = []
    @State private var suggestions: [UserSuggestion] = []
    @State private var isSearchingMembers = false
    @State private var availabilityResults: [String: AvailabilityResponse] = [:]
    @State private var availabilityMember: UserSuggestion?
    @State private var availabilityResult: AvailabilityResponse?
    
    @State private var emailSearchTask: Task<Void, Never>?
    
    @FocusState private var emailFieldFocused: Bool
    
    private let availableSkills = ["Design", "Développement", "Marketing", "Photoshop", "Musique", "Autre"]
    private let durationOptions = [30, 60, 90, 120]
    private var stepTitles: [String] {
        [localized(.stepSession), localized(.stepPlanning), localized(.stepInvitations)]
    }
    private let userService = UserService.shared
    
    private var allSkills: [String] {
        Array(Set(availableSkills + customSkills)).sorted()
    }
    
    private var sessionDateTime: Date {
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: startTime)
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute
        return Calendar.current.date(from: dateComponents) ?? selectedDate
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    header
                    progressIndicator
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            switch currentStep {
                            case 1: step1Content
                            case 2: step2Content
                            default: step3Content
                            }
                            
                            if let formError {
                                Text(formError)
                                    .font(.footnote)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                    
                    bottomButtons
                }
            }
        }
        .navigationBarBackButtonHidden()
        .sheet(item: $availabilityMember) { member in
            AvailabilitySheet(member: member, availability: availabilityResult)
        }
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerView(address: $location, coordinate: $selectedCoordinate)
        }
    }
    
    // MARK: - Header & Progress
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    if currentStep > 1 {
                        currentStep -= 1
                    } else {
                        dismiss()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text("SkillSwapTN")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(localized(.createSessionTitle))
                    .font(.title3.bold())
                Text(localized(.createSessionSubtitle))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.top, 16)
    }
    
    private var progressIndicator: some View {
        HStack(alignment: .center, spacing: 0) {
            ForEach(stepTitles.indices, id: \.self) { index in
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(index + 1 <= currentStep ? Color.orange : Color(.systemGray5))
                            .frame(width: 34, height: 34)
                        Text("\(index + 1)")
                            .font(.subheadline.bold())
                            .foregroundColor(index + 1 <= currentStep ? .white : .secondary)
                    }
                    Text(stepTitles[index])
                        .font(.caption)
                        .foregroundColor(index + 1 <= currentStep ? .primary : .secondary)
                }
                
                if index < stepTitles.count - 1 {
                    Rectangle()
                        .fill(index + 1 < currentStep ? Color.orange : Color(.systemGray4))
                        .frame(width: 50, height: 2)
                        .padding(.horizontal, 6)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 16)
    }
    
    // MARK: - Steps
    private var step1Content: some View {
        VStack(spacing: 20) {
            card {
                sectionHeader(localized(.sessionTitle))
                inputField(placeholder: localized(.sessionTitlePlaceholder), text: $title)
                
                sectionHeader(localized(.description))
                descriptionField
                
                sectionHeader(localized(.skill))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 12)], spacing: 12) {
                    ForEach(allSkills, id: \.self) { skill in
                        Button {
                            toggleSkill(skill)
                        } label: {
                            Text(skill)
                                .font(.subheadline.weight(.semibold))
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(selectedSkills.contains(skill) ? Color.orange : Color(.secondarySystemBackground))
                                )
                                .foregroundColor(selectedSkills.contains(skill) ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Divider()
                
                sectionHeader(localized(.addSkill))
                HStack(spacing: 12) {
                    TextField(localized(.customSkillPlaceholder), text: $customSkillInput)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
                    
                    Button {
                        addCustomSkill()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                            .background(Circle().fill(Color.orange))
                    }
                    .disabled(customSkillInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private var step2Content: some View {
        VStack(spacing: 20) {
            card {
                sectionHeader(localized(.sessionDate))
                datePickerField
                
                Divider()
                
                sectionHeader(localized(.startTime))
                timePickerField
                
                Divider()
                
                sectionHeader(localized(.duration))
                durationSelector
            }
        }
    }
    
    private var step3Content: some View {
        VStack(spacing: 20) {
            card {
                sectionHeader(localized(.membersJoin), subtitle: localized(.membersJoinSubtitle))
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(selectedMembers) { member in
                            MemberChip(member: member, availabilityStatus: getAvailabilityStatus(for: member.email)) {
                                removeMember(member)
                            }
                        }
                        
                        Button {
                            emailFieldFocused = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.headline)
                                .frame(width: 46, height: 46)
                                .background(Circle().strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6])))
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(localized(.participantEmail))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    
                    HStack {
                        TextField(localized(.emailPlaceholder), text: $emailInput)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .focused($emailFieldFocused)
                            .disabled(isValidatingEmail)
                            .onChange(of: emailInput, perform: handleEmailInputChange)
                        
                        if isSearchingMembers || isValidatingEmail {
                            ProgressView().scaleEffect(0.9)
                        } else if !emailInput.isEmpty {
                            Button(action: addEmail) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.orange)
                            }
                            .disabled(emailInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).stroke(Color.orange, lineWidth: 1))
                    
                    if let error = emailError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                if !suggestions.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(suggestions) { suggestion in
                            Button {
                                selectSuggestion(suggestion)
                            } label: {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(Color.orange.opacity(0.15))
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Text(suggestion.username.prefix(1).uppercased())
                                                .font(.headline)
                                                .foregroundColor(.orange)
                                        )
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(suggestion.username)
                                            .font(.subheadline.bold())
                                        Text(suggestion.email)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    let status = getAvailabilityStatus(for: suggestion.email)
                                    if status != .unknown {
                                        Circle()
                                            .fill(status == .available ? Color.green : Color.red)
                                            .frame(width: 10, height: 10)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                            
                            if suggestion.id != suggestions.last?.id {
                                Divider().padding(.leading, 60)
                            }
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color(.systemBackground)))
                    .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
                }
            }
            
            card {
                sectionHeader(localized(.sessionMode))
                HStack(spacing: 12) {
                    modeSelectionButton(title: localized(.online), icon: "video.fill", index: 0)
                    modeSelectionButton(title: localized(.inPerson), icon: "person.2.fill", index: 1)
                }
                
                Divider().padding(.vertical, 8)
                
                if sessionMode == 0 {
                    sectionHeader(localized(.meetingLink))
                    inputField(placeholder: localized(.meetingLinkPlaceholder), text: $meetingLinkInput, icon: "link")
                } else {
                    sectionHeader(localized(.meetingLocation))
                    inputField(placeholder: localized(.meetingLocationPlaceholder), text: $location, icon: "mappin")
                    
                    if let coordinate = selectedCoordinate {
                        Text(String(format: "Coordonnées: %.4f, %.4f", coordinate.latitude, coordinate.longitude))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: { showLocationPicker = true }) {
                        HStack {
                            Image(systemName: "map")
                            Text(localized(.selectOnMap))
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.orange))
                    }
                }
            }
        }
    }
    
    // MARK: - Subviews
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color(.systemBackground)))
        .shadow(color: .black.opacity(0.05), radius: 18, x: 0, y: 8)
    }
    
    private func sectionHeader(_ title: String, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            if let subtitle {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func inputField(placeholder: String, text: Binding<String>, icon: String? = nil) -> some View {
        HStack(spacing: 10) {
            if let icon {
                Image(systemName: icon)
                    .foregroundColor(.orange)
            }
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.sentences)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))
    }
    
    private var descriptionField: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $description)
                .frame(minHeight: 120)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))
            
            if description.isEmpty {
                Text(localized(.descriptionPlaceholder))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
            }
        }
    }
    
    private var datePickerField: some View {
        HStack {
            Image(systemName: "calendar")
                .foregroundColor(.orange)
            DatePicker("", selection: $selectedDate, displayedComponents: .date)
                .labelsHidden()
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))
    }
    
    private var timePickerField: some View {
        HStack {
            Image(systemName: "clock")
                .foregroundColor(.orange)
            DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                .labelsHidden()
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))
    }
    
    private var durationSelector: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 12)], spacing: 12) {
            ForEach(durationOptions, id: \.self) { option in
                Button {
                    duration = option
                } label: {
                    Text(option == 120 ? "120min" : "\(option)min")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(duration == option ? Color.orange : Color(.secondarySystemBackground))
                        )
                        .foregroundColor(duration == option ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func modeSelectionButton(title: String, icon: String, index: Int) -> some View {
        Button {
            sessionMode = index
        } label: {
            HStack {
                Image(systemName: icon)
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(sessionMode == index ? Color.orange : Color(.secondarySystemBackground))
            )
            .foregroundColor(sessionMode == index ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
    
    private var bottomButtons: some View {
        HStack(spacing: 12) {
            if currentStep > 1 {
                Button {
                    currentStep -= 1
                } label: {
                    Text(localized(.back))
                        .font(.headline)
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 18).stroke(Color.orange, lineWidth: 1.5))
                }
            }
            
            Button {
                if currentStep < 3 {
                    currentStep += 1
                } else {
                    submitSession()
                }
            } label: {
                HStack {
                    Text(currentStep < 3 ? localized(.continueButton) : (isSubmitting ? localized(.creatingButton) : localized(.createSessionButton)))
                        .font(.headline)
                    Image(systemName: currentStep < 3 ? "chevron.right" : "sparkles")
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(RoundedRectangle(cornerRadius: 18).fill(Color.orange))
            }
            .disabled(isSubmitting)
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Actions
    private func toggleSkill(_ skill: String) {
        if selectedSkills.contains(skill) {
            selectedSkills.remove(skill)
        } else {
            selectedSkills.insert(skill)
        }
    }
    
    private func addCustomSkill() {
        let trimmed = customSkillInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !customSkills.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            customSkills.append(trimmed)
        }
        selectedSkills.insert(trimmed)
        customSkillInput = ""
    }
    
    private func addEmail() {
        let trimmed = emailInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else {
            emailError = localized(.enterEmailError)
            return
        }
        guard trimmed.contains("@"), trimmed.contains(".") else {
            emailError = localized(.invalidEmailError)
            return
        }
        guard !selectedMembers.contains(where: { $0.email.lowercased() == trimmed }) else {
            emailError = localized(.participantExistsError)
            return
        }
        
        emailError = nil
        isValidatingEmail = true
        
        Task {
            do {
                let suggestion = try await userService.fetchUserSuggestion(email: trimmed)
                await MainActor.run {
                    isValidatingEmail = false
                    selectedMembers.append(suggestion)
                    emailInput = ""
                    suggestions.removeAll()
                    showAvailability(for: suggestion)
                }
            } catch {
                await MainActor.run {
                    isValidatingEmail = false
                    emailError = localized(.participantNotFoundError)
                }
            }
        }
    }
    
    private func submitSession() {
        formError = nil
        
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            formError = localized(.titleRequiredError)
            currentStep = 1
            return
        }
        
        guard !selectedSkills.isEmpty else {
            formError = localized(.skillRequiredError)
            currentStep = 1
            return
        }
        
        guard !selectedMembers.isEmpty else {
            formError = localized(.participantRequiredError)
            return
        }
        
        if sessionMode == 1 && location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            formError = localized(.locationRequiredError)
            return
        }
        
        isSubmitting = true
        
        Task {
            do {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let dateString = formatter.string(from: sessionDateTime)
                
                let memberEmails = selectedMembers.map { $0.email }
                let skillValue = selectedSkills.sorted().joined(separator: ", ")
                let finalMeetingLink = sessionMode == 0
                    ? (meetingLinkInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : meetingLinkInput)
                    : nil
                
                let newSession = NewSession(
                    title: title,
                    skill: skillValue.isEmpty ? "Autre" : skillValue,
                    date: dateString,
                    duration: duration,
                    status: "upcoming",
                    meetingLink: finalMeetingLink,
                    location: sessionMode == 1 ? location : nil,
                    notes: description.isEmpty ? nil : description,
                    studentEmail: memberEmails.first,
                    studentEmails: memberEmails.count > 1 ? memberEmails : nil
                )
                
                guard let token = UserDefaults.standard.string(forKey: "authToken") else {
                    throw NSError(domain: "SessionService", code: 401,
                                  userInfo: [NSLocalizedDescriptionKey: localized(.userNotConnectedError)])
                }
                _ = try await SessionService.shared.createSession(session: newSession, token: token)
                await MainActor.run {
                    isSubmitting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    formError = String(format: localized(.creationError), error.localizedDescription)
                }
            }
        }
    }
    
    private func handleEmailInputChange(_ newValue: String) {
        emailSearchTask?.cancel()
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            suggestions = []
            return
        }
        
        emailSearchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            await searchSuggestions(for: trimmed)
        }
    }
    
    private func searchSuggestions(for query: String) async {
        do {
            await MainActor.run { isSearchingMembers = true }
            let results = try await userService.searchUsers(query: query)
            print("✅ Got \(results.count) user results")
            let filtered = results.filter { suggestion in
                !selectedMembers.contains(where: { $0.id == suggestion.id })
            }
            
            await MainActor.run {
                suggestions = filtered
                isSearchingMembers = false
            }
            
            // Fetch availability separately - don't fail the whole search if this fails
            let emails = filtered.map { $0.email }
            if !emails.isEmpty {
                do {
                    let availability = try await SessionService.shared.fetchAvailability(
                        emails: emails,
                        startDate: sessionDateTime,
                        duration: duration
                    )
                    await MainActor.run {
                        availabilityResults.merge(availability) { _, new in new }
                    }
                } catch {
                    print("⚠️ Availability check failed (non-critical): \(error)")
                }
            }
        } catch {
            // Ignore cancellation errors (user kept typing)
            if (error as NSError).code == NSURLErrorCancelled || Task.isCancelled {
                print("🔄 Search cancelled (user typing)")
                return
            }
            print("❌ Search error: \(error.localizedDescription)")
            print("❌ Full error: \(error)")
            await MainActor.run {
                isSearchingMembers = false
                emailError = localized(.loadSuggestionsError)
                suggestions = []
            }
        }
    }
    
    private func selectSuggestion(_ suggestion: UserSuggestion) {
        guard !selectedMembers.contains(where: { $0.id == suggestion.id }) else {
            emailInput = ""
            suggestions.removeAll()
            return
        }
        selectedMembers.append(suggestion)
        emailInput = ""
        suggestions.removeAll()
        emailFieldFocused = false
        showAvailability(for: suggestion)
    }
    
    private func removeMember(_ member: UserSuggestion) {
        selectedMembers.removeAll { $0.id == member.id }
        availabilityResults.removeValue(forKey: member.email)
    }
    
    private func showAvailability(for member: UserSuggestion) {
        Task {
            do {
                let response = try await SessionService.shared.fetchAvailability(
                    emails: [member.email],
                    startDate: sessionDateTime,
                    duration: duration
                )
                if let value = response[member.email] {
                    await MainActor.run {
                        availabilityResult = value
                        availabilityMember = member
                        availabilityResults[member.email] = value
                    }
                }
            } catch {
                await MainActor.run {
                    emailError = localized(.fetchAvailabilityError)
                }
            }
        }
    }
    
    private func getAvailabilityStatus(for email: String) -> MemberChip.AvailabilityStatus {
        guard let response = availabilityResults[email] else { return .unknown }
        return response.isAvailable ? .available : .busy
    }
}

struct CreateSessionView_Previews: PreviewProvider {
    static var previews: some View {
        CreateSessionView()
    }
}
