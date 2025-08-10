//
//  ThemeSwitcher.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI

// MARK: - Theme Switcher Component
struct ThemeSwitcher: View {
    @ObservedObject var themeManager: ThemeManager
    @State private var showThemeSelector = false
    
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(.light)
            showThemeSelector = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: themeManager.currentTheme.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primaryBrand)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Theme")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primaryText)
                    
                    Text(themeManager.currentTheme.displayName)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.tertiaryText)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color.cardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .actionSheet(isPresented: $showThemeSelector) {
            ActionSheet(
                title: Text("Choose Theme"),
                message: Text("Select your preferred appearance"),
                buttons: createThemeButtons()
            )
        }
    }
    
    private func createThemeButtons() -> [ActionSheet.Button] {
        var buttons: [ActionSheet.Button] = []
        
        for theme in ThemeManager.Theme.allCases {
            let isSelected = themeManager.currentTheme == theme
            let title = isSelected ? "\(theme.displayName) ✓" : theme.displayName
            
            buttons.append(.default(Text(title)) {
                HapticManager.shared.impact(.medium)
                withAnimation(.easeInOut(duration: 0.3)) {
                    themeManager.setTheme(theme)
                }
            })
        }
        
        buttons.append(.cancel())
        return buttons
    }
}

// MARK: - Theme Selector Grid (Alternative Implementation)
struct ThemeSelectorGrid: View {
    @ObservedObject var themeManager: ThemeManager
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Appearance")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primaryText)
            
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(ThemeManager.Theme.allCases, id: \.self) { theme in
                    ThemeCard(
                        theme: theme,
                        isSelected: themeManager.currentTheme == theme,
                        action: {
                            HapticManager.shared.impact(.medium)
                            withAnimation(.easeInOut(duration: 0.3)) {
                                themeManager.setTheme(theme)
                            }
                        }
                    )
                }
            }
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(16)
    }
}

// MARK: - Theme Card
struct ThemeCard: View {
    let theme: ThemeManager.Theme
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(previewBackground)
                        .frame(height: 60)
                    
                    // Preview content
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(previewText)
                            .frame(width: 24, height: 3)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(previewText.opacity(0.6))
                            .frame(width: 32, height: 3)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.primaryBrand : Color.divider, lineWidth: isSelected ? 2 : 1)
                )
                
                VStack(spacing: 2) {
                    Image(systemName: theme.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isSelected ? .primaryBrand : .secondaryText)
                    
                    Text(theme.displayName)
                        .font(.caption)
                        .fontWeight(isSelected ? .semibold : .medium)
                        .foregroundColor(isSelected ? .primaryBrand : .secondaryText)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    private var previewBackground: Color {
        switch theme {
        case .light:
            return Color.lightBackground
        case .dark:
            return Color.darkBackground
        case .system:
            return Color.background
        }
    }
    
    private var previewText: Color {
        switch theme {
        case .light:
            return Color.lightPrimaryText
        case .dark:
            return Color.darkPrimaryText
        case .system:
            return Color.primaryText
        }
    }
}

// MARK: - Inline Theme Toggle (Compact Version)
struct InlineThemeToggle: View {
    @ObservedObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(ThemeManager.Theme.allCases, id: \.self) { theme in
                Button(action: {
                    HapticManager.shared.impact(.light)
                    withAnimation(.easeInOut(duration: 0.3)) {
                        themeManager.setTheme(theme)
                    }
                }) {
                    Image(systemName: theme.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(themeManager.currentTheme == theme ? .white : .primaryBrand)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(themeManager.currentTheme == theme ? Color.primaryBrand : Color.primaryBrand.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Preview
#Preview("Theme Switcher") {
    VStack(spacing: 20) {
        ThemeSwitcher(themeManager: ThemeManager())
        
        ThemeSelectorGrid(themeManager: ThemeManager())
        
        InlineThemeToggle(themeManager: ThemeManager())
    }
    .padding()
    .background(Color.background)
}

#Preview("Theme Switcher - Dark") {
    VStack(spacing: 20) {
        ThemeSwitcher(themeManager: ThemeManager())
        
        ThemeSelectorGrid(themeManager: ThemeManager())
        
        InlineThemeToggle(themeManager: ThemeManager())
    }
    .padding()
    .background(Color.background)
    .preferredColorScheme(.dark)
} 