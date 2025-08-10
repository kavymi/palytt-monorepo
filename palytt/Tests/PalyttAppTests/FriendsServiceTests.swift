//
//  FriendsServiceTests.swift
//  PalyttAppTests
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//

import XCTest
@testable import Palytt

// MARK: - Test Doubles (Mocks)

final class MockBackendService: BackendServiceProtocol {
    var sendFriendRequestResult: Result<BackendService.FriendRequest, Error>?
    var getFriendRequestsResult: Result<[BackendService.FriendRequest], Error>?
    var getUserFriendsResult: Result<[BackendService.User], Error>?
    var searchUsersResult: Result<[BackendService.BackendUser], Error>?
    var getSuggestedUsersResult: Result<[BackendService.BackendUser], Error>?
    
    // Call tracking
    var sendFriendRequestCallCount = 0
    var getFriendRequestsCallCount = 0
    var getUserFriendsCallCount = 0
    
    func sendFriendRequest(senderId: String, receiverId: String) async throws -> BackendService.FriendRequest {
        sendFriendRequestCallCount += 1
        
        switch sendFriendRequestResult {
        case .success(let request):
            return request
        case .failure(let error):
            throw error
        case .none:
            throw TestError.notConfigured
        }
    }
    
    func getPendingFriendRequests(userId: String) async throws -> [BackendService.FriendRequest] {
        getFriendRequestsCallCount += 1
        
        switch getFriendRequestsResult {
        case .success(let requests):
            return requests
        case .failure(let error):
            throw error
        case .none:
            throw TestError.notConfigured
        }
    }
    
    func getUserFriends(userId: String) async throws -> [BackendService.User] {
        getUserFriendsCallCount += 1
        
        switch getUserFriendsResult {
        case .success(let friends):
            return friends
        case .failure(let error):
            throw error
        case .none:
            throw TestError.notConfigured
        }
    }
    
    func searchUsers(query: String, limit: Int) async throws -> [BackendService.BackendUser] {
        switch searchUsersResult {
        case .success(let users):
            return users
        case .failure(let error):
            throw error
        case .none:
            throw TestError.notConfigured
        }
    }
    
    func getSuggestedUsers(userId: String, limit: Int) async throws -> [BackendService.BackendUser] {
        switch getSuggestedUsersResult {
        case .success(let users):
            return users
        case .failure(let error):
            throw error
        case .none:
            throw TestError.notConfigured
        }
    }
    
    // Placeholder implementations for other protocol methods
    func acceptFriendRequest(requestId: String) async throws -> BackendService.FriendRequestResponse {
        return BackendService.FriendRequestResponse(success: true, message: "Accepted")
    }
    
    func rejectFriendRequest(requestId: String) async throws -> BackendService.FriendRequestResponse {
        return BackendService.FriendRequestResponse(success: true, message: "Rejected")
    }
    
    func removeFriend(userId1: String, userId2: String) async throws -> BackendService.FriendRequestResponse {
        return BackendService.FriendRequestResponse(success: true, message: "Removed")
    }
    
    func areFriends(userId1: String, userId2: String) async throws -> BackendService.AreFriendsResponse {
        return BackendService.AreFriendsResponse(areFriends: true)
    }
    
    func getFriendRequestStatus(senderId: String, receiverId: String) async throws -> BackendService.FriendRequestStatusResponse {
        return BackendService.FriendRequestStatusResponse(status: "none", request: nil)
    }
}

enum TestError: Error {
    case notConfigured
    case networkFailure
    case invalidData
}

// MARK: - Test Data Factory

struct FriendsTestDataFactory {
    static func makeFriendRequest(
        id: String = "test_request_1",
        senderId: String = "sender_123",
        receiverId: String = "receiver_456",
        status: String = "pending"
    ) -> BackendService.FriendRequest {
        BackendService.FriendRequest(
            _id: id,
            senderId: senderId,
            receiverId: receiverId,
            status: status,
            createdAt: Int(Date().timeIntervalSince1970 * 1000),
            updatedAt: Int(Date().timeIntervalSince1970 * 1000),
            sender: BackendService.FriendRequestSender(
                _id: senderId,
                clerkId: senderId,
                displayName: "Test Sender",
                username: "testsender",
                avatarUrl: nil
            )
        )
    }
    
