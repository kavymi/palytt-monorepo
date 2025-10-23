//
//  SocialServiceTests.swift
//  PalyttAppTests
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//

import XCTest
@testable import PalyttApp

@MainActor
final class SocialServiceTests: XCTestCase {
    
    var sut: SocialService!
    var mockAPIClient: MockAPIClient!
    
    override func setUp() {
        super.setUp()
        mockAPIClient = MockAPIClient()
        sut = SocialService(apiClient: mockAPIClient)
    }
    
    override func tearDown() {
        sut = nil
        mockAPIClient = nil
        super.tearDown()
    }
    
    // MARK: - Follow/Unfollow Tests
    
    func testFollowUser_Success() async throws {
        // Given
        let response = FollowResponse(success: true, message: nil)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let success = try await sut.followUser(followerId: "user1", followingId: "user2")
        
        // Then
        XCTAssertTrue(success)
        XCTAssertEqual(mockAPIClient.lastRequestPath, "trpc/social.followUser")
    }
    
    func testUnfollowUser_Success() async throws {
        // Given
        let response = FollowResponse(success: true, message: nil)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let success = try await sut.unfollowUser(followerId: "user1", followingId: "user2")
        
        // Then
        XCTAssertTrue(success)
    }
    
    func testIsFollowing_True() async throws {
        // Given
        let response = IsFollowingResponse(isFollowing: true)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let isFollowing = try await sut.isFollowing(followerId: "user1", followingId: "user2")
        
        // Then
        XCTAssertTrue(isFollowing)
    }
    
    // MARK: - Friends Tests
    
    func testGetFriends_Success() async throws {
        // Given
        let mockUsers = [createMockUserDTO(), createMockUserDTO()]
        let response = GetFriendsResponse(friends: mockUsers, total: 2, hasMore: false)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let friends = try await sut.getFriends(userId: "user1", limit: 50)
        
        // Then
        XCTAssertEqual(friends.count, 2)
    }
    
    func testGetMutualFriends_Success() async throws {
        // Given
        let mockUsers = [createMockUserDTO()]
        let response = MutualFriendsResponse(mutualFriends: mockUsers, count: 1, total: 1)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let mutualFriends = try await sut.getMutualFriends(userId1: "user1", userId2: "user2", limit: 10)
        
        // Then
        XCTAssertEqual(mutualFriends.count, 1)
    }
    
    func testAreFriends_True() async throws {
        // Given
        let response = AreFriendsResponse(areFriends: true)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let areFriends = try await sut.areFriends(userId1: "user1", userId2: "user2")
        
        // Then
        XCTAssertTrue(areFriends)
    }
    
    // MARK: - Friend Requests Tests
    
    func testSendFriendRequest_Success() async throws {
        // Given
        let response = FriendRequestResponse(success: true, message: nil, request: nil)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let success = try await sut.sendFriendRequest(senderId: "user1", receiverId: "user2")
        
        // Then
        XCTAssertTrue(success)
    }
    
    func testAcceptFriendRequest_Success() async throws {
        // Given
        let response = FriendRequestResponse(success: true, message: nil, request: nil)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let success = try await sut.acceptFriendRequest(requestId: "request123")
        
        // Then
        XCTAssertTrue(success)
    }
    
    func testRejectFriendRequest_Success() async throws {
        // Given
        let response = FriendRequestResponse(success: true, message: nil, request: nil)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let success = try await sut.rejectFriendRequest(requestId: "request123")
        
        // Then
        XCTAssertTrue(success)
    }
    
    // MARK: - Helper Methods
    
    private func createMockUserDTO() -> UserDTO {
        return UserDTO(
            id: UUID().uuidString,
            clerkId: "clerk_test",
            username: "testuser",
            displayName: "Test User",
            email: "test@test.com",
            phoneNumber: nil,
            bio: nil,
            profileImageUrl: nil,
            isPrivate: false,
            isVerified: false,
            followersCount: 0,
            followingCount: 0,
            postsCount: 0,
            friendsCount: 0,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date()),
            instagramHandle: nil,
            twitterHandle: nil,
            tikTokHandle: nil,
            location: nil,
            website: nil,
            dateOfBirth: nil,
            appleId: nil,
            googleId: nil
        )
    }
}

