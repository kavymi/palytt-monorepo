//
//  InteractiveOnboardingView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI

// MARK: - Interactive Onboarding View

struct InteractiveOnboardingView: View {
    @StateObject private var onboardingManager = OnboardingManager()
    @State private var currentPage = 0
    @State private var isAnimating = false
    
    let onComplete: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dynamic background
                AnimatedBackground(currentPage: currentPage)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Skip button
                    HStack {
                        Spacer()
                        Button("Skip") {
                            onComplete()
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primaryText.opacity(0.7))
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                    }
                    
                    // Page content
                    TabView(selection: $currentPage) {
                        WelcomePage()
                            .tag(0)
                        
                        ShareFoodPage()
                            .tag(1)
                        
                        DiscoveryPage()
                            .tag(2)
                        
                        ClusteringPage()
                            .tag(3)
                        
                        SocialPage()
                            .tag(4)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .onChange(of: currentPage) { _, newValue in
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            isAnimating = true
                        }
                    }
                    
                    // Bottom navigation
                    OnboardingBottomNavigation(
                        currentPage: $currentPage,
                        totalPages: 5,
                        onComplete: onComplete
                    )
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Animated Background

struct AnimatedBackground: View {
    let currentPage: Int
    @State private var floatingOffset1: CGFloat = 0
    @State private var floatingOffset2: CGFloat = 0
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Floating food icons
            ForEach(0..<6, id: \.self) { index in
                Image(systemName: foodIcons[index % foodIcons.count])
                    .font(.system(size: 24 + CGFloat(index * 4), weight: .light))
                    .foregroundColor(.white.opacity(0.1))
                    .offset(
                        x: CGFloat.random(in: -150...150) + floatingOffset1,
                        y: CGFloat.random(in: -200...200) + floatingOffset2
                    )
                    .rotationEffect(.degrees(rotation))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                floatingOffset1 = 50
                floatingOffset2 = 30
                rotation = 360
            }
        }
    }
    
    private var backgroundColors: [Color] {
        switch currentPage {
        case 0:
            return [.primaryBrand.opacity(0.3), .primaryBrand.opacity(0.2)]
        case 1:
            return [.primaryBrand.opacity(0.35), .primaryBrand.opacity(0.25)]
        case 2:
            return [.primaryBrand.opacity(0.4), .primaryBrand.opacity(0.3)]
        case 3:
            return [.primaryBrand.opacity(0.45), .primaryBrand.opacity(0.35)]
        case 4:
            return [.primaryBrand.opacity(0.5), .primaryBrand.opacity(0.4)]
        default:
            return [.primaryBrand.opacity(0.3), .primaryBrand.opacity(0.2)]
        }
    }
    
    private let foodIcons = ["fork.knife", "cup.and.saucer", "birthday.cake", "carrot", "fish", "leaf"]
}

// MARK: - Welcome Page

struct WelcomePage: View {
    @State private var logoScale: CGFloat = 0.5
    @State private var titleOffset: CGFloat = 50
    @State private var titleOpacity: Double = 0
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Animated logo
            ZStack {
                // Glow effect
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .primaryBrand.opacity(0.3),
                                .primaryBrand.opacity(0.1),
                                .clear
                            ],
                            center: .center,
                            startRadius: 40,
                            endRadius: 120
                        )
                    )
                    .frame(width: 240, height: 240)
                    .scaleEffect(logoScale)
                
                // Logo background
                Circle()
                    .fill(LinearGradient.primaryGradient)
                    .frame(width: 140, height: 140)
                    .scaleEffect(logoScale)
                
                // Fork and knife icon
                Image(systemName: "fork.knife")
                    .font(.system(size: 56, weight: .medium))
                    .foregroundColor(.white)
                    .scaleEffect(logoScale)
            }
            
            // Title and description
            VStack(spacing: 16) {
                Text("Welcome to")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondaryText)
                    .offset(y: titleOffset)
                    .opacity(titleOpacity)
                
                Text("Palytt")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
                    .offset(y: titleOffset)
                    .opacity(titleOpacity)
                
                Text("Your ultimate food discovery\nand sharing companion")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondaryText)
                    .padding(.horizontal, 32)
                    .offset(y: titleOffset)
                    .opacity(titleOpacity)
            }
            
            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2)) {
                logoScale = 1.0
            }
            
            withAnimation(.easeOut(duration: 0.8).delay(0.6)) {
                titleOffset = 0
                titleOpacity = 1.0
            }
        }
    }
}

