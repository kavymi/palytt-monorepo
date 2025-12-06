//
//  SocialListViews.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI

// MARK: - Shared Components for Social Features

// MARK: - User Row View
struct UserRowView: View {
    let user: BackendUser
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationLink(destination: ProfileView(targetUser: user.toUser())) {
            HStack(spacing: 12) {
                // Profile image
                BackendUserAvatar(user: user, size: 44)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName ?? user.username ?? "Unknown User")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                        .lineLimit(1)
                    
                    Text("@\(user.username ?? "unknown")")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .lineLimit(1)
                    
                    if let bio = user.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.caption)
                            .foregroundColor(.tertiaryText)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Quick follow button for current user's lists
                if user.clerkId != appState.currentUser?.clerkId {
                    QuickFollowButton(targetUser: user.toUser())
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Quick Follow Button
struct QuickFollowButton: View {
    let targetUser: User
    @StateObject private var viewModel = QuickFollowViewModel()
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Button(action: {
            Task {
                await toggleFollow()
            }
        }) {
            Text(viewModel.isFollowing ? "Following" : "Follow")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(viewModel.isFollowing ? .white : .primaryBrand)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(viewModel.isFollowing ? Color.primaryBrand : Color.clear)
                        .stroke(Color.primaryBrand, lineWidth: 1)
                )
        }
        .disabled(viewModel.isLoading)
        .onAppear {
            Task {
                await loadFollowStatus()
            }
        }
    }
    
    private func loadFollowStatus() async {
        guard let currentUser = appState.currentUser,
              let currentUserClerkId = currentUser.clerkId,
              let targetUserClerkId = targetUser.clerkId else { return }
        await viewModel.loadFollowStatus(
            currentUserId: currentUserClerkId,
            targetUserId: targetUserClerkId
        )
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
}

// MARK: - Social List ViewModel
@MainActor
class SocialListViewModel: ObservableObject {
    @Published var users: [BackendUser] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasMore = true
    
    private let backendService = BackendService.shared
    private var currentPage = 1
    private let pageSize = 20
    private var currentUserId: String?
    private var listType: ListType = .followers
    
    enum ListType {
        case followers
        case following
    }
    
    func loadFollowers(for userId: String) async {
        currentUserId = userId
        listType = .followers
        await loadUsers()
    }
    
    func loadFollowing(for userId: String) async {
        currentUserId = userId
        listType = .following
        await loadUsers()
    }
    
    func refresh() async {
        currentPage = 1
        hasMore = true
        users = []
        await loadUsers()
    }
    
    func loadMore() async {
        guard hasMore && !isLoading else { return }
        currentPage += 1
        await loadUsers()
    }
    
    private func loadUsers() async {
        guard let userId = currentUserId else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let newUsers: [BackendUser]
            
            switch listType {
            case .followers:
                newUsers = try await backendService.getFollowers(
                    userId: userId,
                    limit: pageSize
                )
            case .following:
                newUsers = try await backendService.getFollowing(
                    userId: userId,
                    limit: pageSize
                )
            }
            
            if currentPage == 1 {
                users = newUsers
            } else {
                users.append(contentsOf: newUsers)
            }
            
            hasMore = newUsers.count == pageSize
            
        } catch {
            errorMessage = "Failed to load users: \(error.localizedDescription)"
            print("❌ Error loading users: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - Quick Follow ViewModel
@MainActor
class QuickFollowViewModel: ObservableObject {
    @Published var isFollowing = false
    @Published var isLoading = false
    
    private let backendService = BackendService.shared
    
    func loadFollowStatus(currentUserId: String, targetUserId: String) async {
        do {
            let response = try await backendService.isFollowing(
                followerId: currentUserId,
                followingId: targetUserId
            )
            isFollowing = response.isFollowing
        } catch {
            print("❌ Error loading follow status: \(error)")
        }
    }
    
    func followUser(followerId: String, followingId: String) async {
        isLoading = true
        
        do {
            _ = try await backendService.followUser(
                followerId: followerId,
                followingId: followingId
            )
            isFollowing = true
        } catch {
            print("❌ Error following user: \(error)")
        }
        
        isLoading = false
    }
    
    func unfollowUser(followerId: String, followingId: String) async {
        isLoading = true
        
        do {
            _ = try await backendService.unfollowUser(
                followerId: followerId,
                followingId: followingId
            )
            isFollowing = false
        } catch {
            print("❌ Error unfollowing user: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - Preview Data
#Preview {
    let mockUser = BackendUser(
        id: "user_123",
        userId: "user_123",
        clerkId: "user_123",
        email: "john@example.com",
        firstName: "John",
        lastName: "Doe",
        username: "johndoe",
        displayName: "John Doe",
        name: "John Doe",
        bio: "Food enthusiast and traveler",
        avatarUrl: nil,
        profileImage: nil,
        role: "user",
        appleId: nil,
        googleId: nil,
        dietaryPreferences: nil,
        followerCount: 150,
        followingCount: 200,
        postsCount: 5,
        isVerified: false,
        isActive: true,
        createdAt: .timestamp(Int(Date().timeIntervalSince1970 * 1000)),
        updatedAt: .timestamp(Int(Date().timeIntervalSince1970 * 1000))
    )
    
    VStack {
        UserRowView(user: mockUser)
        Spacer()
    }
    .environmentObject(MockAppState())
} 