//
//  ProfileView.swift
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
import Foundation
import Combine
#if os(iOS)
import UIKit
#endif

struct ProfileView: View {
    let targetUser: User? // If nil, shows current user's profile
    @StateObject private var viewModel: ProfileViewModel
    @EnvironmentObject var appState: AppState
    
    // Initialize with appropriate ViewModel based on context
    init(targetUser: User? = nil, mockViewModel: ProfileViewModel? = nil) {
        self.targetUser = targetUser
        
        if let mockViewModel = mockViewModel {
            self._viewModel = StateObject(wrappedValue: mockViewModel)
        } else {
            // Check if we're in preview mode
            let isPreviewMode = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            
            if isPreviewMode {
                // We're in preview mode - use a mock view model with data
                let mockVM = ProfileViewModel()
                if let targetUser = targetUser {
                    mockVM.currentUser = targetUser
                    mockVM.userPosts = MockData.generateUserPosts(for: targetUser)
                } else {
                    mockVM.currentUser = MockData.currentUser
                    mockVM.userPosts = MockData.generateUserPosts(for: MockData.currentUser)
                }
                mockVM.isLoading = false
                mockVM.errorMessage = nil
                self._viewModel = StateObject(wrappedValue: mockVM)
            } else {
                // Normal runtime - use regular ProfileViewModel
                self._viewModel = StateObject(wrappedValue: ProfileViewModel())
            }
        }
    }
    @State private var showSettings = false
    @State private var showEditProfile = false
    @State private var showAdminSettings = false
    @State private var showFollowersSheet = false
    @State private var showFollowingSheet = false
    @State private var showFriendsView = false  // Unified friends view
    @State private var showInviteView = false
    @State private var showStreakView = false
    @State private var currentStreak: Int = 0
    @State private var isStreakActive: Bool = false
    
    // Phase 3 Services (temporarily disabled for build)
    // @StateObject private var privacyManager = PrivacyControlsManager.shared
    // @StateObject private var analyticsService = AnalyticsService.shared
    // @StateObject private var contentModeration = ContentModerationService.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    profileContent
                }
                .frame(maxWidth: .infinity)
                .background(Color.appBackground)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.appBackground)
            .scrollContentBackground(.hidden)
            .refreshable {
                await viewModel.refreshProfile()
                await loadStreakData()
            }
            .task {
                await loadStreakData()
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    toolbarButtons
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    toolbarButtons
                }
                #endif
            }
            .modifier(SheetPresentationModifier(
                showSettings: $showSettings,
                showEditProfile: $showEditProfile,
                showAdminSettings: $showAdminSettings,
                showFollowersSheet: $showFollowersSheet,
                showFollowingSheet: $showFollowingSheet,
                viewModel: viewModel
            ))
            .sheet(isPresented: $showInviteView) {
                InviteView()
            }
            .sheet(isPresented: $showStreakView) {
                StreakView()
            }
            .sheet(isPresented: $showFriendsView) {
                FriendsView()
                    .environmentObject(appState)
            }
        }
        .background(Color.appBackground)
        .task {
            if let targetUser = targetUser {
                await viewModel.loadOtherUserProfile(targetUser)
                
                // Track viewing another user's profile (temporarily disabled)
                // analyticsService.trackUserAction(.profileView, properties: [
                //     "target_user_id": targetUser.id,
                //     "is_own_profile": "false"
                // ])
            } else {
                await viewModel.loadUserProfile()
                
                // Track viewing own profile (temporarily disabled)
                // analyticsService.trackUserAction(.profileView, properties: [
                //     "is_own_profile": "true"
                // ])
            }
            
            // Track screen view (temporarily disabled)
            // analyticsService.trackScreenView(targetUser != nil ? "Other User Profile" : "Own Profile")
        }
    }
    
    @ViewBuilder
    private var profileContent: some View {
        if viewModel.isLoading {
            loadingContent
        } else if let currentUser = viewModel.currentUser {
            loadedContent(user: currentUser)
        } else if let errorMessage = viewModel.errorMessage {
            errorContent(message: errorMessage)
        } else {
            emptyContent
        }
    }
    
    @ViewBuilder
    private var loadingContent: some View {
        ProfileHeaderSkeleton()
        
        HStack(spacing: 40) {
            ForEach(0..<3, id: \.self) { _ in
                VStack(spacing: 4) {
                    SkeletonLoader()
                        .frame(width: 40, height: 20)
                    SkeletonLoader()
                        .frame(width: 60, height: 12)
                }
            }
        }
        .padding(.horizontal)
        
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 2),
            GridItem(.flexible(), spacing: 2),
            GridItem(.flexible(), spacing: 2)
        ], spacing: 2) {
            ForEach(0..<9, id: \.self) { _ in
                GridItemSkeleton()
            }
        }
        .padding(.horizontal, 2)
    }
    
    @ViewBuilder
    private func loadedContent(user: User) -> some View {
        // Profile Header
        if let targetUser = targetUser, targetUser.id != appState.currentUser?.id {
            // Viewing another user's profile
            OtherUserProfileHeaderView(user: targetUser)
        } else {
            // Viewing own profile
            VStack(spacing: 0) {
                ProfileHeaderView(
                    user: user,
                    onEditProfile: { showEditProfile = true }
                )
                
                // Streak Badge (tappable)
                if currentStreak > 0 || isStreakActive {
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        showStreakView = true
                    }) {
                        StreakBadgeView(currentStreak: currentStreak, isActive: isStreakActive)
                    }
                    .padding(.top, -8)
                }
            }
        }
        
        // Stats
        ProfileStatsView(
            user: user,
            showFollowersSheet: $showFollowersSheet,
            showFollowingSheet: $showFollowingSheet
        )
        
        // Daily Challenges Section (only for own profile)
        if targetUser == nil || targetUser?.id == appState.currentUser?.id {
            ProfileChallengesSection()
        }
        
        // Admin Section (visible to admin users)
        if user.isAdmin {
            AdminQuickAccessView(showAdminSettings: $showAdminSettings)
        }
        
        // Posts Grid
        ProfilePostsGrid(posts: viewModel.userPosts)
    }
    
    @ViewBuilder
    private func errorContent(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.warning)
            
            Text("Error Loading Profile")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.appPrimaryText)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.appSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                Button("Try Again") {
                    Task {
                        if let targetUser = targetUser {
                            await viewModel.loadOtherUserProfile(targetUser)
                        } else {
                            await viewModel.loadUserProfile()
                        }
                    }
                }
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.primaryBrand)
                .cornerRadius(12)
                
                // Sign Out button for authentication issues
                Button("Sign Out") {
                    Task {
                        await self.signOut()
                    }
                }
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primaryBrand)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.primaryBrand.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private var emptyContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.circle")
                .font(.system(size: 50))
                .foregroundColor(.appTertiaryText)
            
            Text("No Profile Data")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.appPrimaryText)
            
            Text("Unable to load profile information")
                .font(.subheadline)
                .foregroundColor(.appSecondaryText)
        }
        .padding()
    }
    
    private var toolbarButtons: some View {
        HStack(spacing: 12) {
            // Only show these buttons for own profile
            if targetUser == nil {
                Button(action: { 
                    showInviteView = true
                    // analyticsService.trackUserAction(.profileView, properties: ["section": "invite"])
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.primaryBrand)
                }
            }
            
            if viewModel.currentUser?.isAdmin == true {
                Button(action: { 
                    showAdminSettings = true
                    // analyticsService.trackUserAction(.profileView, properties: ["section": "admin"])
                }) {
                    Image(systemName: "shield.fill")
                        .foregroundColor(.error)
                }
            }
            
            Button(action: { 
                showSettings = true
                // analyticsService.trackUserAction(.profileView, properties: ["section": "settings"])
            }) {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.primaryBrand)
            }
        }
    }
    
    private func loadStreakData() async {
        guard let currentUser = Clerk.shared.user else { return }
        
        do {
            let response = try await BackendService.shared.getStreakInfo(clerkId: currentUser.id)
            currentStreak = response.currentStreak
            isStreakActive = response.isStreakActive
        } catch {
            print("❌ ProfileView: Failed to load streak data: \(error)")
        }
    }
    
    private func signOut() async {
        do {
            try await Clerk.shared.signOut()
            // Reset app state
            await MainActor.run {
                appState.isAuthenticated = false
                appState.currentUser = nil
            }
        } catch {
            print("Error signing out: \(error)")
        }
    }
}

