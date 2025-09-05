//
//  OnboardingView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI

// MARK: - Onboarding Container View

struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var isAnimating = false
    @Environment(\.dismiss) private var dismiss
    
    let onComplete: () -> Void
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            id: 0,
            title: "Welcome to Palytt",
            subtitle: "Your ultimate food discovery and sharing companion",
            description: "Share your culinary adventures, discover amazing places, and connect with fellow food lovers in your area.",
            systemImage: "fork.knife",
            primaryColor: .primaryBrand,
            backgroundColor: .primaryBrand.opacity(0.1)
        ),
        OnboardingPage(
            id: 1,
            title: "Share Your Food Adventures",
            subtitle: "Capture and share your favorite moments",
            description: "Take photos of your meals, share reviews, and let others discover your favorite food spots.",
            systemImage: "camera.fill",
            primaryColor: .primaryBrand,
            backgroundColor: .primaryBrand.opacity(0.08)
        ),
        OnboardingPage(
            id: 2,
            title: "Discover Nearby Places",
            subtitle: "Explore restaurants and cafes around you",
            description: "Find top-rated restaurants, hidden gems, and trending food spots in your neighborhood.",
            systemImage: "location.fill",
            primaryColor: .primaryBrand,
            backgroundColor: .primaryBrand.opacity(0.12)
        ),
        OnboardingPage(
            id: 3,
            title: "Explore Food Clusters",
            subtitle: "See what's popular in each area",
            description: "Discover food hotspots with our smart clustering. Tap to see all the amazing posts in any location.",
            systemImage: "map.fill",
            primaryColor: .primaryBrand,
            backgroundColor: .primaryBrand.opacity(0.15)
        ),
        OnboardingPage(
            id: 4,
            title: "Connect with Food Lovers",
            subtitle: "Build your foodie community",
            description: "Follow friends, discover new tastes, and share recommendations with your personal food network.",
            systemImage: "heart.fill",
            primaryColor: .primaryBrand,
            backgroundColor: .primaryBrand.opacity(0.18)
        )
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        pages[currentPage].backgroundColor,
                        pages[currentPage].backgroundColor.opacity(0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Skip button
                    HStack {
                        Spacer()
                        Button("Skip") {
                            onComplete()
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                    }
                    
                    // Content
                    TabView(selection: $currentPage) {
                        ForEach(pages, id: \.id) { page in
                            OnboardingPageView(
                                page: page,
                                geometry: geometry,
                                isCurrentPage: currentPage == page.id
                            )
                            .tag(page.id)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.5), value: currentPage)
                    
                    // Bottom section
                    VStack(spacing: 24) {
                        // Page indicators
                        HStack(spacing: 8) {
                            ForEach(0..<pages.count, id: \.self) { index in
                                Circle()
                                    .fill(index == currentPage ? .primaryBrand : Color.gray.opacity(0.3))
                                    .frame(width: index == currentPage ? 12 : 8, height: index == currentPage ? 12 : 8)
                                    .animation(.spring(response: 0.4), value: currentPage)
                            }
                        }
                        .padding(.bottom, 8)
                        
                        // Action buttons
                        VStack(spacing: 12) {
                            if currentPage == pages.count - 1 {
                                // Get Started button on last page
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
                                // Next button
                                Button(action: nextPage) {
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
                                            .fill(
                                                LinearGradient(
                                                    colors: [.primaryBrand, .primaryBrand.opacity(0.8)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    )
                                }
                                .shadow(color: .primaryBrand.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8)) {
                isAnimating = true
            }
        }
    }
    
    private func nextPage() {
        withAnimation(.easeInOut(duration: 0.5)) {
            if currentPage < pages.count - 1 {
                currentPage += 1
            }
        }
    }
}

// MARK: - Onboarding Page Model

struct OnboardingPage {
    let id: Int
    let title: String
    let subtitle: String
    let description: String
    let systemImage: String
    let primaryColor: Color
    let backgroundColor: Color
}

// MARK: - Individual Page View

struct OnboardingPageView: View {
    let page: OnboardingPage
    let geometry: GeometryProxy
    let isCurrentPage: Bool
    
    @State private var iconScale: CGFloat = 0.5
    @State private var contentOffset: CGFloat = 50
    @State private var contentOpacity: Double = 0
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Animated icon
            ZStack {
                // Background circle with glow effect
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                page.primaryColor.opacity(0.2),
                                page.primaryColor.opacity(0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 30,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .scaleEffect(isCurrentPage ? 1.0 : 0.8)
                
                // Icon background
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                page.primaryColor,
                                page.primaryColor.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(iconScale)
                
                // Icon
                Image(systemName: page.systemImage)
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(.white)
                    .scaleEffect(iconScale)
            }
            .padding(.bottom, 20)
            
            // Content
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
                    .multilineTextAlignment(.center)
                    .offset(y: contentOffset)
                    .opacity(contentOpacity)
                
                Text(page.subtitle)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(page.primaryColor)
                    .multilineTextAlignment(.center)
                    .offset(y: contentOffset)
                    .opacity(contentOpacity)
                
                Text(page.description)
                    .font(.body)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .padding(.horizontal, 32)
                    .offset(y: contentOffset)
                    .opacity(contentOpacity)
            }
            
            Spacer()
            Spacer()
        }
        .onChange(of: isCurrentPage) { _, newValue in
            if newValue {
                animateIn()
            } else {
                animateOut()
            }
        }
        .onAppear {
            if isCurrentPage {
                animateIn()
            }
        }
    }
    
    private func animateIn() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
            iconScale = 1.0
        }
        
        withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
            contentOffset = 0
            contentOpacity = 1.0
        }
    }
    
    private func animateOut() {
        withAnimation(.easeIn(duration: 0.3)) {
            iconScale = 0.5
            contentOffset = 50
            contentOpacity = 0
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView {
        print("Onboarding completed")
    }
} 