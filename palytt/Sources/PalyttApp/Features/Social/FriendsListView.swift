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
                            FriendRowView(user: user)
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
                
                // Friend indicator
                HStack(spacing: 4) {
                    Image(systemName: "person.2.circle.fill")
                        .font(.caption)
                        .foregroundColor(.primaryBrand)
                    
                    Text("Friend")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primaryBrand)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primaryBrand.opacity(0.1))
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
        } catch {
            errorMessage = "Failed to load friends: \(error.localizedDescription)"
            print("❌ Error loading friends: \(error)")
        }
        
        isLoading = false
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
            bio: "Food enthusiast and traveler",
            avatarUrl: nil,
            role: "user",
            appleId: nil,
            googleId: nil,
            dietaryPreferences: nil,
            followersCount: 150,
            followingCount: 200,
            postsCount: 5,
            isVerified: false,
            isActive: true,
            createdAt: Int(Date().timeIntervalSince1970 * 1000),
            updatedAt: Int(Date().timeIntervalSince1970 * 1000)
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
            bio: "Culinary explorer",
            avatarUrl: nil,
            role: "user",
            appleId: nil,
            googleId: nil,
            dietaryPreferences: nil,
            followersCount: 300,
            followingCount: 180,
            postsCount: 8,
            isVerified: true,
            isActive: true,
            createdAt: Int(Date().timeIntervalSince1970 * 1000),
            updatedAt: Int(Date().timeIntervalSince1970 * 1000)
        )
    ]
    
    FriendsListView(userId: "user_123", userName: "John Doe")
        .environmentObject(MockAppState())
} 