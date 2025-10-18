//
//  SocialService.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import Foundation

// MARK: - Protocol

protocol SocialServiceProtocol {
    // Follow/Unfollow
    func followUser(followerId: String, followingId: String) async throws -> Bool
    func unfollowUser(followerId: String, followingId: String) async throws -> Bool
    func isFollowing(followerId: String, followingId: String) async throws -> Bool
    func getFollowing(userId: String, limit: Int) async throws -> [User]
    func getFollowers(userId: String, limit: Int) async throws -> [User]
    func getFollowingPosts(userId: String, limit: Int) async throws -> [FollowingPost]
    
    // Friends
    func getFriends(userId: String, limit: Int) async throws -> [User]
    func getMutualFriends(userId1: String, userId2: String, limit: Int) async throws -> [User]
    func areFriends(userId1: String, userId2: String) async throws -> Bool
    
    // Friend Requests
    func sendFriendRequest(senderId: String, receiverId: String) async throws -> Bool
    func acceptFriendRequest(requestId: String) async throws -> Bool
    func rejectFriendRequest(requestId: String) async throws -> Bool
    func removeFriend(userId1: String, userId2: String) async throws -> Bool
    func getPendingFriendRequests(userId: String) async throws -> [FriendRequest]
    func getFriendRequestStatus(userId1: String, userId2: String) async throws -> String
    
    // Suggestions
    func getFriendSuggestions(limit: Int, excludeRequested: Bool) async throws -> [FriendSuggestion]
}

// MARK: - Service Implementation

@MainActor
final class SocialService: SocialServiceProtocol {
    
