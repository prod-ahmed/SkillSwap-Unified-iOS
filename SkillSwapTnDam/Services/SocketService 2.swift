import Foundation
import SocketIO

class SocketService: ObservableObject {
    static let shared = SocketService()
    
    private var manager: SocketManager?
    private var socket: SocketIOClient?
    
    @Published var isConnected: Bool = false
    
    private let baseURL = NetworkConfig.baseURL
    
    private var pendingHandlers: [(SocketIOClient) -> Void] = []
    
    private init() {}
    
    func connect(userId: String) {
        guard let url = URL(string: baseURL) else { return }
        
        // Disconnect existing if any
        if socket != nil {
            disconnect()
        }
        
        manager = SocketManager(socketURL: url, config: [
            .log(true), // Enable logs for debugging
            .compress,
            .connectParams(["userId": userId])
        ])
        
        socket = manager?.socket(forNamespace: "/calling")
        
        // Apply pending handlers
        pendingHandlers.forEach { $0(socket!) }
        // Keep pendingHandlers in case we reconnect? 
        // For now, let's keep them or clear them. 
        // If we clear, and we disconnect/reconnect, we might lose them unless CallManager re-registers.
        // Better to NOT clear them if we want to support reconnection with same instance, 
        // BUT SocketIO client might duplicate listeners if we re-apply.
        // Safest is to clear and rely on the fact that we usually don't destroy the socket instance unless logging out.
        // Actually, if we recreate 'manager' and 'socket', we MUST re-apply.
        // So we should NOT clear pendingHandlers, but we must ensure we don't duplicate if we call connect() multiple times without recreating socket.
        // But here we recreate socket every connect(). So re-applying is correct.
        
        socket?.on(clientEvent: .connect) { [weak self] data, ack in
            print("✅ Socket connected")
            DispatchQueue.main.async {
                self?.isConnected = true
            }
        }
        
        socket?.on(clientEvent: .disconnect) { [weak self] data, ack in
            print("❌ Socket disconnected")
            DispatchQueue.main.async {
                self?.isConnected = false
            }
        }
        
        socket?.on(clientEvent: .error) { data, ack in
            print("⚠️ Socket error: \(data)")
        }
        
        socket?.connect()
    }
    
    func disconnect() {
        socket?.disconnect()
        socket = nil
        manager = nil
        isConnected = false
    }
    
    // MARK: - Emit Events
    
    func emitCallOffer(recipientId: String, callType: String, sdp: String) {
        socket?.emit("call:offer", [
            "recipientId": recipientId,
            "callType": callType,
            "sdp": sdp
        ])
    }
    
    func emitCallAnswer(callId: String, sdp: String) {
        socket?.emit("call:answer", [
            "callId": callId,
            "sdp": sdp
        ])
    }
    
    func emitIceCandidate(callId: String, candidate: [String: Any]) {
        socket?.emit("call:ice-candidate", [
            "callId": callId,
            "candidate": candidate
        ])
    }
    
    func emitCallReject(callId: String) {
        socket?.emit("call:reject", ["callId": callId])
    }
    
    func emitCallEnd(callId: String) {
        socket?.emit("call:end", ["callId": callId])
    }
    
    func emitCallBusy(callId: String) {
        socket?.emit("call:busy", ["callId": callId])
    }
    
    // MARK: - Listen to Events
    
    private func registerListener(event: String, handler: @escaping ([String: Any]) -> Void) {
        let registration = { (socket: SocketIOClient) in
            _ = socket.on(event) { data, ack in
                if let callData = data.first as? [String: Any] {
                    handler(callData)
                }
            }
        }
        
        if let socket = socket {
            registration(socket)
        }
        
        // Always add to pending so it survives reconnections/re-initializations
        pendingHandlers.append(registration)
    }
    
    func onIncomingCall(handler: @escaping ([String: Any]) -> Void) {
        registerListener(event: "call:incoming", handler: handler)
    }
    
    func onCallRinging(handler: @escaping ([String: Any]) -> Void) {
        registerListener(event: "call:ringing", handler: handler)
    }
    
    func onCallAnswered(handler: @escaping ([String: Any]) -> Void) {
        registerListener(event: "call:answered", handler: handler)
    }
    
    func onCallEnded(handler: @escaping ([String: Any]) -> Void) {
        registerListener(event: "call:ended", handler: handler)
    }
    
    func onCallRejected(handler: @escaping ([String: Any]) -> Void) {
        registerListener(event: "call:rejected", handler: handler)
    }
    
    func onCallBusy(handler: @escaping ([String: Any]) -> Void) {
        registerListener(event: "call:busy", handler: handler)
    }
    
    func onIceCandidate(handler: @escaping ([String: Any]) -> Void) {
        registerListener(event: "call:ice-candidate", handler: handler)
    }
    
    func onCallError(handler: @escaping ([String: Any]) -> Void) {
        registerListener(event: "call:error", handler: handler)
    }
}
