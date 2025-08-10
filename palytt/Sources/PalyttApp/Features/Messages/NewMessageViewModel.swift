//
//  NewMessageViewModel.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI
import Clerk
#if !targetEnvironment(simulator)
// import ConvexMobile // temporarily disabled
#endif

@MainActor
class NewMessageViewModel: ObservableObject {
    @Published var searchResults: [BackendService.User] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var createdChatroom: BackendService.Chatroom?
    
    private let backendService = BackendService.shared
    private var searchTimer: Timer?
    
    func searchUsers(query: String) {
        // Clear results if query is empty
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        // Debounce search to avoid too many API calls
        searchTimer?.invalidate()
        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            Task { @MainActor in
                await self.performSearch(query: query)
            }
        }
    }
    
    private func performSearch(query: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let users = try await backendService.searchUsersForMessaging(query: query, limit: 20)
            searchResults = users
            
            // If no results found but no error, that's not an error state
            if users.isEmpty {
                print("🔍 No users found for query: \(query)")
            } else {
                print("✅ Found \(users.count) users for query: \(query)")
            }
        } catch {
            let errorMsg = handleSearchError(error)
            errorMessage = errorMsg
            print("❌ Error searching users: \(error)")
            HapticManager.shared.impact(.error)
            searchResults = []
        }
        
        isLoading = false
    }
    
    private func handleSearchError(_ error: Error) -> String {
        if let backendError = error as? BackendError {
            switch backendError {
            case .networkError(_):
                return "Network connection failed. Please check your internet connection and try again."
            case .trpcError(let message, let code):
                if code == 500 {
                    return "Server error occurred. Please try again in a moment."
                } else if code == 401 || code == 403 {
                    return "Authentication failed. Please sign in again."
                } else {
                    return "Search failed: \(message)"
                }
            case .invalidResponse:
                return "Invalid response from server. Please try again."
            case .decodingError:
                return "Failed to process search results. Please try again."
            }
        } else {
            return "Search failed. Please check your connection and try again."
        }
    }
    
    func createChatroom(with user: BackendService.User) {
        guard let currentUserId = Clerk.shared.user?.id else {
            errorMessage = "Authentication required"
            HapticManager.shared.impact(.error)
            return
        }
        
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                // Create participants array with current user and selected user
                let participants = [currentUserId, user.clerkId]
                
                // Create a direct chatroom
                let chatroomId = try await backendService.createChatroom(
                    participants: participants,
                    type: "direct"
                )
                
                // Create the chatroom object for navigation
                let chatroom = BackendService.Chatroom(
                    _id: chatroomId,
                    name: nil,
                    type: "direct",
                    participants: [user], // Only include the other user for display
                    createdBy: currentUserId,
                    lastMessageId: nil,
                    lastMessage: nil,
                    lastActivity: Int(Date().timeIntervalSince1970 * 1000),
                    unreadCount: 0,
                    isTyping: false,
                    typingUserId: nil
                )
                
                createdChatroom = chatroom
                HapticManager.shared.impact(.success)
                
            } catch {
                errorMessage = "Failed to create chatroom: \(error.localizedDescription)"
                print("❌ Error creating chatroom: \(error)")
                HapticManager.shared.impact(.error)
            }
            
            isLoading = false
        }
    }
    
    func clearSearch() {
        searchResults = []
        searchTimer?.invalidate()
        searchTimer = nil
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    deinit {
        searchTimer?.invalidate()
    }
} 