    static func makeUser(
        id: String = "user_123",
        username: String = "testuser",
        displayName: String = "Test User"
    ) -> BackendService.User {
        BackendService.User(
            _id: id,
            clerkId: id,
            username: username,
            displayName: displayName,
            avatarUrl: nil,
            bio: nil,
            isOnline: true,
            lastActiveAt: Int(Date().timeIntervalSince1970 * 1000)
        )
    }
    
    static func makeBackendUser(
        id: String = "user_123",
        username: String = "testuser",
        email: String = "test@example.com"
    ) -> BackendService.BackendUser {
        BackendService.BackendUser(
            _id: id,
            clerkId: id,
            email: email,
            username: username,
            displayName: "Test User",
            avatarUrl: nil,
            bio: nil,
            isVerified: false,
            isActive: true,
            followersCount: 0,
            followingCount: 0,
            postsCount: 0,
            friendsCount: 0,
            isOnline: true,
            lastActiveAt: Int(Date().timeIntervalSince1970 * 1000),
            createdAt: Int(Date().timeIntervalSince1970 * 1000),
            updatedAt: Int(Date().timeIntervalSince1970 * 1000)
        )
    }
}

// MARK: - Main Test Class

final class FriendsServiceTests: XCTestCase {
    
    // MARK: - Properties
    
