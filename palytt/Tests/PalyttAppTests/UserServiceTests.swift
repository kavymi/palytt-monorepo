//
//  UserServiceTests.swift
//  PalyttAppTests
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import XCTest
@testable import PalyttApp

@MainActor
final class UserServiceTests: XCTestCase {
    
    var sut: UserService!
    var mockAPIClient: MockAPIClient!
    var mockAuthProvider: MockAuthProvider!
    
    override func setUp() {
        super.setUp()
        mockAPIClient = MockAPIClient()
        mockAuthProvider = MockAuthProvider()
        sut = UserService(apiClient: mockAPIClient, authProvider: mockAuthProvider)
    }
    
    override func tearDown() {
        sut = nil
        mockAPIClient = nil
        mockAuthProvider = nil
        super.tearDown()
    }
    
    // MARK: - getUserByClerkId Tests
    
    func testGetUserByClerkId_Success() async throws {
        // Given
        let clerkId = "clerk_test123"
        let mockUserDTO = createMockUserDTO(clerkId: clerkId)
        let response = GetUserResponse(user: mockUserDTO)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let user = try await sut.getUserByClerkId(clerkId)
        
        // Then
        XCTAssertEqual(user.clerkId, clerkId)
        XCTAssertEqual(user.username, mockUserDTO.username)
        XCTAssertEqual(mockAPIClient.lastRequestPath, "trpc/users.getByClerkId")
    }
    
