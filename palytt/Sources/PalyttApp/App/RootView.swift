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

// MARK: - Liquid Glass Effect Components

/// Shape type for liquid glass backgrounds
enum LiquidGlassShape {
    case roundedRectangle(cornerRadius: CGFloat)
    case capsule
    case circle
}

/// A reusable liquid glass background view that creates the iOS 26-style frosted glass effect
/// with layered blur, inner glow, gradient border, and depth shadows
struct LiquidGlassBackground: View {
    let shape: LiquidGlassShape
    @Environment(\.colorScheme) var colorScheme
    
    // Dynamic colors based on color scheme
    private var glowOpacity: Double {
        colorScheme == .dark ? 0.15 : 0.35
    }
    
    private var borderTopOpacity: Double {
        colorScheme == .dark ? 0.3 : 0.6
    }
    
    private var borderBottomOpacity: Double {
        colorScheme == .dark ? 0.05 : 0.15
    }
    
    private var nearShadowOpacity: Double {
        colorScheme == .dark ? 0.35 : 0.12
    }
    
    private var farShadowOpacity: Double {
        colorScheme == .dark ? 0.2 : 0.06
    }
    
    var body: some View {
        ZStack {
            // Layer 1: Base blur material
            baseShape
                .fill(.ultraThinMaterial)
            
            // Layer 2: Inner glow/highlight (light refraction simulation)
            baseShape
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(glowOpacity),
                            Color.white.opacity(glowOpacity * 0.3),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Layer 3: Subtle color tint for depth
            baseShape
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.03 : 0.08),
                            Color.clear
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
        }
        // Layer 4: Gradient border stroke
        .overlay {
            strokeShape
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(borderTopOpacity),
                            Color.white.opacity(borderBottomOpacity)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        }
        // Layer 5: Layered shadows for depth
        .shadow(color: Color.black.opacity(nearShadowOpacity), radius: 8, x: 0, y: 4)
        .shadow(color: Color.black.opacity(farShadowOpacity), radius: 20, x: 0, y: 10)
    }
    
    @ViewBuilder
    private var baseShape: some Shape {
        switch shape {
        case .roundedRectangle(let cornerRadius):
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        case .capsule:
            Capsule()
        case .circle:
            Circle()
        }
    }
    
    @ViewBuilder
    private var strokeShape: some InsettableShape {
        switch shape {
        case .roundedRectangle(let cornerRadius):
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        case .capsule:
            Capsule()
        case .circle:
            Circle()
        }
    }
}

/// View modifier to apply liquid glass effect to any view
struct LiquidGlassModifier: ViewModifier {
    let shape: LiquidGlassShape
    
    func body(content: Content) -> some View {
        content
            .background {
                LiquidGlassBackground(shape: shape)
            }
    }
}

extension View {
    /// Apply liquid glass background effect
    func liquidGlass(shape: LiquidGlassShape = .roundedRectangle(cornerRadius: 22)) -> some View {
        modifier(LiquidGlassModifier(shape: shape))
    }
}

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
                // Mini tab bar indicator when hidden - Liquid Glass style
                if appState.selectedTab == .explore {
                    VStack {
                        Spacer()
                        
                        HStack {
                            Spacer()
                            
                            LiquidGlassMiniNavButton {
                                appState.showTabBar()
                                HapticManager.shared.impact(.light)
                            }
                            
                            Spacer()
                        }
                        .padding(.bottom, 12)
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity).animation(.spring(response: 0.4, dampingFraction: 0.75)),
                        removal: .move(edge: .bottom).combined(with: .opacity).animation(.easeOut(duration: 0.2))
                    ))
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

// MARK: - Custom Tab Bar (iOS 26 Liquid Glass Theme - Enhanced)
struct CustomTabBar: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @Namespace private var tabSelectionAnimation
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                LiquidGlassTabButton(
                    icon: tab.icon,
                    tab: tab,
                    selectedTab: $appState.selectedTab,
                    namespace: tabSelectionAnimation
                )
            }
        }
        .frame(height: 48)
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background {
            LiquidGlassBackground(shape: .roundedRectangle(cornerRadius: 26))
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

// MARK: - Liquid Glass Tab Button with Selection Animation
struct LiquidGlassTabButton: View {
    let icon: String
    let tab: AppTab
    @Binding var selectedTab: AppTab
    let namespace: Namespace.ID
    
    @Environment(\.colorScheme) var colorScheme
    
    private var isSelected: Bool {
        selectedTab == tab
    }
    
    // Dynamic icon colors
    private var iconColor: Color {
        if isSelected {
            return .primaryBrand
        }
        return colorScheme == .dark ? Color.white.opacity(0.55) : Color.black.opacity(0.45)
    }
    
    private var selectedIconColor: Color {
        colorScheme == .dark ? .white : .primaryText
    }
    
    var body: some View {
        Button {
            guard selectedTab != tab else { return }
            HapticManager.shared.impact(.light)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        } label: {
            ZStack {
                // Selection pill background with matchedGeometryEffect
                if isSelected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.primaryBrand.opacity(colorScheme == .dark ? 0.25 : 0.18),
                                    Color.primaryBrand.opacity(colorScheme == .dark ? 0.15 : 0.08)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(
                                    Color.primaryBrand.opacity(colorScheme == .dark ? 0.4 : 0.25),
                                    lineWidth: 0.5
                                )
                        }
                        .matchedGeometryEffect(id: "tabSelection", in: namespace)
                }
                
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(iconColor)
                    .symbolEffect(.bounce, value: isSelected)
            }
            .frame(width: 52, height: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(LiquidGlassTabButtonStyle())
    }
}

// MARK: - Liquid Glass Tab Button Style
struct LiquidGlassTabButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

// MARK: - Create Post Floating Action Button (Liquid Glass Style)
struct CreatePostFAB: View {
    @Environment(\.colorScheme) var colorScheme
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(.medium)
            action()
        }) {
            ZStack {
                // Liquid glass background
                LiquidGlassBackground(shape: .circle)
                
                // Plus icon with subtle glow
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.primaryBrand)
                    .shadow(color: Color.primaryBrand.opacity(0.3), radius: 4, x: 0, y: 0)
            }
            .frame(width: 56, height: 56)
            .clipShape(Circle())
        }
        .buttonStyle(LiquidGlassFABButtonStyle())
    }
}

// MARK: - Liquid Glass FAB Button Style
struct LiquidGlassFABButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
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

// MARK: - Liquid Glass Mini Navigation Button
struct LiquidGlassMiniNavButton: View {
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .semibold))
                Text("Navigation")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(colorScheme == .dark ? .white.opacity(0.9) : .primary)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background {
                LiquidGlassBackground(shape: .capsule)
            }
            .clipShape(Capsule())
        }
        .buttonStyle(GlassMiniTabButtonStyle())
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