    var mockBackendService: MockBackendService!
    var friendsService: TestFriendsService!
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        mockBackendService = MockBackendService()
        friendsService = TestFriendsService(backendService: mockBackendService)
    }
    
    override func tearDownWithError() throws {
        mockBackendService = nil
        friendsService = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Send Friend Request Tests
    
    func test_sendFriendRequest_whenSuccessful_returnsFriendRequest() async throws {
        // Given (Arrange)
        let expectedRequest = FriendsTestDataFactory.makeFriendRequest()
        mockBackendService.sendFriendRequestResult = .success(expectedRequest)
        
        // When (Act)
        let result = try await friendsService.sendFriendRequest(
            from: expectedRequest.senderId,
            to: expectedRequest.receiverId
        )
        
        // Then (Assert)
        XCTAssertEqual(result.id, expectedRequest._id)
        XCTAssertEqual(result.senderId, expectedRequest.senderId)
        XCTAssertEqual(result.receiverId, expectedRequest.receiverId)
        XCTAssertEqual(result.status.rawValue, expectedRequest.status)
        XCTAssertNotNil(result.createdAt)
        XCTAssertNotNil(result.updatedAt)
        XCTAssertEqual(mockBackendService.sendFriendRequestCallCount, 1)
    }
    
    func test_sendFriendRequest_whenNetworkFails_throwsError() async {
        // Given
        mockBackendService.sendFriendRequestResult = .failure(TestError.networkFailure)
        
        // When & Then
        await XCTAssertThrowsError(
            try await friendsService.sendFriendRequest(from: "user1", to: "user2")
        ) { error in
            XCTAssertEqual(error as? TestError, .networkFailure)
        }
        
        XCTAssertEqual(mockBackendService.sendFriendRequestCallCount, 1)
    }
    
    func test_sendFriendRequest_whenSendingToSelf_throwsError() async {
        // Given
        let userId = "same_user"
        
        // When & Then
        await XCTAssertThrowsError(
            try await friendsService.sendFriendRequest(from: userId, to: userId)
        ) { error in
            XCTAssertTrue(error is TestFriendsService.FriendsError)
            if case TestFriendsService.FriendsError.cannotSendToSelf = error {
                // Expected error
            } else {
                XCTFail("Expected cannotSendToSelf error")
            }
        }
        
        // Should not call backend when validation fails
        XCTAssertEqual(mockBackendService.sendFriendRequestCallCount, 0)
    }
    
    // MARK: - Get Friend Requests Tests
    
    func test_getFriendRequests_whenSuccessful_returnsRequests() async throws {
        // Given
        let expectedRequests = [
            FriendsTestDataFactory.makeFriendRequest(id: "req1"),
            FriendsTestDataFactory.makeFriendRequest(id: "req2")
        ]
        mockBackendService.getFriendRequestsResult = .success(expectedRequests)
        
        // When
        let result = try await friendsService.getFriendRequests(for: "user_123")
        
        // Then
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].id, "req1")
        XCTAssertEqual(result[1].id, "req2")
        XCTAssertEqual(mockBackendService.getFriendRequestsCallCount, 1)
    }
    
    func test_getFriendRequests_whenEmpty_returnsEmptyArray() async throws {
        // Given
        mockBackendService.getFriendRequestsResult = .success([])
        
        // When
        let result = try await friendsService.getFriendRequests(for: "user_123")
        
        // Then
        XCTAssertTrue(result.isEmpty)
        XCTAssertEqual(mockBackendService.getFriendRequestsCallCount, 1)
    }
    
    // MARK: - Get Friends Tests
    
    func test_getUserFriends_whenSuccessful_returnsFriends() async throws {
        // Given
        let expectedFriends = [
            FriendsTestDataFactory.makeUser(id: "friend1", username: "friend_one"),
            FriendsTestDataFactory.makeUser(id: "friend2", username: "friend_two")
        ]
        mockBackendService.getUserFriendsResult = .success(expectedFriends)
        
        // When
        let result = try await friendsService.getUserFriends(for: "user_123")
        
        // Then
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].username, "friend_one")
        XCTAssertEqual(result[1].username, "friend_two")
        XCTAssertEqual(mockBackendService.getUserFriendsCallCount, 1)
    }
    
    // MARK: - Search Users Tests
    
    func test_searchUsers_whenSuccessful_returnsUsers() async throws {
        // Given
        let expectedUsers = [
            FriendsTestDataFactory.makeBackendUser(id: "user1", username: "john"),
            FriendsTestDataFactory.makeBackendUser(id: "user2", username: "jane")
        ]
        mockBackendService.searchUsersResult = .success(expectedUsers)
        
        // When
        let result = try await mockBackendService.searchUsers(query: "j", limit: 10)
        
        // Then
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].username, "john")
        XCTAssertEqual(result[1].username, "jane")
    }
    
    // MARK: - Performance Tests
    
    func test_sendFriendRequest_performance() {
        // Given
        let request = FriendsTestDataFactory.makeFriendRequest()
        mockBackendService.sendFriendRequestResult = .success(request)
        
        // When & Then
        measure {
            let expectation = expectation(description: "Friend request sent")
            Task {
                _ = try await friendsService.sendFriendRequest(from: "user1", to: "user2")
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 1.0)
        }
    }
    
    // MARK: - Integration-style Tests (using real models)
    
    func test_friendRequest_dataConversion_isCorrect() async throws {
        // Given
        let backendRequest = FriendsTestDataFactory.makeFriendRequest(
            id: "test_123",
            senderId: "sender_456",
            receiverId: "receiver_789",
            status: "pending"
        )
        mockBackendService.sendFriendRequestResult = .success(backendRequest)
        
        // When
        let result = try await friendsService.sendFriendRequest(
            from: backendRequest.senderId,
            to: backendRequest.receiverId
        )
        
        // Then
        XCTAssertEqual(result.id, backendRequest._id)
        XCTAssertEqual(result.senderId, backendRequest.senderId)
        XCTAssertEqual(result.receiverId, backendRequest.receiverId)
        XCTAssertEqual(result.status.rawValue, backendRequest.status)
        XCTAssertNotNil(result.createdAt)
        XCTAssertNotNil(result.updatedAt)
    }
}

// MARK: - Helper Extensions

extension XCTestCase {
    func XCTAssertThrowsError<T>(
        _ expression: @autoclosure () async throws -> T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line,
        _ errorHandler: (_ error: Error) -> Void = { _ in }
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected error to be thrown", file: file, line: line)
        } catch {
            errorHandler(error)
        }
    }
} 