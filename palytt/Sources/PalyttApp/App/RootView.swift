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
                case .friends:
                    FriendsTabView()
                case .profile:
                    ProfileView()
                default:
                    HomeView()
                }
            case .friends:
                FriendsTabView()
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
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20) // Reduced padding for smaller bar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                // Mini tab bar indicator when hidden - iOS 26 Liquid Glass style
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
                                        .font(.system(size: 11, weight: .semibold))
                                    Text("Navigation")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 11)
                                .background {
                                    ZStack {
                                        Capsule()
                                            .fill(.ultraThinMaterial)
                                        
                                        // Inner glow
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color.white.opacity(0.3),
                                                        Color.clear
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    }
                                }
                                .overlay(
                                    Capsule()
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.5),
                                                    Color.white.opacity(0.1)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
                                .shadow(color: .black.opacity(0.08), radius: 24, x: 0, y: 12)
                            }
                            .buttonStyle(GlassMiniTabButtonStyle())
                            
                            Spacer()
                        }
                        .padding(.bottom, 12)
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

// MARK: - Custom Tab Bar (iOS 26 Liquid Glass Theme)
struct CustomTabBar: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    
    // Liquid Glass color properties
    private var glassBackground: some ShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(.ultraThinMaterial)
        } else {
            return AnyShapeStyle(.thinMaterial)
        }
    }
    
    private var innerGlowColor: Color {
        colorScheme == .dark 
            ? Color.white.opacity(0.15) 
            : Color.white.opacity(0.7)
    }
    
    private var outerGlowColor: Color {
        colorScheme == .dark 
            ? Color.white.opacity(0.08) 
            : Color.white.opacity(0.4)
    }
    
    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(colorScheme == .dark ? 0.3 : 0.8),
                Color.white.opacity(colorScheme == .dark ? 0.05 : 0.2),
                Color.white.opacity(colorScheme == .dark ? 0.15 : 0.4)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        HStack(spacing: 8) {
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
                icon: "person.2.fill",
                tab: .friends,
                selectedTab: $appState.selectedTab
            )
            
            TabBarButton(
                icon: "person.fill",
                tab: .profile,
                selectedTab: $appState.selectedTab
            )
        }
        .frame(height: 54)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background {
            // iOS 26 Liquid Glass layered background
            ZStack {
                // Base glass material
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .fill(.ultraThinMaterial)
                
                // Inner subtle gradient for depth/refraction effect
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                innerGlowColor,
                                Color.clear,
                                outerGlowColor
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Subtle color tint for glass effect
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.05 : 0.15),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
            }
        }
        .overlay {
            // iOS 26 style border with gradient for light refraction
            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .strokeBorder(borderGradient, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.08), radius: 1, x: 0, y: 1) // Inner shadow illusion
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.15), radius: 20, x: 0, y: 10) // Soft outer shadow
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.08), radius: 40, x: 0, y: 20) // Diffuse shadow
    }
}

// MARK: - Tab Bar Button (iOS 26 Liquid Glass Theme)
struct TabBarButton: View {
    let icon: String
    let tab: AppTab
    @Binding var selectedTab: AppTab
    var isSpecial: Bool = false
    var showBadge: Bool = false
    
    @Environment(\.colorScheme) var colorScheme
    
    var isSelected: Bool {
        selectedTab == tab
    }
    
    // iOS 26 style icon colors
    private var iconColor: Color {
        if isSelected {
            return .primaryBrand
        } else {
            return colorScheme == .dark 
                ? Color.white.opacity(0.5) 
                : Color.black.opacity(0.4)
        }
    }
    
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(.light)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        }) {
            ZStack {
                // Selected state background glow (iOS 26 style)
                if isSelected && !isSpecial {
                    Circle()
                        .fill(Color.primaryBrand.opacity(0.15))
                        .frame(width: 44, height: 44)
                        .blur(radius: 8)
                }
                
                VStack(spacing: 4) {
                    ZStack {
                        // Icon with iOS 26 style transitions
                        Image(systemName: icon)
                            .font(.system(size: isSpecial ? 26 : 22, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(iconColor)
                            .symbolEffect(.bounce, value: isSelected)
                            .scaleEffect(isSelected ? 1.08 : 1.0)
                    }
                    
                    // Selection indicator dot
                    if isSelected && !isSpecial {
                        Capsule()
                            .fill(Color.primaryBrand)
                            .frame(width: 5, height: 5)
                            .shadow(color: Color.primaryBrand.opacity(0.5), radius: 4, x: 0, y: 0)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Notification badge
                if showBadge {
                    VStack {
                        HStack {
                            Spacer()
                            TabBarNotificationBadge()
                                .offset(x: -4, y: 4)
                        }
                        Spacer()
                    }
                }
            }
        }
        .buttonStyle(GlassTabButtonStyle(isSpecial: isSpecial))
    }
}

// MARK: - Glass Tab Button Style
struct GlassTabButtonStyle: ButtonStyle {
    var isSpecial: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : (isSpecial ? 1.1 : 1.0))
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Glass Mini Tab Button Style
struct GlassMiniTabButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
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

// MARK: - Friends Tab View (Wrapper for tab navigation)
struct FriendsTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var showAddFriends = false
    
    var body: some View {
        NavigationStack {
            FriendsContentView()
                .navigationTitle("Friends")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            HapticManager.shared.impact(.light)
                            showAddFriends = true
                        }) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 18))
                                .foregroundColor(.primaryBrand)
                        }
                    }
                }
                .sheet(isPresented: $showAddFriends) {
                    AddFriendsView()
                        .environmentObject(appState)
                }
        }
    }
}

