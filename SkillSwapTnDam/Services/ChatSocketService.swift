import Foundation
import SocketIO

class ChatSocketService: ObservableObject {
    static let shared = ChatSocketService()
    
    private var manager: SocketManager?
    private var socket: SocketIOClient?
    
    @Published var isConnected = false
    
    // Callbacks
    var onMessageReceived: ((ChatMessage) -> Void)?
    var onTypingUpdate: ((String, String, Bool) -> Void)? // threadId, userId, isTyping
    
    private init() {
        setupSocket()
    }
    
    func setupSocket() {
        let socketURL = URL(string: NetworkConfig.baseURL)!
        
        // Use same config as CallManager but different namespace
        var config: SocketIOClientConfiguration = [
            .log(true),
            .compress,
            .path("/socket.io/"),
            .reconnects(true),
            .reconnectAttempts(-1),
            .reconnectWait(1),
            .forceNew(true)
        ]

        // Add userId to query if available (access MainActor property safely)
        if let userId = UserDefaults.standard.data(forKey: "currentUser")
            .flatMap({ try? JSONDecoder().decode(User.self, from: $0) })?.id {
            config.insert(.connectParams(["userId": userId]))
        }

        // Propagate bearer token for servers that require auth on socket handshake
        if let token = AuthenticationManager.shared.accessToken, !token.isEmpty {
            config.insert(.extraHeaders(["Authorization": "Bearer \(token)"]))
        }
        
        manager = SocketManager(socketURL: socketURL, config: config)
        socket = manager?.socket(forNamespace: "/chat") // Ensure namespace matches backend
        
        setupListeners()
        
        // Auto-connect
        socket?.connect()
    }
    
    private func setupListeners() {
        guard let socket = socket else { return }
        
        socket.on(clientEvent: .connect) { [weak self] data, ack in
            print("💬 [ChatSocket] Connected")
            DispatchQueue.main.async {
                self?.isConnected = true
            }
        }
        
        socket.on(clientEvent: .disconnect) { [weak self] data, ack in
            print("💬 [ChatSocket] Disconnected")
            DispatchQueue.main.async {
                self?.isConnected = false
            }
        }
        
        socket.on("message:new") { [weak self] data, ack in
            print("💬 [ChatSocket] New message received: \(data)")
            guard let self = self,
                  let messageData = data.first as? [String: Any] else { return }
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: messageData)
                let decoder = JSONDecoder()
                
                // Handle custom date format if needed, matching ChatService
                decoder.dateDecodingStrategy = .custom { decoder in
                    let container = try decoder.singleValueContainer()
                    let value = try container.decode(String.self)
                    if let date = ISO8601DateFormatter.full.date(from: value) {
                        return date
                    }
                    if let fallback = ISO8601DateFormatter().date(from: value) {
                        return fallback
                    }
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format: \(value)")
                }
                
                let message = try decoder.decode(ChatMessage.self, from: jsonData)
                
                DispatchQueue.main.async {
                    self.onMessageReceived?(message)
                }
            } catch {
                print("💬 [ChatSocket] Failed to decode message: \(error)")
            }
        }
        
        socket.on("user:typing") { [weak self] data, ack in
            guard let self = self,
                  let typingData = data.first as? [String: Any],
                  let threadId = typingData["threadId"] as? String,
                  let userId = typingData["userId"] as? String,
                  let isTyping = typingData["isTyping"] as? Bool else { return }
            
            DispatchQueue.main.async {
                self.onTypingUpdate?(threadId, userId, isTyping)
            }
        }
    }
    
    func connect() {
        guard let socket = socket else { return }
        if socket.status != .connected {
            print("💬 [ChatSocket] Connecting...")
            socket.connect()
        }
    }
    
    func disconnect() {
        socket?.disconnect()
    }
    
    func joinThread(threadId: String) {
        guard let socket = socket else { return }
        
        // If not connected, connect first then join
        if socket.status != .connected {
            print("💬 [ChatSocket] Not connected, connecting before joining thread...")
            socket.connect()
            
            // Wait for connection
            socket.once(clientEvent: .connect) { [weak self] _, _ in
                print("💬 [ChatSocket] Connected, now joining thread: \(threadId)")
                self?.socket?.emit("chat:join", ["threadId": threadId])
            }
        } else {
            print("💬 [ChatSocket] Joining thread: \(threadId)")
            socket.emit("chat:join", ["threadId": threadId])
        }
    }
    
    func leaveThread(threadId: String) {
        guard let socket = socket, socket.status == .connected else { return }
        print("💬 [ChatSocket] Leaving thread: \(threadId)")
        socket.emit("chat:leave", ["threadId": threadId])
    }
    
    func sendTyping(threadId: String, isTyping: Bool) {
        guard let socket = socket, socket.status == .connected else { return }
        socket.emit("chat:typing", ["threadId": threadId, "isTyping": isTyping])
    }
    
    // MARK: - Event Listeners
    
    private func registerListener(event: String, handler: @escaping ([String: Any]) -> Void) {
        socket?.on(event) { data, ack in
            if let eventData = data.first as? [String: Any] {
                handler(eventData)
            }
        }
    }
    
    func onMessageReaction(handler: @escaping ([String: Any]) -> Void) {
        registerListener(event: "message:reaction", handler: handler)
    }
    
    func onMessageDeleted(handler: @escaping ([String: Any]) -> Void) {
        registerListener(event: "message:deleted", handler: handler)
    }
}

