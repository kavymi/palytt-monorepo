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

// MARK: - Tab Bar Layout Constants
enum TabBarLayout {
    /// Total height of the floating tab bar area (bar + padding + FAB consideration)
    static let bottomInset: CGFloat = 80
    /// Height when tab bar is hidden
    static let collapsedInset: CGFloat = 0
}

// MARK: - Main Tab View
struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var showCreatePost = false
    @State private var showHashtagFeed = false
    @State private var selectedHashtag: String = ""
    
    @ViewBuilder
    private var tabContent: some View {
        switch appState.selectedTab {
            case .home:
                HomeView()
            case .explore:
                ExploreView()
            case .friends:
                FriendsTabView()
            case .profile:
                ProfileView()
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab Content with bottom safe area for floating tab bar
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaInset(edge: .bottom) {
                    // Reserve space for the floating tab bar
                    Color.clear
                        .frame(height: appState.isTabBarVisible ? TabBarLayout.bottomInset : TabBarLayout.collapsedInset)
                }
            
            // Custom Tab Bar + FAB with visibility control
            if appState.isTabBarVisible {
                HStack(alignment: .bottom, spacing: 12) {
                    // Main Tab Bar (4 tabs)
                    CustomTabBar()
                    
                    // Floating Create Post Button
                    CreatePostFAB {
                        showCreatePost = true
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
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
        #if os(iOS)
        .fullScreenCover(isPresented: $showCreatePost) {
            CreatePostView()
                .environmentObject(appState)
        }
        .fullScreenCover(isPresented: $showHashtagFeed) {
            HashtagFeedView(hashtag: selectedHashtag)
                .environmentObject(appState)
        }
        #else
        .sheet(isPresented: $showCreatePost) {
            CreatePostView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showHashtagFeed) {
            HashtagFeedView(hashtag: selectedHashtag)
                .environmentObject(appState)
        }
        #endif
        .onReceive(NotificationCenter.default.publisher(for: .navigateToHashtag)) { notification in
            if let hashtag = notification.userInfo?["hashtag"] as? String {
                selectedHashtag = hashtag
                showHashtagFeed = true
            }
        }
    }
}

// MARK: - Custom Tab Bar (iOS 26 Liquid Glass Theme - Optimized)
struct CustomTabBar: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    
    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color.white.opacity(0.5)
    }
    
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
        .frame(height: 44)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tabBarBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 0.5)
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.1), radius: 12, x: 0, y: 6)
    }
    
    @ViewBuilder
    private var tabBarBackground: some View {
        if #available(iOS 26, *) {
            // iOS 26: Use native glassEffect
            Rectangle()
                .fill(.clear)
                .glassEffect(.regular.interactive())
        } else {
            // iOS 17-25: Material-based glass
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }
}

// MARK: - Create Post Floating Action Button (Matches Tab Bar Style)
struct CreatePostFAB: View {
    @Environment(\.colorScheme) var colorScheme
    let action: () -> Void
    
    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color.white.opacity(0.5)
    }
    
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(.medium)
            action()
        }) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.primaryBrand)
                .frame(width: 52, height: 52)
                .background(fabBackground)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .strokeBorder(borderColor, lineWidth: 0.5)
                }
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.1), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(OptimizedTabButtonStyle(isSelected: false))
    }
    
    @ViewBuilder
    private var fabBackground: some View {
        if #available(iOS 26, *) {
            // iOS 26: Use native glassEffect
            Circle()
                .fill(.clear)
                .glassEffect(.regular.interactive())
        } else {
            // iOS 17-25: Material-based glass
            Circle()
                .fill(.ultraThinMaterial)
        }
    }
}

// MARK: - Tab Bar Button (iOS 26 Liquid Glass Theme - Optimized)
struct TabBarButton: View {
    let icon: String
    let tab: AppTab
    @Binding var selectedTab: AppTab
    var showBadge: Bool = false
    
    @Environment(\.colorScheme) var colorScheme
    
    private var isSelected: Bool {
        selectedTab == tab
    }
    
    // iOS 26 style icon colors - simplified computation
    private var iconColor: Color {
        isSelected ? .primaryBrand : (colorScheme == .dark ? Color.white.opacity(0.6) : Color.black.opacity(0.5))
    }
    
    var body: some View {
        Button {
            guard selectedTab != tab else { return } // Prevent redundant taps
            HapticManager.shared.impact(.light)
            selectedTab = tab
        } label: {
            VStack(spacing: 2) {
                // Icon - compact size
                Image(systemName: icon)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(iconColor)
                
                // Selection indicator dot - simplified
                Circle()
                    .fill(isSelected ? Color.primaryBrand : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .frame(width: 48, height: 44)
            .contentShape(Rectangle()) // Critical: ensures entire area is tappable
            .overlay(alignment: .topTrailing) {
                // Notification badge - moved outside ZStack
                if showBadge {
                    TabBarNotificationBadge()
                        .offset(x: -6, y: 2)
                }
            }
        }
        .buttonStyle(OptimizedTabButtonStyle(isSelected: isSelected))
    }
}

// MARK: - Optimized Tab Button Style
struct OptimizedTabButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
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
