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
    
    var body: some Scene {
        WindowGroup {
            RootView() // Start with RootView to handle onboarding and authentication
                .environmentObject(AuthenticationManager.shared)
                .preferredColorScheme(isDarkMode ? .dark : .light)
                .environment(\.layoutDirection, localization.currentLanguage.isRTL ? .rightToLeft : .leftToRight)
        }
    }
}