// MARK: - Profile Header View
struct ProfileHeaderView: View {
    let user: User
    let onEditProfile: () -> Void
    @State private var avatarScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 20) {
            // Profile Picture with Gradient Ring
            ZStack {
                // Outer gradient ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.primaryBrand, .primaryBrand.opacity(0.6), .primaryBrand.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 4
                    )
                    .frame(width: 120, height: 120)
                
                // Avatar
                if let avatarURL = user.avatarURL {
                    KFImage(avatarURL)
                        .placeholder {
                            profileInitials
                        }
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 108, height: 108)
                        .clipShape(Circle())
                } else {
                    profileInitials
                }
            }
            .scaleEffect(avatarScale)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                    avatarScale = 1.0
                }
            }
            .shadow(color: .primaryBrand.opacity(0.2), radius: 12, x: 0, y: 6)
            
            // User Info
            VStack(spacing: 6) {
                Text(user.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.appPrimaryText)
                
                HStack(spacing: 4) {
                    Text("@\(user.username)")
                        .font(.subheadline)
                        .foregroundColor(.appSecondaryText)
                }
                
                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.subheadline)
                        .foregroundColor(.appPrimaryText.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 32)
                        .padding(.top, 4)
                }
            }
            
            // Edit Profile Button - Enhanced
            Button(action: onEditProfile) {
                HStack(spacing: 8) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Edit Profile")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(LinearGradient.primaryGradient)
                        .shadow(color: .primaryBrand.opacity(0.3), radius: 8, x: 0, y: 4)
                )
            }
            .buttonStyle(ProfileScaleButtonStyle())
        }
        .padding(.vertical, 24)
        .padding(.horizontal)
    }
    
    private var profileInitials: some View {
        Circle()
            .fill(LinearGradient.primaryGradient)
            .frame(width: 108, height: 108)
            .overlay(
                Text(user.username.prefix(2).uppercased())
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            )
    }
}

// MARK: - Profile Scale Button Style
struct ProfileScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    HapticManager.shared.impact(.light)
                }
            }
    }
}

// MARK: - Other User Profile Header View  
struct OtherUserProfileHeaderView: View {
    let user: User
    @StateObject private var socialActionViewModel = SocialActionViewModel()
    @EnvironmentObject var appState: AppState
    @State private var avatarScale: CGFloat = 0.9
    
