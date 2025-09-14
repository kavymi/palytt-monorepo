//
//  RootView.swift
//  Palytt 
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI
import Clerk
#if !targetEnvironment(simulator)
#if !targetEnvironment(simulator)
// import ConvexMobile // temporarily disabled
#endif
#endif

// MARK: - Preview Mode Utilities
extension ProcessInfo {
    /// Check if the app is running in Xcode Preview mode
    static var isPreviewMode: Bool {
        processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

// MARK: - Preview Safety for Views
extension View {
    /// Apply Clerk-free environment for preview mode
    func previewSafe() -> some View {
        if ProcessInfo.isPreviewMode {
            return AnyView(self)
        } else {
            return AnyView(self)
        }
    }
}

// Simple OnboardingManager for now
class OnboardingManager: ObservableObject {
    @Published var shouldShowOnboarding = false
    
    init() {
        // Check if user has completed onboarding
        self.shouldShowOnboarding = !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }
    
    func completeOnboarding() {
        shouldShowOnboarding = false
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
}

// Simple onboarding view for now
struct SimpleOnboardingView: View {
    @EnvironmentObject var onboardingManager: OnboardingManager
    
    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.orange)
                
                Text("Welcome to Palytt!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Discover and share amazing food experiences with the community")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 20) {
                OnboardingFeatureRow(
                    icon: "camera.fill",
                    title: "Share Food Adventures",
                    description: "Capture and share your favorite food moments"
                )
                
                OnboardingFeatureRow(
                    icon: "location.fill",
                    title: "Discover Places",
                    description: "Find amazing restaurants and hidden gems"
                )
                
                OnboardingFeatureRow(
                    icon: "heart.fill",
                    title: "Connect with Food Lovers",
                    description: "Follow friends and discover new tastes"
                )
            }
            
            Spacer()
            
            Button("Get Started") {
                HapticManager.shared.impact(.medium)
                onboardingManager.completeOnboarding()
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.orange)
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .padding()
        .background(Color.background)
    }
}

