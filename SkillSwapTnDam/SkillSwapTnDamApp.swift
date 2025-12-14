//
//  SkillSwapTnDamApp.swift
//  SkillSwapTnDam
//
//  Created by Apple Esprit on 7/11/2025.
//

// SkillSwapTnDamApp.swift
import SwiftUI

@main
struct SkillSwapTnDamApp: App {
    @StateObject private var localization = LocalizationManager.shared
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var deepLinkUrl: URL?
    
    var body: some Scene {
        WindowGroup {
            RootView() // Start with RootView to handle onboarding and authentication
                .environmentObject(AuthenticationManager.shared)
                .preferredColorScheme(isDarkMode ? .dark : .light)
                .environment(\.layoutDirection, localization.currentLanguage.isRTL ? .rightToLeft : .leftToRight)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        print("🔗 Deep link received: \(url)")
        
        // Handle skillswap:// URLs
        if url.scheme == "skillswap" {
            let path = url.host ?? ""
            let components = path.components(separatedBy: "/").filter { !$0.isEmpty }
            
            print("🔗 Path: \(path), Components: \(components)")
            
            // Examples:
            // skillswap://session/123
            // skillswap://profile/456
            // skillswap://chat/789
            
            // Store for navigation handling in RootView or MainTabView
            deepLinkUrl = url
        }
        
        // Handle https://skillswap.tn URLs (Universal Links)
        if url.scheme == "https" && url.host == "skillswap.tn" {
            print("🔗 Universal link: \(url.path)")
            deepLinkUrl = url
        }
    }
}
