//
//  GroupCreationViewModel.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI
import Clerk

@MainActor
class GroupCreationViewModel: ObservableObject {
    @Published var searchResults: [BackendService.User] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var createdChatroom: BackendService.Chatroom?
    @Published var isCreatingGroup = false
    
    private let backendService = BackendService.shared
    private var searchTask: Task<Void, Never>?
    
    deinit {
        searchTask?.cancel()
    }
    
    func searchUsers(query: String) {
        // Cancel previous search
        searchTask?.cancel()
        
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        searchTask = Task {
            await performSearch(query: query)
        }
    }
    
    func clearSearchResults() {
        searchTask?.cancel()
        searchResults = []
        errorMessage = nil
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    func createGroup(name: String, description: String?, participantIds: [String]) {
        guard !isCreatingGroup else { return }
        
        Task {
            isCreatingGroup = true
            errorMessage = nil
            
            do {
                let chatroom = try await backendService.createGroupChatroom(
                    name: name,
                    description: description,
                    participantIds: participantIds
                )
                
                createdChatroom = chatroom
                
                HapticManager.shared.impact(.success, sound: .success)
                
            } catch {
                errorMessage = "Failed to create group: \(error.localizedDescription)"
                print("❌ Error creating group: \(error)")
                HapticManager.shared.impact(.error)
            }
            
            isCreatingGroup = false
        }
    }
    
    private func performSearch(query: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let users = try await backendService.searchUsers(query: query)
            
            await MainActor.run {
                searchResults = users
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to search users: \(error.localizedDescription)"
                searchResults = []
                print("❌ Error searching users: \(error)")
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
}
