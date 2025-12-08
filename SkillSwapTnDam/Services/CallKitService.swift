import Foundation
import CallKit
import AVFoundation

final class CallKitService: NSObject {
    
    private let callController = CXCallController()
    private let provider: CXProvider
    private let uuid = UUID()
    
    var onCallAction: ((CXAction) -> Void)?
    
    override init() {
        print("📞 [CallKitService] Initializing...")
        let config = CXProviderConfiguration()
        config.supportsVideo = true
        config.maximumCallsPerCallGroup = 1
        config.supportedHandleTypes = [.generic]
        // Don't set ringtoneSound if the file doesn't exist - use system default
        // config.ringtoneSound = "ringtone.caf"
        
        self.provider = CXProvider(configuration: config)
        
        super.init()
        
        self.provider.setDelegate(self, queue: nil)
        print("📞 [CallKitService] Initialized successfully")
    }
    
    func reportIncomingCall(uuid: UUID, handle: String, hasVideo: Bool = false, completion: ((Error?) -> Void)? = nil) {
        print("📞 [CallKitService] reportIncomingCall() - uuid: \(uuid), handle: \(handle)")
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: handle)
        update.hasVideo = hasVideo
        update.localizedCallerName = handle
        
        self.provider.reportNewIncomingCall(with: uuid, update: update) { error in
            if let error = error {
                print("📞 [CallKitService] ❌ reportNewIncomingCall failed: \(error.localizedDescription)")
            } else {
                print("📞 [CallKitService] ✅ reportNewIncomingCall succeeded")
            }
            completion?(error)
        }
    }
    
    func startCall(uuid: UUID, handle: String, hasVideo: Bool = false) {
        let handle = CXHandle(type: .generic, value: handle)
        let startCallAction = CXStartCallAction(call: uuid, handle: handle)
        startCallAction.isVideo = hasVideo
        
        let transaction = CXTransaction(action: startCallAction)
        self.callController.request(transaction) { error in
            if let error = error {
                print("Error requesting transaction: \(error)")
            } else {
                print("Requested transaction successfully")
            }
        }
    }
    
    func endCall(uuid: UUID, completion: ((Error?) -> Void)? = nil) {
        let endCallAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endCallAction)
        
        self.callController.request(transaction) { error in
            if let error = error {
                print("Error requesting transaction: \(error)")
            }
            completion?(error)
        }
    }
    
    func answerCall(uuid: UUID, completion: ((Error?) -> Void)? = nil) {
        let answerCallAction = CXAnswerCallAction(call: uuid)
        let transaction = CXTransaction(action: answerCallAction)
        
        self.callController.request(transaction) { error in
            if let error = error {
                print("Error requesting transaction: \(error)")
            }
            completion?(error)
        }
    }
    
    func setHeld(uuid: UUID, onHold: Bool) {
        let setHeldAction = CXSetHeldCallAction(call: uuid, onHold: onHold)
        let transaction = CXTransaction(action: setHeldAction)
        
        self.callController.request(transaction) { error in
            if let error = error {
                print("Error requesting transaction: \(error)")
            }
        }
    }
}

extension CallKitService: CXProviderDelegate {
    
    func providerDidReset(_ provider: CXProvider) {
        // Stop audio
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        // Configure audio session
        self.onCallAction?(action)
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        // Stop audio
        self.onCallAction?(action)
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        self.onCallAction?(action)
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        // Configure audio session
        self.onCallAction?(action)
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        print("CallKit Audio Session Activated")
    }
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        print("CallKit Audio Session Deactivated")
    }
}
