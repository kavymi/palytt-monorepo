//
//  PalyttApp.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import SwiftUI
import Clerk
import Foundation
import UserNotifications
import UIKit
// import PostHog // Temporarily commented until we can integrate via Xcode properly
#if !targetEnvironment(simulator)
// import ConvexMobile // temporarily disabled
#endif

// MARK: - Shared Types
enum AppTab: Hashable {
    case home
    case explore
    case friends
    case profile
}

@main
struct PalyttApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var clerk = Clerk.shared
    @StateObject private var appState = AppState()
    @State private var showSplashScreen = true
    
    // Animation state for splash screen
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0.0
    @State private var textOpacity: Double = 0.0
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplashScreen {
                    // Embedded Splash Screen
                    ZStack {
                        // Background with solid color
                        Color.lightBackground
                            .ignoresSafeArea()
                        
                        VStack(spacing: 32) {
                            Spacer()
                            
                            // Logo with animation
                            Image("palytt-logo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 140, height: 140)
                                .scaleEffect(logoScale)
                                .opacity(logoOpacity)
                                .shadow(color: Color.matchaGreen.opacity(0.3), radius: 20, x: 0, y: 10)
                                .animation(.spring(response: 0.8, dampingFraction: 0.6), value: logoScale)
                                .animation(.easeInOut(duration: 0.6), value: logoOpacity)
                            
                            Spacer()
                            
                            // Subtle loading indicator
                            VStack(spacing: 8) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .matchaGreen))
                                    .scaleEffect(0.8)
                                
                                Text("Welcome to your Palytt experience!")
                                    .font(.caption)
                                    .foregroundColor(.appSecondaryText)
                                    .opacity(0.7)
                            }
                            .padding(.bottom, 60)
                        }
                        .padding(.horizontal, 40)
                    }
                    .onAppear {
                        logoScale = 1.0
                        logoOpacity = 1.0
                        textOpacity = 1.0
                    }
                    .transition(.opacity)
                } else if clerk.isLoaded {
                    RootView()
                        .environmentObject(appState)
                        .environmentObject(appState.themeManager)
                        .preferredColorScheme(appState.themeManager.colorScheme)
                        .tint(Color.primaryBrand)
                        .transition(.opacity)
                } else {
                    // Loading screen while Clerk initializes
                    VStack(spacing: 24) {
                        Image("palytt-logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 120)
                        
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .primaryBrand))
                            .scaleEffect(1.2)
                        
                        Text("Loading...")
                            .font(.caption)
                            .foregroundColor(.appSecondaryText)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.appBackground)
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: showSplashScreen)
            .animation(.easeInOut(duration: 0.3), value: clerk.isLoaded)
            .environment(clerk)
            .task {
                // Configure for production and native notifications
                await configureAppForProduction()
                
                // Start splash screen timer
                Task {
                    try? await Task.sleep(nanoseconds: 2_500_000_000) // 2.5 seconds
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            showSplashScreen = false
                        }
                    }
                }
                
                // Configure Clerk with your publishable key
                clerk.configure(publishableKey: "pk_test_bmF0dXJhbC13YWxsZXllLTQ4LmNsZXJrLmFjY291bnRzLmRldiQ")
                try? await clerk.load()
                
                // Update app state based on Clerk authentication
                updateAuthenticationState()
            }
            .onChange(of: clerk.user) {
                updateAuthenticationState()
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
        }
    }
    
    // MARK: - Deep Link Handling
    
    /// Handle deep links for referral invites and other app URLs
    private func handleDeepLink(_ url: URL) {
        print("📨 PalyttApp: Received deep link: \(url)")
        
        // Handle palytt.app/invite/CODE or palytt://invite/CODE
        if url.pathComponents.contains("invite"),
           let code = url.pathComponents.last, code != "invite" {
            // Store pending referral code to apply after signup
            UserDefaults.standard.set(code.uppercased(), forKey: "pendingReferralCode")
            print("📨 PalyttApp: Stored pending referral code: \(code.uppercased())")
            
            // If user is already authenticated, apply the code immediately
            if appState.isAuthenticated {
                Task {
                    do {
                        let result = try await BackendService.shared.applyReferralCode(code)
                        UserDefaults.standard.removeObject(forKey: "pendingReferralCode")
                        print("📨 PalyttApp: Applied referral code immediately: \(result.message)")
                    } catch {
                        print("⚠️ PalyttApp: Failed to apply referral code: \(error)")
                    }
                }
            }
        }
    }
    
    @MainActor
    private func updateAuthenticationState() {
        print("🔐 AppState: Updating authentication state - isAuthenticated: \(clerk.user != nil)")
        
        appState.isAuthenticated = clerk.user != nil
        if let clerkUser = clerk.user {
            print("✅ AppState: User is authenticated: \(clerkUser.id)")
            
            // Convert Clerk user to your app's User model
            // Note: Using a deterministic UUID based on Clerk's string ID
            let userUUID = UUID(uuidString: clerkUser.id) ?? UUID()
            
            appState.currentUser = User(
                id: userUUID,
                email: clerkUser.primaryEmailAddress?.emailAddress ?? "",
                firstName: clerkUser.firstName,
                lastName: clerkUser.lastName,
                username: clerkUser.username ?? clerkUser.firstName ?? "User",
                displayName: "\(clerkUser.firstName ?? "") \(clerkUser.lastName ?? "")".trimmingCharacters(in: .whitespaces),
                bio: nil,
                avatarURL: URL(string: clerkUser.imageUrl),
                clerkId: clerkUser.id,
                dietaryPreferences: [],
                location: nil,
                joinedAt: Date(), // You might want to use clerkUser.createdAt if available
                followersCount: 0,
                followingCount: 0,
                postsCount: 0
            )
            
            print("✅ AppState: Created user object with clerkId: \(clerkUser.id)")
            
            // Identify user for analytics
            // AnalyticsManager.shared.identify(
            //     userId: clerkUser.id,
            //     properties: [
            //         "email": clerkUser.primaryEmailAddress?.emailAddress ?? "",
            //         "first_name": clerkUser.firstName ?? "",
            //         "last_name": clerkUser.lastName ?? "",
            //         "username": clerkUser.username ?? ""
            //     ]
            // )
            // AnalyticsManager.shared.trackUserLogin(method: "clerk")
            
            // Sync user data with backend and activate notifications
            Task {
                await syncUserWithBackend()
                appState.activateNotifications()
            }
        } else {
            print("❌ AppState: User is not authenticated")
            // Track logout if we had a user before
            // if appState.currentUser != nil {
            //     AnalyticsManager.shared.trackUserLogout()
            // }
            appState.currentUser = nil
        }
    }
    
    private func syncUserWithBackend() async {
        guard clerk.user != nil else { return }
        
        do {
            // Use the unified sync method that handles all user types
            let syncedUser = try await BackendService.shared.syncUserFromClerk()
            let displayName = [syncedUser.firstName, syncedUser.lastName].compactMap { $0 }.joined(separator: " ")
            let nameToShow = !displayName.isEmpty ? displayName : (syncedUser.username ?? "Unknown")
            print("✅ User synced with backend successfully: \(nameToShow)")
            
            // Update app state with synced user data if needed
            await MainActor.run {
                // Trigger home feed fetch after successful backend sync
                // This ensures posts load immediately after first-time login
                if appState.homeViewModel.posts.isEmpty {
                    print("🏠 PalyttApp: Backend sync complete, triggering home feed fetch")
                    appState.homeViewModel.fetchPosts()
                }
            }
        } catch {
            print("⚠️ Failed to sync user with backend: \(error)")
            // App continues to work with Clerk data even if backend sync fails
            // Still try to fetch posts since auth may be working
            await MainActor.run {
                if appState.homeViewModel.posts.isEmpty && !appState.homeViewModel.isLoading {
                    print("🏠 PalyttApp: Backend sync failed, but attempting home feed fetch anyway")
                    appState.homeViewModel.fetchPostsWhenReady()
                }
            }
        }
    }
    
    // MARK: - Production Configuration
    
    @MainActor
    private func configureAppForProduction() async {
        print("🚀 PalyttApp: Configuring app for production")
        
        // Only configure backend for production in release builds
        #if !DEBUG
        BackendService.shared.configureForProduction()
        #else
        print("🔧 PalyttApp: DEBUG mode - keeping local backend configuration")
        #endif
        
        // Initialize native notification system
        await setupNativeNotifications()
        
        // Set up analytics and monitoring
        // AnalyticsManager.shared.configure()
        // AnalyticsManager.shared.trackAppLaunch()
        
        // Send test event to verify PostHog integration
        // AnalyticsManager.shared.capture("Test Event", properties: [
        //     "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
        //     "platform": "iOS",
        //     "environment": "production"
        // ])
        
        // Initialize error tracking
        // errorTracker.initialize(environment: .production)
        
        print("✅ PalyttApp: Production configuration complete")
    }
    
    /// Set up native iOS notifications
    @MainActor
    private func setupNativeNotifications() async {
        print("📱 PalyttApp: Setting up native notifications")
        
        let nativeNotificationManager = NativeNotificationManager.shared
        
        // Check current authorization status
        await nativeNotificationManager.checkAuthorizationStatus()
        
        // Set up notification categories for interactive notifications
        nativeNotificationManager.setupNotificationCategories()
        
        // Set up notification handling observers
        setupNotificationObservers()
        
        print("✅ PalyttApp: Native notifications setup complete")
    }
    
    /// Set up observers for handling notification interactions
    @MainActor
    private func setupNotificationObservers() {
        // Navigate to notifications view when notification is tapped
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NavigateToNotifications"),
            object: nil,
            queue: .main
        ) { notification in
            Task { @MainActor in
                appState.selectedTab = .profile // Notifications are in profile section
            }
        }
        
        // Handle friend request actions from notifications
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("HandleFriendRequest"),
            object: nil,
            queue: .main
        ) { notification in
            guard let userInfo = notification.object as? [String: Any],
                  let requestId = userInfo["requestId"] as? String,
                  let accept = userInfo["accept"] as? Bool else { return }
            
            Task {
                // Handle friend request action
                print("📱 PalyttApp: Handling friend request \(accept ? "acceptance" : "decline") for: \(requestId)")
                // This would trigger the friend request handling in the notifications view
            }
        }
        
        // Navigate to specific post
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NavigateToPost"),
            object: nil,
            queue: .main
        ) { notification in
            Task { @MainActor in
                appState.selectedTab = .home
            }
            // Additional navigation logic could be added here
        }
        
        // Navigate to messages
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NavigateToMessages"),
            object: nil,
            queue: .main
        ) { notification in
            Task { @MainActor in
                // Navigate to messages view (you might need to add this tab or view)
                appState.selectedTab = .home // Update this to messages tab when available
                print("📱 PalyttApp: Navigating to messages")
            }
        }
    }
}

