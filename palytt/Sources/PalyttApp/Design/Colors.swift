//
//  Colors.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI

// MARK: - Theme Management
@MainActor
class ThemeManager: ObservableObject {
    @Published var currentTheme: Theme = .system
    
    enum Theme: String, CaseIterable {
        case light = "light"
        case dark = "dark"
        case system = "system"
        
        var displayName: String {
            switch self {
            case .light: return "Light"
            case .dark: return "Dark"
            case .system: return "System"
            }
        }
        
        var icon: String {
            switch self {
            case .light: return "sun.max.fill"
            case .dark: return "moon.fill"
            case .system: return "circle.lefthalf.filled"
            }
        }
    }
    
    init() {
        // Load saved theme preference
        if let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme"),
           let theme = Theme(rawValue: savedTheme) {
            self.currentTheme = theme
        }
    }
    
    func setTheme(_ theme: Theme) {
        currentTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: "selectedTheme")
    }
    
    var colorScheme: ColorScheme? {
        switch currentTheme {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

// MARK: - Brand Colors
extension Color {
    // Primary Brand Colors (consistent across themes)
    static let oldRose = Color(hex: "#d29985")
    static let matchaGreen = oldRose // Legacy compatibility
    static let milkTea = Color(hex: "#e3c4a8")
    static let coffeeDark = Color(hex: "#3b2b2b")
    static let blueAccent = Color(hex: "#9ac8eb")
    static let lightBlueAccent = Color(hex: "#d4e4f2")
    
    // Primary brand color (consistent)
    static let primaryBrand = oldRose
    
    // Shops and Places color (aligned with primary brand)
    static let shopsPlaces = oldRose
    
    // Legacy app-prefixed colors (for backward compatibility)
    static var appPrimaryText: Color {
        primaryText
    }
    
    static var appSecondaryText: Color {
        secondaryText
    }
    
    static var appTertiaryText: Color {
        tertiaryText
    }
    
    static var appBackground: Color {
        background
    }
    
    static var appCardBackground: Color {
        cardBackground
    }
    
    static var appDivider: Color {
        divider
    }
    
    static var appSurface: Color {
        surface
    }
    
    static var appOverlay: Color {
        overlay
    }
    
    // Consistent accent colors
    static let warmAccentText = milkTea
    
    // State Colors (consistent across themes)
    static let successColor = Color(hex: "#10B981")
    static let warningColor = Color(hex: "#F59E0B")
    static let errorColor = Color(hex: "#EF4444")
    static let infoColor = blueAccent
    
    // Semantic color aliases for easier usage
    static var success: Color { successColor }
    static var warning: Color { warningColor }
    static var error: Color { errorColor }
    static var info: Color { infoColor }
    
    // Light theme specific colors
    static let lightBackground = Color(hex: "#fbf4e6")  // riceBackground
    static let lightCardBackground = Color.white
    static let lightPrimaryText = coffeeDark
    static let lightSecondaryText = Color(hex: "#6B7280")
    static let lightTertiaryText = Color(hex: "#9CA3AF")
    static let lightDivider = Color(hex: "#E5E7EB")
    static let lightSurface = Color.white
    static let lightOverlay = Color.black.opacity(0.05)
    
    // Dark theme specific colors
    static let darkBackground = Color(hex: "#1a1a1a")
    static let darkCardBackground = Color(hex: "#2d2d2d")
    static let darkPrimaryText = Color(hex: "#ffffff")
    static let darkSecondaryText = Color(hex: "#b3b3b3")
    static let darkTertiaryText = Color(hex: "#808080")
    static let darkDivider = Color(hex: "#404040")
    static let darkSurface = Color(hex: "#333333")
    static let darkOverlay = Color.white.opacity(0.05)
    
    // Note: The following colors are auto-generated from asset catalog:
    // - background, cardBackground, primaryText, secondaryText, tertiaryText
    // - divider, surface, overlay
    // They can be used directly as Color.background, Color.primaryText, etc.
    
    // Additional app colors
    static var primary: Color {
        accent // Use the auto-generated accent color
    }
    
    static var secondary: Color {
        Color.gray
    }
    
    // UI Component Colors
    static var tabBarBackground: Color {
        Color(.systemBackground)
    }
    
    static var navigationBackground: Color {
        Color(.systemBackground)
    }
    
    static var buttonPrimary: Color {
        Color("AccentColor")
    }
    
    static var buttonSecondary: Color {
        Color(.systemGray5)
    }
    
    static var shadow: Color {
        Color.black.opacity(0.1)
    }
    
    // Dark Mode Support
    static var adaptiveText: Color {
        Color(.label)
    }
    
    static var adaptiveSecondary: Color {
        Color(.secondaryLabel)
    }
    
    static var adaptiveTertiary: Color {
        Color(.tertiaryLabel)
    }
    
    static var adaptiveBackground: Color {
        Color(.systemBackground)
    }
    
    static var adaptiveSecondaryBackground: Color {
        Color(.secondarySystemBackground)
    }
}

// MARK: - Color Extension for Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Color Scheme Helpers
extension Color {
    static func dynamic(light: Color, dark: Color) -> Color {
        return Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
    }
}

// MARK: - Gradient Definitions
extension LinearGradient {
    static let primaryGradient = LinearGradient(
        colors: [Color.matchaGreen, Color.matchaGreen.opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static var cardGradient: LinearGradient {
        LinearGradient(
            colors: [Color.appCardBackground, Color.appBackground.opacity(0.3)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    static let darkPrimaryGradient = LinearGradient(
        colors: [Color.matchaGreen, Color.matchaGreen.opacity(0.6)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let backgroundGradient = LinearGradient(
        colors: [.adaptiveBackground, .adaptiveSecondaryBackground],
        startPoint: .top,
        endPoint: .bottom
    )
} 