//
//  QuickThemeToggle.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI

// MARK: - Quick Theme Toggle Button
struct QuickThemeToggle: View {
    @ObservedObject var themeManager: ThemeManager
    @State private var isAnimating = false
    
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(.medium)
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                isAnimating = true
                themeManager.setTheme(nextTheme)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isAnimating = false
            }
        }) {
            Image(systemName: themeManager.currentTheme.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(LinearGradient.primaryGradient)
                        .shadow(color: Color.primaryBrand.opacity(0.3), radius: 8, x: 0, y: 4)
                )
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .rotationEffect(.degrees(isAnimating ? 180 : 0))
        }
        .buttonStyle(.plain)
    }
    
    private var nextTheme: ThemeManager.Theme {
        switch themeManager.currentTheme {
        case .light:
            return .dark
        case .dark:
            return .system
        case .system:
            return .light
        }
    }
}

// MARK: - Toolbar Theme Toggle
struct ToolbarThemeToggle: View {
    @ObservedObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(.light)
            withAnimation(.easeInOut(duration: 0.3)) {
                themeManager.setTheme(toggledTheme)
            }
        }) {
            Image(systemName: themeIconName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primaryBrand)
        }
    }
    
    private var toggledTheme: ThemeManager.Theme {
        themeManager.currentTheme == .dark ? .light : .dark
    }
    
    private var themeIconName: String {
        switch themeManager.currentTheme {
        case .light:
            return "moon"
        case .dark:
            return "sun.max"
        case .system:
            return "circle.lefthalf.filled"
        }
    }
}

// MARK: - Floating Theme Button
struct FloatingThemeButton: View {
    @ObservedObject var themeManager: ThemeManager
    let position: FloatingPosition
    
    enum FloatingPosition {
        case topTrailing
        case bottomTrailing
        case bottomLeading
        case topLeading
        
        var alignment: Alignment {
            switch self {
            case .topTrailing:
                return .topTrailing
            case .bottomTrailing:
                return .bottomTrailing
            case .bottomLeading:
                return .bottomLeading
            case .topLeading:
                return .topLeading
            }
        }
        
        var padding: EdgeInsets {
            switch self {
            case .topTrailing:
                return EdgeInsets(top: 60, leading: 0, bottom: 0, trailing: 20)
            case .bottomTrailing:
                return EdgeInsets(top: 0, leading: 0, bottom: 100, trailing: 20)
            case .bottomLeading:
                return EdgeInsets(top: 0, leading: 20, bottom: 100, trailing: 0)
            case .topLeading:
                return EdgeInsets(top: 60, leading: 20, bottom: 0, trailing: 0)
            }
        }
    }
    
    var body: some View {
        QuickThemeToggle(themeManager: themeManager)
            .padding(position.padding)
    }
}

// MARK: - Theme Status Indicator
struct ThemeStatusIndicator: View {
    @ObservedObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: themeManager.currentTheme.icon)
                .font(.caption)
                .foregroundColor(.primaryBrand)
            
            Text(themeManager.currentTheme.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondaryText)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.primaryBrand.opacity(0.1))
        )
    }
}

// MARK: - Preview
struct QuickThemeToggle_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack(spacing: 30) {
                QuickThemeToggle(themeManager: ThemeManager())
                
                ToolbarThemeToggle(themeManager: ThemeManager())
                
                ThemeStatusIndicator(themeManager: ThemeManager())
                
                // Simulate floating button position
                ZStack {
                    Rectangle()
                        .fill(Color.background)
                        .frame(height: 200)
                        .overlay(
                            Text("Preview Area")
                                .foregroundStyle(Color.secondaryText)
                        )
                    
                    VStack {
                        HStack {
                            Spacer()
                            FloatingThemeButton(themeManager: ThemeManager(), position: .topTrailing)
                        }
                        Spacer()
                    }
                }
            }
            .padding()
            .previewDisplayName("Theme Toggles - Light")
            
            VStack(spacing: 30) {
                QuickThemeToggle(themeManager: ThemeManager())
                
                ToolbarThemeToggle(themeManager: ThemeManager())
                
                ThemeStatusIndicator(themeManager: ThemeManager())
            }
            .padding()
            .background(Color.background)
            .preferredColorScheme(.dark)
            .previewDisplayName("Theme Toggles - Dark")
        }
    }
} 