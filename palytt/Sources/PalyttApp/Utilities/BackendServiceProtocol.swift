//
//  BackendServiceProtocol.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//

import Foundation

// MARK: - BackendServiceProtocol

protocol BackendServiceProtocol {
    // Friends functionality
    func sendFriendRequest(senderId: String, receiverId: String) async throws -> BackendService.FriendRequest
    func getPendingFriendRequests(userId: String) async throws -> [BackendService.FriendRequest]
    func acceptFriendRequest(requestId: String) async throws -> BackendService.FriendRequestResponse
    func rejectFriendRequest(requestId: String) async throws -> BackendService.FriendRequestResponse
    func removeFriend(userId1: String, userId2: String) async throws -> BackendService.FriendRequestResponse
    func areFriends(userId1: String, userId2: String) async throws -> BackendService.AreFriendsResponse
    func getFriendRequestStatus(senderId: String, receiverId: String) async throws -> BackendService.FriendRequestStatusResponse
    func getUserFriends(userId: String) async throws -> [BackendService.User]
    
    // Search functionality
    func searchUsers(query: String, limit: Int) async throws -> [BackendService.BackendUser]
    func getSuggestedUsers(userId: String, limit: Int) async throws -> [BackendService.BackendUser]
}

// MARK: - BackendService Protocol Conformance

extension BackendService: BackendServiceProtocol {
    // The BackendService already implements all these methods
    // This extension just makes it conform to the protocol
}

// MARK: - Test-only Models

#if DEBUG
// These are simplified models for testing
struct TestFriendRequest: Codable {
    let id: String
    let senderId: String
    let receiverId: String
    let status: FriendRequestStatus
    let createdAt: Date
    let updatedAt: Date
}

enum FriendRequestStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case accepted = "accepted"
    case rejected = "rejected"
}

struct TestUser: Codable {
    let id: String
    let username: String
    let email: String
    let displayName: String
    let bio: String?
    let profilePictureUrl: String?
    let isVerified: Bool
    let createdAt: Date
    let followersCount: Int
    let followingCount: Int
    let postsCount: Int
}

struct TestFriendsService {
    private let backendService: BackendServiceProtocol
    
    init(backendService: BackendServiceProtocol) {
        self.backendService = backendService
    }
    
    func sendFriendRequest(from senderId: String, to receiverId: String) async throws -> TestFriendRequest {
        // Validate input
        guard senderId != receiverId else {
            throw FriendsError.cannotSendToSelf
        }
        
        let backendRequest = try await backendService.sendFriendRequest(senderId: senderId, receiverId: receiverId)
        
        // Convert to test model
        return TestFriendRequest(
            id: backendRequest._id,
            senderId: backendRequest.senderId,
            receiverId: backendRequest.receiverId,
            status: FriendRequestStatus(rawValue: backendRequest.status) ?? .pending,
            createdAt: Date(timeIntervalSince1970: Double(backendRequest.createdAt) / 1000),
            updatedAt: Date(timeIntervalSince1970: Double(backendRequest.updatedAt) / 1000)
        )
    }
    
    func getFriendRequests(for userId: String) async throws -> [TestFriendRequest] {
        let backendRequests = try await backendService.getPendingFriendRequests(userId: userId)
        
        return backendRequests.map { request in
            TestFriendRequest(
                id: request._id,
                senderId: request.senderId,
                receiverId: request.receiverId,
                status: FriendRequestStatus(rawValue: request.status) ?? .pending,
                createdAt: Date(timeIntervalSince1970: Double(request.createdAt) / 1000),
                updatedAt: Date(timeIntervalSince1970: Double(request.updatedAt) / 1000)
            )
        }
    }
    
    func getUserFriends(for userId: String) async throws -> [TestUser] {
        let backendFriends = try await backendService.getUserFriends(userId: userId)
        
        return backendFriends.map { user in
            TestUser(
                id: user._id,
                username: user.username ?? "",
                email: "", // Not provided in backend User model
                displayName: user.displayName ?? "",
                bio: user.bio,
                profilePictureUrl: user.avatarUrl,
                isVerified: false, // Not provided in backend User model
                createdAt: Date(timeIntervalSince1970: Double(user.lastActiveAt) / 1000),
                followersCount: 0, // Not provided in backend User model
                followingCount: 0, // Not provided in backend User model
                postsCount: 0 // Not provided in backend User model
            )
        }
    }
    
    enum FriendsError: Error, LocalizedError {
        case cannotSendToSelf
        case requestNotFound
        case alreadyFriends
        case networkError(String)
        
        var errorDescription: String? {
            switch self {
            case .cannotSendToSelf:
                return "Cannot send friend request to yourself"
            case .requestNotFound:
                return "Friend request not found"
            case .alreadyFriends:
                return "Users are already friends"
            case .networkError(let message):
                return "Network error: \(message)"
            }
        }
    }
}
#endif 