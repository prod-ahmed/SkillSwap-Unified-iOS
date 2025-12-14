import Foundation

struct NetworkConfig {
    static var baseURL: String {
        // Try to read from environment/Info.plist first
        if let envURL = ProcessInfo.processInfo.environment["SKILLSWAP_API_URL"] {
            return envURL
        }
        
        // Try from Info.plist
        if let plistURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           !plistURL.isEmpty {
            return plistURL
        }
        
        // Fallback to local development
        #if targetEnvironment(simulator)
        return "http://localhost:3000"
        #else
        return "http://192.168.1.15:3000"
        #endif
    }
    
    static var socketURL: URL? {
        return URL(string: baseURL)
    }
    
    static var mapsAPIKey: String {
        if let key = ProcessInfo.processInfo.environment["SKILLSWAP_MAPS_API_KEY"] {
            return key
        }
        if let key = Bundle.main.object(forInfoDictionaryKey: "MAPS_API_KEY") as? String {
            return key
        }
        return ""
    }
    
    static var openAIKey: String {
        if let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
            return key
        }
        if let key = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String {
            return key
        }
        return ""
    }
    
    static var geminiKey: String {
        if let key = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] {
            return key
        }
        if let key = Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String {
            return key
        }
        return ""
    }
}
