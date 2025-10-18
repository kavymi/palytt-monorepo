//
//  SocialDTO.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import Foundation

// MARK: - Follow DTOs

struct FollowRequest: Codable {
    let followerId: String
    let followingId: String
}

struct FollowResponse: Codable {
    let success: Bool
    let message: String?
}

struct IsFollowingRequest: Codable {
    let followerId: String
    let followingId: String
}

struct IsFollowingResponse: Codable {
    let isFollowing: Bool
}

struct GetFollowListRequest: Codable {
    let userId: String
    let limit: Int?
}

struct GetFollowListResponse: Codable {
    let users: [UserDTO]
    let total: Int
    let hasMore: Bool
}

// MARK: - Friend DTOs

struct FriendRequestDTO: Codable {
    let id: String
    let senderId: String
    let receiverId: String
    let status: String // "pending", "accepted", "rejected"
    let createdAt: String
    let updatedAt: String
    
    // Denormalized user info
    let senderUsername: String?
    let senderDisplayName: String?
    let senderProfileImageUrl: String?
    let receiverUsername: String?
    let receiverDisplayName: String?
    let receiverProfileImageUrl: String?
}

struct SendFriendRequestRequest: Codable {
    let senderId: String
    let receiverId: String
}

struct FriendRequestResponse: Codable {
    let success: Bool
    let message: String?
    let request: FriendRequestDTO?
}

struct AcceptFriendRequestRequest: Codable {
    let requestId: String
}

struct RejectFriendRequestRequest: Codable {
    let requestId: String
}

struct RemoveFriendRequest: Codable {
    let userId1: String
    let userId2: String
}

struct GetFriendRequestsRequest: Codable {
    let userId: String
}

struct GetFriendRequestsResponse: Codable {
    let requests: [FriendRequestDTO]
    let total: Int
}

struct GetFriendsRequest: Codable {
    let userId: String
    let limit: Int?
}

struct GetFriendsResponse: Codable {
    let friends: [UserDTO]
    let total: Int
    let hasMore: Bool
}

struct AreFriendsRequest: Codable {
    let userId1: String
    let userId2: String
}

struct AreFriendsResponse: Codable {
    let areFriends: Bool
}

struct FriendRequestStatusRequest: Codable {
    let userId1: String
    let userId2: String
}

struct FriendRequestStatusResponse: Codable {
    let status: String // "none", "pending_sent", "pending_received", "friends"
    let requestId: String?
}

// MARK: - Mutual Friends DTOs

struct GetMutualFriendsRequest: Codable {
    let userId1: String
    let userId2: String
    let limit: Int?
}

struct MutualFriendsResponse: Codable {
    let mutualFriends: [UserDTO]
    let count: Int
    let total: Int
}

// MARK: - Friend Suggestions DTOs

struct GetFriendSuggestionsRequest: Codable {
    let limit: Int?
    let excludeRequested: Bool?
}

struct FriendSuggestionDTO: Codable {
    let user: UserDTO
    let reason: String // "mutual_friends", "same_location", "similar_interests", etc.
    let mutualFriendsCount: Int?
}

struct FriendSuggestionsResponse: Codable {
    let suggestions: [FriendSuggestionDTO]
    let total: Int
}

// MARK: - Following Posts DTOs

struct FollowingPostDTO: Codable {
    let post: PostResponseDTO
    let author: UserDTO
}

struct GetFollowingPostsRequest: Codable {
    let userId: String
    let limit: Int?
}

struct GetFollowingPostsResponse: Codable {
    let posts: [FollowingPostDTO]
    let hasMore: Bool
}

// MARK: - Domain Model Conversion

extension FriendRequestDTO {
    func toDomain() -> FriendRequest {
        return FriendRequest(
            id: UUID(uuidString: self.id) ?? UUID(),
            senderId: UUID(uuidString: self.senderId) ?? UUID(),
            receiverId: UUID(uuidString: self.receiverId) ?? UUID(),
            status: FriendRequestStatus(rawValue: self.status) ?? .pending,
            createdAt: ISO8601DateFormatter().date(from: self.createdAt) ?? Date()
        )
    }
}

extension FriendSuggestionDTO {
    func toDomain() -> FriendSuggestion {
        return FriendSuggestion(
            user: User.from(userDTO: self.user),
            reason: self.reason,
            mutualFriendsCount: self.mutualFriendsCount ?? 0
        )
    }
}

// Helper structs for domain models (if they don't exist yet)
struct FriendRequest {
    let id: UUID
    let senderId: UUID
    let receiverId: UUID
    let status: FriendRequestStatus
    let createdAt: Date
}

enum FriendRequestStatus: String {
    case pending
    case accepted
    case rejected
}

struct FriendSuggestion {
    let user: User
    let reason: String
    let mutualFriendsCount: Int
}

struct FollowingPost {
    let post: Post
    let author: User
}

