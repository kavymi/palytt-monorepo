//
//  FriendsListView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI

// MARK: - Friends List View
struct FriendsListView: View {
    let userId: String
    let userName: String
    @StateObject private var viewModel = FriendsViewModel()
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.isLoading && viewModel.friends.isEmpty {
                    // Loading state
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading friends...")
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.friends.isEmpty && !viewModel.isLoading {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.tertiaryText)
                        
                        Text("No Friends Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primaryText)
                        
                        Text("Friends are people who follow each other. When \(userName) has mutual connections, they'll appear here.")
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Friends list
                    List {
                        ForEach(viewModel.friends, id: \.clerkId) { user in
                            FriendRowView(
                                user: user,
                                presenceStatus: viewModel.getPresenceStatus(for: user.clerkId)
                            )
                            .listRowBackground(Color.cardBackground)
                            .listRowSeparatorTint(Color.divider)
                        }
                        
                        // Load more indicator
                        if viewModel.hasMore && !viewModel.isLoading {
                            HStack {
                                Spacer()
                                Button("Load More") {
                                    Task {
                                        await viewModel.loadMore()
                                    }
                                }
                                .font(.subheadline)
                                .foregroundColor(.primaryBrand)
                                Spacer()
                            }
                            .listRowBackground(Color.clear)
                        } else if viewModel.isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(0.8)
                                Spacer()
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(PlainListStyle())
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
                
                // Error message
                if let errorMessage = viewModel.errorMessage {
                    VStack(spacing: 12) {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                        
                        Button("Try Again") {
                            Task {
                                await viewModel.loadFriends(for: userId)
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.primaryBrand)
                    }
                    .padding()
                    .background(Color.cardBackground)
                }
            }
            .navigationTitle("Friends")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.primaryBrand)
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.primaryBrand)
                }
                #endif
            }
            .background(Color.background)
        }
        .task {
            await viewModel.loadFriends(for: userId)
        }
    }
}

// MARK: - Friend Row View
struct FriendRowView: View {
    let user: BackendUser
    var presenceStatus: PresenceStatus? = nil // Optional Convex presence status
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationLink(destination: ProfileView(targetUser: user.toUser())) {
            HStack(spacing: 12) {
                // Profile image with presence indicator
                ZStack(alignment: .bottomTrailing) {
                    BackendUserAvatar(user: user, size: 44)
                    
                    // Online status indicator (Convex presence)
                    if let status = presenceStatus, status != .offline {
                        PresenceIndicatorView(status: status, size: 12)
                            .offset(x: 2, y: 2)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(user.displayName ?? user.username ?? "Unknown User")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primaryText)
                            .lineLimit(1)
                        
                        // Subtle online indicator text
                        if let status = presenceStatus, status == .online {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    
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
                
                // Friend indicator with online status
                HStack(spacing: 4) {
                    Image(systemName: "person.2.circle.fill")
                        .font(.caption)
                        .foregroundColor(.primaryBrand)
                    
                    if let status = presenceStatus, status == .online {
                        Text("Online")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    } else {
                        Text("Friend")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primaryBrand)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(presenceStatus == .online ? Color.green.opacity(0.1) : Color.primaryBrand.opacity(0.1))
                .cornerRadius(8)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Friends ViewModel
@MainActor
class FriendsViewModel: ObservableObject {
    @Published var friends: [BackendUser] = []
    @Published var friendPresence: [String: PresenceStatus] = [:] // clerkId -> status
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasMore = true
    
    private let backendService = BackendService.shared
    private var currentPage = 1
    private let pageSize = 20
    private var currentUserId: String?
    
    func loadFriends(for userId: String) async {
        currentUserId = userId
        currentPage = 1
        hasMore = true
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Get mutual connections (friends)
            let friendsData = try await backendService.getFriends(
                userId: userId,
                limit: pageSize
            )
            friends = friendsData
            hasMore = friendsData.count == pageSize
            
            // Subscribe to presence for all friends via Convex
            subscribeToFriendsPresence()
            
        } catch {
            errorMessage = "Failed to load friends: \(error.localizedDescription)"
            print("❌ Error loading friends: \(error)")
        }
        
        isLoading = false
    }
    
    /// Subscribe to presence updates for all friends using Convex
    private func subscribeToFriendsPresence() {
        let friendClerkIds = friends.compactMap { $0.clerkId }
        guard !friendClerkIds.isEmpty else { return }
        
        // Subscribe via BackendService (which uses PresenceService internally)
        BackendService.shared.subscribeToFriendPresence(friendIds: friendClerkIds)
        
        // Load initial presence data
        Task {
            let presenceData = await BackendService.shared.getBatchPresence(clerkIds: friendClerkIds)
            await MainActor.run {
                self.friendPresence = presenceData
            }
        }
        
        print("🟢 FriendsViewModel: Subscribed to presence for \(friendClerkIds.count) friends")
    }
    
    /// Get presence status for a specific friend
    func getPresenceStatus(for clerkId: String) -> PresenceStatus {
        // First check our local cache
        if let status = friendPresence[clerkId] {
            return status
        }
        
        // Then check PresenceService's online friends
        if let presence = PresenceService.shared.onlineFriends[clerkId] {
            return presence.status
        }
        
        return .offline
    }
    
    func refresh() async {
        guard let userId = currentUserId else { return }
        await loadFriends(for: userId)
    }
    
    func loadMore() async {
        guard hasMore && !isLoading, let userId = currentUserId else { return }
        
        currentPage += 1
        isLoading = true
        
        do {
            let newFriends = try await backendService.getFriends(
                userId: userId,
                limit: pageSize
            )
            
            friends.append(contentsOf: newFriends)
            hasMore = newFriends.count == pageSize
            
            // Also subscribe to new friends' presence
            if !newFriends.isEmpty {
                subscribeToFriendsPresence()
            }
            
        } catch {
            errorMessage = "Failed to load more friends: \(error.localizedDescription)"
            currentPage -= 1 // Revert page increment
            print("❌ Error loading more friends: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - Preview Data
#Preview {
    let _ = [
        BackendUser(
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
        ),
        BackendUser(
            id: "user_456",
            userId: "user_456",
            clerkId: "user_456",
            email: "jane@example.com",
            firstName: "Jane",
            lastName: "Doe",
            username: "janedoe",
            displayName: "Jane Doe",
            name: "Jane Doe",
            bio: "Culinary explorer",
            avatarUrl: nil,
            profileImage: nil,
            role: "user",
            appleId: nil,
            googleId: nil,
            dietaryPreferences: nil,
            followerCount: 300,
            followingCount: 180,
            postsCount: 8,
            isVerified: true,
            isActive: true,
            createdAt: .timestamp(Int(Date().timeIntervalSince1970 * 1000)),
            updatedAt: .timestamp(Int(Date().timeIntervalSince1970 * 1000))
        )
    ]
    
    FriendsListView(userId: "user_123", userName: "John Doe")
        .environmentObject(MockAppState())
} 