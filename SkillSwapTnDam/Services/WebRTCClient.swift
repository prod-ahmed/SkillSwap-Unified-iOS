import Foundation
import WebRTC

protocol WebRTCClientDelegate: AnyObject {
    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate)
    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState)
    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data)
    func webRTCClient(_ client: WebRTCClient, didReceiveRemoteVideoTrack track: RTCVideoTrack)
}

// Default implementation for optional delegate methods
extension WebRTCClientDelegate {
    func webRTCClient(_ client: WebRTCClient, didReceiveRemoteVideoTrack track: RTCVideoTrack) {}
}

final class WebRTCClient: NSObject {
    
    // The `RTCPeerConnectionFactory` is in charge of creating new RTCPeerConnection instances.
    // A new RTCPeerConnection should be created every new call, but the factory is shared.
    private static let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        let videoEncoderFactory = RTCDefaultVideoEncoderFactory()
        let videoDecoderFactory = RTCDefaultVideoDecoderFactory()
        return RTCPeerConnectionFactory(encoderFactory: videoEncoderFactory, decoderFactory: videoDecoderFactory)
    }()
    
    weak var delegate: WebRTCClientDelegate?
    private let peerConnection: RTCPeerConnection
    private let rtcAudioSession = RTCAudioSession.sharedInstance()
    private let audioQueue = DispatchQueue(label: "audio")
    
    // Video support
    private var isVideoEnabled: Bool = false
    private var videoCapturer: RTCVideoCapturer?
    private var localVideoTrack: RTCVideoTrack?
    private var remoteVideoTrack: RTCVideoTrack?
    private var localAudioTrack: RTCAudioTrack?
    private var remoteAudioTrack: RTCAudioTrack?
    
    // Video renderer for local preview
    var localVideoView: RTCMTLVideoView?
    var remoteVideoView: RTCMTLVideoView?
    
    private var mediaConstrains: [String: String] {
        if isVideoEnabled {
            return [kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
                    kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue]
        } else {
            return [kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
                    kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueFalse]
        }
    }
    
    @available(*, unavailable)
    override init() {
        fatalError("WebRTCClient:init is unavailable")
    }
    
    required init(iceServers: [String], isVideo: Bool = false) {
        self.isVideoEnabled = isVideo
        
        let config = RTCConfiguration()
        config.iceServers = [RTCIceServer(urlStrings: iceServers)]
        
        // Unified plan is more modern and standard compliant (vs Plan B)
        config.sdpSemantics = .unifiedPlan
        
        // gatherContinually will let WebRTC to listen to any network changes and send any new candidates to the other client
        config.iceCandidatePoolSize = 10
        
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: ["DtlsSrtpKeyAgreement": kRTCMediaConstraintsValueTrue])
        
        guard let peerConnection = WebRTCClient.factory.peerConnection(with: config, constraints: constraints, delegate: nil) else {
            fatalError("Could not create new RTCPeerConnection")
        }
        
        self.peerConnection = peerConnection
        
        super.init()
        self.createMediaSenders()
        self.configureAudioSession()
        self.peerConnection.delegate = self
    }
    
    // MARK: Signaling
    func offer(completion: @escaping (_ sdp: RTCSessionDescription) -> Void) {
        let constrains = RTCMediaConstraints(mandatoryConstraints: self.mediaConstrains,
                                             optionalConstraints: nil)
        print("WebRTCClient: Creating offer...")
        self.peerConnection.offer(for: constrains) { (sdp, error) in
            if let error = error {
                print("WebRTCClient: Error creating offer: \(error)")
                return
            }
            
            guard let sdp = sdp else {
                print("WebRTCClient: Error creating offer: SDP is nil")
                return
            }
            
            print("WebRTCClient: Offer created, setting local description...")
            self.peerConnection.setLocalDescription(sdp, completionHandler: { (error) in
                if let error = error {
                    print("WebRTCClient: Error setting local description: \(error)")
                } else {
                    print("WebRTCClient: Local description set successfully")
                    completion(sdp)
                }
            })
        }
    }
    
    func answer(completion: @escaping (_ sdp: RTCSessionDescription) -> Void)  {
        let constrains = RTCMediaConstraints(mandatoryConstraints: self.mediaConstrains,
                                             optionalConstraints: nil)
        self.peerConnection.answer(for: constrains) { (sdp, error) in
            guard let sdp = sdp else {
                return
            }
            
            self.peerConnection.setLocalDescription(sdp, completionHandler: { (error) in
                completion(sdp)
            })
        }
    }
    
    func set(remoteSdp: RTCSessionDescription, completion: @escaping (Error?) -> Void) {
        self.peerConnection.setRemoteDescription(remoteSdp, completionHandler: completion)
    }
    
    func set(remoteCandidate: RTCIceCandidate, completion: @escaping (Error?) -> Void) {
        self.peerConnection.add(remoteCandidate, completionHandler: completion)
    }
    
    // MARK: Media
    func muteAudio() {
        self.setAudioEnabled(false)
    }
    
    func unmuteAudio() {
        self.setAudioEnabled(true)
    }
    
    func enableVideo() {
        self.localVideoTrack?.isEnabled = true
        startCaptureLocalVideo()
    }
    
    func disableVideo() {
        self.localVideoTrack?.isEnabled = false
        stopCaptureLocalVideo()
    }
    
    func switchCamera() {
        guard let capturer = self.videoCapturer as? RTCCameraVideoCapturer else { return }
        
        let position = capturer.captureSession.inputs
            .compactMap { ($0 as? AVCaptureDeviceInput)?.device }
            .first?.position ?? .front
        
        let newPosition: AVCaptureDevice.Position = position == .front ? .back : .front
        
        guard let device = RTCCameraVideoCapturer.captureDevices().first(where: { $0.position == newPosition }) else { return }
        
        let format = selectFormat(for: device)
        let fps = selectFps(for: format)
        
        capturer.startCapture(with: device, format: format, fps: fps)
    }
    
    // Fallback to the default playing device: headphones/bluetooth/ear speaker
    func speakerOff() {
        self.audioQueue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            self.rtcAudioSession.lockForConfiguration()
            do {
                try self.rtcAudioSession.setCategory(AVAudioSession.Category.playAndRecord.rawValue, with: [])
                try self.rtcAudioSession.overrideOutputAudioPort(.none)
            } catch let error {
                debugPrint("Error setting AVAudioSession category: \(error)")
            }
            self.rtcAudioSession.unlockForConfiguration()
        }
    }
    
    // Force speaker
    func speakerOn() {
        self.audioQueue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            self.rtcAudioSession.lockForConfiguration()
            do {
                try self.rtcAudioSession.setCategory(AVAudioSession.Category.playAndRecord.rawValue, with: [])
                try self.rtcAudioSession.overrideOutputAudioPort(.speaker)
                try self.rtcAudioSession.setActive(true)
            } catch let error {
                debugPrint("Couldn't force audio to speaker: \(error)")
            }
            self.rtcAudioSession.unlockForConfiguration()
        }
    }
    
    private func createMediaSenders() {
        let streamId = "stream"
        
        // Audio
        let audioTrack = self.createAudioTrack()
        self.peerConnection.add(audioTrack, streamIds: [streamId])
        self.localAudioTrack = audioTrack
        
        // Video (if enabled)
        if isVideoEnabled {
            let videoTrack = self.createVideoTrack()
            self.peerConnection.add(videoTrack, streamIds: [streamId])
            self.localVideoTrack = videoTrack
        }
    }
    
    private func createAudioTrack() -> RTCAudioTrack {
        let audioConstrains = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let audioSource = WebRTCClient.factory.audioSource(with: audioConstrains)
        let audioTrack = WebRTCClient.factory.audioTrack(with: audioSource, trackId: "audio0")
        return audioTrack
    }
    
    private func createVideoTrack() -> RTCVideoTrack {
        let videoSource = WebRTCClient.factory.videoSource()
        
        #if targetEnvironment(simulator)
        // Use file capturer for simulator
        self.videoCapturer = RTCFileVideoCapturer(delegate: videoSource)
        #else
        // Use camera capturer for real device
        self.videoCapturer = RTCCameraVideoCapturer(delegate: videoSource)
        #endif
        
        let videoTrack = WebRTCClient.factory.videoTrack(with: videoSource, trackId: "video0")
        return videoTrack
    }
    
    func startCaptureLocalVideo() {
        #if targetEnvironment(simulator)
        print("📹 [WebRTC] Skipping camera capture on simulator")
        return
        #else
        guard let capturer = self.videoCapturer as? RTCCameraVideoCapturer else {
            print("📹 [WebRTC] No camera capturer available")
            return
        }
        
        let devices = RTCCameraVideoCapturer.captureDevices()
        guard let frontCamera = devices.first(where: { $0.position == .front }) ?? devices.first else {
            print("📹 [WebRTC] No camera device found")
            return
        }
        
        let formats = RTCCameraVideoCapturer.supportedFormats(for: frontCamera)
        guard let format = formats.first(where: { format in
            let dimension = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            return dimension.width >= 640 && dimension.height >= 480
        }) ?? formats.last else {
            print("📹 [WebRTC] No supported format found")
            return
        }
        
        let fps = format.videoSupportedFrameRateRanges
            .compactMap { $0.maxFrameRate }
            .min() ?? 30
        
        print("📹 [WebRTC] Starting camera capture: \(frontCamera.localizedName), fps: \(Int(fps))")
        capturer.startCapture(with: frontCamera, format: format, fps: Int(min(fps, 30)))
        #endif
    }
    
    func stopCaptureLocalVideo() {
        guard let capturer = self.videoCapturer as? RTCCameraVideoCapturer else { return }
        capturer.stopCapture()
    }
    
    func renderLocalVideo(to view: RTCMTLVideoView) {
        self.localVideoView = view
        self.localVideoTrack?.add(view)
    }
    
    func renderRemoteVideo(to view: RTCMTLVideoView) {
        self.remoteVideoView = view
        self.remoteVideoTrack?.add(view)
    }
    
    private func selectFormat(for device: AVCaptureDevice) -> AVCaptureDevice.Format {
        let formats = RTCCameraVideoCapturer.supportedFormats(for: device)
        let targetWidth: Int32 = 640
        let targetHeight: Int32 = 480
        
        var selectedFormat: AVCaptureDevice.Format?
        var currentDiff = Int32.max
        
        for format in formats {
            let dimension = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            let diff = abs(targetWidth - dimension.width) + abs(targetHeight - dimension.height)
            if diff < currentDiff {
                selectedFormat = format
                currentDiff = diff
            }
        }
        
        return selectedFormat ?? formats.first!
    }
    
    private func selectFps(for format: AVCaptureDevice.Format) -> Int {
        var maxFrameRate: Float64 = 0
        for range in format.videoSupportedFrameRateRanges {
            maxFrameRate = max(maxFrameRate, range.maxFrameRate)
        }
        return Int(min(maxFrameRate, 30))
    }

    private func configureAudioSession() {
        self.rtcAudioSession.lockForConfiguration()
        do {
            try self.rtcAudioSession.setCategory(AVAudioSession.Category.playAndRecord.rawValue, with: [])
            try self.rtcAudioSession.setMode(AVAudioSession.Mode.voiceChat.rawValue)
        } catch let error {
            debugPrint("Error changeing AVAudioSession category: \(error)")
        }
        self.rtcAudioSession.unlockForConfiguration()
    }
    
    private func setAudioEnabled(_ isEnabled: Bool) {
        self.localAudioTrack?.isEnabled = isEnabled
    }
    
    func close() {
        stopCaptureLocalVideo()
        self.localVideoTrack?.remove(localVideoView ?? RTCMTLVideoView())
        self.remoteVideoTrack?.remove(remoteVideoView ?? RTCMTLVideoView())
        self.peerConnection.close()
    }
}

extension WebRTCClient: RTCPeerConnectionDelegate {
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        debugPrint("peerConnection new signaling state: \(stateChanged)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        debugPrint("peerConnection did add stream")
        if let videoTrack = stream.videoTracks.first {
            debugPrint("peerConnection did receive remote video track")
            self.remoteVideoTrack = videoTrack
            DispatchQueue.main.async {
                self.delegate?.webRTCClient(self, didReceiveRemoteVideoTrack: videoTrack)
            }
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        debugPrint("peerConnection did remove stream")
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        debugPrint("peerConnection should negotiate")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        debugPrint("peerConnection new connection state: \(newState)")
        self.delegate?.webRTCClient(self, didChangeConnectionState: newState)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        debugPrint("peerConnection new gathering state: \(newState)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        self.delegate?.webRTCClient(self, didDiscoverLocalCandidate: candidate)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        debugPrint("peerConnection did remove candidate(s)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        debugPrint("peerConnection did open data channel")
    }
}
