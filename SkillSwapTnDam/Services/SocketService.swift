import Foundation
import SocketIO

class SocketService: ObservableObject {
    static let shared = SocketService()
    
    private var manager: SocketManager?
    private var socket: SocketIOClient?
    
    @Published var isConnected: Bool = false
    @Published var connectionStatus: String = "Not connected"
    @Published var lastEventReceived: String = "None"
    
    private let baseURL = NetworkConfig.baseURL
    
    // Store handler registrations as (eventName, handler) tuples so we can replay them
    private var eventHandlers: [(String, ([String: Any]) -> Void)] = []
    private var hasRegisteredHandlersOnSocket = false
    private var currentUserId: String?
    
    private init() {
        print("📱 [SocketService] Initialized with baseURL: \(baseURL)")
    }
    
    func connect(userId: String) {
        print("📱 [SocketService] ====== CONNECT CALLED ======")
        print("📱 [SocketService] userId: \(userId)")
        print("📱 [SocketService] baseURL: \(baseURL)")
        print("📱 [SocketService] eventHandlers count BEFORE connect: \(eventHandlers.count)")
        
        // List all registered handlers
        for (index, handler) in eventHandlers.enumerated() {
            print("📱 [SocketService] Handler[\(index)]: \(handler.0)")
        }
        
        guard let url = URL(string: baseURL) else {
            print("📱 [SocketService] ❌ Invalid base URL: \(baseURL)")
            DispatchQueue.main.async {
                self.connectionStatus = "Invalid URL"
            }
            return
        }
        
        // Disconnect existing if any
        if socket != nil {
            print("📱 [SocketService] Disconnecting existing socket first")
            disconnect()
        }
        
        currentUserId = userId
        
        // Reset the flag so we re-register handlers on the new socket
        hasRegisteredHandlersOnSocket = false
        
        DispatchQueue.main.async {
            self.connectionStatus = "Connecting..."
        }
        
        manager = SocketManager(socketURL: url, config: [
            .log(false), // Disable verbose SocketIO logs to reduce noise
            .compress,
            .reconnects(true),
            .reconnectAttempts(-1), // Infinite reconnection attempts
            .reconnectWait(2),
            .reconnectWaitMax(10),
            .connectParams(["userId": userId]),
            .forceWebsockets(true),
            .forcePolling(false)
        ])
        
        socket = manager?.socket(forNamespace: "/calling")
        print("📱 [SocketService] Created socket for namespace /calling")
        
        // Register all stored event handlers on the new socket
        registerAllHandlersOnSocket()
        
        socket?.on(clientEvent: .connect) { [weak self] data, ack in
            print("📱 [SocketService] ✅✅✅ Socket CONNECTED to /calling namespace!")
            print("📱 [SocketService] Connection data: \(data)")
            print("📱 [SocketService] Socket ID: \(self?.socket?.sid ?? "unknown")")
            DispatchQueue.main.async {
                self?.isConnected = true
                self?.connectionStatus = "Connected ✅ (SID: \(self?.socket?.sid ?? "?"))"
            }
        }
        
        // Listen for connection confirmation from server
        socket?.on("connection:confirmed") { [weak self] data, ack in
            print("📱 [SocketService] 🎉🎉🎉 CONNECTION CONFIRMED BY SERVER!")
            print("📱 [SocketService] Confirmation data: \(data)")
            DispatchQueue.main.async {
                self?.connectionStatus = "Confirmed by server ✅"
            }
        }
        
        socket?.on(clientEvent: .disconnect) { [weak self] data, ack in
            print("📱 [SocketService] ❌ Socket disconnected. Reason: \(data)")
            DispatchQueue.main.async {
                self?.isConnected = false
                self?.connectionStatus = "Disconnected ❌"
            }
        }
        
        socket?.on(clientEvent: .error) { [weak self] data, ack in
            print("📱 [SocketService] ⚠️ Socket error: \(data)")
            DispatchQueue.main.async {
                self?.connectionStatus = "Error: \(data)"
            }
        }
        
        socket?.on(clientEvent: .reconnect) { [weak self] data, ack in
            print("📱 [SocketService] 🔄 Socket reconnected")
            DispatchQueue.main.async {
                self?.isConnected = true
                self?.connectionStatus = "Reconnected 🔄"
            }
        }
        
        socket?.on(clientEvent: .reconnectAttempt) { [weak self] data, ack in
            print("📱 [SocketService] 🔄 Reconnection attempt: \(data)")
            DispatchQueue.main.async {
                self?.connectionStatus = "Reconnecting..."
            }
        }
        
        socket?.on(clientEvent: .statusChange) { [weak self] data, ack in
            print("📱 [SocketService] 📊 Status change: \(data)")
            if let status = data.first as? SocketIOStatus {
                DispatchQueue.main.async {
                    self?.connectionStatus = "Status: \(status)"
                }
            }
        }
        
        // Listen for ANY event for debugging
        socket?.onAny { [weak self] event in
            print("📱 [SocketService] 🎯 ANY EVENT: \(event.event) - Data: \(event.items ?? [])")
            DispatchQueue.main.async {
                self?.lastEventReceived = "\(event.event) @ \(Date())"
            }
        }
        
        print("📱 [SocketService] Calling socket.connect()...")
        socket?.connect()
        print("📱 [SocketService] ====== CONNECT INITIATED ======")
    }
    