struct OnboardingFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.orange)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal)
    }
}

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var onboardingManager = OnboardingManager()
    
    // Check if we're running in preview mode
    private var isPreviewMode: Bool {
        ProcessInfo.isPreviewMode
    }
    
    var body: some View {
        Group {
            if isPreviewMode {
                // In preview mode, always show the main app with mock data
                MainTabView()
            } else if !appState.isAuthenticated {
                AuthenticationView()
            } else if onboardingManager.shouldShowOnboarding {
                SimpleOnboardingView()
                    .environmentObject(onboardingManager)
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut, value: appState.isAuthenticated)
        .animation(.easeInOut, value: onboardingManager.shouldShowOnboarding)
        .onAppear {
            if isPreviewMode {
                setupPreviewMode() 
            }
        }
    }
    
    private func setupPreviewMode() {
        print("🎭 RootView: Setting up preview mode - bypassing all authentication")
        
        // Force authenticated state with rich mock data
        appState.isAuthenticated = true
        appState.currentUser = MockData.currentUser // Use the rich mock user instead
        
        // Bypass onboarding in preview
        onboardingManager.shouldShowOnboarding = false
        
        print("✅ RootView: Preview mode setup complete - User: \(appState.currentUser?.displayName ?? "Unknown")")
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var showCreatePost = false
    @State private var previousTab: AppTab = .home
    
    @ViewBuilder
    private var tabContent: some View {
        switch appState.selectedTab {
            case .home:
                HomeView()
            case .explore:
                ExploreView()
            case .create:
                // Show previous tab content when create is selected
                switch previousTab {
                case .home:
                    HomeView()
                case .explore:
                    ExploreView()
                case .notifications:
                    NotificationsView()
                case .profile:
                    ProfileView()
                default:
                    HomeView()
                }
            case .notifications:
                NotificationsView()
            case .profile:
                ProfileView()
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab Content
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Custom Tab Bar with visibility control
            if appState.isTabBarVisible {
                CustomTabBar()
                    .padding(.horizontal)
                    .padding(.bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                // Mini tab bar indicator when hidden - only show on Explore tab
                if appState.selectedTab == .explore {
                    VStack {
                        Spacer()
                        
                        HStack {
                            Spacer()
                            
                            Button(action: {
                                appState.showTabBar()
                                HapticManager.shared.impact(.light)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "chevron.up")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    Text("Navigation")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                        )
                                )
                                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                            }
                            
                            Spacer()
                        }
                        .padding(.bottom, 10)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .onChange(of: appState.selectedTab) { oldValue, newValue in
            if newValue == .create {
                // Play create post sound when opening camera/create view
                // SoundManager.shared.playWithHaptic(.modalPresent, hapticType: .medium)
                showCreatePost = true
                // Revert to previous tab
                DispatchQueue.main.async {
                    appState.selectedTab = previousTab
                }
            } else {
                previousTab = newValue
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showCreatePost) {
            CreatePostView()
                .environmentObject(appState)
        }
        #else
        .sheet(isPresented: $showCreatePost) {
            CreatePostView()
                .environmentObject(appState)
        }
        #endif
    }
}

// MARK: - Custom Tab Bar
struct CustomTabBar: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 0) {
            TabBarButton(
                icon: "house.fill",
                tab: .home,
                selectedTab: $appState.selectedTab
            )
            
            TabBarButton(
                icon: "magnifyingglass",
                tab: .explore,
                selectedTab: $appState.selectedTab
            )
            
            TabBarButton(
                icon: "plus.circle.fill",
                tab: .create,
                selectedTab: $appState.selectedTab,
                isSpecial: true
            )
            
            TabBarButton(
                icon: "bell.fill",
                tab: .notifications,
                selectedTab: $appState.selectedTab,
                showBadge: true
            )
            
            TabBarButton(
                icon: "person.fill",
                tab: .profile,
                selectedTab: $appState.selectedTab
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 30)
                .fill(Color.cardBackground)
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        )
    }
}

// MARK: - Tab Bar Button
struct TabBarButton: View {
    let icon: String
    let tab: AppTab
    @Binding var selectedTab: AppTab
    var isSpecial: Bool = false
    var showBadge: Bool = false
    
    var isSelected: Bool {
        selectedTab == tab
    }
    
    var body: some View {
        Button(action: {
            // SoundManager.shared.playWithHaptic(.tabSwitch, hapticType: .selection)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        }) {
            ZStack {
                VStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: isSpecial ? 28 : 24))
                        .foregroundColor(isSelected ? .primaryBrand : .tertiaryText)
                        .scaleEffect(isSelected ? 1.15 : 1.0)
                        .rotationEffect(.degrees(isSelected && !isSpecial ? 10 : 0))
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isSelected)
                    
                    if isSelected && !isSpecial {
                        Circle()
                            .fill(Color.primaryBrand)
                            .frame(width: 5, height: 5)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Notification badge
                if showBadge {
                    VStack {
                        HStack {
                            Spacer()
                            TabBarNotificationBadge()
                                .offset(x: -8, y: 8)
                        }
                        Spacer()
                    }
                }
            }
        }
        .scaleEffect(isSpecial ? 1.2 : 1.0)
    }
}

#Preview("🚀 Clerk-Free Preview Status") {
    VStack(spacing: 20) {
        Image(systemName: "fork.knife.circle.fill")
            .font(.system(size: 60))
            .foregroundColor(.orange)
        
        Text("Palytt Preview")
            .font(.title)
            .fontWeight(.bold)
        
        Text("Clerk-Free Preview Mode")
            .font(.subheadline)
            .foregroundColor(.secondary)
        
        VStack(alignment: .leading, spacing: 8) {
            Label("Mock Authentication: Active", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
            Label("Navigation: Ready", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
            Label("Theme: Loaded", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
            Label("Clerk: Disabled", systemImage: "xmark.circle.fill")
                .foregroundColor(.orange)
            Label("Mock Data: Loaded", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
        .font(.caption)
    }
    .padding()
}

#Preview("📱 Full App - Mock Data Priority") {
    // Create a preview-safe AppState with mock data - NO Clerk!
    let appState = AppState.createForPreview()
    
    return RootView()
        .environmentObject(appState)
        .environmentObject(appState.themeManager)
        // NO .environment(clerk) - completely Clerk-free preview
}

#Preview("🔐 Auth Flow - Clerk Disabled") {
    // Create a simple preview showing auth flow - NO Clerk!
    let appState = AppState()
    
    return VStack(spacing: 20) {
        Image(systemName: "person.circle.fill")
            .font(.system(size: 60))
            .foregroundColor(.blue)
        
        Text("Authentication Flow")
            .font(.title)
            .fontWeight(.bold)
        
        Text("Preview Mode - No Clerk Authentication")
            .font(.subheadline)
            .foregroundColor(.secondary)
        
        VStack(alignment: .leading, spacing: 8) {
            Label("Mock Authentication Ready", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
            Label("No Network Calls", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
            Label("Clerk Disabled", systemImage: "checkmark.circle.fill")
                .foregroundColor(.orange)
        }
        .font(.caption)
        
        Button("Simulate Sign In") {
            // In real preview, this would trigger auth state change
            print("Mock sign in triggered")
        }
        .buttonStyle(.borderedProminent)
    }
    .padding()
    .environmentObject(appState)
    .environmentObject(appState.themeManager)
    // NO .environment(clerk) - completely Clerk-free preview
} 