    var body: some View {
        VStack(spacing: 20) {
            // Profile Picture with Gradient Ring
            ZStack {
                // Outer gradient ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.primaryBrand, .primaryBrand.opacity(0.6), .primaryBrand.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 4
                    )
                    .frame(width: 120, height: 120)
                
                // Avatar
                if let avatarURL = user.avatarURL {
                    KFImage(avatarURL)
                        .placeholder {
                            profileInitials
                        }
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 108, height: 108)
                        .clipShape(Circle())
                } else {
                    profileInitials
                }
            }
            .scaleEffect(avatarScale)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                    avatarScale = 1.0
                }
            }
            .shadow(color: .primaryBrand.opacity(0.2), radius: 12, x: 0, y: 6)
            
            // User Info
            VStack(spacing: 6) {
                Text(user.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.appPrimaryText)
                
                Text("@\(user.username)")
                    .font(.subheadline)
                    .foregroundColor(.appSecondaryText)
                
                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.subheadline)
                        .foregroundColor(.appPrimaryText.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 32)
                        .padding(.top, 4)
                }
            }
            
            // Social Actions for other users
            SocialActionsView(targetUser: user, viewModel: socialActionViewModel)
        }
        .padding(.vertical, 24)
        .padding(.horizontal)
        .task {
            await socialActionViewModel.loadUserRelationship(for: user, currentUser: appState.currentUser)
        }
    }
    
    private var profileInitials: some View {
        Circle()
            .fill(LinearGradient.primaryGradient)
            .frame(width: 108, height: 108)
            .overlay(
                Text(user.username.prefix(2).uppercased())
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            )
    }
}

// MARK: - Social Actions View
struct SocialActionsView: View {
    let targetUser: User
    @ObservedObject var viewModel: SocialActionViewModel
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 12) {
            // Follow/Unfollow Button
            Button(action: {
                Task {
                    await toggleFollow()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.isFollowing ? "checkmark" : "plus")
                        .font(.system(size: 14, weight: .semibold))
                    Text(viewModel.isFollowing ? "Following" : "Follow")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(viewModel.isFollowing ? .white : .primaryBrand)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(viewModel.isFollowing ? Color.primaryBrand : Color.clear)
                        .stroke(Color.primaryBrand, lineWidth: 1.5)
                )
            }
            .disabled(viewModel.isLoading)
            .buttonStyle(HapticButtonStyle(haptic: .medium))
            
            // Friend Request Button
            Button(action: {
                Task {
                    await handleFriendAction()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: friendButtonIcon)
                        .font(.system(size: 14, weight: .semibold))
                    Text(friendButtonText)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(friendButtonColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(friendButtonBackground)
                        .stroke(friendButtonColor, lineWidth: 1.5)
                )
            }
            .disabled(viewModel.isLoading)
            .buttonStyle(HapticButtonStyle(haptic: .medium))
            
            // Loading indicator
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
                    .progressViewStyle(CircularProgressViewStyle(tint: .primaryBrand))
            }
        }
    }
    
    private var friendButtonIcon: String {
        switch viewModel.friendRequestStatus {
        case .friends:
            return "person.fill.checkmark"
        case .sent:
            return "clock"
        case .received:
            return "person.badge.plus"
        case .none:
            return "person.badge.plus"
        }
    }
    
    private var friendButtonText: String {
        switch viewModel.friendRequestStatus {
        case .friends:
            return "Friends"
        case .sent:
            return "Pending"
        case .received:
            return "Accept"
        case .none:
            return "Add Friend"
        }
    }
    
    private var friendButtonColor: Color {
        switch viewModel.friendRequestStatus {
        case .friends:
            return .white
        case .sent:
            return .secondaryText
        case .received:
            return .white
        case .none:
            return .primaryBrand
        }
    }
    
    private var friendButtonBackground: Color {
        switch viewModel.friendRequestStatus {
        case .friends:
            return .green
        case .sent:
            return .clear
        case .received:
            return .primaryBrand
        case .none:
            return .clear
        }
    }
    
    private func toggleFollow() async {
        guard let currentUser = appState.currentUser,
              let currentUserClerkId = currentUser.clerkId,
              let targetUserClerkId = targetUser.clerkId else { return }
        
        if viewModel.isFollowing {
            await viewModel.unfollowUser(
                followerId: currentUserClerkId,
                followingId: targetUserClerkId
            )
        } else {
            await viewModel.followUser(
                followerId: currentUserClerkId,
                followingId: targetUserClerkId
            )
        }
    }
    
    private func handleFriendAction() async {
        guard let currentUser = appState.currentUser,
              let currentUserClerkId = currentUser.clerkId,
              let targetUserClerkId = targetUser.clerkId else { return }
        
        switch viewModel.friendRequestStatus {
        case .friends:
            // Already friends - could show options to unfriend
            break
        case .sent:
            // Request already sent - could show cancel option
            break
        case .received:
            // Accept friend request
            await viewModel.acceptFriendRequest(
                currentUserId: currentUserClerkId,
                targetUserId: targetUserClerkId
            )
        case .none:
            // Send friend request
            await viewModel.sendFriendRequest(
                senderId: currentUserClerkId,
                receiverId: targetUserClerkId
            )
        }
    }
}

// MARK: - Social Action ViewModel
@MainActor
class SocialActionViewModel: ObservableObject {
    @Published var isFollowing = false
    @Published var friendRequestStatus: FriendRequestStatus = .none
    @Published var isLoading = false
    
    private let backendService = BackendService.shared
    
    enum FriendRequestStatus {
        case friends
        case sent
        case received
        case none
    }
    
