//
//  HomeView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI
import Kingfisher
import Clerk
#if !targetEnvironment(simulator)
#if !targetEnvironment(simulator)
// import ConvexMobile // temporarily disabled
#endif
#endif

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var showNotifications = false
    
    @ObservedObject private var notificationService = NotificationService.shared
    private let backendService = BackendService.shared
    // @StateObject private var realtimeService = RealtimeService.shared
    // @StateObject private var analyticsService = AnalyticsService.shared
    // @StateObject private var offlineManager = OfflineSupportManager.shared
    // @StateObject private var performanceOptimizer = PerformanceOptimizer.shared
    
    // Use the AppState's homeViewModel instead of creating a new one
    private var viewModel: HomeViewModel {
        appState.homeViewModel
    }
    
    @ViewBuilder
    private var feedStatusSection: some View {
        // Friends feed doesn't need a status indicator - it's the default and only feed
        EmptyView()
    }
    
    @ViewBuilder
    private var connectionStatusSection: some View {
        if !backendService.isAPIHealthy {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .foregroundColor(.red)
                Text("Connection issues detected")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.red.opacity(0.1))
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var mainContentSection: some View {
        if (viewModel.isLoading && viewModel.posts.isEmpty) || (!appState.isAuthenticated && viewModel.posts.isEmpty) {
            // Initial loading skeleton - show while loading OR while waiting for auth
            ForEach(0..<3, id: \.self) { _ in
                PostCardSkeleton()
                    .padding(.horizontal)
            }
        } else if viewModel.posts.isEmpty && !viewModel.isLoading && appState.isAuthenticated {
            // Empty state - only show when authenticated and not loading
            EmptyFeedView()
        } else {
                    // Posts grid with staggered animation
                    ForEach(Array(viewModel.posts.enumerated()), id: \.element.id) { index, post in
                        PostCard(
                            post: post,
                            onLike: { postId in
                                Task {
                                    await viewModel.toggleLike(for: postId)
                                }
                            },
                            onBookmark: { postId in
                                Task {
                                    await viewModel.toggleBookmark(for: postId)
                                }
                            },
                            onBookmarkNavigate: {
                                HapticManager.shared.impact(.medium)
                                appState.selectedTab = .profile
                            }
                        )
                        .padding(.horizontal, 12)
                        .onAppear {
                            viewModel.checkForMorePosts(currentPost: post)
                        }
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.95)),
                                removal: .opacity
                            )
                        )
                    }
            
            // Loading more indicator
            if viewModel.isLoadingMore {
                LoadingMoreView()
                    .padding(.vertical)
            }
            
            // End of content indicator
            if !viewModel.hasMorePages && !viewModel.posts.isEmpty {
                EndOfContentView()
                    .padding(.vertical)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    feedStatusSection
                    connectionStatusSection
                    // Real-time updates feed (temporarily disabled)
                    // if !realtimeService.liveUpdates.isEmpty || !offlineManager.isOffline {
                    //     VStack(spacing: 12) {
                    //         // Offline indicator
                    //         if offlineManager.isOffline {
                    //             OfflineIndicatorView()
                    //                 .padding(.horizontal)
                    //         }
                    //         
                    //         // Live updates feed
                    //         LiveUpdatesFeedView()
                    //             .padding(.horizontal)
                    //     }
                    //     .padding(.bottom, 8)
                    // }
                    
                    // Main content
                    mainContentSection
                }
                .padding(.vertical, 4)
            }
            .background(Color.appBackground)
            .animation(.easeInOut(duration: 0.3), value: viewModel.posts.count)
            .refreshable {
                // Pull-to-refresh functionality with haptic feedback
                HapticManager.shared.impact(.light)
                
                // let startTime = Date()
                viewModel.refreshPosts()
                
                // Track refresh performance (temporarily disabled)
                // let refreshTime = Date().timeIntervalSince(startTime) * 1000 // Convert to milliseconds
                // analyticsService.trackPerformanceMetric(PerformanceMetric(
                //     name: "feed_refresh_time",
                //     value: refreshTime,
                //     unit: "ms"
                // ))
                
                // Track user action
                // AnalyticsManager.shared.trackFeatureUsed("home_refresh", context: ["trigger": "pull_to_refresh"])
            }
            .onAppear {
                // ✅ Always attempt to fetch posts on first appear
                // If authenticated, fetch immediately
                // If not authenticated yet, show loading and wait for auth
                if appState.isAuthenticated {
                    // User is already authenticated - fetch posts if needed
                    viewModel.fetchPostsIfNeeded()
                } else if viewModel.posts.isEmpty {
                    // Not authenticated yet - show loading state
                    // The onChange handler will trigger fetch when auth is ready
                    viewModel.isLoading = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NewPostCreated"))) { _ in
                // Refresh posts when a new post is created
                viewModel.refreshPosts()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserPostsUpdated"))) { _ in
                // Refresh posts when user posts are updated
                viewModel.refreshPosts()
            }
            // ✅ Refresh when app becomes active from background (if data is stale)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                if viewModel.isDataStale {
                    viewModel.fetchPosts()
                }
            }
            // ✅ Refresh when home tab is selected (if data is stale)
            .onChange(of: appState.selectedTab) { oldValue, newValue in
                if newValue == .home && viewModel.isDataStale {
                    viewModel.fetchPosts()
                }
            }
            // ✅ Refresh when user authentication state changes (e.g., after Clerk loads)
            .onChange(of: appState.isAuthenticated) { oldValue, newValue in
                if newValue {
                    // User just became authenticated - fetch posts immediately
                    print("🔐 HomeView: User authenticated, fetching posts")
                    viewModel.fetchPosts()
                } else if !newValue {
                    // User logged out - clear posts
                    viewModel.clearPosts()
                }
            }
            // .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RealtimeLiveUpdate"))) { notification in
            //     // Handle real-time live updates (temporarily disabled)
            //     if let liveUpdate = notification.object as? LiveUpdate {
            //         switch liveUpdate.type {
            //         case .newPost:
            //             // Refresh posts for new content
            //             viewModel.refreshPosts()
            //         case .newLike, .newComment:
            //             // Could update specific post metrics here
            //             break
            //         default:
            //             break
            //         }
            //     }
            // }
            .navigationTitle("Palytt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        showNotifications = true
                        
                        // Track analytics (temporarily disabled)
                        // analyticsService.trackUserAction(.profileView, properties: ["section": "notifications"])
                    }) {
                        ZStack {
                            Image(systemName: "bell")
                                .font(.system(size: 18))
                                .foregroundColor(.appPrimaryText)
                            
                            // Notification badge
                            if notificationService.unreadCount > 0 {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showNotifications) {
                NotificationsView()
                    .environmentObject(appState)
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { 
                    viewModel.errorMessage = nil 
                }
                Button("Retry") { 
                    viewModel.fetchPosts() 
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}

// MARK: - Supporting Views

struct EmptyFeedView: View {
    @EnvironmentObject var appState: AppState
    @State private var showFindFriends = false
    @State private var iconBounce = false
    @State private var appeared = false
    
    var body: some View {
        VStack(spacing: 28) {
            // Animated illustration with layered circles
            ZStack {
                // Outer pulsing ring
                Circle()
                    .stroke(Color.primaryBrand.opacity(0.15), lineWidth: 2)
                    .frame(width: 160, height: 160)
                    .scaleEffect(iconBounce ? 1.1 : 1.0)
                    .opacity(iconBounce ? 0.5 : 0.8)
                
                Circle()
                    .fill(Color.primaryBrand.opacity(0.08))
                    .frame(width: 140, height: 140)
                
                Circle()
                    .fill(Color.primaryBrand.opacity(0.12))
                    .frame(width: 110, height: 110)
                
                Image(systemName: "person.2.fill")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(.primaryBrand)
                    .offset(y: iconBounce ? -3 : 0)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    iconBounce = true
                }
            }
            
            VStack(spacing: 14) {
                Text("See what your friends are eating")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.primaryText)
                    .multilineTextAlignment(.center)
                
                Text("Add friends to see their food discoveries here")
                    .font(.system(size: 15))
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 40)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            
            VStack(spacing: 16) {
                // Find Friends CTA - Enhanced
                Button(action: {
                    HapticManager.shared.impact(.medium)
                    showFindFriends = true
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Find Friends")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(LinearGradient.primaryGradient)
                            .shadow(color: .primaryBrand.opacity(0.35), radius: 12, x: 0, y: 6)
                    )
                }
                .scaleEffect(appeared ? 1 : 0.9)
                
                // Secondary action - Invite friends
                Button(action: {
                    HapticManager.shared.impact(.light)
                    // Could trigger invite flow
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .medium))
                        Text("Invite friends to Palytt")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.primaryBrand)
                }
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 30)
        }
        .padding(.top, 60)
        .padding(.bottom, 100)
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.2)) {
                appeared = true
            }
        }
        .sheet(isPresented: $showFindFriends) {
            AddFriendsView()
        }
    }
}