    func testGetUserByClerkId_Failure() async {
        // Given
        mockAPIClient.shouldFail = true
        mockAPIClient.mockError = .networkError(URLError(.notConnectedToInternet))
        
        // When/Then
        do {
            _ = try await sut.getUserByClerkId("clerk_test123")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - updateUser Tests
    
    func testUpdateUser_Success() async throws {
        // Given
        let request = UpdateUserRequest(
            username: "newusername",
            displayName: "New Display Name",
            bio: "Updated bio",
            profileImageUrl: nil,
            isPrivate: nil,
            phoneNumber: nil,
            location: nil,
            website: nil,
            dateOfBirth: nil,
            instagramHandle: nil,
            twitterHandle: nil,
            tikTokHandle: nil
        )
        let mockUserDTO = createMockUserDTO(username: "newusername")
        let response = UpdateUserResponse(success: true, user: mockUserDTO)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let user = try await sut.updateUser(request)
        
        // Then
        XCTAssertEqual(user.username, "newusername")
        XCTAssertEqual(mockAPIClient.lastRequestPath, "trpc/users.update")
        XCTAssertEqual(mockAPIClient.lastRequestMethod, .post)
    }
    
    func testUpdateUser_Failure_ServerError() async {
        // Given
        let request = UpdateUserRequest(
            username: "newusername",
            displayName: nil,
            bio: nil,
            profileImageUrl: nil,
            isPrivate: nil,
            phoneNumber: nil,
            location: nil,
            website: nil,
            dateOfBirth: nil,
            instagramHandle: nil,
            twitterHandle: nil,
            tikTokHandle: nil
        )
        let response = UpdateUserResponse(success: false, user: createMockUserDTO())
        mockAPIClient.mockResponseData = try? JSONEncoder().encode(response)
        
        // When/Then
        do {
            _ = try await sut.updateUser(request)
            XCTFail("Expected error to be thrown")
        } catch let error as APIError {
            if case .serverError(let message) = error {
                XCTAssertEqual(message, "Failed to update user")
            } else {
                XCTFail("Expected serverError")
            }
        }
    }
    
    // MARK: - syncUserFromClerk Tests
    
    func testSyncUserFromClerk_Success() async throws {
        // Given
        mockAuthProvider.mockClerkUserId = "clerk_test123"
        let mockUserDTO = createMockUserDTO()
        let response = SyncUserResponse(success: true, user: mockUserDTO)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let user = try await sut.syncUserFromClerk()
        
        // Then
        XCTAssertNotNil(user)
        XCTAssertEqual(mockAPIClient.lastRequestPath, "trpc/users.syncFromClerk")
    }
    
    func testSyncUserFromClerk_NoAuthUser() async {
        // Given
        mockAuthProvider.shouldFail = true
        mockAuthProvider.mockError = .authenticationError(message: "No authenticated user")
        
        // When/Then
        do {
            _ = try await sut.syncUserFromClerk()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - upsertUser Tests
    
    func testUpsertUser_CreateNewUser() async throws {
        // Given
        let request = UpsertUserRequest(
            clerkId: "clerk_new123",
            username: "newuser",
            displayName: "New User",
            email: "new@test.com",
            phoneNumber: nil,
            profileImageUrl: nil,
            appleId: nil,
            googleId: nil
        )
        let mockUserDTO = createMockUserDTO(username: "newuser")
        let response = UpsertUserResponse(success: true, user: mockUserDTO, isNewUser: true)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let user = try await sut.upsertUser(request)
        
        // Then
        XCTAssertEqual(user.username, "newuser")
        XCTAssertEqual(mockAPIClient.lastRequestPath, "trpc/users.upsert")
    }
    
    func testUpsertUser_UpdateExistingUser() async throws {
        // Given
        let request = UpsertUserRequest(
            clerkId: "clerk_existing123",
            username: "existinguser",
            displayName: "Existing User",
            email: "existing@test.com",
            phoneNumber: nil,
            profileImageUrl: nil,
            appleId: nil,
            googleId: nil
        )
        let mockUserDTO = createMockUserDTO(username: "existinguser")
        let response = UpsertUserResponse(success: true, user: mockUserDTO, isNewUser: false)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let user = try await sut.upsertUser(request)
        
        // Then
        XCTAssertEqual(user.username, "existinguser")
    }
    
    // MARK: - upsertUserByAppleId Tests
    
    func testUpsertUserByAppleId_Success() async throws {
        // Given
        mockAuthProvider.mockClerkUserId = "clerk_apple123"
        let mockUserDTO = createMockUserDTO()
        let response = UpsertUserResponse(success: true, user: mockUserDTO, isNewUser: true)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let user = try await sut.upsertUserByAppleId(
            appleId: "apple_123",
            email: "apple@test.com",
            displayName: "Apple User"
        )
        
        // Then
        XCTAssertNotNil(user)
    }
    
    // MARK: - upsertUserByGoogleId Tests
    
    func testUpsertUserByGoogleId_Success() async throws {
        // Given
        mockAuthProvider.mockClerkUserId = "clerk_google123"
        let mockUserDTO = createMockUserDTO()
        let response = UpsertUserResponse(success: true, user: mockUserDTO, isNewUser: true)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let user = try await sut.upsertUserByGoogleId(
            googleId: "google_123",
            email: "google@test.com",
            displayName: "Google User"
        )
        
        // Then
        XCTAssertNotNil(user)
    }
    
    // MARK: - Availability Check Tests
    
    func testCheckUsernameAvailability_Available() async throws {
        // Given
        let response = CheckAvailabilityResponse(available: true, message: nil)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let isAvailable = try await sut.checkUsernameAvailability("newusername")
        
        // Then
        XCTAssertTrue(isAvailable)
        XCTAssertEqual(mockAPIClient.lastRequestPath, "trpc/users.checkUsername")
    }
    
    func testCheckUsernameAvailability_NotAvailable() async throws {
        // Given
        let response = CheckAvailabilityResponse(available: false, message: "Username taken")
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let isAvailable = try await sut.checkUsernameAvailability("takenusername")
        
        // Then
        XCTAssertFalse(isAvailable)
    }
    
    func testCheckEmailAvailability_Available() async throws {
        // Given
        let response = CheckAvailabilityResponse(available: true, message: nil)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let isAvailable = try await sut.checkEmailAvailability("new@test.com")
        
        // Then
        XCTAssertTrue(isAvailable)
    }
    
    func testCheckPhoneAvailability_Available() async throws {
        // Given
        let response = CheckAvailabilityResponse(available: true, message: nil)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let isAvailable = try await sut.checkPhoneAvailability("+1234567890")
        
        // Then
        XCTAssertTrue(isAvailable)
    }
    
    // MARK: - Search Tests
    
    func testSearchUsers_Success() async throws {
        // Given
        let mockUsers = [createMockUserDTO(), createMockUserDTO(username: "user2")]
        let response = SearchUsersResponse(users: mockUsers, total: 2, hasMore: false)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let users = try await sut.searchUsers(query: "test", limit: 20, offset: 0)
        
        // Then
        XCTAssertEqual(users.count, 2)
        XCTAssertEqual(mockAPIClient.lastRequestPath, "trpc/users.search")
    }
    
    func testSearchUsers_EmptyResults() async throws {
        // Given
        let response = SearchUsersResponse(users: [], total: 0, hasMore: false)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let users = try await sut.searchUsers(query: "nonexistent", limit: 20, offset: 0)
        
        // Then
        XCTAssertEqual(users.count, 0)
    }
    
    // MARK: - Get Suggested Users Tests
    
    func testGetSuggestedUsers_Success() async throws {
        // Given
        let mockUsers = [createMockUserDTO(), createMockUserDTO(username: "suggested2")]
        let response = SuggestedUsersResponse(users: mockUsers, reasons: nil)
        mockAPIClient.mockResponseData = try JSONEncoder().encode(response)
        
        // When
        let users = try await sut.getSuggestedUsers(limit: 10)
        
        // Then
        XCTAssertEqual(users.count, 2)
        XCTAssertEqual(mockAPIClient.lastRequestPath, "trpc/users.getSuggestions")
    }
    
    // MARK: - Helper Methods
    
    private func createMockUserDTO(
        clerkId: String = "clerk_test123",
        username: String = "testuser"
    ) -> UserDTO {
        return UserDTO(
            id: UUID().uuidString,
            clerkId: clerkId,
            username: username,
            displayName: "Test User",
            email: "test@test.com",
            phoneNumber: nil,
            bio: "Test bio",
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
    
    private struct GetUserResponse: Codable {
        let user: UserDTO
    }
    
    private struct SyncUserResponse: Codable {
        let success: Bool
        let user: UserDTO
    }
}

// MARK: - Mock APIClient

class MockAPIClient: APIClientProtocol {
    var mockResponseData: Data?
    var shouldFail = false
    var mockError: APIError = .networkError(URLError(.notConnectedToInternet))
    var lastRequestPath: String?
    var lastRequestMethod: HTTPMethod?
    
    func request<T: Encodable, R: Decodable>(
        path: String,
        method: HTTPMethod,
        parameters: T?,
        responseType: R.Type
    ) async throws -> R {
        lastRequestPath = path
        lastRequestMethod = method
        
        if shouldFail {
            throw mockError
        }
        
        guard let data = mockResponseData else {
            throw APIError.serverError(message: "No mock data")
        }
        
        return try JSONDecoder().decode(R.self, from: data)
    }
}

// MARK: - Mock AuthProvider

class MockAuthProvider: AuthProviderProtocol {
    var mockToken = "mock_jwt_token"
    var mockClerkUserId = "clerk_mock123"
    var shouldFail = false
    var mockError: APIError = .authenticationError(message: "Mock auth error")
    var isAuthenticatedValue = true
    
    var isAuthenticatedPublisher: AnyPublisher<Bool, Never> {
        Just(isAuthenticatedValue).eraseToAnyPublisher()
    }
    
    func getAuthToken() async throws -> String {
        if shouldFail { throw mockError }
        return mockToken
    }
    
    func getClerkUserId() async throws -> String {
        if shouldFail { throw mockError }
        return mockClerkUserId
    }
}

