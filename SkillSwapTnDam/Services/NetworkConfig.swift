import Foundation

struct NetworkConfig {
    static var baseURL: String {
        #if targetEnvironment(simulator)
        return "http://127.0.0.1:3000"
        #else
        return "http://192.168.1.15:3000"
        #endif
    }
    
    static var socketURL: URL? {
        return URL(string: baseURL)
    }
}
