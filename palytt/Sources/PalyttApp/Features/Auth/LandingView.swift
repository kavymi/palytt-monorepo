//
//  LandingView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import SwiftUI

// MARK: - Landing View

struct LandingView: View {
    let onContinue: () -> Void
    
    // Animation states
    @State private var logoScale: CGFloat = 0.3
    @State private var logoOpacity: Double = 0
    @State private var glowScale: CGFloat = 0.5
    @State private var glowOpacity: Double = 0
    @State private var cardsVisible: [Bool] = [false, false, false]
    @State private var ctaOpacity: Double = 0
    @State private var ctaScale: CGFloat = 0.9
    @State private var isPulsing: Bool = false
    @State private var floatingOffset: CGFloat = 0
    
    // Feature cards data
    private let features: [(icon: String, title: String, description: String)] = [
        ("mappin.and.ellipse", "Discover", "Find amazing food spots nearby"),
        ("camera.fill", "Share", "Capture your food adventures"),
        ("person.2.fill", "Connect", "Join fellow food lovers")
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Animated background
                LandingBackground(floatingOffset: floatingOffset)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Hero Section with animated logo
                    heroSection
                    
                    Spacer()
                        .frame(height: 40)
                    
                    // Feature cards
                    featureCards
                    
                    Spacer()
                    
                    // CTA Button
                    ctaButton
                        .padding(.bottom, 50)
                }
                .padding(.horizontal, 24)
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - Hero Section
    
    private var heroSection: some View {
        VStack(spacing: 24) {
            ZStack {
                // Pulsing glow behind logo
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.primaryBrand.opacity(0.4),
                                Color.primaryBrand.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 40,
                            endRadius: 140
                        )
                    )
                    .frame(width: 280, height: 280)
                    .scaleEffect(glowScale)
                    .opacity(glowOpacity)
                
                // Main logo
                Image("palytt-logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 160, height: 160)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .shadow(color: Color.primaryBrand.opacity(0.3), radius: 20, x: 0, y: 10)
            }
            
            // Tagline
            VStack(spacing: 8) {
                Text("Welcome to")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondaryText)
                    .opacity(logoOpacity)
                
                Text("Palytt")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.primaryText)
                    .opacity(logoOpacity)
                
                Text("Your food discovery companion")
                    .font(.body)
                    .foregroundColor(.secondaryText)
                    .opacity(logoOpacity)
            }
        }
    }
    
    // MARK: - Feature Cards
    
    private var featureCards: some View {
        HStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { index in
                FeatureCard(
                    icon: features[index].icon,
                    title: features[index].title,
                    description: features[index].description
                )
                .opacity(cardsVisible[index] ? 1 : 0)
                .offset(y: cardsVisible[index] ? 0 : 30)
            }
        }
    }
    
    // MARK: - CTA Button
    
    private var ctaButton: some View {
        Button(action: {
            HapticManager.shared.impact(.medium)
            onContinue()
        }) {
            HStack(spacing: 12) {
                Text("Get Started")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient.primaryGradient)
            )
            .scaleEffect(ctaScale)
            .opacity(ctaOpacity)
        }
        .buttonStyle(LandingButtonStyle())
        .shadow(color: Color.primaryBrand.opacity(0.4), radius: 12, x: 0, y: 6)
    }
    
    // MARK: - Animations
    
    private func startAnimations() {
        // Logo entrance animation
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        
        // Glow animation (slightly delayed)
        withAnimation(.easeInOut(duration: 0.6).delay(0.2)) {
            glowScale = 1.0
            glowOpacity = 1.0
        }
        
        // Start pulsing glow
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isPulsing = true
                glowScale = 1.1
            }
        }
        
        // Feature cards staggered animation
        for index in 0..<3 {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5 + Double(index) * 0.15)) {
                cardsVisible[index] = true
            }
        }
        
        // CTA button animation
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(1.0)) {
            ctaOpacity = 1.0
            ctaScale = 1.0
        }
        
        // Start floating animation for background
        withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
            floatingOffset = 20
        }
    }
}

// MARK: - Feature Card

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.primaryBrand.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.primaryBrand)
            }
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cardBackground)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Landing Background

struct LandingBackground: View {
    var floatingOffset: CGFloat
    
    // Food icons for floating particles
    private let foodIcons = ["fork.knife", "cup.and.saucer", "birthday.cake", "carrot", "leaf.fill"]
    
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color.lightBackground,
                    Color.lightBackground.opacity(0.95),
                    Color.primaryBrand.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Floating food particles
            ForEach(0..<8, id: \.self) { index in
                Image(systemName: foodIcons[index % foodIcons.count])
                    .font(.system(size: CGFloat(14 + index * 2), weight: .light))
                    .foregroundColor(Color.primaryBrand.opacity(0.08 + Double(index) * 0.01))
                    .offset(
                        x: particleX(for: index),
                        y: particleY(for: index) + floatingOffset * (index % 2 == 0 ? 1 : -1)
                    )
                    .rotationEffect(.degrees(Double(index * 15)))
            }
        }
    }
    
    private func particleX(for index: Int) -> CGFloat {
        let positions: [CGFloat] = [-140, 160, -100, 130, -170, 90, -60, 150]
        return positions[index % positions.count]
    }
    
    private func particleY(for index: Int) -> CGFloat {
        let positions: [CGFloat] = [-280, -180, 120, 220, -100, 300, -220, 50]
        return positions[index % positions.count]
    }
}

// MARK: - Landing Button Style

struct LandingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("Landing View") {
    LandingView {
        print("Get Started tapped")
    }
}

#Preview("Feature Card") {
    FeatureCard(
        icon: "mappin.and.ellipse",
        title: "Discover",
        description: "Find amazing food spots nearby"
    )
    .frame(width: 120)
    .padding()
    .background(Color.lightBackground)
}

