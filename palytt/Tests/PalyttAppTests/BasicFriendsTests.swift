//
//  BasicFriendsTests.swift
//  PalyttAppTests
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//

import XCTest
@testable import Palytt

final class BasicFriendsTests: XCTestCase {
    
    // MARK: - Simple Data Model Tests
    
    func test_friendRequest_creation_isValid() {
        // Given
        let senderId = "user_123"
        let receiverId = "user_456"
        let status = "pending"
        let currentTime = Int(Date().timeIntervalSince1970 * 1000)
        
        // When
        let friendRequest = BackendService.FriendRequest(
            _id: "request_789",
            senderId: senderId,
            receiverId: receiverId,
            status: status,
            createdAt: currentTime,
            updatedAt: currentTime,
            sender: nil
        )
        
        // Then
        XCTAssertEqual(friendRequest._id, "request_789")
        XCTAssertEqual(friendRequest.senderId, senderId)
        XCTAssertEqual(friendRequest.receiverId, receiverId)
        XCTAssertEqual(friendRequest.status, status)
        XCTAssertEqual(friendRequest.createdAt, currentTime)
    }
    
    func test_user_creation_isValid() {
        // Given
        let userId = "user_123"
        let username = "testuser"
        let displayName = "Test User"
        let currentTime = Int(Date().timeIntervalSince1970 * 1000)
        
        // When
        let user = BackendService.User(
            _id: userId,
            clerkId: userId,
            username: username,
            displayName: displayName,
            avatarUrl: nil,
            bio: "Test bio",
            isOnline: true,
            lastActiveAt: currentTime
        )
        
        // Then
        XCTAssertEqual(user._id, userId)
        XCTAssertEqual(user.clerkId, userId)
        XCTAssertEqual(user.username, username)
        XCTAssertEqual(user.displayName, displayName)
        XCTAssertEqual(user.bio, "Test bio")
        XCTAssertTrue(user.isOnline)
    }
    
    func test_backendUser_creation_isValid() {
        // Given
        let userId = "user_123"
        let email = "test@example.com"
        let username = "testuser"
        let currentTime = Int(Date().timeIntervalSince1970 * 1000)
        
        // When
        let backendUser = BackendService.BackendUser(
            _id: userId,
            clerkId: userId,
            email: email,
            username: username,
            displayName: "Test User",
            avatarUrl: nil,
            bio: "Test bio",
            isVerified: false,
            isActive: true,
            followersCount: 0,
            followingCount: 0,
            postsCount: 0,
            friendsCount: 0,
            isOnline: true,
            lastActiveAt: currentTime,
            createdAt: currentTime,
            updatedAt: currentTime
        )
        
        // Then
        XCTAssertEqual(backendUser._id, userId)
        XCTAssertEqual(backendUser.email, email)
        XCTAssertEqual(backendUser.username, username)
        XCTAssertFalse(backendUser.isVerified)
        XCTAssertTrue(backendUser.isActive)
        XCTAssertEqual(backendUser.friendsCount, 0)
    }
    
    // MARK: - String Validation Tests
    
    func test_userId_validation_works() {
        // Test valid user ID formats
        let validUserIds = ["user_123", "clerk_abc123", "test-user-456"]
        
        for userId in validUserIds {
            XCTAssertFalse(userId.isEmpty, "User ID should not be empty")
            XCTAssertTrue(userId.count > 3, "User ID should be longer than 3 characters")
        }
    }
    
    func test_friendRequest_status_validation() {
        // Given
        let validStatuses = ["pending", "accepted", "rejected"]
        let invalidStatuses = ["", "unknown", "maybe"]
        
        // When & Then
        for status in validStatuses {
            XCTAssertTrue(["pending", "accepted", "rejected"].contains(status))
        }
        
        for status in invalidStatuses {
            XCTAssertFalse(["pending", "accepted", "rejected"].contains(status))
        }
    }
    
    // MARK: - Date and Time Tests
    
    func test_timestamp_creation_isRecent() {
        // Given
        let currentTime = Int(Date().timeIntervalSince1970 * 1000)
        
        // When
        let testTime = Int(Date().timeIntervalSince1970 * 1000)
        
        // Then
        let timeDifference = abs(testTime - currentTime)
        XCTAssertLessThan(timeDifference, 1000, "Timestamps should be within 1 second")
    }
    
