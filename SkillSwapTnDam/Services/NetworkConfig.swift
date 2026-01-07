import Foundation

struct NetworkConfig {
    static var baseURL: String {
        // Env override
        if let envURL = ProcessInfo.processInfo.environment["SKILLSWAP_API_URL"],
           !envURL.isEmpty {
            return normalized(envURL)
        }

        // Info.plist override
        if let plistURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           !plistURL.isEmpty {
            return normalized(plistURL)
        }

        // Persisted override (set by AuthenticationManager after login)
        if let saved = UserDefaults.standard.string(forKey: "api_base_url"),
           !saved.isEmpty {
            return normalized(saved)
        }

        // Shared default fallback (aligns with Android BuildConfig default)
        // For iOS Simulator: localhost refers to the Mac host
        // For Android Emulator: 10.0.2.2 refers to the host
        #if targetEnvironment(simulator)
        return "http://145.223.103.252:3001"
        #else
        // For physical devices, use your machine's IP or production URL
        return "http://145.223.103.252:3001"
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

    private static func normalized(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return trimmed
        }
        return "https://\(trimmed)"
    }
}
