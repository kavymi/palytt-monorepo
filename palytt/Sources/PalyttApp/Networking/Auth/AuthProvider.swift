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
    
    // Token caching - use short expiry since Clerk tokens expire quickly (60 seconds default)
    private var cachedToken: String?
    private var tokenFetchTime: Date?
    // Clerk session tokens expire in ~60 seconds, so cache for max 30 seconds
    private let tokenCacheMaxAge: TimeInterval = 30
    
    // MARK: - Singleton
    
    static let shared = AuthProvider()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Get valid authentication token, refreshing if necessary
    /// - Returns: Valid JWT token from Clerk
    /// - Throws: APIError if token cannot be obtained
    func getToken() async throws -> String {
        // Check if we have a recently fetched token (within 30 seconds)
        // This avoids excessive API calls while still keeping tokens fresh
        if let token = cachedToken,
           let fetchTime = tokenFetchTime,
           Date().timeIntervalSince(fetchTime) < tokenCacheMaxAge {
            return token
        }
        
        // Get fresh token from Clerk
        guard let session = clerk.session else {
            print("⚠️ AuthProvider: No active Clerk session")
            clearCache()
            throw APIError.authenticationRequired
        }
        
        do {
            // ✅ Always get a fresh token from Clerk - it handles its own caching
            // The getToken() call will return a cached token if still valid,
            // or refresh it automatically if expired
            let tokenResource = try await session.getToken()
            
            guard let token = tokenResource?.jwt else {
                print("⚠️ AuthProvider: getToken() returned nil JWT")
                clearCache()
                throw APIError.authenticationRequired
            }
            
            // Cache token with fetch timestamp
            cachedToken = token
            tokenFetchTime = Date()
            
            print("✅ AuthProvider: Got fresh token from Clerk")
            return token
        } catch {
            // Clear cache on error
            clearCache()
            
            print("❌ AuthProvider: Failed to get token: \(error)")
            
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
    
    /// Check if user is authenticated with an active session
    /// - Returns: true if user is signed in AND has an active session
    func isAuthenticated() -> Bool {
        // Must have both a user AND an active session to be truly authenticated
        // A user can exist without a session (e.g., session expired)
        return clerk.user != nil && clerk.session != nil
    }
    
    /// Clear cached authentication data
    func clearCache() {
        cachedToken = nil
        tokenFetchTime = nil
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