// MARK: - Share Food Page

struct ShareFoodPage: View {
    @State private var cameraScale: CGFloat = 0.8
    @State private var photosOffset: [CGFloat] = Array(repeating: 100, count: 3)
    @State private var photosOpacity: [Double] = Array(repeating: 0, count: 3)
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Camera animation
            ZStack {
                // Background glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .primaryBrand.opacity(0.3),
                                .primaryBrand.opacity(0.1),
                                .clear
                            ],
                            center: .center,
                            startRadius: 30,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                
                // Camera
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.primaryBrand, .primaryBrand.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(cameraScale)
                
                Image(systemName: "camera.fill")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(.white)
                    .scaleEffect(cameraScale)
                
                // Sample food photos floating around
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [.white, .gray.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: foodEmojis[index])
                                .font(.title2)
                                .foregroundColor(.primaryBrand)
                        )
                        .offset(
                            x: photoOffsets[index].x,
                            y: photoOffsets[index].y + photosOffset[index]
                        )
                        .opacity(photosOpacity[index])
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
            }
            
            // Content
            VStack(spacing: 16) {
                Text("Share Your Food Adventures")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
                    .multilineTextAlignment(.center)
                
                Text("Capture and share your favorite moments")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.primaryBrand)
                    .multilineTextAlignment(.center)
                
                Text("Take photos of your meals, share reviews, and let others discover your favorite food spots.")
                    .font(.body)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                cameraScale = 1.0
            }
            
            // Animate photos one by one
            for index in 0..<3 {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.2 + 0.4)) {
                    photosOffset[index] = 0
                    photosOpacity[index] = 1.0
                }
            }
        }
    }
    
    private let foodEmojis = ["birthday.cake", "cup.and.saucer", "fish"]
    private let photoOffsets: [CGPoint] = [
        CGPoint(x: -80, y: -40),
        CGPoint(x: 80, y: -20),
        CGPoint(x: 0, y: 60)
    ]
}

// MARK: - Bottom Navigation

struct OnboardingBottomNavigation: View {
    @Binding var currentPage: Int
    let totalPages: Int
    let onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Page indicators
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? .primaryBrand : Color.gray.opacity(0.3))
                        .frame(width: index == currentPage ? 12 : 8, height: index == currentPage ? 12 : 8)
                        .animation(.spring(response: 0.4), value: currentPage)
                }
            }
            .padding(.bottom, 8)
            
            // Action buttons
            if currentPage == totalPages - 1 {
                Button(action: onComplete) {
                    HStack {
                        Text("Get Started")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Image(systemName: "arrow.right")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(LinearGradient.primaryGradient)
                    )
                }
                .shadow(color: .primaryBrand.opacity(0.3), radius: 8, x: 0, y: 4)
            } else {
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.5)) {
                        currentPage += 1
                    }
                }) {
                    HStack {
                        Text("Next")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Image(systemName: "arrow.right")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(width: 140, height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(LinearGradient.primaryGradient)
                    )
                }
                .shadow(color: .primaryBrand.opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 40)
    }
}

// Additional placeholder structs for the missing pages
struct DiscoveryPage: View {
    var body: some View {
        VStack {
            Text("Discover Nearby Places")
                .font(.largeTitle)
                .fontWeight(.bold)
        }
    }
}

struct ClusteringPage: View {
    var body: some View {
        VStack {
            Text("Explore Food Clusters")
                .font(.largeTitle)
                .fontWeight(.bold)
        }
    }
}

struct SocialPage: View {
    var body: some View {
        VStack {
            Text("Connect with Food Lovers")
                .font(.largeTitle)
                .fontWeight(.bold)
        }
    }
}

// MARK: - Preview

#Preview {
    InteractiveOnboardingView {
        print("Interactive onboarding completed")
    }
} 