    func loadUserRelationship(for targetUser: User, currentUser: User?) async {
        guard let currentUser = currentUser,
              let currentUserClerkId = currentUser.clerkId,
              let targetUserClerkId = targetUser.clerkId else { return }
        
        isLoading = true
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.checkFollowingStatus(
                    followerId: currentUserClerkId,
                    followingId: targetUserClerkId
                )
            }
            group.addTask {
                await self.checkFriendStatus(
                    userId1: currentUserClerkId,
                    userId2: targetUserClerkId
                )
            }
        }
        
        isLoading = false
    }
    
    private func checkFollowingStatus(followerId: String, followingId: String) async {
        do {
            let response = try await backendService.isFollowing(
                followerId: followerId,
                followingId: followingId
            )
            isFollowing = response.isFollowing
        } catch {
            print("❌ Error checking following status: \(error)")
        }
    }
    
    private func checkFriendStatus(userId1: String, userId2: String) async {
        do {
            let friendResponse = try await backendService.areFriends(userId1: userId1, userId2: userId2)
            if friendResponse.areFriends {
                friendRequestStatus = .friends
                return
            }
            
            let requestResponse = try await backendService.getFriendRequestStatus(userId1: userId1, userId2: userId2)
            switch requestResponse.status {
            case "sent":
                friendRequestStatus = .sent
            case "received":
                friendRequestStatus = .received
            default:
                friendRequestStatus = .none
            }
        } catch {
            print("❌ Error checking friend status: \(error)")
            friendRequestStatus = .none
        }
    }
    
    func followUser(followerId: String, followingId: String) async {
        isLoading = true
        
        do {
            _ = try await backendService.followUser(followerId: followerId, followingId: followingId)
            isFollowing = true
            HapticManager.shared.impact(.success)
        } catch {
            print("❌ Error following user: \(error)")
            HapticManager.shared.impact(.error)
        }
        
        isLoading = false
    }
    
    func unfollowUser(followerId: String, followingId: String) async {
        isLoading = true
        
        do {
            _ = try await backendService.unfollowUser(followerId: followerId, followingId: followingId)
            isFollowing = false
            HapticManager.shared.impact(.medium)
        } catch {
            print("❌ Error unfollowing user: \(error)")
            HapticManager.shared.impact(.error)
        }
        
        isLoading = false
    }
    
    func sendFriendRequest(senderId: String, receiverId: String) async {
        isLoading = true
        
        do {
            _ = try await backendService.sendFriendRequest(senderId: senderId, receiverId: receiverId)
            friendRequestStatus = .sent
            HapticManager.shared.impact(.success)
        } catch {
            print("❌ Error sending friend request: \(error)")
            HapticManager.shared.impact(.error)
        }
        
        isLoading = false
    }
    
    func acceptFriendRequest(currentUserId: String, targetUserId: String) async {
        isLoading = true
        
        do {
            // First get the friend request to find the request ID
            let requestResponse = try await backendService.getFriendRequestStatus(userId1: targetUserId, userId2: currentUserId)
            if let request = requestResponse.request {
                _ = try await backendService.acceptFriendRequest(requestId: request._id)
                friendRequestStatus = .friends
                HapticManager.shared.impact(.success)
            }
        } catch {
            print("❌ Error accepting friend request: \(error)")
            HapticManager.shared.impact(.error)
        }
        
        isLoading = false
    }
}

// MARK: - Profile Stats View
struct ProfileStatsView: View {
    let user: User
    @Binding var showFollowersSheet: Bool
    @Binding var showFollowingSheet: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            EnhancedStatButton(
                count: user.postsCount,
                label: "Posts",
                icon: "square.grid.2x2.fill"
            ) {
                // Scroll to posts
            }
            
            // Divider
            Rectangle()
                .fill(Color.appSecondaryText.opacity(0.2))
                .frame(width: 1, height: 40)
            
            EnhancedStatButton(
                count: user.followersCount,
                label: "Followers",
                icon: "person.2.fill"
            ) {
                showFollowersSheet = true
            }
            
            // Divider
            Rectangle()
                .fill(Color.appSecondaryText.opacity(0.2))
                .frame(width: 1, height: 40)
            
            EnhancedStatButton(
                count: user.followingCount,
                label: "Following",
                icon: "heart.fill"
            ) {
                showFollowingSheet = true
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal)
    }
}

struct EnhancedStatButton: View {
    let count: Int
    let label: String
    let icon: String
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(.light)
            action()
        }) {
            VStack(spacing: 6) {
                Text(formatCount(count))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.appPrimaryText)
                    .contentTransition(.numericText())
                
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.appSecondaryText)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }
    
    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 10_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

// Legacy StatButton for compatibility
struct StatButton: View {
    let count: Int
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("\(count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.appPrimaryText)
                
                Text(label)
                    .font(.caption)
                    .foregroundColor(.appSecondaryText)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Profile Posts Grid
struct ProfilePostsGrid: View {
    let posts: [Post]
    @State private var showCreatePost = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Section Header
            HStack {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primaryBrand)
                
                Text("Posts")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.appPrimaryText)
                
                Spacer()
                
                if !posts.isEmpty {
                    Text("\(posts.count)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.appSecondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.appCardBackground)
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            
            Divider()
                .padding(.horizontal)
            
            if posts.isEmpty {
                // Empty State
                ProfileEmptyPostsView(showCreatePost: $showCreatePost)
                    .padding(.top, 40)
            } else {
                // Posts Grid
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 3),
                    GridItem(.flexible(), spacing: 3),
                    GridItem(.flexible(), spacing: 3)
                ], spacing: 3) {
                    ForEach(posts, id: \.id) { post in
                        NavigationLink(destination: PostDetailView(post: post)) {
                            ProfilePostGridItem(post: post)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 3)
                .padding(.top, 3)
            }
        }
        .sheet(isPresented: $showCreatePost) {
            CreatePostView()
        }
    }
}

