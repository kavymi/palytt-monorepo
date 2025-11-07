//
//  AuthProvider.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import Foundation
import Clerk

/// Protocol for authentication providers
protocol AuthProviderProtocol {
    func getToken() async throws -> String
    func getHeaders() async throws -> [String: String]
    func getCurrentUserId() -> String?
    func isAuthenticated() -> Bool
    func clearCache()
}

/// Manages authentication tokens and headers using Clerk
@MainActor
final class AuthProvider: AuthProviderProtocol {
    
    // MARK: - Properties
    
    private let clerk = Clerk.shared
    
    // Token caching
    private var cachedToken: String?
    private var tokenExpiry: Date?
    private let tokenRefreshBuffer: TimeInterval = 5 * 60 // Refresh 5 minutes before expiry
    
    // MARK: - Singleton
    
    static let shared = AuthProvider()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Get valid authentication token, refreshing if necessary
    /// - Returns: Valid JWT token from Clerk
    /// - Throws: APIError if token cannot be obtained
    func getToken() async throws -> String {
        // Return cached token if still valid
        if let token = cachedToken,
           let expiry = tokenExpiry,
           expiry > Date() {
            return token
        }
        
        // Get fresh token from Clerk
        guard let session = clerk.session else {
            throw APIError.authenticationRequired
        }
        
        do {
            // ✅ Use real JWT token from Clerk
            let tokenResource = try await session.getToken()
            
            guard let token = tokenResource?.jwt else {
                throw APIError.authenticationRequired
            }
            
            // Cache token with buffer before expiry
            cachedToken = token
            // Clerk tokens typically expire in 1 hour, refresh after 55 minutes
            tokenExpiry = Date().addingTimeInterval(55 * 60)
            
            return token
        } catch {
            // Clear cache on error
            clearCache()
            
            // Map Clerk errors to API errors
            if error.localizedDescription.contains("expired") {
                throw APIError.tokenExpired
            } else if error.localizedDescription.contains("invalid") {
                throw APIError.invalidToken
            } else {
                throw APIError.from(error)
            }
        }
    }
    
    /// Get HTTP headers with authentication
    /// - Returns: Dictionary of headers including Authorization
    /// - Throws: APIError if headers cannot be created
    func getHeaders() async throws -> [String: String] {
        let token = try await getToken()
        
        return [
            "Content-Type": "application/json",
            "Accept": "application/json",
            "Authorization": "Bearer \(token)"
        ]
    }
    
    /// Get current user's ID without throwing
    /// - Returns: User ID if authenticated, nil otherwise
    func getCurrentUserId() -> String? {
        return clerk.user?.id
    }
    
    /// Check if user is authenticated
    /// - Returns: true if user is signed in
    func isAuthenticated() -> Bool {
        return clerk.user != nil
    }
    
    /// Clear cached authentication data
    func clearCache() {
        cachedToken = nil
        tokenExpiry = nil
    }
    
    // MARK: - User ID Helper (for x-clerk-user-id header if needed)
    
    /// Get headers with additional user ID header (for development/debugging)
    /// - Returns: Headers with both Authorization and x-clerk-user-id
    /// - Throws: APIError if headers cannot be created
    func getHeadersWithUserId() async throws -> [String: String] {
        var headers = try await getHeaders()
        
        if let userId = getCurrentUserId() {
            headers["x-clerk-user-id"] = userId
        }
        
        return headers
    }
}

// MARK: - Mock for Testing

#if DEBUG
/// Mock auth provider for testing
final class MockAuthProvider: AuthProviderProtocol {
    var shouldFail = false
    var mockToken = "mock_token_12345"
    var mockUserId: String? = "user_123"
    
    func getToken() async throws -> String {
        if shouldFail {
            throw APIError.unauthorized
        }
        return mockToken
    }
    
    func getHeaders() async throws -> [String: String] {
        if shouldFail {
            throw APIError.unauthorized
        }
        return [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(mockToken)"
        ]
    }
    
    func getCurrentUserId() -> String? {
        return mockUserId
    }
    
    func isAuthenticated() -> Bool {
        return mockUserId != nil
    }
    
    func clearCache() {
        mockToken = ""
    }
}
#endif

