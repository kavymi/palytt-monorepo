//
//  SocialActionsView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI

struct SocialActionsView: View {
    let targetUser: User
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = SocialActionsViewModel()
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Follow Button
                Button(action: {
                    Task {
                        await toggleFollow()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.isFollowing ? "person.fill.checkmark" : "person.badge.plus")
                            .font(.caption)
                        
                        Text(viewModel.isFollowing ? "Following" : "Follow")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(viewModel.isFollowing ? .white : .primaryBrand)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(viewModel.isFollowing ? Color.primaryBrand : Color.clear)
                            .stroke(Color.primaryBrand, lineWidth: 1)
                    )
                }
                .disabled(viewModel.isLoading)
                
                // Friend Button
                friendButton
            }
            
            // Error message
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
            
            // Friend request notification
            if let friendRequestMessage = viewModel.friendRequestMessage {
                Text(friendRequestMessage)
                    .font(.caption)
                    .foregroundColor(.green)
                    .multilineTextAlignment(.center)
            }
        }
        .onAppear {
            Task {
                await loadSocialStatus()
            }
        }
    }
    
    @ViewBuilder
    private var friendButton: some View {
        switch viewModel.friendStatus {
        case "none":
            Button(action: {
                Task {
                    await sendFriendRequest()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.badge.plus")
                        .font(.caption)
                    
                    Text("Add Friend")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.primaryBrand)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.primaryBrand, lineWidth: 1)
                )
            }
            .disabled(viewModel.isLoading)
            
        case "sent":
            Button(action: {
                // Show option to cancel request
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption)
                    
                    Text("Request Sent")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.orange, lineWidth: 1)
                )
            }
            .disabled(true)
            
        case "received":
            HStack(spacing: 8) {
                Button(action: {
                    Task {
                        await acceptFriendRequest()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.caption)
                        Text("Accept")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green)
                    .cornerRadius(16)
                }
                .disabled(viewModel.isLoading)
                
                Button(action: {
                    Task {
                        await rejectFriendRequest()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.caption)
                        Text("Decline")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red)
                    .cornerRadius(16)
                }
                .disabled(viewModel.isLoading)
            }
            
        case "friends":
            Button(action: {
                Task {
                    await removeFriend()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                    
                    Text("Friends")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.green)
                )
            }
            .disabled(viewModel.isLoading)
            
        default:
            EmptyView()
        }
    }
    
    private func loadSocialStatus() async {
        guard let currentUser = appState.currentUser,
              let currentUserId = currentUser.clerkId,
              let targetUserId = targetUser.clerkId else { return }
        await viewModel.loadSocialStatus(
            currentUserId: currentUserId,
            targetUserId: targetUserId
        )
    }
    
    private func toggleFollow() async {
        guard let currentUser = appState.currentUser,
              let currentUserId = currentUser.clerkId,
              let targetUserId = targetUser.clerkId else { return }
        
        if viewModel.isFollowing {
            await viewModel.unfollowUser(
                followerId: currentUserId,
                followingId: targetUserId
            )
        } else {
            await viewModel.followUser(
                followerId: currentUserId,
                followingId: targetUserId
            )
        }
    }
    
    private func sendFriendRequest() async {
        guard let currentUser = appState.currentUser,
              let senderId = currentUser.clerkId,
              let receiverId = targetUser.clerkId else { return }
        await viewModel.sendFriendRequest(
            senderId: senderId,
            receiverId: receiverId
        )
    }
    
    private func acceptFriendRequest() async {
        await viewModel.acceptFriendRequest()
    }
    
    private func rejectFriendRequest() async {
        await viewModel.rejectFriendRequest()
    }
    
    private func removeFriend() async {
        guard let currentUser = appState.currentUser,
              let userId1 = currentUser.clerkId,
              let userId2 = targetUser.clerkId else { return }
        await viewModel.removeFriend(
            userId1: userId1,
            userId2: userId2
        )
    }
}

