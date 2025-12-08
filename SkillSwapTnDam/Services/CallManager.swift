import Foundation
import WebRTC
import CallKit
import AVFoundation

final class CallManager: NSObject, ObservableObject {
    static let shared = CallManager()
    
    @Published var isCallActive = false
    @Published var callStatus: String = ""
    @Published var remoteUser: User?
    @Published var isMuted = false
    @Published var isSpeakerOn = false
    @Published var isVideoEnabled = false
    @Published var isVideoCall = false
    @Published var isFrontCamera = true
    @Published var debugLog: String = "Ready"
    @Published var remoteVideoTrack: RTCVideoTrack?
    
    private let socketService = SocketService.shared
    
    // ... (existing properties)

    // ...

    private func handleIncomingCall(_ data: [String: Any]) {
        print("📞 [CallManager] ========== HANDLING INCOMING CALL ==========")
        print("📞 [CallManager] Thread: \(Thread.current)")
        print("📞 [CallManager] Raw data: \(data)")
        
        guard let callId = data["callId"] as? String else {
            print("📞 [CallManager] ❌ Missing callId in data")
            return
        }
        guard let callerId = data["callerId"] as? String else {
            print("📞 [CallManager] ❌ Missing callerId in data")
            return
        }
        guard let sdp = data["sdp"] as? String else {
            print("📞 [CallManager] ❌ Missing sdp in data")
            return
        }
        
        // Check if it's a video call
        let callType = data["callType"] as? String ?? "audio"
        let isVideo = callType == "video"
        
        print("📞 [CallManager] callId: \(callId)")
        print("📞 [CallManager] callerId: \(callerId)")
        print("📞 [CallManager] callType: \(callType) (isVideo: \(isVideo))")
        print("📞 [CallManager] sdp length: \(sdp.count)")
        
        // Switch to main thread for all UI-related work
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.debugLog = "Processing incoming call..."
            
            if self.isCallActive {
                print("📞 [CallManager] Already in a call, sending busy signal")
                self.socketService.emitCallBusy(callId: callId)
                return
            }
            
            self.currentCallId = callId
            self.isInitiator = false
            self.currentUUID = UUID()
            self.isVideoCall = isVideo
            self.isVideoEnabled = isVideo
            
            print("📞 [CallManager] Initializing WebRTC client (isVideo: \(isVideo))...")
            // Initialize WebRTC with video support if needed
            self.webRTCClient = WebRTCClient(iceServers: self.iceServers, isVideo: isVideo)
            self.webRTCClient?.delegate = self
            
            // Start video capture if video call
            if isVideo {
                self.webRTCClient?.startCaptureLocalVideo()
            }
            
            // Set Remote Description (Offer)
            let sessionDescription = RTCSessionDescription(type: .offer, sdp: sdp)
            self.webRTCClient?.set(remoteSdp: sessionDescription) { error in
                if let error = error {
                    print("📞 [CallManager] Error setting remote description: \(error)")
                } else {
                    print("📞 [CallManager] Remote SDP set successfully")
                }
            }
            
            // Set a placeholder remote user immediately
            self.remoteUser = User(id: callerId, username: "Incoming Call", email: "")
            
            // SIMULATOR BYPASS: Skip CallKit in simulator
            if self.isSimulator {
                print("📞 [CallManager] 🖥️ SIMULATOR MODE - Bypassing CallKit, showing UI directly")
                self.debugLog = "Incoming call (Simulator mode)"
                self.isCallActive = true
                self.callStatus = "Incoming call..."
                
                // Fetch Caller Profile in background
                Task {
                    do {
                        let userService = UserService()
                        if let token = await AuthenticationManager.shared.accessToken {
                            let users = try await userService.fetchUsers(accessToken: token)
                            if let caller = users.first(where: { $0.id == callerId }) {
                                await MainActor.run {
                                    print("📞 [CallManager] Found caller: \(caller.username)")
                                    self.remoteUser = caller
                                }
                            }
                        }
                    } catch {
                        print("📞 [CallManager] Failed to fetch caller profile: \(error)")
                    }
                }
                
                print("📞 [CallManager] ========== END HANDLING INCOMING CALL ==========")
                return
            }
            
            // REAL DEVICE: Use CallKit
            print("📞 [CallManager] 📱 REAL DEVICE - Reporting incoming call to CallKit...")
            self.debugLog = "Reporting to CallKit..."
            
            self.callKitService.reportIncomingCall(uuid: self.currentUUID!, handle: "SkillSwap Call") { [weak self] error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("📞 [CallManager] ❌ CallKit error: \(error.localizedDescription)")
                        self.debugLog = "CallKit error: \(error.localizedDescription)"
                    } else {
                        print("📞 [CallManager] ✅ CallKit reported incoming call successfully")
                        self.debugLog = "CallKit success!"
                    }
                    
                    // Show call UI regardless of CallKit result
                    print("📞 [CallManager] 🎯 Setting isCallActive = true")
                    self.isCallActive = true
                    self.callStatus = "Incoming call..."
                    print("📞 [CallManager] 🎯 isCallActive is now: \(self.isCallActive)")
                    
                    // Fetch Caller Profile in background
                    Task {
                        do {
                            let userService = UserService()
                            if let token = await AuthenticationManager.shared.accessToken {
                                let users = try await userService.fetchUsers(accessToken: token)
                                if let caller = users.first(where: { $0.id == callerId }) {
                                    await MainActor.run {
                                        print("📞 [CallManager] Found caller: \(caller.username)")
                                        self.remoteUser = caller
                                    }
                                }
                            }
                        } catch {
                            print("📞 [CallManager] Failed to fetch caller profile: \(error)")
                        }
                    }
                }
            }
            
            print("📞 [CallManager] ========== END HANDLING INCOMING CALL ==========")
        }
    }
    private var webRTCClient: WebRTCClient?
    private let callKitService = CallKitService()
    
    private var currentCallId: String?
    private var currentUUID: UUID?
    private var isInitiator = false
    private var callTimeoutTask: Task<Void, Never>?
    
    // ICE Servers - in production these should be fetched from a TURN server provider
    private let iceServers = ["stun:stun.l.google.com:19302",
                              "stun:stun1.l.google.com:19302",
                              "stun:stun2.l.google.com:19302"]
    
    // Detect if running in simulator (CallKit doesn't work in simulator)
    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    override private init() {
        super.init()
        print("📞 [CallManager] Initializing CallManager singleton")
        print("📞 [CallManager] Running on: \(isSimulator ? "SIMULATOR (CallKit bypass enabled)" : "REAL DEVICE")")
        setupSocketListeners()
        
        callKitService.onCallAction = { [weak self] action in
            self?.handleCallKitAction(action)
        }
        print("📞 [CallManager] Initialization complete")
    }
    
    private func setupSocketListeners() {
        print("📞 [CallManager] Setting up socket listeners...")
        DispatchQueue.main.async { self.debugLog = "Socket listeners registered" }
        
        socketService.onIncomingCall { [weak self] (data: [String: Any]) in
            print("📞 [CallManager] 🔔🔔🔔 INCOMING CALL RECEIVED! Data: \(data)")
            DispatchQueue.main.async { 
                self?.debugLog = "Socket event received: call:incoming"
            }
            self?.handleIncomingCall(data)
        }
        
        socketService.onCallRinging { [weak self] (data: [String: Any]) in
            print("📞 [CallManager] 📳 onCallRinging listener triggered")
            DispatchQueue.main.async {
                self?.callStatus = "Ringing..."
            }
        }
        
        socketService.onCallAnswered { [weak self] (data: [String: Any]) in
            print("📞 [CallManager] ✅ onCallAnswered listener triggered")
            self?.handleCallAnswered(data)
        }
        
        socketService.onIceCandidate { [weak self] (data: [String: Any]) in
            print("📞 [CallManager] 🧊 onIceCandidate listener triggered")
            self?.handleRemoteCandidate(data)
        }
        
        socketService.onCallEnded { [weak self] (data: [String: Any]) in
            print("📞 [CallManager] ⏹️ onCallEnded listener triggered")
            self?.endCall(reason: "Call ended by remote peer")
        }
        
        socketService.onCallRejected { [weak self] (data: [String: Any]) in
            print("📞 [CallManager] ❌ onCallRejected listener triggered")
            self?.endCall(reason: "Call rejected")
        }
        
        socketService.onCallBusy { [weak self] (data: [String: Any]) in
            print("📞 [CallManager] 📵 onCallBusy listener triggered")
            self?.endCall(reason: "User is busy")
        }
        
        socketService.onCallError { [weak self] (data: [String: Any]) in
            print("📞 [CallManager] ⚠️ onCallError listener triggered: \(data)")
            if let message = data["message"] as? String {
                DispatchQueue.main.async {
                    self?.callStatus = "Error: \(message)"
                }
            }
        }
        
        print("📞 [CallManager] ✅ All socket listeners registered successfully")
    }
    
    // MARK: - Public API
    
    func startCall(recipientId: String, recipientName: String, isVideo: Bool = false) {
        guard !isCallActive else { return }
        
        // Check socket connection
        guard socketService.isConnected else {
            print("CallManager: Cannot start call, socket not connected")
            callStatus = "Connection Error"
            return
        }
        
        self.isInitiator = true
        self.currentUUID = UUID()
        self.isCallActive = true
        self.isVideoCall = isVideo
        self.isVideoEnabled = isVideo
        self.callStatus = "Calling..."
        
        // Set remote user for UI
        self.remoteUser = User(id: recipientId, username: recipientName, email: "")
        
        // Initialize WebRTC with video support
        self.webRTCClient = WebRTCClient(iceServers: self.iceServers, isVideo: isVideo)
        self.webRTCClient?.delegate = self
        
        // Start video capture if video call
        if isVideo {
            self.webRTCClient?.startCaptureLocalVideo()
        }
        
        // Start CallKit call (skip in simulator)
        if !isSimulator {
            callKitService.startCall(uuid: self.currentUUID!, handle: recipientName, hasVideo: isVideo)
        } else {
            print("📞 [CallManager] 🖥️ Skipping CallKit startCall (simulator mode)")
        }
        
        // Start timeout timer (30 seconds)
        startCallTimeout()
        
        // Create Offer
        print("CallManager: Generating WebRTC offer...")
        self.webRTCClient?.offer { [weak self] sdp in
            print("CallManager: Offer generated! Sending to socket...")
            // Send offer via Socket
            self?.socketService.emitCallOffer(recipientId: recipientId,
                                             callType: isVideo ? "video" : "audio",
                                             sdp: sdp.sdp)
            print("CallManager: Offer emitted to socket for recipient \(recipientId)")
        }
    }
    
    // MARK: - Video Controls
    
    func toggleVideo() {
        isVideoEnabled.toggle()
        if isVideoEnabled {
            webRTCClient?.enableVideo()
        } else {
            webRTCClient?.disableVideo()
        }
    }
    
    func switchCamera() {
        isFrontCamera.toggle()
        webRTCClient?.switchCamera()
    }
    
    func renderLocalVideo(to view: RTCMTLVideoView) {
        webRTCClient?.renderLocalVideo(to: view)
    }
    
    func renderRemoteVideo(to view: RTCMTLVideoView) {
        webRTCClient?.renderRemoteVideo(to: view)
    }
    
    private func startCallTimeout() {
        // Cancel any existing timeout
        callTimeoutTask?.cancel()
        
        // Start new timeout (30 seconds)
        callTimeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                
                // If we reach here, call timed out
                await MainActor.run {
                    print("📞 [CallManager] ⏰ Call timed out after 30 seconds")
                    self?.endCall(reason: "No answer")
                }
            } catch {
                // Task was cancelled (call was answered or ended)
                print("📞 [CallManager] Timeout cancelled - call \(error is CancellationError ? "answered/ended" : "error")")
            }
        }
    }
    
    private func cancelCallTimeout() {
        callTimeoutTask?.cancel()
        callTimeoutTask = nil
    }
    
    func answerCall() {
        // SIMULATOR BYPASS: Skip CallKit in simulator
        if isSimulator {
            print("📞 [CallManager] 🖥️ SIMULATOR - Bypassing CallKit answerCall, triggering directly")
            // Directly execute answer logic (same as what CallKit would trigger)
            self.callStatus = "Connecting..."
            
            // Create Answer
            self.webRTCClient?.answer { [weak self] sdp in
                guard let self = self, let callId = self.currentCallId else { return }
                print("📞 [CallManager] Answer generated, emitting to socket")
                self.socketService.emitCallAnswer(callId: callId, sdp: sdp.sdp)
            }
            return
        }
        
        // REAL DEVICE: Answer the call via CallKit (which will trigger the delegate action)
        if let uuid = currentUUID {
            callKitService.answerCall(uuid: uuid) { error in
                if let error = error {
                    print("CallManager: Error requesting answer transaction: \(error)")
                } else {
                    print("CallManager: Answer transaction requested successfully")
                }
            }
        }
    }
    
    func endCall() {
        // SIMULATOR BYPASS: Skip CallKit in simulator
        if isSimulator {
            print("📞 [CallManager] 🖥️ SIMULATOR - Bypassing CallKit endCall, cleaning up directly")
            cleanup(reason: "Call Ended")
            return
        }
        
        // REAL DEVICE: End call via CallKit
        if let uuid = currentUUID {
            callKitService.endCall(uuid: uuid) { [weak self] error in
                if let error = error {
                    print("CallManager: CallKit endCall failed: \(error)")
                    // Force cleanup if CallKit fails
                    self?.cleanup(reason: "Call Ended (Force)")
                }
            }
        } else {
            // No UUID, just cleanup
            cleanup(reason: "Call Ended (No UUID)")
        }
    }
    
    func toggleMute() {
        isMuted.toggle()
        if isMuted {
            webRTCClient?.muteAudio()
        } else {
            webRTCClient?.unmuteAudio()
        }
    }
    
    func toggleSpeaker() {
        isSpeakerOn.toggle()
        if isSpeakerOn {
            webRTCClient?.speakerOn()
        } else {
            webRTCClient?.speakerOff()
        }
    }
    
    // MARK: - Private Handling
    
    // MARK: - Private Handling
    
    // handleIncomingCall is defined above with debug logging
    
    
    private func handleCallAnswered(_ data: [String: Any]) {
        guard let sdp = data["sdp"] as? String,
              let callId = data["callId"] as? String else { return }
        
        self.currentCallId = callId
        self.callStatus = "Connected"
        
        let sessionDescription = RTCSessionDescription(type: .answer, sdp: sdp)
        self.webRTCClient?.set(remoteSdp: sessionDescription) { error in
            if let error = error {
                print("Error setting remote description: \(error)")
            }
        }
    }
    
    private func handleRemoteCandidate(_ data: [String: Any]) {
        guard let candidateData = data["candidate"] as? [String: Any],
              let sdp = candidateData["candidate"] as? String,
              let sdpMid = candidateData["sdpMid"] as? String,
              let sdpMLineIndex = candidateData["sdpMLineIndex"] as? Int32 else { return }
        
        let candidate = RTCIceCandidate(sdp: sdp, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
        self.webRTCClient?.set(remoteCandidate: candidate) { error in
            if let error = error {
                print("Error setting remote candidate: \(error)")
            }
        }
    }
    
    private func endCall(reason: String) {
        if let uuid = currentUUID {
            callKitService.endCall(uuid: uuid)
        }
        cleanup(reason: reason)
    }
    
    private func cleanup(reason: String) {
        print("📞 [CallManager] Cleaning up call. Reason: \(reason)")
        cancelCallTimeout() // Cancel timeout timer
        
        DispatchQueue.main.async {
            self.isCallActive = false
            self.callStatus = reason
            self.currentCallId = nil
            self.currentUUID = nil
            self.webRTCClient?.close()
            self.webRTCClient = nil
            self.isSpeakerOn = false
            self.isMuted = false
            self.isVideoEnabled = false
            self.isVideoCall = false
            self.isFrontCamera = true
            self.remoteVideoTrack = nil
        }
    }

    private func handleCallKitAction(_ action: CXAction) {
        print("CallManager: Handling CallKit action: \(type(of: action))")
        switch action {
        case let startAction as CXStartCallAction:
            // Call started
            break
            
        case let answerAction as CXAnswerCallAction:
            print("CallManager: Answer action received")
            // User answered call
            self.callStatus = "Connecting..."
            
            // Create Answer
            self.webRTCClient?.answer { [weak self] sdp in
                guard let self = self, let callId = self.currentCallId else { return }
                self.socketService.emitCallAnswer(callId: callId, sdp: sdp.sdp)
            }
            
        case let endAction as CXEndCallAction:
            print("CallManager: End action received")
            // User ended call
            if let callId = currentCallId {
                if isCallActive {
                    socketService.emitCallEnd(callId: callId)
                } else {
                    socketService.emitCallReject(callId: callId)
                }
            }
            cleanup(reason: "Call ended")
            
        case let setMutedAction as CXSetMutedCallAction:
             // ...
            if setMutedAction.isMuted {
                webRTCClient?.muteAudio()
                isMuted = true
            } else {
                webRTCClient?.unmuteAudio()
                isMuted = false
            }
            
        default:
            break
        }
    }
}

extension CallManager: WebRTCClientDelegate {
    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate) {
        guard let callId = currentCallId else { return }
        
        let candidateDict: [String: Any] = [
            "candidate": candidate.sdp,
            "sdpMid": candidate.sdpMid ?? "",
            "sdpMLineIndex": candidate.sdpMLineIndex
        ]
        
        socketService.emitIceCandidate(callId: callId, candidate: candidateDict)
    }
    
    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected, .completed:
                print("📞 [CallManager] WebRTC connected!")
                self.callStatus = "Connected"
                self.cancelCallTimeout() // Call connected, cancel timeout
            case .disconnected:
                self.callStatus = "Disconnected"
                self.endCall(reason: "Disconnected")
            case .failed:
                self.callStatus = "Failed"
                self.endCall(reason: "Connection failed")
            case .closed:
                self.callStatus = "Closed"
            default:
                break
            }
        }
    }
    
    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data) {
        // Handle data channel messages if needed
    }
    
    func webRTCClient(_ client: WebRTCClient, didReceiveRemoteVideoTrack track: RTCVideoTrack) {
        DispatchQueue.main.async {
            print("📞 [CallManager] Received remote video track")
            self.remoteVideoTrack = track
        }
    }
}
