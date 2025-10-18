//
//  UserService.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import Foundation

// MARK: - Protocol

protocol UserServiceProtocol {
    // Profile Management
    func getUserByClerkId(_ clerkId: String) async throws -> User
    func updateUser(_ request: UpdateUserRequest) async throws -> User
    func syncUserFromClerk() async throws -> User
    
    // User Creation/Upsert
    func upsertUser(_ request: UpsertUserRequest) async throws -> User
    func upsertUserByAppleId(appleId: String, email: String?, displayName: String?) async throws -> User
    func upsertUserByGoogleId(googleId: String, email: String?, displayName: String?) async throws -> User
    
    // Availability Checks
    func checkUsernameAvailability(_ username: String) async throws -> Bool
    func checkEmailAvailability(_ email: String) async throws -> Bool
    func checkPhoneAvailability(_ phoneNumber: String) async throws -> Bool
    
    // Search & Discovery
    func searchUsers(query: String, limit: Int, offset: Int) async throws -> [User]
    func getSuggestedUsers(limit: Int) async throws -> [User]
}

// MARK: - Service Implementation

@MainActor
final class UserService: UserServiceProtocol {
    
    private let apiClient: APIClientProtocol
    private let authProvider: AuthProviderProtocol
    
    init(
        apiClient: APIClientProtocol,
        authProvider: AuthProviderProtocol = AuthProvider.shared
    ) {
        self.apiClient = apiClient
        self.authProvider = authProvider
    }
    
    convenience init(baseURL: URL) {
        let apiClient = APIClient(baseURL: baseURL)
        self.init(apiClient: apiClient)
    }
    
    // MARK: - Profile Management
    
    func getUserByClerkId(_ clerkId: String) async throws -> User {
        print("🔍 UserService: Getting user by Clerk ID: \(clerkId)")
        
        struct GetUserRequest: Encodable {
            let clerkId: String
        }
        
        struct GetUserResponse: Decodable {
            let user: UserDTO
        }
        
        let response = try await apiClient.request(
            path: "trpc/users.getByClerkId",
            method: .get,
            parameters: GetUserRequest(clerkId: clerkId),
            responseType: GetUserResponse.self
        )
        
        print("✅ UserService: Successfully retrieved user")
        return User.from(userDTO: response.user)
    }
    
    func updateUser(_ request: UpdateUserRequest) async throws -> User {
        print("📝 UserService: Updating user profile")
        
        let response = try await apiClient.request(
            path: "trpc/users.update",
            method: .post,
            parameters: request,
            responseType: UpdateUserResponse.self
        )
        
        guard response.success else {
            throw APIError.serverError(message: "Failed to update user")
        }
        
        print("✅ UserService: Successfully updated user")
        return User.from(userDTO: response.user)
    }
    
    func syncUserFromClerk() async throws -> User {
        print("🔄 UserService: Syncing user from Clerk")
        
        let clerkUserId = try await authProvider.getClerkUserId()
        
        struct SyncUserRequest: Encodable {
            let clerkId: String
        }
        
        struct SyncUserResponse: Decodable {
            let success: Bool
            let user: UserDTO
        }
        
        let response = try await apiClient.request(
            path: "trpc/users.syncFromClerk",
            method: .post,
            parameters: SyncUserRequest(clerkId: clerkUserId),
            responseType: SyncUserResponse.self
        )
        
        guard response.success else {
            throw APIError.serverError(message: "Failed to sync user from Clerk")
        }
        
        print("✅ UserService: Successfully synced user from Clerk")
        return User.from(userDTO: response.user)
    }
    
    // MARK: - User Creation/Upsert
    
    func upsertUser(_ request: UpsertUserRequest) async throws -> User {
        print("🆕 UserService: Upserting user")
        
        let response = try await apiClient.request(
            path: "trpc/users.upsert",
            method: .post,
            parameters: request,
            responseType: UpsertUserResponse.self
        )
        
        guard response.success else {
            throw APIError.serverError(message: "Failed to upsert user")
        }
        
        if response.isNewUser == true {
            print("✅ UserService: Created new user")
        } else {
            print("✅ UserService: Updated existing user")
        }
        
        return User.from(userDTO: response.user)
    }
    
    func upsertUserByAppleId(
        appleId: String,
        email: String?,
        displayName: String?
    ) async throws -> User {
        print("🍎 UserService: Upserting user by Apple ID")
        
        let clerkUserId = try await authProvider.getClerkUserId()
        
        let request = UpsertUserRequest(
            clerkId: clerkUserId,
            username: nil,
            displayName: displayName,
            email: email,
            phoneNumber: nil,
            profileImageUrl: nil,
            appleId: appleId,
            googleId: nil
        )
        
        return try await upsertUser(request)
    }
    
    func upsertUserByGoogleId(
        googleId: String,
        email: String?,
        displayName: String?
    ) async throws -> User {
        print("🔍 UserService: Upserting user by Google ID")
        
        let clerkUserId = try await authProvider.getClerkUserId()
        
        let request = UpsertUserRequest(
            clerkId: clerkUserId,
            username: nil,
            displayName: displayName,
            email: email,
            phoneNumber: nil,
            profileImageUrl: nil,
            appleId: nil,
            googleId: googleId
        )
        
        return try await upsertUser(request)
    }
    
