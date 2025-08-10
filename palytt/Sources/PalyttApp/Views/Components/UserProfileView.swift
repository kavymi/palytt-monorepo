//
//  UserProfileView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI
import Kingfisher

struct UserProfileView: View {
    let user: User
    @StateObject private var viewModel = UserProfileViewModel()
    @State private var isFollowing = false
    @State private var showFollowButton = true
    @State private var showFollowersSheet = false
    @State private var showFollowingSheet = false
    
    var body: some View {
        ZStack {
            // Full screen background
            Color.background
                .ignoresSafeArea(.all)
            
            // Content
            ScrollView {
                VStack(spacing: 24) {
                    if viewModel.isLoading {
                        // Show skeleton loaders while loading
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
                    } else if let errorMessage = viewModel.errorMessage {
                        // Error State
                        VStack(spacing: 16) {
                            // Still show profile header even with error
                            UserProfileHeaderView(
                                user: user,
                                isFollowing: $isFollowing,
                                showFollowButton: showFollowButton
                            )
                            
                            // Error message for posts
                            VStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.largeTitle)
                                    .foregroundColor(.orange)
                                
                                Text("Unable to load posts")
                                    .font(.headline)
                                    .foregroundColor(.primaryText)
                                
                                Text(errorMessage)
                                    .font(.subheadline)
                                    .foregroundColor(.secondaryText)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                Button("Try Again") {
                                    Task {
                                        await viewModel.loadUserProfile(user: user)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding()
                        }
                    } else {
                        // Profile Header
                        UserProfileHeaderView(
                            user: user,
                            isFollowing: $isFollowing,
                            showFollowButton: showFollowButton
                        )
                        
                        // Stats
                        ProfileStatsView(
                            user: user,
                            showFollowersSheet: $showFollowersSheet,
                            showFollowingSheet: $showFollowingSheet
                        )
                        
                        // Dietary Preferences
                        if !user.dietaryPreferences.isEmpty {
                            // DietaryPreferencesView(preferences: user.dietaryPreferences)
                            Text("Dietary preferences: \(user.dietaryPreferences.map { $0.rawValue }.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Posts Grid
                        ProfilePostsGrid(posts: viewModel.userPosts)
                    }
                }
            }
        }
        .navigationTitle("@\(user.username)")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await viewModel.loadUserProfile(user: user)
            // TODO: Check if current user is following this user
        }
    }
}

// MARK: - User Profile Header View
struct UserProfileHeaderView: View {
    let user: User
    @Binding var isFollowing: Bool
    let showFollowButton: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Profile Picture
            if let avatarURL = user.avatarURL {
                KFImage(avatarURL)
                    .placeholder {
                        Circle()
                            .fill(LinearGradient.primaryGradient)
                            .frame(width: 100, height: 100)
                            .overlay(
                                Text(user.displayName.prefix(2).uppercased())
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
            } else {
                ZStack {
                    Circle()
                        .fill(LinearGradient.primaryGradient)
                        .frame(width: 100, height: 100)
                    
                    // Subtle logo watermark
                    Image("palytt-logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                        .opacity(0.3)
                        .offset(x: 25, y: 25)
                    
                    // User initials
                    Text(user.displayName.prefix(2).uppercased())
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            
            VStack(spacing: 8) {
                Text("@\(user.username)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
                
                if let bio = user.bio {
                    Text(bio)
                        .font(.subheadline)
                        .foregroundColor(.primaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            
            if showFollowButton {
                Button(action: {
                    HapticManager.shared.impact(.light)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isFollowing.toggle()
                    }
                    // TODO: Implement follow/unfollow API call
                }) {
                    Text(isFollowing ? "Following" : "Follow")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(isFollowing ? .primaryText : .white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(isFollowing ? Color.clear : Color.primaryBrand)
                                .stroke(Color.primaryBrand, lineWidth: isFollowing ? 1.5 : 0)
                        )
                }
                .scaleEffect(isFollowing ? 0.95 : 1.0)
            }
        }
        .padding()
    }
}

// MARK: - User Profile View Model
@MainActor
class UserProfileViewModel: ObservableObject {
    @Published var userPosts: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let backendService = BackendService.shared
    
    func loadUserProfile(user: User) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Use clerkId if available, otherwise fall back to userId string
            let userIdToQuery = user.clerkId ?? user.id.uuidString
            
            // Fetch posts from backend
            let backendPosts = try await backendService.getPostsByUser(userId: userIdToQuery)
            
            // Convert backend posts to Post objects
            let convertedPosts = await convertBackendPosts(backendPosts, defaultAuthor: user)
            
            await MainActor.run {
                self.userPosts = convertedPosts
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load user posts: \(error.localizedDescription)"
                self.userPosts = []
                self.isLoading = false
            }
            print("❌ Failed to load user posts: \(error)")
        }
    }
    
    private func convertBackendPosts(_ backendPosts: [BackendService.BackendPost], defaultAuthor: User) async -> [Post] {
        var convertedPosts: [Post] = []
        
        for backendPost in backendPosts {
            // Try to get author information from backend, or use the default author
            var author: User = defaultAuthor
            
            // If the backend post has different author info, try to fetch it
            if backendPost.authorClerkId != defaultAuthor.clerkId {
                do {
                    let backendAuthor = try await backendService.getUserByClerkId(clerkId: backendPost.authorClerkId)
                    author = backendAuthor.toUser()
                } catch {
                    print("⚠️ Failed to get author info for post \(backendPost.id): \(error)")
                    // Will fall back to using default author
                }
            }
            
            let post = Post.from(backendPost: backendPost, author: author)
            convertedPosts.append(post)
        }
        
        return convertedPosts
    }
}

#Preview("User Profile - Maya Rodriguez") {
    NavigationStack {
        UserProfileView(user: MockData.previewUser)
    }
}

#Preview("User Profile - Jamie Park") {
    NavigationStack {
        UserProfileView(user: MockData.sampleUsers[0])
    }
}

#Preview("User Profile - With Dietary Preferences") {
    NavigationStack {
        UserProfileView(user: MockData.sampleUsers[3])
    }
} 