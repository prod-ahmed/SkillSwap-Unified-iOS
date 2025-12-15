import SwiftUI

struct ActiveCallView: View {
    @ObservedObject var callManager = CallManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        Group {
            if callManager.isVideoCall {
                VideoCallView()
            } else {
                audioCallContent
            }
        }
        .onChange(of: callManager.isCallActive) { isActive in
            if !isActive {
                dismiss()
            }
        }
    }
    
    // MARK: - Audio Call Content
    @ViewBuilder
    private var audioCallContent: some View {
        let darkColor = Color(hex: "#1A1A1A")
        let blueColor = Color(hex: "#2C3E50")
        let orangeColor = Color(hex: "#FF6B35")
        
        ZStack {
            // Background Gradient
            LinearGradient(
                colors: [darkColor, blueColor],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Caller Info
                VStack(spacing: 16) {
                    Circle()
                        .fill(orangeColor.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 60))
                                .foregroundColor(orangeColor)
                        )
                    
                    Text(callManager.remoteUser?.username ?? "Unknown User")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(callManager.callStatus)
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.7))
                    
                    if !SocketService.shared.isConnected {
                        Text("⚠️ No Connection")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(6)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                // Controls
                if callManager.callStatus == "Incoming call..." {
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
                } else {
                    HStack(spacing: 40) {
                        // Mute Button
                        Button {
                            callManager.toggleMute()
                        } label: {
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(callManager.isMuted ? .white : .white.opacity(0.2))
                                    .frame(width: 64, height: 64)
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
                        
                        // End Call Button
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
                                Text("End")
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
                                    .frame(width: 64, height: 64)
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
                    .padding(.bottom, 50)
                }
            }
        }
    }
}