struct LoadingMoreView: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Custom animated loader
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.primaryBrand)
                        .frame(width: 6, height: 6)
                        .scaleEffect(isAnimating ? 1.0 : 0.5)
                        .opacity(isAnimating ? 1.0 : 0.4)
                        .animation(
                            .easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.15),
                            value: isAnimating
                        )
                }
            }
            
            Text("Loading more...")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.appSecondaryText)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .onAppear {
            isAnimating = true
        }
    }
}

struct EndOfContentView: View {
    @State private var appeared = false
    
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.primaryBrand.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(.primaryBrand)
            }
            .scaleEffect(appeared ? 1.0 : 0.8)
            
            Text("You're all caught up!")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.appPrimaryText)
            
            Text("Check back later for new posts")
                .font(.system(size: 12))
                .foregroundColor(.appSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }
}

// MARK: - SwiftUI Previews
#Preview("Home Feed - Standard") {
    HomeView()
        .environmentObject(MockAppState())
}

#Preview("Home Feed - Empty State") {
    let mockState = MockAppState()
    mockState.homeViewModel.posts = []
    
    return HomeView()
        .environmentObject(mockState)
}

#Preview("Home Feed - Loading") {
    let mockState = MockAppState()
    mockState.homeViewModel.isLoading = true
    
    return HomeView()
        .environmentObject(mockState)
}

#Preview("Home Feed - Trending Only") {
    let mockState = MockAppState()
    mockState.homeViewModel.posts = Array(MockData.generateTrendingPosts())
    
    return HomeView()
        .environmentObject(mockState)
}

#Preview("Home Feed - Recent Posts") {
    let mockState = MockAppState()
    mockState.homeViewModel.posts = Array(MockData.generateRecentPosts())
    
    return HomeView()
        .environmentObject(mockState)
}

#Preview("Home Feed - Dark Mode") {
    HomeView()
        .environmentObject(MockAppState())
        .preferredColorScheme(.dark)
}