// MARK: - Profile Empty Posts View
struct ProfileEmptyPostsView: View {
    @Binding var showCreatePost: Bool
    @State private var iconBounce = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Animated Icon
            ZStack {
                Circle()
                    .fill(Color.primaryBrand.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Circle()
                    .fill(Color.primaryBrand.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "camera.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.primaryBrand)
                    .offset(y: iconBounce ? -4 : 0)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    iconBounce = true
                }
            }
            
            VStack(spacing: 10) {
                Text("Share Your First Discovery")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.appPrimaryText)
                
                Text("Capture and share the amazing food\nyou've been enjoying lately")
                    .font(.subheadline)
                    .foregroundColor(.appSecondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            Button(action: {
                HapticManager.shared.impact(.medium)
                showCreatePost = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Create Post")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(LinearGradient.primaryGradient)
                        .shadow(color: .primaryBrand.opacity(0.3), radius: 10, x: 0, y: 5)
                )
            }
            .buttonStyle(ProfileScaleButtonStyle())
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 60)
    }
}

struct ProfilePostGridItem: View {
    let post: Post
    @State private var isLoaded = false
    
    private var gridItemSize: CGFloat {
        (UIScreen.main.bounds.width - 12) / 3
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let imageURL = post.mediaURLs.first {
                KFImage(imageURL)
                    .placeholder {
                        Rectangle()
                            .fill(Color.appCardBackground)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .primaryBrand))
                                    .scaleEffect(0.8)
                            )
                    }
                    .onSuccess { _ in
                        withAnimation(.easeOut(duration: 0.3)) {
                            isLoaded = true
                        }
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: gridItemSize, height: gridItemSize)
                    .clipped()
                    .opacity(isLoaded ? 1 : 0.7)
            } else {
                Rectangle()
                    .fill(LinearGradient.primaryGradient)
                    .frame(width: gridItemSize, height: gridItemSize)
                    .overlay(
                        VStack(spacing: 4) {
                            Image(systemName: "fork.knife")
                                .font(.system(size: 20, weight: .medium))
                            Text(post.caption.prefix(12) + (post.caption.count > 12 ? "..." : ""))
                                .font(.system(size: 10, weight: .medium))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 4)
                        }
                        .foregroundColor(.white)
                    )
            }
            
            // Overlay gradient for better indicator visibility
            if post.mediaURLs.count > 1 {
                LinearGradient(
                    colors: [.black.opacity(0.4), .clear],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
                .frame(width: 50, height: 50)
            }
            
            // Multiple photos indicator - improved design
            if post.mediaURLs.count > 1 {
                Image(systemName: "square.fill.on.square.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    .padding(8)
            }
            
            // Rating badge if exists
            if let rating = post.rating, rating > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text(String(format: "%.1f", rating))
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.6))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(6)
            }
        }
        .cornerRadius(2)
    }
}

// MARK: - Admin Quick Access View
struct AdminQuickAccessView: View {
    @Binding var showAdminSettings: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "shield.fill")
                    .foregroundColor(.error)
                Text("Admin Controls")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.appPrimaryText)
                Spacer()
            }
            
            HStack(spacing: 12) {
                AdminQuickButton(
                    icon: "gearshape.fill",
                    title: "Dashboard",
                    color: .error
                ) {
                    showAdminSettings = true
                }
                
                AdminQuickButton(
                    icon: "chart.bar.fill",
                    title: "Analytics",
                    color: .blue
                ) {
                    // Open analytics
                }
                
                AdminQuickButton(
                    icon: "exclamationmark.triangle.fill",
                    title: "Reports",
                    color: .orange
                ) {
                    // Open moderation
                }
                
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.error.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.error.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }
}