    private func registerAllHandlersOnSocket() {
        guard let socket = socket, !hasRegisteredHandlersOnSocket else {
            print("📱 [SocketService] Skipping handler registration (socket nil or already registered)")
            return
        }
        
        print("📱 [SocketService] 📝 Registering \(eventHandlers.count) event handlers on socket")
        
        for (event, handler) in eventHandlers {
            print("📱 [SocketService] 📝 Registering handler for: \(event)")
            socket.on(event) { data, ack in
                print("📱 [SocketService] 🔔🔔🔔 RECEIVED EVENT: \(event)")
                print("📱 [SocketService] Raw data: \(data)")
                if let callData = data.first as? [String: Any] {
                    print("📱 [SocketService] Parsed data: \(callData)")
                    handler(callData)
                } else {
                    print("📱 [SocketService] ⚠️ Could not parse event data as [String: Any]")
                }
            }
        }
        
        hasRegisteredHandlersOnSocket = true
        print("📱 [SocketService] ✅ All handlers registered on socket")
    }
    
    func disconnect() {
        print("📱 [SocketService] disconnect() called")
        socket?.disconnect()
        socket = nil
        manager = nil
        isConnected = false
        hasRegisteredHandlersOnSocket = false
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
        print("📱 [SocketService] registerListener() for event: \(event)")
        
        // Check if we already have a handler for this event to avoid duplicates
        let alreadyExists = eventHandlers.contains { $0.0 == event }
        if alreadyExists {
            print("📱 [SocketService] ⚠️ Handler for \(event) already exists, skipping duplicate registration")
            return
        }
        
        // Store for replay on reconnect
        eventHandlers.append((event, handler))
        print("📱 [SocketService] Stored handler for \(event). Total handlers: \(eventHandlers.count)")
        
        // If socket exists and handlers are registered, register this one immediately
        if let socket = socket {
            print("📱 [SocketService] Socket exists, registering handler immediately for: \(event)")
            socket.on(event) { data, ack in
                print("📱 [SocketService] 🔔🔔🔔 RECEIVED EVENT: \(event)")
                print("📱 [SocketService] Raw data: \(data)")
                if let callData = data.first as? [String: Any] {
                    print("📱 [SocketService] Parsed data: \(callData)")
                    handler(callData)
                } else {
                    print("📱 [SocketService] ⚠️ Could not parse event data as [String: Any]")
                }
            }
        } else {
            print("📱 [SocketService] Socket is nil, handler stored for later")
        }
    }
    
    func onIncomingCall(handler: @escaping ([String: Any]) -> Void) {
        print("📱 [SocketService] onIncomingCall() called")
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