@MainActor
class SocialActionsViewModel: ObservableObject {
    @Published var isFollowing = false
    @Published var friendStatus = "none" // "none", "sent", "received", "friends"
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var friendRequestMessage: String?
    
    private var currentFriendRequest: BackendService.FriendRequest?
    private let backendService = BackendService.shared
    
    func loadSocialStatus(currentUserId: String, targetUserId: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Check follow status
            let followResponse = try await backendService.isFollowing(
                followerId: currentUserId,
                followingId: targetUserId
            )
            isFollowing = followResponse.isFollowing
            
            // Check friend status
            let friendResponse = try await backendService.getFriendRequestStatus(
                userId1: currentUserId,
                userId2: targetUserId
            )
            friendStatus = friendResponse.status
            currentFriendRequest = friendResponse.request
            
        } catch {
            errorMessage = "Failed to load social status: \(error.localizedDescription)"
            print("❌ Error loading social status: \(error)")
        }
        
        isLoading = false
    }
    
    func followUser(followerId: String, followingId: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await backendService.followUser(
                followerId: followerId,
                followingId: followingId
            )
            isFollowing = true
        } catch {
            errorMessage = "Failed to follow user: \(error.localizedDescription)"
            print("❌ Error following user: \(error)")
        }
        
        isLoading = false
    }
    
    func unfollowUser(followerId: String, followingId: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await backendService.unfollowUser(
                followerId: followerId,
                followingId: followingId
            )
            isFollowing = false
        } catch {
            errorMessage = "Failed to unfollow user: \(error.localizedDescription)"
            print("❌ Error unfollowing user: \(error)")
        }
        
        isLoading = false
    }
    
    func sendFriendRequest(senderId: String, receiverId: String) async {
        isLoading = true
        errorMessage = nil
        friendRequestMessage = nil
        
        do {
            let response = try await backendService.sendFriendRequest(
                senderId: senderId,
                receiverId: receiverId
            )
            
            if response.message?.contains("automatically accepted") == true {
                friendStatus = "friends"
                friendRequestMessage = "You are now friends!"
            } else {
                friendStatus = "sent"
                friendRequestMessage = "Friend request sent!"
            }
            
            // Clear message after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.friendRequestMessage = nil
            }
            
        } catch {
            errorMessage = "Failed to send friend request: \(error.localizedDescription)"
            print("❌ Error sending friend request: \(error)")
        }
        
        isLoading = false
    }
    
    func acceptFriendRequest() async {
        guard let request = currentFriendRequest else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await backendService.acceptFriendRequest(requestId: request._id)
            friendStatus = "friends"
            friendRequestMessage = "Friend request accepted!"
            
            // Clear message after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.friendRequestMessage = nil
            }
            
        } catch {
            errorMessage = "Failed to accept friend request: \(error.localizedDescription)"
            print("❌ Error accepting friend request: \(error)")
        }
        
        isLoading = false
    }
    
    func rejectFriendRequest() async {
        guard let request = currentFriendRequest else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await backendService.rejectFriendRequest(requestId: request._id)
            friendStatus = "none"
            friendRequestMessage = "Friend request declined"
            
            // Clear message after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.friendRequestMessage = nil
            }
            
        } catch {
            errorMessage = "Failed to reject friend request: \(error.localizedDescription)"
            print("❌ Error rejecting friend request: \(error)")
        }
        
        isLoading = false
    }
    
    func removeFriend(userId1: String, userId2: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await backendService.removeFriend(userId1: userId1, userId2: userId2)
            friendStatus = "none"
            friendRequestMessage = "Friendship removed"
            
            // Clear message after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.friendRequestMessage = nil
            }
            
        } catch {
            errorMessage = "Failed to remove friend: \(error.localizedDescription)"
            print("❌ Error removing friend: \(error)")
        }
        
        isLoading = false
    }
} 