// MARK: - App State
@MainActor
final class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var selectedTab: AppTab = .home
    @Published var homeViewModel = HomeViewModel()
    @Published var isTabBarVisible = true
    
    // Theme management
    let themeManager = ThemeManager()
    
    // Services - Using singleton pattern
    private let notificationService = NotificationService.shared
    
    // Track if this is a preview instance
    private var isPreviewInstance: Bool = false
    
    init() {
        print("🚀 AppState: Initializing...")
        setupHomeViewModel()
    }
    
    // Static factory method for preview instances
    static func createForPreview() -> AppState {
        let state = AppState()
        state.isPreviewInstance = true
        
        // Set preview-safe values with complete mock data
        state.isAuthenticated = true
        state.currentUser = MockData.currentUser
        state.selectedTab = .home
        state.isTabBarVisible = true
        
        // Force preview mode setup
        state.setupPreviewData()
        
        print("🚀 AppState: Created preview instance with complete mock data")
        return state
    }
    
    private func setupPreviewData() {
        // Ensure we have complete mock data for preview
        if currentUser == nil {
            currentUser = MockData.currentUser
        }
        
        // Set up any other preview-specific state
        isAuthenticated = true
        
        print("✅ AppState: Preview data setup complete - User: \(currentUser?.displayName ?? "Unknown")")
    }
    
    private func setupHomeViewModel() {
        print("🏠 AppState: Setting up HomeViewModel...")
        // The HomeViewModel is already initialized, no additional setup needed currently
    }
    
    /// Refresh the home feed - useful after creating a new post
    func refreshHomeFeed() async {
        print("🔄 AppState: Refreshing home feed...")
        if !isPreviewInstance {
            homeViewModel.refreshPosts()
        }
    }
    
    /// Activate notifications subscription
    func activateNotifications() {
        print("🔔 AppState: Activating notifications subscription...")
        if !isPreviewInstance {
            // notificationService.subscribeToNotifications() // Method doesn't exist, commenting out
        }
    }
    
    /// Hide the tab bar with animation
    func hideTabBar() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isTabBarVisible = false
        }
    }
    
    /// Show the tab bar with animation
    func showTabBar() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isTabBarVisible = true
        }
    }
    
    /// Toggle tab bar visibility
    func toggleTabBar() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isTabBarVisible.toggle()
        }
    }
} 