struct AdminQuickButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.appPrimaryText)
            }
            .frame(width: 60, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(Clerk.self) var clerk
    
    @State private var showLogoutConfirmation = false
    @State private var showProfileEdit = false
    @State private var showNotificationSettings = false
    @State private var showPrivacySettings = false
    @State private var showBlockedUsers = false
    @State private var showHelpCenter = false
    @State private var showContactUs = false
    @State private var showDeleteAccountSheet = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    VStack(spacing: 12) {
                        Circle()
                            .fill(LinearGradient.primaryGradient)
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                            )
                        
                        Text("Settings")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.appPrimaryText)
                    }
                    .padding(.top, 20)
                    
                    // Settings Sections
                    VStack(spacing: 20) {
                        // Account Section
                        SettingsSectionView(title: "Account") {
                            SettingsRowView(
                                icon: "person.circle",
                                title: "Profile Information",
                                subtitle: "Update your profile details"
                            ) {
                                showProfileEdit = true
                            }
                            
                            SettingsRowView(
                                icon: "bell",
                                title: "Notifications",
                                subtitle: "Manage notification preferences"
                            ) {
                                showNotificationSettings = true
                            }
                        }
                        
                        // Privacy Section
                        SettingsSectionView(title: "Privacy & Security") {
                            SettingsRowView(
                                icon: "lock.shield",
                                title: "Privacy Settings",
                                subtitle: "Control who can see your content"
                            ) {
                                showPrivacySettings = true
                            }
                            
                            SettingsRowView(
                                icon: "eye.slash",
                                title: "Blocked Users",
                                subtitle: "Manage blocked accounts"
                            ) {
                                showBlockedUsers = true
                            }
                        }
                        
                        // Theme Quick Access
                        SettingsSectionView(title: "Appearance") {
                            ThemeQuickSwitcher()
                        }
                        
                        // Support Section
                        SettingsSectionView(title: "Support") {
                            SettingsRowView(
                                icon: "questionmark.circle",
                                title: "Help Center",
                                subtitle: "Get help and find answers"
                            ) {
                                showHelpCenter = true
                            }
                            
                            SettingsRowView(
                                icon: "envelope",
                                title: "Contact Us",
                                subtitle: "Send feedback or report issues"
                            ) {
                                showContactUs = true
                            }
                            
                            NavigationLink(destination: AboutView()) {
                                SettingsRowLinkView(
                                    icon: "info.circle",
                                    title: "About",
                                    subtitle: "App version and information"
                                )
                            }
                        }
                        
                        // Legal Section
                        SettingsSectionView(title: "Legal") {
                            NavigationLink(destination: TermsOfServiceView()) {
                                SettingsRowLinkView(
                                    icon: "doc.text",
                                    title: "Terms of Service",
                                    subtitle: "Read our terms and conditions"
                                )
                            }
                            
                            NavigationLink(destination: PrivacyPolicyView()) {
                                SettingsRowLinkView(
                                    icon: "hand.raised",
                                    title: "Privacy Policy",
                                    subtitle: "How we handle your data"
                                )
                            }
                        }
                        
                        // Account Actions
                        SettingsSectionView(title: "Account Actions") {
                            Button(action: {
                                HapticManager.shared.impact(.medium)
                                showLogoutConfirmation = true
                            }) {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(Color.error.opacity(0.1))
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.error)
                                        )
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Log Out")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.error)
                                        
                                        Text("Sign out of your account")
                                            .font(.caption)
                                            .foregroundColor(.appSecondaryText)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 20)
                                .background(Color.appCardBackground)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: {
                                HapticManager.shared.impact(.heavy)
                                showDeleteAccountSheet = true
                            }) {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(Color.error.opacity(0.15))
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Image(systemName: "trash.fill")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.error)
                                        )
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Delete Account")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.error)
                                        
                                        Text("Permanently delete your account")
                                            .font(.caption)
                                            .foregroundColor(.appSecondaryText)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 20)
                                .background(Color.appCardBackground)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    Spacer(minLength: 100)
                }
            }
            .background(Color.appBackground)
            .scrollContentBackground(.hidden)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        HapticManager.shared.impact(.light)
                        dismiss()
                    }
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryBrand)
                }
                #else
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        HapticManager.shared.impact(.light)
                        dismiss()
                    }
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryBrand)
                }
                #endif
            }
        }
        .background(Color.appBackground)
        .sheet(isPresented: $showProfileEdit) {
            if appState.currentUser != nil {
                EditProfileView(viewModel: ProfileViewModel())
            }
        }
        .sheet(isPresented: $showNotificationSettings) {
            NotificationPreferencesView()
        }
        .sheet(isPresented: $showPrivacySettings) {
            Text("Privacy settings coming soon")
                .padding()
        }
        .sheet(isPresented: $showBlockedUsers) {
            BlockedUsersView()
        }
        .sheet(isPresented: $showHelpCenter) {
            HelpSupportView()
        }
        .sheet(isPresented: $showContactUs) {
            ContactSupportView()
        }
        .alert("Log Out", isPresented: $showLogoutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Log Out", role: .destructive) {
                Task {
                    try? await clerk.signOut()
                    dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to log out of your account?")
        }
        .sheet(isPresented: $showDeleteAccountSheet) {
            DeleteAccountConfirmationView(
                isDeleting: $isDeleting,
                deleteError: $deleteError,
                onDelete: {
                    Task {
                        await deleteAccount()
                    }
                },
                onCancel: {
                    showDeleteAccountSheet = false
                }
            )
            .environmentObject(appState)
        }
        .alert("Error", isPresented: .init(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(deleteError ?? "An error occurred")
        }
    }
    
    private func deleteAccount() async {
        isDeleting = true
        deleteError = nil
        
        do {
            // Delete account from backend
            _ = try await BackendService.shared.deleteAccount()
            
            // Sign out from Clerk
            try? await clerk.signOut()
            
            await MainActor.run {
                isDeleting = false
                showDeleteAccountSheet = false
                appState.isAuthenticated = false
                appState.currentUser = nil
                dismiss()
            }
        } catch {
            await MainActor.run {
                isDeleting = false
                deleteError = error.localizedDescription
            }
        }
    }
}

// MARK: - Delete Account Confirmation View
struct DeleteAccountConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    
    @Binding var isDeleting: Bool
    @Binding var deleteError: String?
    let onDelete: () -> Void
    let onCancel: () -> Void
    
    @State private var confirmationText = ""
    @FocusState private var isTextFieldFocused: Bool
    
    private let confirmationPhrase = "DELETE"
    
    private var canDelete: Bool {
        confirmationText.uppercased() == confirmationPhrase && !isDeleting
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Warning Icon
                    VStack(spacing: 16) {
                        Circle()
                            .fill(Color.error.opacity(0.15))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.error)
                            )
                        
                        Text("Delete Account")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.appPrimaryText)
                        
                        Text("This action cannot be undone")
                            .font(.subheadline)
                            .foregroundColor(.error)
                            .fontWeight(.medium)
                    }
                    .padding(.top, 20)
                    
                    // Warning Message
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What will be deleted:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.appPrimaryText)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            DeleteWarningRow(text: "All your posts and content")
                            DeleteWarningRow(text: "Your profile information")
                            DeleteWarningRow(text: "All comments and reactions")
                            DeleteWarningRow(text: "Your friends and followers")
                            DeleteWarningRow(text: "All messages and conversations")
                            DeleteWarningRow(text: "Bookmarks and saved items")
                        }
                    }
                    .padding(16)
                    .background(Color.error.opacity(0.08))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    
                    // Confirmation Input
                    VStack(alignment: .leading, spacing: 12) {
                        Text("To confirm, type \"\(confirmationPhrase)\" below:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.appPrimaryText)
                        
                        TextField("Type \(confirmationPhrase) to confirm", text: $confirmationText)
                            .textFieldStyle(.plain)
                            .padding(16)
                            .background(Color.appCardBackground)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        confirmationText.isEmpty ? Color.appSecondaryText.opacity(0.3) :
                                            (canDelete ? Color.error : Color.appSecondaryText.opacity(0.5)),
                                        lineWidth: 1.5
                                    )
                            )
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.characters)
                            .focused($isTextFieldFocused)
                    }
                    .padding(.horizontal, 20)
                    
                    // Delete Button
                    Button(action: {
                        HapticManager.shared.impact(.warning)
                        onDelete()
                    }) {
                        HStack(spacing: 8) {
                            if isDeleting {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.9)
                            } else {
                                Image(systemName: "trash.fill")
                            }
                            Text(isDeleting ? "Deleting..." : "Delete My Account")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canDelete ? Color.error : Color.error.opacity(0.4))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!canDelete)
                    .padding(.horizontal, 20)
                    
                    // Cancel Button
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        onCancel()
                    }) {
                        Text("Cancel")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primaryBrand)
                    }
                    .disabled(isDeleting)
                    
                    Spacer(minLength: 40)
                }
            }
            .background(Color.appBackground)
            .scrollContentBackground(.hidden)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        onCancel()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.appSecondaryText)
                    }
                    .disabled(isDeleting)
                }
                #endif
            }
            .interactiveDismissDisabled(isDeleting)
        }
    }
}