    // MARK: - Availability Checks
    
    func checkUsernameAvailability(_ username: String) async throws -> Bool {
        print("🔍 UserService: Checking username availability: \(username)")
        
        let response = try await apiClient.request(
            path: "trpc/users.checkUsername",
            method: .get,
            parameters: CheckAvailabilityRequest(value: username),
            responseType: CheckAvailabilityResponse.self
        )
        
        print("✅ UserService: Username '\(username)' is \(response.available ? "available" : "taken")")
        return response.available
    }
    
    func checkEmailAvailability(_ email: String) async throws -> Bool {
        print("🔍 UserService: Checking email availability")
        
        let response = try await apiClient.request(
            path: "trpc/users.checkEmail",
            method: .get,
            parameters: CheckAvailabilityRequest(value: email),
            responseType: CheckAvailabilityResponse.self
        )
        
        print("✅ UserService: Email is \(response.available ? "available" : "taken")")
        return response.available
    }
    
    func checkPhoneAvailability(_ phoneNumber: String) async throws -> Bool {
        print("🔍 UserService: Checking phone availability")
        
        let response = try await apiClient.request(
            path: "trpc/users.checkPhone",
            method: .get,
            parameters: CheckAvailabilityRequest(value: phoneNumber),
            responseType: CheckAvailabilityResponse.self
        )
        
        print("✅ UserService: Phone is \(response.available ? "available" : "taken")")
        return response.available
    }
    
    // MARK: - Search & Discovery
    
    func searchUsers(query: String, limit: Int = 20, offset: Int = 0) async throws -> [User] {
        print("🔍 UserService: Searching users with query: '\(query)'")
        
        let request = SearchUsersRequest(
            query: query,
            limit: limit,
            offset: offset
        )
        
        let response = try await apiClient.request(
            path: "trpc/users.search",
            method: .get,
            parameters: request,
            responseType: SearchUsersResponse.self
        )
        
        print("✅ UserService: Found \(response.users.count) users")
        return response.users.map { User.from(userDTO: $0) }
    }
    
    func getSuggestedUsers(limit: Int = 10) async throws -> [User] {
        print("💡 UserService: Getting suggested users")
        
        struct GetSuggestionsRequest: Encodable {
            let limit: Int
        }
        
        let response = try await apiClient.request(
            path: "trpc/users.getSuggestions",
            method: .get,
            parameters: GetSuggestionsRequest(limit: limit),
            responseType: SuggestedUsersResponse.self
        )
        
        print("✅ UserService: Got \(response.users.count) suggested users")
        return response.users.map { User.from(userDTO: $0) }
    }
}

// MARK: - Mock Implementation for Testing

#if DEBUG
final class MockUserService: UserServiceProtocol {
    var mockUser: User?
    var mockUsers: [User] = []
    var shouldFail = false
    var mockError: APIError = .networkError(URLError(.notConnectedToInternet))
    var mockAvailability = true
    
    func getUserByClerkId(_ clerkId: String) async throws -> User {
        if shouldFail { throw mockError }
        return mockUser ?? createMockUser()
    }
    
    func updateUser(_ request: UpdateUserRequest) async throws -> User {
        if shouldFail { throw mockError }
        return mockUser ?? createMockUser()
    }
    
    func syncUserFromClerk() async throws -> User {
        if shouldFail { throw mockError }
        return mockUser ?? createMockUser()
    }
    
    func upsertUser(_ request: UpsertUserRequest) async throws -> User {
        if shouldFail { throw mockError }
        return mockUser ?? createMockUser()
    }
    
    func upsertUserByAppleId(appleId: String, email: String?, displayName: String?) async throws -> User {
        if shouldFail { throw mockError }
        return mockUser ?? createMockUser()
    }
    
    func upsertUserByGoogleId(googleId: String, email: String?, displayName: String?) async throws -> User {
        if shouldFail { throw mockError }
        return mockUser ?? createMockUser()
    }
    
    func checkUsernameAvailability(_ username: String) async throws -> Bool {
        if shouldFail { throw mockError }
        return mockAvailability
    }
    
    func checkEmailAvailability(_ email: String) async throws -> Bool {
        if shouldFail { throw mockError }
        return mockAvailability
    }
    
    func checkPhoneAvailability(_ phoneNumber: String) async throws -> Bool {
        if shouldFail { throw mockError }
        return mockAvailability
    }
    
    func searchUsers(query: String, limit: Int, offset: Int) async throws -> [User] {
        if shouldFail { throw mockError }
        return mockUsers
    }
    
    func getSuggestedUsers(limit: Int) async throws -> [User] {
        if shouldFail { throw mockError }
        return mockUsers
    }
    
    private func createMockUser() -> User {
        return User(
            id: UUID(),
            username: "mockuser",
            displayName: "Mock User",
            email: "mock@test.com"
        )
    }
}
#endif

