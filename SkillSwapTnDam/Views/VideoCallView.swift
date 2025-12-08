import SwiftUI
import WebRTC

// MARK: - Video View Wrapper for SwiftUI
struct RTCVideoViewRepresentable: UIViewRepresentable {
    let videoTrack: RTCVideoTrack?
    
    func makeUIView(context: Context) -> RTCMTLVideoView {
        let view = RTCMTLVideoView(frame: .zero)
        view.videoContentMode = .scaleAspectFill
        return view
    }
    
    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {
        if let track = videoTrack {
            track.add(uiView)
        }
    }
    
    static func dismantleUIView(_ uiView: RTCMTLVideoView, coordinator: ()) {
        // Clean up if needed
    }
}

// MARK: - Local Video View
struct LocalVideoView: UIViewRepresentable {
    @ObservedObject var callManager: CallManager
    
    func makeUIView(context: Context) -> RTCMTLVideoView {
        let view = RTCMTLVideoView(frame: .zero)
        view.videoContentMode = .scaleAspectFill
        view.transform = CGAffineTransform(scaleX: -1, y: 1) // Mirror for front camera
        DispatchQueue.main.async {
            callManager.renderLocalVideo(to: view)
        }
        return view
    }
    
    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {
        // Update if needed
    }
}

// MARK: - Remote Video View
struct RemoteVideoView: UIViewRepresentable {
    @ObservedObject var callManager: CallManager
    
    func makeUIView(context: Context) -> RTCMTLVideoView {
        let view = RTCMTLVideoView(frame: .zero)
        view.videoContentMode = .scaleAspectFill
        DispatchQueue.main.async {
            callManager.renderRemoteVideo(to: view)
        }
        return view
    }
    
    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {
        // Update if needed
    }
}

// MARK: - Video Call View
struct VideoCallView: View {
    @ObservedObject var callManager = CallManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var showControls = true
    @State private var controlsTimer: Timer?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Remote Video (Full Screen)
                if callManager.remoteVideoTrack != nil {
                    RemoteVideoView(callManager: callManager)
                        .ignoresSafeArea()
                } else {
                    // Placeholder when no remote video
                    Color.black
                        .ignoresSafeArea()
                    
                    VStack {
                        Circle()
                            .fill(Color(hex: "#FF6B35").opacity(0.2))
                            .frame(width: 120, height: 120)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(Color(hex: "#FF6B35"))
                            )
                        
                        Text(callManager.remoteUser?.username ?? "Unknown")
                            .font(.title)
                            .foregroundColor(.white)
                        
                        Text(callManager.callStatus)
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                // Local Video (Picture in Picture)
                if callManager.isVideoEnabled {
                    VStack {
                        HStack {
                            Spacer()
                            LocalVideoView(callManager: callManager)
                                .frame(width: 120, height: 160)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white, lineWidth: 2)
                                )
                                .shadow(radius: 5)
                                .padding()
                        }
                        Spacer()
                    }
                }
                
                // Controls Overlay
                if showControls {
                    VStack {
                        // Top Bar
                        HStack {
                            VStack(alignment: .leading) {
                                Text(callManager.remoteUser?.username ?? "Video Call")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text(callManager.callStatus)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            Spacer()
                            
                            // Switch Camera Button
                            if callManager.isVideoEnabled {
                                Button {
                                    callManager.switchCamera()
                                } label: {
                                    Image(systemName: "camera.rotate")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .padding(12)
                                        .background(Color.black.opacity(0.5))
                                        .clipShape(Circle())
                                }
                            }
                        }
                        .padding()
                        .background(
                            LinearGradient(colors: [.black.opacity(0.6), .clear],
                                           startPoint: .top,
                                           endPoint: .bottom)
                        )
                        
                        Spacer()
                        
                        // Bottom Controls
                        if callManager.callStatus == "Incoming call..." {
                            incomingCallControls
                        } else {
                            activeCallControls
                        }
                    }
                }
            }
            .onTapGesture {
                withAnimation {
                    showControls.toggle()
                }
                resetControlsTimer()
            }
            .onAppear {
                resetControlsTimer()
            }
            .onChange(of: callManager.isCallActive) { isActive in
                if !isActive {
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - Incoming Call Controls
    private var incomingCallControls: some View {
        HStack(spacing: 60) {
            // Decline Button
            Button {
                callManager.endCall()
            } label: {
                VStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 72, height: 72)
                        .overlay(
                            Image(systemName: "phone.down.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        )
                    Text("Decline")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            
            // Accept Button
            Button {
                callManager.answerCall()
            } label: {
                VStack(spacing: 8) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 72, height: 72)
                        .overlay(
                            Image(systemName: "phone.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        )
                    Text("Accept")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.bottom, 50)
        .background(
            LinearGradient(colors: [.clear, .black.opacity(0.6)],
                           startPoint: .top,
                           endPoint: .bottom)
        )
    }
    
    // MARK: - Active Call Controls
    private var activeCallControls: some View {
        VStack(spacing: 20) {
            HStack(spacing: 30) {
                // Mute Button
                Button {
                    callManager.toggleMute()
                } label: {
                    VStack(spacing: 8) {
                        Circle()
                            .fill(callManager.isMuted ? .white : .white.opacity(0.2))
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: callManager.isMuted ? "mic.slash.fill" : "mic.fill")
                                    .font(.title2)
                                    .foregroundColor(callManager.isMuted ? .black : .white)
                            )
                        Text("Mute")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
                
                // Video Toggle Button
                Button {
                    callManager.toggleVideo()
                } label: {
                    VStack(spacing: 8) {
                        Circle()
                            .fill(callManager.isVideoEnabled ? .white : .white.opacity(0.2))
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: callManager.isVideoEnabled ? "video.fill" : "video.slash.fill")
                                    .font(.title2)
                                    .foregroundColor(callManager.isVideoEnabled ? .black : .white)
                            )
                        Text("Video")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
                
                // Speaker Button
                Button {
                    callManager.toggleSpeaker()
                } label: {
                    VStack(spacing: 8) {
                        Circle()
                            .fill(callManager.isSpeakerOn ? .white : .white.opacity(0.2))
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: "speaker.wave.3.fill")
                                    .font(.title2)
                                    .foregroundColor(callManager.isSpeakerOn ? .black : .white)
                            )
                        Text("Speaker")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
            }
            
            // End Call Button
            Button {
                callManager.endCall()
            } label: {
                Circle()
                    .fill(Color.red)
                    .frame(width: 72, height: 72)
                    .overlay(
                        Image(systemName: "phone.down.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    )
            }
        }
        .padding(.bottom, 40)
        .padding(.top, 20)
        .background(
            LinearGradient(colors: [.clear, .black.opacity(0.6)],
                           startPoint: .top,
                           endPoint: .bottom)
        )
    }
    
    // MARK: - Timer for auto-hiding controls
    private func resetControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            withAnimation {
                showControls = false
            }
        }
    }
}

// MARK: - Preview
struct VideoCallView_Previews: PreviewProvider {
    static var previews: some View {
        VideoCallView()
    }
}
