//
//  OnboardingIntegrationExample.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI

// MARK: - Onboarding Integration Example

struct OnboardingIntegrationExample: View {
    @StateObject private var onboardingManager = OnboardingManager()
    @State private var showingOnboarding = false
    
    var body: some View {
        ZStack {
            // Your main app content
            MainAppContent()
            
            // Onboarding overlay
            if onboardingManager.shouldShowOnboarding || showingOnboarding {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                OnboardingView {
                    // Called when onboarding is completed
                    onboardingManager.completeOnboarding()
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showingOnboarding = false
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            // Check if onboarding should be shown
            if onboardingManager.shouldShowOnboarding {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        showingOnboarding = true
                    }
                }
            }
        }
    }
}

// MARK: - Alternative: Sheet Presentation

struct OnboardingSheetExample: View {
    @StateObject private var onboardingManager = OnboardingManager()
    
    var body: some View {
        MainAppContent()
            .sheet(isPresented: $onboardingManager.shouldShowOnboarding) {
                OnboardingView {
                    onboardingManager.completeOnboarding()
                }
            }
    }
}

// MARK: - Alternative: Navigation-based

struct OnboardingNavigationExample: View {
    @StateObject private var onboardingManager = OnboardingManager()
    
    var body: some View {
        NavigationStack {
            if onboardingManager.hasCompletedOnboarding {
                MainAppContent()
            } else {
                OnboardingView {
                    onboardingManager.completeOnboarding()
                }
            }
        }
        .animation(.easeInOut(duration: 0.5), value: onboardingManager.hasCompletedOnboarding)
    }
}

// MARK: - Alternative: Interactive Version

struct InteractiveOnboardingExample: View {
    @StateObject private var onboardingManager = OnboardingManager()
    
    var body: some View {
        NavigationStack {
            if onboardingManager.hasCompletedOnboarding {
                MainAppContent()
            } else {
                InteractiveOnboardingView {
                    onboardingManager.completeOnboarding()
                }
            }
        }
        .animation(.easeInOut(duration: 0.5), value: onboardingManager.hasCompletedOnboarding)
    }
}

// MARK: - Main App Content Placeholder

struct MainAppContent: View {
    @StateObject private var onboardingManager = OnboardingManager()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to Palytt!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primaryText)
            
            Text("Your main app content goes here")
                .font(.body)
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()
            
            // Button to show onboarding again (for testing)
            VStack(spacing: 12) {
                Button("Show Onboarding Again") {
                    onboardingManager.showOnboardingAgain()
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient.primaryGradient)
                )
                .padding(.horizontal, 32)
                
                Button("Reset Onboarding Status") {
                    onboardingManager.resetOnboarding()
                }
                .font(.subheadline)
                .foregroundColor(.secondaryText)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.background)
    }
}

// MARK: - Usage in App.swift

/*
 To integrate onboarding into your main app, replace your app's root view with one of these examples:

 @main
 struct PalyttApp: App {
     var body: some Scene {
         WindowGroup {
             // Option 1: Overlay presentation
             OnboardingIntegrationExample()
             
             // Option 2: Sheet presentation
             // OnboardingSheetExample()
             
             // Option 3: Navigation-based
             // OnboardingNavigationExample()
             
             // Option 4: Interactive version
             // InteractiveOnboardingExample()
         }
     }
 }
 */

// MARK: - Environment Object Integration

struct AppWithOnboardingEnvironment: View {
    @StateObject private var onboardingManager = OnboardingManager()
    
    var body: some View {
        if onboardingManager.hasCompletedOnboarding {
            MainAppContent()
                .environmentObject(onboardingManager)
        } else {
            OnboardingView {
                onboardingManager.completeOnboarding()
            }
            .environmentObject(onboardingManager)
        }
    }
}

// MARK: - Onboarding Settings View

struct OnboardingSettingsView: View {
    @ObservedObject var onboardingManager: OnboardingManager
    
    var body: some View {
        NavigationStack {
            List {
                Section("Onboarding Status") {
                    HStack {
                        Text("Completed")
                        Spacer()
                        Text(onboardingManager.hasCompletedOnboarding ? "Yes" : "No")
                            .foregroundColor(onboardingManager.hasCompletedOnboarding ? .success : .error)
                    }
                }
                
                Section("Actions") {
                    Button("Show Onboarding Again") {
                        onboardingManager.showOnboardingAgain()
                    }
                    
                    Button("Reset Onboarding") {
                        onboardingManager.resetOnboarding()
                    }
                    .foregroundColor(.error)
                }
            }
            .navigationTitle("Onboarding Settings")
        }
    }
}

// MARK: - Preview

#Preview("Onboarding Integration") {
    OnboardingIntegrationExample()
}

#Preview("Interactive Onboarding") {
    InteractiveOnboardingExample()
}

#Preview("Main App Content") {
    MainAppContent()
} 