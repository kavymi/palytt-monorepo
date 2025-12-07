//
//  DesignTokens.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
//  Design Tokens - Centralized design system values
//  Use these tokens consistently across the app to maintain visual coherence
//
import SwiftUI

// MARK: - Design Tokens
struct DesignTokens {
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 30
        
        // Component-specific spacing
        struct Component {
            static let cardPadding: CGFloat = 16
            static let cardVerticalPadding: CGFloat = 14
            static let cardHorizontalPadding: CGFloat = 16
            static let cardSpacing: CGFloat = 14
            static let buttonPadding: CGFloat = 12
            static let buttonHorizontalPadding: CGFloat = 20
            static let sectionSpacing: CGFloat = 20
            static let listItemSpacing: CGFloat = 12
        }
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 18
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 26
        
        // Component-specific radius
        struct Component {
            static let card: CGFloat = 24
            static let button: CGFloat = 12
            static let buttonPill: CGFloat = 20
            static let image: CGFloat = 18
            static let badge: CGFloat = 8
            static let avatar: CGFloat = 999 // Circle
            static let tabBar: CGFloat = 26
        }
    }
    
    // MARK: - Typography
    struct Typography {
        // Font sizes
        struct Size {
            static let caption2: CGFloat = 10
            static let caption: CGFloat = 12
            static let footnote: CGFloat = 13
            static let subheadline: CGFloat = 15
            static let body: CGFloat = 17
            static let headline: CGFloat = 17
            static let title3: CGFloat = 20
            static let title2: CGFloat = 22
            static let title: CGFloat = 28
            static let largeTitle: CGFloat = 34
        }
        
        // Font weights
        struct Weight {
            static let regular: Font.Weight = .regular
            static let medium: Font.Weight = .medium
            static let semibold: Font.Weight = .semibold
            static let bold: Font.Weight = .bold
        }
        
        // Predefined text styles
        static func caption2(weight: Font.Weight = .regular) -> Font {
            .system(size: Size.caption2, weight: weight)
        }
        
        static func caption(weight: Font.Weight = .regular) -> Font {
            .system(size: Size.caption, weight: weight)
        }
        
        static func footnote(weight: Font.Weight = .regular) -> Font {
            .system(size: Size.footnote, weight: weight)
        }
        
        static func subheadline(weight: Font.Weight = .regular) -> Font {
            .system(size: Size.subheadline, weight: weight)
        }
        
        static func body(weight: Font.Weight = .regular) -> Font {
            .system(size: Size.body, weight: weight)
        }
        
        static func headline(weight: Font.Weight = .semibold) -> Font {
            .system(size: Size.headline, weight: weight)
        }
        
        static func title3(weight: Font.Weight = .semibold) -> Font {
            .system(size: Size.title3, weight: weight)
        }
        
        static func title2(weight: Font.Weight = .semibold) -> Font {
            .system(size: Size.title2, weight: weight)
        }
        
        static func title(weight: Font.Weight = .bold) -> Font {
            .system(size: Size.title, weight: weight)
        }
        
        static func largeTitle(weight: Font.Weight = .bold) -> Font {
            .system(size: Size.largeTitle, weight: weight)
        }
    }
    
    // MARK: - Shadows
    struct Shadow {
        // Card shadows
        static let cardLight = ShadowValues(
            color: .black.opacity(0.04),
            radius: 12,
            x: 0,
            y: 4
        )
        
        static let cardSubtle = ShadowValues(
            color: .black.opacity(0.02),
            radius: 2,
            x: 0,
            y: 1
        )
        
        // Image shadows
        static let image = ShadowValues(
            color: .black.opacity(0.08),
            radius: 8,
            x: 0,
            y: 4
        )
        
        // Badge shadows
        static let badge = ShadowValues(
            color: .black.opacity(0.2),
            radius: 4,
            x: 0,
            y: 2
        )
        
        // Location badge shadow
        static let locationBadge = ShadowValues(
            color: .black.opacity(0.3),
            radius: 8,
            x: 0,
            y: 4
        )
        
        // Button hover shadow
        static let buttonHover = ShadowValues(
            color: Color.primaryBrand.opacity(0.25),
            radius: 8,
            x: 0,
            y: 4
        )
        
        struct ShadowValues {
            let color: Color
            let radius: CGFloat
            let x: CGFloat
            let y: CGFloat
        }
    }
    
    // MARK: - Animation
    struct Animation {
        // Spring animations
        static let springQuick = SwiftUI.Animation.spring(
            response: 0.3,
            dampingFraction: 0.7
        )
        
        static let springMedium = SwiftUI.Animation.spring(
            response: 0.4,
            dampingFraction: 0.6
        )
        
        static let springSmooth = SwiftUI.Animation.spring(
            response: 0.5,
            dampingFraction: 0.75
        )
        
        static let springInteractive = SwiftUI.Animation.spring(
            response: 0.6,
            dampingFraction: 0.8,
            blendDuration: 0.1
        )
        
        // Ease animations
        static let easeInOut = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let easeOut = SwiftUI.Animation.easeOut(duration: 0.1)
        
        // Durations
        struct Duration {
            static let quick: Double = 0.1
            static let short: Double = 0.2
            static let medium: Double = 0.3
            static let long: Double = 0.5
        }
    }
    
    // MARK: - Component Sizes
    struct ComponentSize {
        // Avatar sizes
        struct Avatar {
            static let xs: CGFloat = 20
            static let sm: CGFloat = 24
            static let md: CGFloat = 40
            static let lg: CGFloat = 44
            static let xl: CGFloat = 60
            static let xxl: CGFloat = 80
            static let xxxl: CGFloat = 120
        }
        
        // Button sizes
        struct Button {
            static let height: CGFloat = 44
            static let heightCompact: CGFloat = 36
            static let fabSize: CGFloat = 56
            static let iconButton: CGFloat = 36
        }
        
        // Icon sizes
        struct Icon {
            static let xs: CGFloat = 10
            static let sm: CGFloat = 12
            static let md: CGFloat = 16
            static let lg: CGFloat = 20
            static let xl: CGFloat = 24
        }
    }
    
    // MARK: - Opacity
    struct Opacity {
        static let disabled: Double = 0.5
        static let subtle: Double = 0.4
        static let medium: Double = 0.6
        static let strong: Double = 0.85
        static let overlay: Double = 0.05
        static let overlayStrong: Double = 0.5
    }
    
    // MARK: - Border
    struct Border {
        static let width: CGFloat = 1
        static let widthThick: CGFloat = 1.5
        static let widthThickest: CGFloat = 2
    }
}