// MARK: - Friends Content View (Embedded in tab)
struct FriendsContentView: View {
    @StateObject private var viewModel = FriendsViewViewModel()
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: FriendsContentTab = .friends
    @Namespace private var tabAnimation
    
    enum FriendsContentTab: String, CaseIterable {
        case friends = "Friends"
        case requests = "Requests"
        
        var icon: String {
            switch self {
            case .friends: return "person.2.fill"
            case .requests: return "person.badge.clock.fill"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Selector
            tabSelector
            
            // Content
            contentView
        }
        .background(Color.appBackground)
        .task {
            await loadInitialData()
        }
    }
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(FriendsContentTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                    HapticManager.shared.impact(.light)
                    loadTabData(for: tab)
                }) {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 14))
                            
                            Text(tab.rawValue)
                                .font(.system(size: 14, weight: .semibold))
                            
                            // Badge for requests
                            if tab == .requests && viewModel.pendingRequestsCount > 0 {
                                Text("\(viewModel.pendingRequestsCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red)
                                    .clipShape(Capsule())
                            }
                        }
                        .foregroundColor(selectedTab == tab ? .primaryBrand : .secondaryText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        
                        // Indicator
                        Rectangle()
                            .fill(selectedTab == tab ? Color.primaryBrand : Color.clear)
                            .frame(height: 3)
                            .cornerRadius(1.5)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 8)
        .background(Color.appBackground)
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .friends:
            friendsContent
        case .requests:
            requestsContent
        }
    }
    
    private var friendsContent: some View {
        Group {
            if viewModel.isLoadingFriends && viewModel.friends.isEmpty {
                loadingView(message: "Loading friends...")
            } else if viewModel.friends.isEmpty && !viewModel.isLoadingFriends {
                emptyFriendsState
            } else {
                List {
                    ForEach(viewModel.friends, id: \.clerkId) { user in
                        FriendRowView(user: user)
                            .listRowBackground(Color.cardBackground)
                            .listRowSeparatorTint(Color.divider)
                    }
                    
                    if viewModel.hasMoreFriends && !viewModel.isLoadingFriends {
                        loadMoreButton {
                            Task { await viewModel.loadMoreFriends() }
                        }
                    } else if viewModel.isLoadingFriends {
                        loadingIndicator
                    }
                }
                .listStyle(PlainListStyle())
                .refreshable {
                    await viewModel.refreshFriends()
                }
            }
        }
    }
    
    private var requestsContent: some View {
        Group {
            if viewModel.isLoadingRequests && viewModel.friendRequests.isEmpty {
                loadingView(message: "Loading requests...")
            } else if viewModel.friendRequests.isEmpty && !viewModel.isLoadingRequests {
                emptyRequestsState
            } else {
                List {
                    ForEach(viewModel.friendRequests, id: \._id) { request in
                        FriendRequestRowView(
                            request: request,
                            onAccept: {
                                Task { await viewModel.acceptRequest(request._id) }
                            },
                            onDecline: {
                                Task { await viewModel.rejectRequest(request._id) }
                            }
                        )
                        .listRowBackground(Color.cardBackground)
                        .listRowSeparatorTint(Color.divider)
                    }
                }
                .listStyle(PlainListStyle())
                .refreshable {
                    await viewModel.refreshRequests()
                }
            }
        }
    }
    
    private var emptyFriendsState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.primaryBrand.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "person.2")
                    .font(.system(size: 40))
                    .foregroundColor(.primaryBrand)
            }
            
            VStack(spacing: 8) {
                Text("No Friends Yet")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                Text("Connect with people to see them here")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyRequestsState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.primaryBrand.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "person.2.badge.gearshape")
                    .font(.system(size: 40))
                    .foregroundColor(.primaryBrand)
            }
            
            VStack(spacing: 8) {
                Text("No Friend Requests")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                Text("When people send you friend requests, they'll appear here")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func loadingView(message: String) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func loadMoreButton(action: @escaping () -> Void) -> some View {
        HStack {
            Spacer()
            Button("Load More", action: action)
                .font(.subheadline)
                .foregroundColor(.primaryBrand)
            Spacer()
        }
        .listRowBackground(Color.clear)
    }
    
    private var loadingIndicator: some View {
        HStack {
            Spacer()
            ProgressView()
                .scaleEffect(0.8)
            Spacer()
        }
        .listRowBackground(Color.clear)
    }
    
    private func loadInitialData() async {
        guard let userId = appState.currentUser?.clerkId else { return }
        await viewModel.loadInitialData(userId: userId)
    }
    
    private func loadTabData(for tab: FriendsContentTab) {
        guard let userId = appState.currentUser?.clerkId else { return }
        Task {
            switch tab {
            case .friends:
                if viewModel.friends.isEmpty {
                    await viewModel.loadFriends(for: userId)
                }
            case .requests:
                if viewModel.friendRequests.isEmpty {
                    await viewModel.loadFriendRequests(for: userId)
                }
            }
        }
    }
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

#Preview("👥 Friends Tab") {
    let appState = AppState.createForPreview()
    
    return FriendsTabView()
        .environmentObject(appState)
        .environmentObject(appState.themeManager)
} 