    private let apiClient: APIClientProtocol
    
    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }
    
    convenience init(baseURL: URL) {
        let apiClient = APIClient(baseURL: baseURL)
        self.init(apiClient: apiClient)
    }
    
    // MARK: - Follow/Unfollow
    
    func followUser(followerId: String, followingId: String) async throws -> Bool {
        print("👥 SocialService: Following user \(followingId)")
        
        let request = FollowRequest(followerId: followerId, followingId: followingId)
        
        let response = try await apiClient.request(
            path: "trpc/social.followUser",
            method: .post,
            parameters: request,
            responseType: FollowResponse.self
        )
        
        print("✅ SocialService: Successfully followed user")
        return response.success
    }
    
    func unfollowUser(followerId: String, followingId: String) async throws -> Bool {
        print("👥 SocialService: Unfollowing user \(followingId)")
        
        let request = FollowRequest(followerId: followerId, followingId: followingId)
        
        let response = try await apiClient.request(
            path: "trpc/social.unfollowUser",
            method: .post,
            parameters: request,
            responseType: FollowResponse.self
        )
        
        print("✅ SocialService: Successfully unfollowed user")
        return response.success
    }
    
    func isFollowing(followerId: String, followingId: String) async throws -> Bool {
        print("🔍 SocialService: Checking if user \(followerId) follows \(followingId)")
        
        let request = IsFollowingRequest(followerId: followerId, followingId: followingId)
        
        let response = try await apiClient.request(
            path: "trpc/social.isFollowing",
            method: .get,
            parameters: request,
            responseType: IsFollowingResponse.self
        )
        
        print("✅ SocialService: Is following: \(response.isFollowing)")
        return response.isFollowing
    }
    
    func getFollowing(userId: String, limit: Int = 50) async throws -> [User] {
        print("👥 SocialService: Getting following list for user \(userId)")
        
        let request = GetFollowListRequest(userId: userId, limit: limit)
        
        let response = try await apiClient.request(
            path: "trpc/social.getFollowing",
            method: .get,
            parameters: request,
            responseType: GetFollowListResponse.self
        )
        
        print("✅ SocialService: Got \(response.users.count) following")
        return response.users.map { User.from(userDTO: $0) }
    }
    
    func getFollowers(userId: String, limit: Int = 50) async throws -> [User] {
        print("👥 SocialService: Getting followers for user \(userId)")
        
        let request = GetFollowListRequest(userId: userId, limit: limit)
        
        let response = try await apiClient.request(
            path: "trpc/social.getFollowers",
            method: .get,
            parameters: request,
            responseType: GetFollowListResponse.self
        )
        
        print("✅ SocialService: Got \(response.users.count) followers")
        return response.users.map { User.from(userDTO: $0) }
    }
    
    func getFollowingPosts(userId: String, limit: Int = 100) async throws -> [FollowingPost] {
        print("📱 SocialService: Getting posts from following for user \(userId)")
        
        let request = GetFollowingPostsRequest(userId: userId, limit: limit)
        
        let response = try await apiClient.request(
            path: "trpc/social.getFollowingPosts",
            method: .get,
            parameters: request,
            responseType: GetFollowingPostsResponse.self
        )
        
        print("✅ SocialService: Got \(response.posts.count) posts from following")
        return response.posts.map { followingPostDTO in
            FollowingPost(
                post: Post.from(postResponseDTO: followingPostDTO.post),
                author: User.from(userDTO: followingPostDTO.author)
            )
        }
    }
    
    // MARK: - Friends
    
    func getFriends(userId: String, limit: Int = 50) async throws -> [User] {
        print("👥 SocialService: Getting friends for user \(userId)")
        
        let request = GetFriendsRequest(userId: userId, limit: limit)
        
        let response = try await apiClient.request(
            path: "trpc/social.getFriends",
            method: .get,
            parameters: request,
            responseType: GetFriendsResponse.self
        )
        
        print("✅ SocialService: Got \(response.friends.count) friends")
        return response.friends.map { User.from(userDTO: $0) }
    }
    
    func getMutualFriends(userId1: String, userId2: String, limit: Int = 10) async throws -> [User] {
        print("👥 SocialService: Getting mutual friends between \(userId1) and \(userId2)")
        
        let request = GetMutualFriendsRequest(userId1: userId1, userId2: userId2, limit: limit)
        
        let response = try await apiClient.request(
            path: "trpc/social.getMutualFriends",
            method: .get,
            parameters: request,
            responseType: MutualFriendsResponse.self
        )
        
        print("✅ SocialService: Found \(response.count) mutual friends")
        return response.mutualFriends.map { User.from(userDTO: $0) }
    }
    
    func areFriends(userId1: String, userId2: String) async throws -> Bool {
        print("🔍 SocialService: Checking if \(userId1) and \(userId2) are friends")
        
        let request = AreFriendsRequest(userId1: userId1, userId2: userId2)
        
        let response = try await apiClient.request(
            path: "trpc/social.areFriends",
            method: .get,
            parameters: request,
            responseType: AreFriendsResponse.self
        )
        
        print("✅ SocialService: Are friends: \(response.areFriends)")
        return response.areFriends
    }
    
    // MARK: - Friend Requests
    
    func sendFriendRequest(senderId: String, receiverId: String) async throws -> Bool {
        print("📨 SocialService: Sending friend request from \(senderId) to \(receiverId)")
        
        let request = SendFriendRequestRequest(senderId: senderId, receiverId: receiverId)
        
        let response = try await apiClient.request(
            path: "trpc/social.sendFriendRequest",
            method: .post,
            parameters: request,
            responseType: FriendRequestResponse.self
        )
        
        print("✅ SocialService: Friend request sent successfully")
        return response.success
    }
    
    func acceptFriendRequest(requestId: String) async throws -> Bool {
        print("✅ SocialService: Accepting friend request \(requestId)")
        
        let request = AcceptFriendRequestRequest(requestId: requestId)
        
        let response = try await apiClient.request(
            path: "trpc/social.acceptFriendRequest",
            method: .post,
            parameters: request,
            responseType: FriendRequestResponse.self
        )
        
        print("✅ SocialService: Friend request accepted")
        return response.success
    }
    
    func rejectFriendRequest(requestId: String) async throws -> Bool {
        print("❌ SocialService: Rejecting friend request \(requestId)")
        
        let request = RejectFriendRequestRequest(requestId: requestId)
        
        let response = try await apiClient.request(
            path: "trpc/social.rejectFriendRequest",
            method: .post,
            parameters: request,
            responseType: FriendRequestResponse.self
        )
        
        print("✅ SocialService: Friend request rejected")
        return response.success
    }
    
    func removeFriend(userId1: String, userId2: String) async throws -> Bool {
        print("💔 SocialService: Removing friendship between \(userId1) and \(userId2)")
        
        let request = RemoveFriendRequest(userId1: userId1, userId2: userId2)
        
        let response = try await apiClient.request(
            path: "trpc/social.removeFriend",
            method: .post,
            parameters: request,
            responseType: FriendRequestResponse.self
        )
        
        print("✅ SocialService: Friendship removed")
        return response.success
    }
    
    func getPendingFriendRequests(userId: String) async throws -> [FriendRequest] {
        print("📬 SocialService: Getting pending friend requests for \(userId)")
        
        let request = GetFriendRequestsRequest(userId: userId)
        
        let response = try await apiClient.request(
            path: "trpc/social.getPendingRequests",
            method: .get,
            parameters: request,
            responseType: GetFriendRequestsResponse.self
        )
        
        print("✅ SocialService: Found \(response.requests.count) pending requests")
        return response.requests.map { $0.toDomain() }
    }
    
    func getFriendRequestStatus(userId1: String, userId2: String) async throws -> String {
        print("🔍 SocialService: Getting friend request status between \(userId1) and \(userId2)")
        
        let request = FriendRequestStatusRequest(userId1: userId1, userId2: userId2)
        
        let response = try await apiClient.request(
            path: "trpc/social.getFriendRequestStatus",
            method: .get,
            parameters: request,
            responseType: FriendRequestStatusResponse.self
        )
        
        print("✅ SocialService: Status: \(response.status)")
        return response.status
    }
    
    // MARK: - Suggestions
    
    func getFriendSuggestions(limit: Int = 20, excludeRequested: Bool = true) async throws -> [FriendSuggestion] {
        print("💡 SocialService: Getting friend suggestions")
        
        let request = GetFriendSuggestionsRequest(limit: limit, excludeRequested: excludeRequested)
        
        let response = try await apiClient.request(
            path: "trpc/social.getFriendSuggestions",
            method: .get,
            parameters: request,
            responseType: FriendSuggestionsResponse.self
        )
        
        print("✅ SocialService: Got \(response.suggestions.count) friend suggestions")
        return response.suggestions.map { $0.toDomain() }
    }
}