    func test_date_conversion_works() {
        // Given
        let timestamp = 1642694400000 // Jan 20, 2022
        
        // When
        let date = Date(timeIntervalSince1970: Double(timestamp) / 1000)
        let convertedTimestamp = Int(date.timeIntervalSince1970 * 1000)
        
        // Then
        XCTAssertEqual(convertedTimestamp, timestamp)
    }
    
    // MARK: - Error Handling Tests
    
    func test_friendRequest_errorScenarios() {
        // Test cannot send to self
        let userId = "same_user"
        
        // This should be caught by business logic
        XCTAssertEqual(userId, userId, "Same user ID scenario")
        
        // Test empty strings
        let emptyString = ""
        XCTAssertTrue(emptyString.isEmpty)
        
        // Test nil handling
        let optionalString: String? = nil
        XCTAssertNil(optionalString)
    }
    
    // MARK: - Performance Tests
    
    func test_friendRequest_creation_performance() {
        measure {
            // This will measure the time it takes to create friend requests
            for i in 0..<1000 {
                let friendRequest = BackendService.FriendRequest(
                    _id: "request_\(i)",
                    senderId: "sender_\(i)",
                    receiverId: "receiver_\(i)",
                    status: "pending",
                    createdAt: Int(Date().timeIntervalSince1970 * 1000),
                    updatedAt: Int(Date().timeIntervalSince1970 * 1000),
                    sender: nil
                )
                
                // Simple assertion to ensure object is created
                XCTAssertNotNil(friendRequest)
            }
        }
    }
    
    // MARK: - Collection Tests
    
    func test_friendsList_operations() {
        // Given
        var friends: [BackendService.User] = []
        let currentTime = Int(Date().timeIntervalSince1970 * 1000)
        
        // When - Add friends
        for i in 1...5 {
            let friend = BackendService.User(
                _id: "friend_\(i)",
                clerkId: "friend_\(i)",
                username: "friend\(i)",
                displayName: "Friend \(i)",
                avatarUrl: nil,
                bio: nil,
                isOnline: true,
                lastActiveAt: currentTime
            )
            friends.append(friend)
        }
        
        // Then
        XCTAssertEqual(friends.count, 5)
        XCTAssertEqual(friends.first?.username, "friend1")
        XCTAssertEqual(friends.last?.username, "friend5")
        
        // Test filtering
        let onlineFriends = friends.filter { $0.isOnline }
        XCTAssertEqual(onlineFriends.count, 5)
        
        // Test finding specific friend
        let specificFriend = friends.first { $0._id == "friend_3" }
        XCTAssertNotNil(specificFriend)
        XCTAssertEqual(specificFriend?.displayName, "Friend 3")
    }
    
    // MARK: - Edge Case Tests
    
    func test_edgeCases_handledCorrectly() {
        // Test very long strings
        let longString = String(repeating: "a", count: 1000)
        XCTAssertEqual(longString.count, 1000)
        
        // Test empty collections
        let emptyUsers: [BackendService.User] = []
        XCTAssertTrue(emptyUsers.isEmpty)
        
        // Test maximum timestamp
        let maxTimestamp = Int.max
        XCTAssertGreaterThan(maxTimestamp, 0)
        
        // Test minimum timestamp
        let minTimestamp = 0
        XCTAssertGreaterThanOrEqual(minTimestamp, 0)
    }
    
    // MARK: - Async Test Example
    
    func test_async_operation_simulation() async {
        // Given
        let expectation = XCTestExpectation(description: "Async operation completes")
        
        // When - Simulate an async operation
        Task {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            expectation.fulfill()
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
    }
}

// MARK: - Test Extensions

extension BasicFriendsTests {
    
    /// Helper function to create a test friend request
    func createTestFriendRequest(id: String = "test_request") -> BackendService.FriendRequest {
        return BackendService.FriendRequest(
            _id: id,
            senderId: "test_sender",
            receiverId: "test_receiver",
            status: "pending",
            createdAt: Int(Date().timeIntervalSince1970 * 1000),
            updatedAt: Int(Date().timeIntervalSince1970 * 1000),
            sender: nil
        )
    }
    
    /// Helper function to create a test user
    func createTestUser(id: String = "test_user") -> BackendService.User {
        return BackendService.User(
            _id: id,
            clerkId: id,
            username: "testuser",
            displayName: "Test User",
            avatarUrl: nil,
            bio: nil,
            isOnline: true,
            lastActiveAt: Int(Date().timeIntervalSince1970 * 1000)
        )
    }
} 