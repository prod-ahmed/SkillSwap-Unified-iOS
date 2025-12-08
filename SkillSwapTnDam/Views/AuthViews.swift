import SwiftUI

struct AuthGatewayView: View {
    let onSuccess: () -> Void
    @State private var selection = 0 // 0 = Login, 1 = Register
    @StateObject private var localization = LocalizationManager.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Top Picker to switch views
                Picker("Auth", selection: $selection) {
                    Text(localization.localized(.signIn)).tag(0)
                    Text(localization.localized(.signUp)).tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                // MARK: - Show the appropriate view
                if selection == 0 {
                    LoginView(onSuccess: onSuccess)
                } else {
                    RegisterView(onSuccess: onSuccess)
                }

                Spacer()
            }
            .navigationTitle("SkillSwapTN")
        }
    }
}

struct LoginView: View {
    let onSuccess: () -> Void
    @StateObject private var viewModel = LoginViewModel()
    @StateObject private var localization = LocalizationManager.shared
    @State private var showDebug = false
    @State private var isSecure = true

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // ... (existing content)
                VStack(alignment: .leading, spacing: 12) {
                    Text(localization.localized(.email)).font(.subheadline).foregroundColor(.secondary)
                    HStack {
                        Image(systemName: "envelope").foregroundColor(.secondary)
                        TextField("votre@email.com", text: $viewModel.email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                    }
                    .appField()

                    Text(localization.localized(.password)).font(.subheadline).foregroundColor(.secondary)
                    HStack {
                        Image(systemName: "lock").foregroundColor(.secondary)
                        Group {
                            if isSecure {
                                SecureField("••••••••", text: $viewModel.password)
                            } else {
                                TextField(localization.localized(.password), text: $viewModel.password)
                            }
                        }
                        Button(action: { isSecure.toggle() }) {
                            Image(systemName: isSecure ? "eye" : "eye.slash")
                                .foregroundColor(.secondary)
                        }
                    }
                    .appField()

                    HStack {
                        Image(systemName: viewModel.rememberMe ? "checkmark.square.fill" : "square")
                            .foregroundColor(.secondary)
                            .onTapGesture {
                                viewModel.rememberMe.toggle()
                            }
                        Text(localization.localized(.rememberMe))
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Spacer()

                        NavigationLink(destination: ForgotPasswordView()) {
                            Text(localization.localized(.forgotPassword))
                                .font(.footnote)
                                .foregroundColor(.blue)
                        }
                    }
                }

                PrimaryButton(title: localization.localized(.signIn)) {
                    Task {
                        let success = await viewModel.login()
                        if success { onSuccess() }
                    }
                }

                if let error = viewModel.errorMessage {
                    Text(error).foregroundColor(.red).font(.footnote)
                }

                Text(localization.localized(.orContinueWith))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                HStack(spacing: 12) {
                    socialButton("G", color: .red)
                    socialButton("f", color: .blue)
                }
                
                // Debug Button
                Button(action: { showDebug = true }) {
                    Text("Debug Connection")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 20)
                }
            }
            .padding()
        }
        .sheet(isPresented: $showDebug) {
            ConnectivityTestView()
        }
    }

    private func socialButton(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(RoundedRectangle(cornerRadius: 12).fill(color))
    }
}