// MARK: - Delete Warning Row
struct DeleteWarningRow: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(.error.opacity(0.8))
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.appPrimaryText.opacity(0.9))
        }
    }
}

// MARK: - Settings Section View
struct SettingsSectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.appSecondaryText)
                .padding(.horizontal, 20)
            
            VStack(spacing: 0) {
                content
            }
            .background(Color.appCardBackground)
        }
    }
}

// MARK: - Settings Row View
struct SettingsRowView: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(.light)
            action()
        }) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.matchaGreen.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primaryBrand)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.appPrimaryText)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.appSecondaryText)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.warmAccentText)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Settings Row Link View (for NavigationLink)
struct SettingsRowLinkView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.matchaGreen.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primaryBrand)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.appPrimaryText)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.appSecondaryText)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.warmAccentText)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 20)
        .background(Color.appCardBackground)
    }
}

// MARK: - Theme Quick Switcher
struct ThemeQuickSwitcher: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.matchaGreen.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "paintbrush.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primaryBrand)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text("App Theme")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.appPrimaryText)
                
                Text("Choose your preferred theme")
                    .font(.caption)
                    .foregroundColor(.appSecondaryText)
            }
            
            Spacer()
            
            Picker("Theme", selection: $themeManager.currentTheme) {
                Text("Light").tag(ThemeManager.Theme.light)
                Text("Dark").tag(ThemeManager.Theme.dark)
                Text("Auto").tag(ThemeManager.Theme.system)
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(width: 120)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 20)
    }
}

// MARK: - Settings Views

struct NotificationPreferencesView: View {
    @State private var pushNotifications = true
    @State private var emailNotifications = false
    @State private var commentNotifications = true
    @State private var likeNotifications = true
    @State private var followNotifications = true
    @State private var messageNotifications = true
    