// MARK: - Mock Implementation for Testing

#if DEBUG
final class MockSocialService: SocialServiceProtocol {
    var mockUsers: [User] = []
    var mockFollowingPosts: [FollowingPost] = []
    var mockFriendRequests: [FriendRequest] = []
    var mockFriendSuggestions: [FriendSuggestion] = []
    var shouldFail = false
    var mockError: APIError = .networkError(URLError(.notConnectedToInternet))
    var mockBoolResult = true
    var mockStatus = "none"
    
    func followUser(followerId: String, followingId: String) async throws -> Bool {
        if shouldFail { throw mockError }
        return mockBoolResult
    }
    
    func unfollowUser(followerId: String, followingId: String) async throws -> Bool {
        if shouldFail { throw mockError }
        return mockBoolResult
    }
    
    func isFollowing(followerId: String, followingId: String) async throws -> Bool {
        if shouldFail { throw mockError }
        return mockBoolResult
    }
    
    func getFollowing(userId: String, limit: Int) async throws -> [User] {
        if shouldFail { throw mockError }
        return mockUsers
    }
    
    func getFollowers(userId: String, limit: Int) async throws -> [User] {
        if shouldFail { throw mockError }
        return mockUsers
    }
    
    func getFollowingPosts(userId: String, limit: Int) async throws -> [FollowingPost] {
        if shouldFail { throw mockError }
        return mockFollowingPosts
    }
    
    func getFriends(userId: String, limit: Int) async throws -> [User] {
        if shouldFail { throw mockError }
        return mockUsers
    }
    
    func getMutualFriends(userId1: String, userId2: String, limit: Int) async throws -> [User] {
        if shouldFail { throw mockError }
        return mockUsers
    }
    
    func areFriends(userId1: String, userId2: String) async throws -> Bool {
        if shouldFail { throw mockError }
        return mockBoolResult
    }
    
    func sendFriendRequest(senderId: String, receiverId: String) async throws -> Bool {
        if shouldFail { throw mockError }
        return mockBoolResult
    }
    
    func acceptFriendRequest(requestId: String) async throws -> Bool {
        if shouldFail { throw mockError }
        return mockBoolResult
    }
    
    func rejectFriendRequest(requestId: String) async throws -> Bool {
        if shouldFail { throw mockError }
        return mockBoolResult
    }
    
    func removeFriend(userId1: String, userId2: String) async throws -> Bool {
        if shouldFail { throw mockError }
        return mockBoolResult
    }
    
    func getPendingFriendRequests(userId: String) async throws -> [FriendRequest] {
        if shouldFail { throw mockError }
        return mockFriendRequests
    }
    
    func getFriendRequestStatus(userId1: String, userId2: String) async throws -> String {
        if shouldFail { throw mockError }
        return mockStatus
    }
    
    func getFriendSuggestions(limit: Int, excludeRequested: Bool) async throws -> [FriendSuggestion] {
        if shouldFail { throw mockError }
        return mockFriendSuggestions
    }
}
#endif