struct RegisterView: View {
    let onSuccess: () -> Void
    @StateObject private var viewModel = RegisterViewModel()
    @StateObject private var localization = LocalizationManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                labeledField(localization.localized(.fullName)) {
                    TextField("Votre nom", text: $viewModel.fullName)
                }
                labeledField(localization.localized(.email)) {
                    TextField("votre@email.com", text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                }
                labeledField(localization.localized(.password)) {
                    SecureField("••••••••", text: $viewModel.password)
                }
                labeledField(localization.localized(.confirmPassword)) {
                    SecureField("••••••••", text: $viewModel.confirmPassword)
                }
                labeledField(localization.localized(.referralCode) + " " + localization.localized(.optional)) {
                    TextField("ABCDE", text: $viewModel.referralCode)
                        .textInputAutocapitalization(.characters)
                        .disableAutocorrection(true)
                }
                if !viewModel.referralCode.isEmpty {
                    HStack {
                        Button(localization.localized(.validateCode)) {
                            Task { await viewModel.validateReferral() }
                        }
                        .buttonStyle(.borderedProminent)

                        if viewModel.isValidatingReferral {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                }
                if let referralMessage = viewModel.referralMessage {
                    Text(referralMessage)
                        .font(.footnote)
                        .foregroundColor(viewModel.referralPreview == nil ? .red : .green)
                }

                PrimaryButton(title: localization.localized(.createAccount)) {
                    Task {
                        let success = await viewModel.register()
                        if success {
                            onSuccess()
                        }
                    }
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.footnote)
                }
            }
            .padding()
        }
    }

    private func labeledField(_ label: String, @ViewBuilder field: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.subheadline).foregroundColor(.secondary)
            HStack { field() }
                .appField()
        }
    }
}

struct AuthViews_Previews: PreviewProvider {
    static var previews: some View {
        AuthGatewayView(onSuccess: {})
    }
}

struct ConnectivityTestView: View {
    @State private var result: String = "Ready to test"
    @State private var isLoading = false
    @ObservedObject private var callManager = CallManager.shared
    @ObservedObject private var socketService = SocketService.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Connectivity Debugger")
                .font(.title)
                .bold()
            
            Text("Configured Base URL:")
                .font(.headline)
            Text(NetworkConfig.baseURL)
                .font(.system(.body, design: .monospaced))
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            
            Text("Socket Status: \(socketService.isConnected ? "✅ Connected" : "❌ Disconnected")")
                .font(.headline)
                .foregroundColor(socketService.isConnected ? .green : .red)
            
            Button(action: {
                isLoading = true
                result = "Testing HTTP connection...\n"
                
                Task {
                    do {
                        let url = URL(string: "\(NetworkConfig.baseURL)/")!
                        let (data, response) = try await URLSession.shared.data(from: url)
                        
                        if let httpResponse = response as? HTTPURLResponse {
                            result += "✅ HTTP Status: \(httpResponse.statusCode)\n"
                            result += "URL: \(url.absoluteString)\n"
                            if let body = String(data: data, encoding: .utf8) {
                                result += "Response: \(body.prefix(200))..."
                            }
                        }
                    } catch {
                        result = "❌ Error: \(error.localizedDescription)"
                    }
                    isLoading = false
                }
            }) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.5))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                } else {
                    Text("Test HTTP Connection")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .disabled(isLoading)
            
            Button(action: {
                // Connect with a test user ID for debugging
                print("Connecting socket with test ID...")
                socketService.connect(userId: "test-user-id")
            }) {
                Text("Connect Socket (Test ID)")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            Button(action: {
                // Simulate incoming call
                print("Simulating incoming call...")
                callManager.isCallActive = true
                callManager.callStatus = "Incoming call..."
            }) {
                Text("Simulate Incoming Call (UI Test)")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            Text("Call Debug Log:")
                .font(.headline)
                .padding(.top)
            ScrollView {
                Text(callManager.debugLog)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(8)
            }
            .frame(height: 100)
            
            ScrollView {
                Text(result)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.black.opacity(0.05))
            .cornerRadius(8)
            .frame(maxHeight: 300)
        }
        .padding()
    }
    
    func testConnection() {
        isLoading = true
        result = "Testing..."
        
        guard let url = URL(string: "\(NetworkConfig.baseURL)/") else {
            result = "Invalid URL"
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5 // Short timeout
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    result = """
                    ❌ Error:
                    \(error.localizedDescription)
                    
                    Details:
                    \(error)
                    """
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    result = """
                    ✅ Response Received!
                    Status Code: \(httpResponse.statusCode)
                    
                    (Note: 404 is GOOD if accessing root, it means server is reachable)
                    """
                } else {
                    result = "Unknown response type"
                }
            }
        }.resume()
    }
}