// MARK: - View Extensions for Design Tokens
extension View {
    /// Apply standard card shadow
    func cardShadow() -> some View {
        self.shadow(
            color: DesignTokens.Shadow.cardLight.color,
            radius: DesignTokens.Shadow.cardLight.radius,
            x: DesignTokens.Shadow.cardLight.x,
            y: DesignTokens.Shadow.cardLight.y
        )
        .shadow(
            color: DesignTokens.Shadow.cardSubtle.color,
            radius: DesignTokens.Shadow.cardSubtle.radius,
            x: DesignTokens.Shadow.cardSubtle.x,
            y: DesignTokens.Shadow.cardSubtle.y
        )
    }
    
    /// Apply image shadow
    func imageShadow() -> some View {
        self.shadow(
            color: DesignTokens.Shadow.image.color,
            radius: DesignTokens.Shadow.image.radius,
            x: DesignTokens.Shadow.image.x,
            y: DesignTokens.Shadow.image.y
        )
    }
    
    /// Apply badge shadow
    func badgeShadow() -> some View {
        self.shadow(
            color: DesignTokens.Shadow.badge.color,
            radius: DesignTokens.Shadow.badge.radius,
            x: DesignTokens.Shadow.badge.x,
            y: DesignTokens.Shadow.badge.y
        )
    }
}

