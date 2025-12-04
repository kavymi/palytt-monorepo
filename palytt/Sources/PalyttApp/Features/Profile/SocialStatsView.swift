//
//  SocialStatsView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import SwiftUI

struct SocialStatsView: View {
    let user: User
    @StateObject private var viewModel = SocialStatsViewModel()
    @State private var showMutualFriends = false
    @State private var showAllFriends = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Mutual Friends Section
            if viewModel.mutualFriendsCount > 0 {
                mutualFriendsSection
            }
            
            // Social Stats Grid
            socialStatsGrid
            
            // Friends Quick Actions
            friendsQuickActions
        }
        .task {
            await viewModel.loadSocialStats(for: user)
        }
    }
    
    private var mutualFriendsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Mutual Friends")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                Spacer()
                
                if viewModel.mutualFriendsCount > 3 {
                    Button("See All") {
                        showMutualFriends = true
                    }
                    .font(.caption)
                    .foregroundColor(.primaryBrand)
                    .fontWeight(.medium)
                }
            }
            
            if viewModel.mutualFriends.isEmpty {
                Text("\(viewModel.mutualFriendsCount) mutual friends")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: min(3, viewModel.mutualFriends.count)), spacing: 12) {
                    ForEach(viewModel.mutualFriends.prefix(6), id: \.id) { friend in
                        VStack(spacing: 8) {
                            UserAvatar(user: friend, size: 60)
                            
                            Text(friend.firstName ?? friend.username ?? "Unknown")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.primaryText)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding()
        .background(Color.appCardBackground)
        .cornerRadius(16)
        .sheet(isPresented: $showMutualFriends) {
            MutualFriendsListView(user: user, mutualFriends: viewModel.mutualFriends)
        }
    }
    
    private var socialStatsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
            // Friends Count
            SocialStatCard(
                icon: "person.2.fill",
                title: "Friends",
                value: "\(user.friendsCount)",
                subtitle: "Connected",
                color: .primaryBrand
            ) {
                showAllFriends = true
            }
            
            // Followers Count
            SocialStatCard(
                icon: "heart.fill",
                title: "Followers",
                value: "\(user.followersCount)",
                subtitle: "Following you",
                color: .orange
            )
            
            // Following Count
            SocialStatCard(
                icon: "person.fill.checkmark",
                title: "Following",
                value: "\(user.followingCount)",
                subtitle: "You follow",
                color: .green
            )
            
            // Mutual Connections
            SocialStatCard(
                icon: "link",
                title: "Connections",
                value: "\(viewModel.mutualFriendsCount)",
                subtitle: "In common",
                color: .purple
            ) {
                if viewModel.mutualFriendsCount > 0 {
                    showMutualFriends = true
                }
            }
        }
        .sheet(isPresented: $showAllFriends) {
            FriendsView()
        }
    }
    
    private var friendsQuickActions: some View {
        VStack(spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 16) {
                ActionButton(
                    icon: "person.badge.plus",
                    title: "Add Friends",
                    color: .primaryBrand
                ) {
                    // Navigate to add friends
                }
                
                ActionButton(
                    icon: "paperplane.fill",
                    title: "Invite Friends",
                    color: .blue
                ) {
                    // Show invite view
                }
            }
        }
        .padding()
        .background(Color.appCardBackground)
        .cornerRadius(16)
    }
}

struct SocialStatCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let action: (() -> Void)?
    
    init(icon: String, title: String, value: String, subtitle: String, color: Color, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.color = color
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            action?()
        }) {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primaryText)
                    
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primaryText)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(Color.appCardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(action == nil)
    }
}

struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(color)
            .cornerRadius(25)
        }
    }
}

struct MutualFriendsListView: View {
    let user: User
    let mutualFriends: [User]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(mutualFriends, id: \.id) { friend in
                HStack(spacing: 12) {
                    UserAvatar(user: friend, size: 50)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(friend.displayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primaryText)
                        
                        Text("@\(friend.username ?? "unknown")")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                    
                    Spacer()
                    
                    Button("View") {
                        // Navigate to friend's profile
                    }
                    .font(.caption)
                    .foregroundColor(.primaryBrand)
                    .fontWeight(.medium)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Mutual Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

@MainActor
class SocialStatsViewModel: ObservableObject {
    @Published var mutualFriends: [User] = []
    @Published var mutualFriendsCount = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let backendService = BackendService.shared
    
    func loadSocialStats(for user: User) async {
        // Only load mutual friends if viewing another user's profile
        guard let currentUserId = getCurrentUserId(),
              user.clerkId != currentUserId else {
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await backendService.getMutualFriends(
                between: currentUserId,
                and: user.clerkId,
                limit: 20
            )
            
            mutualFriendsCount = response.totalCount
            mutualFriends = response.mutualFriends.map { backendUser in
                User(
                    id: UUID(),
                    clerkId: backendUser.clerkId,
                    username: backendUser.username,
                    firstName: backendUser.firstName,
                    lastName: backendUser.lastName,
                    displayName: backendUser.displayName,
                    bio: backendUser.bio,
                    profileImageURL: backendUser.avatarUrl != nil ? URL(string: backendUser.avatarUrl!) : nil,
                    email: backendUser.email,
                    createdAt: Date(),
                    dietaryPreferences: backendUser.dietaryPreferences ?? [],
                    friendsCount: 0,
                    followersCount: backendUser.followersCount,
                    followingCount: backendUser.followingCount,
                    postsCount: backendUser.postsCount
                )
            }
        } catch {
            errorMessage = "Failed to load mutual friends: \(error.localizedDescription)"
            print("❌ Failed to load mutual friends: \(error)")
        }
        
        isLoading = false
    }
    
    private func getCurrentUserId() -> String? {
        // TODO: Get current user ID from Clerk or app state
        // For now, return a placeholder
        return "current_user_id"
    }
}

#Preview {
    SocialStatsView(user: User.preview)
}