    var body: some View {
        Form {
            Section("Push Notifications") {
                Toggle("Enable Push Notifications", isOn: $pushNotifications)
                
                if pushNotifications {
                    Toggle("Comments", isOn: $commentNotifications)
                    Toggle("Likes", isOn: $likeNotifications)
                    Toggle("New Followers", isOn: $followNotifications)
                    Toggle("Messages", isOn: $messageNotifications)
                }
            }
            
            Section("Email Notifications") {
                Toggle("Weekly Digest", isOn: $emailNotifications)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}



struct BlockedUsersView: View {
    @State private var blockedUsers: [User] = []
    @State private var isLoading = false
    
    var body: some View {
        List {
            if isLoading {
                ForEach(0..<3, id: \.self) { _ in
                    HStack {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 40, height: 40)
                        
                        VStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 16)
                                .frame(maxWidth: 120)
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 12)
                                .frame(maxWidth: 80)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            } else if blockedUsers.isEmpty {
                VStack {
                    Image(systemName: "person.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("No Blocked Users")
                        .font(.headline)
                        .padding(.top, 8)
                    Text("Users you block will appear here")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(blockedUsers) { user in
                    HStack {
                        UserAvatar(user: user, size: 40)
                        
                        VStack(alignment: .leading) {
                            Text(user.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("@\(user.username)")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                        
                        Spacer()
                        
                        Button("Unblock") {
                            unblockUser(user)
                        }
                        .font(.caption)
                        .foregroundColor(.primaryBrand)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Blocked Users")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadBlockedUsers()
        }
    }
    
    private func loadBlockedUsers() async {
        isLoading = true
        
        // TODO: Load blocked users from backend
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        isLoading = false
        blockedUsers = [] // Empty for now
    }
    
    private func unblockUser(_ user: User) {
        // TODO: Unblock user via backend
        blockedUsers.removeAll { $0.id == user.id }
    }
}

struct HelpSupportView: View {
    var body: some View {
        List {
            Section {
                NavigationLink("FAQ") {
                    FAQView()
                }
                
                NavigationLink("Contact Support") {
                    ContactSupportView()
                }
                
                NavigationLink("Report a Problem") {
                    ReportProblemView()
                }
            }
            
            Section("App Information") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondaryText)
                }
                
                HStack {
                    Text("Build")
                    Spacer()
                    Text("2025.1.1")
                        .foregroundColor(.secondaryText)
                }
            }
        }
        .navigationTitle("Help & Support")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ContactSupportView: View {
    @State private var subject = ""
    @State private var message = ""
    @State private var isSubmitting = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Contact Information") {
                    TextField("Subject", text: $subject)
                    
                    TextField("Message", text: $message, axis: .vertical)
                        .lineLimit(5...10)
                }
                
                Section {
                    Button("Send Message") {
                        submitSupportRequest()
                    }
                    .disabled(subject.isEmpty || message.isEmpty || isSubmitting)
                }
            }
            .navigationTitle("Contact Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func submitSupportRequest() {
        isSubmitting = true
        
        // TODO: Submit support request to backend
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            await MainActor.run {
                isSubmitting = false
                dismiss()
            }
        }
    }
}

struct FAQView: View {
    let faqs = [
        FAQ(question: "How do I create a post?", answer: "Tap the + button on the home screen, select your photos, add a caption and location, then tap 'Share'."),
        FAQ(question: "How do I find friends?", answer: "Go to the Search tab and search for friends by username or email. You can also import contacts."),
        FAQ(question: "How do I save posts?", answer: "Tap the bookmark icon on any post to save it to your Saved collection."),
        FAQ(question: "How do I report inappropriate content?", answer: "Tap the three dots menu on any post and select 'Report'. Choose the reason and submit."),
        FAQ(question: "How do I change my privacy settings?", answer: "Go to Profile > Settings > Privacy to control who can see your content and contact you.")
    ]
    
    var body: some View {
        List(faqs) { faq in
            DisclosureGroup(faq.question) {
                Text(faq.answer)
                    .font(.body)
                    .foregroundColor(.secondaryText)
                    .padding(.top, 8)
            }
        }
        .navigationTitle("FAQ")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FAQ: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
}

struct ReportProblemView: View {
    @State private var problemType = "Bug Report"
    @State private var description = ""
    @State private var isSubmitting = false
    @Environment(\.dismiss) private var dismiss
    
    let problemTypes = ["Bug Report", "Feature Request", "Account Issue", "Content Issue", "Other"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Problem Type") {
                    Picker("Type", selection: $problemType) {
                        ForEach(problemTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section("Description") {
                    TextField("Describe the problem...", text: $description, axis: .vertical)
                        .lineLimit(5...10)
                }
                
                Section {
                    Button("Submit Report") {
                        submitProblemReport()
                    }
                    .disabled(description.isEmpty || isSubmitting)
                }
            }
            .navigationTitle("Report Problem")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func submitProblemReport() {
        isSubmitting = true
        
        // TODO: Submit problem report to backend
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            await MainActor.run {
                isSubmitting = false
                dismiss()
            }
        }
    }
}



// MARK: - Missing Helper Views

// MARK: - Sheet Presentation Modifier
struct SheetPresentationModifier: ViewModifier {
    @Binding var showSettings: Bool
    @Binding var showEditProfile: Bool
    @Binding var showAdminSettings: Bool
    @Binding var showFollowersSheet: Bool
    @Binding var showFollowingSheet: Bool
    let viewModel: ProfileViewModel
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView(viewModel: viewModel)
            }
            .sheet(isPresented: $showAdminSettings) {
                AdminSettingsView(profileViewModel: viewModel)
            }
            .sheet(isPresented: $showFollowersSheet) {
                if let user = viewModel.currentUser,
                   let clerkId = user.clerkId {
                    FollowersListView(
                        userId: clerkId,
                        userName: user.displayName
                    )
                }
            }
            .sheet(isPresented: $showFollowingSheet) {
                if let user = viewModel.currentUser,
                   let clerkId = user.clerkId {
                    FollowingListView(
                        userId: clerkId,
                        userName: user.displayName
                    )
                }
            }
    }
}



// MARK: - Invite View
struct InviteView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 50))
                    .foregroundColor(.primaryBrand)
                
                Text("Invite Friends")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Share Palytt with your friends!")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
            }
            .padding()
            .navigationTitle("Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - SwiftUI Previews

#Preview("Current User Profile") {
    NavigationView {
        ProfileView()
            .environmentObject(AppState.createForPreview())
            .environmentObject(ThemeManager())
    }
}

#Preview("Other User Profile") {
    NavigationView {
        ProfileView(targetUser: MockData.previewUser)
            .environmentObject(AppState.createForPreview())
            .environmentObject(ThemeManager())
    }
}

#Preview("Admin User Profile") {
    NavigationView {
        ProfileView(targetUser: MockData.adminUser)
            .environmentObject(AppState.createForPreview())
            .environmentObject(ThemeManager())
    }
}

#Preview("Food Photographer Profile") {
    NavigationView {
        ProfileView(targetUser: MockData.previewUser)
            .environmentObject(AppState.createForPreview())
            .environmentObject(ThemeManager())
    }
}

#Preview("Profile - Dark Mode") {
    NavigationView {
        ProfileView(targetUser: MockData.previewUser)
            .environmentObject(AppState.createForPreview())
            .environmentObject(ThemeManager())
    }
    .preferredColorScheme(.dark)
}

#Preview("Profile - Loading State") {
    NavigationView {
        ProfileView(mockViewModel: ProfileViewModelLoadingPreview())
            .environmentObject(AppState.createForPreview())
            .environmentObject(ThemeManager())
    }
}

#Preview("Profile - Error State") {
    NavigationView {
        ProfileView(mockViewModel: ProfileViewModelErrorPreview())
            .environmentObject(AppState.createForPreview())
            .environmentObject(ThemeManager())
    }
}

// MARK: - Preview Helper ViewModels
@MainActor
class ProfileViewModelLoadingPreview: ProfileViewModel {
    override init() {
        super.init()
        DispatchQueue.main.async {
            self.isLoading = true
            self.currentUser = nil
            self.userPosts = []
            self.errorMessage = nil
        }
    }
}

@MainActor
class ProfileViewModelErrorPreview: ProfileViewModel {
    override init() {
        super.init()
        DispatchQueue.main.async {
            self.isLoading = false
            self.currentUser = nil
            self.userPosts = []
            self.errorMessage = "Failed to load profile. Please check your internet connection and try again."
        }
    }
}
