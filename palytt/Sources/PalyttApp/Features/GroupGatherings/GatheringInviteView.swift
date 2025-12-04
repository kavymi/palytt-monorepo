//
//  GatheringInviteView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import SwiftUI
import Clerk

// MARK: - Gathering Invite View

struct GatheringInviteView: View {
    let gathering: GroupGathering
    let onInvitesSent: (([String]) -> Void)?
    
    @StateObject private var viewModel = GatheringInviteViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFriends: Set<String> = []
    @State private var searchText = ""
    
    init(gathering: GroupGathering, onInvitesSent: (([String]) -> Void)? = nil) {
        self.gathering = gathering
        self.onInvitesSent = onInvitesSent
    }
    
    var filteredFriends: [BackendUser] {
        if searchText.isEmpty {
            return viewModel.friends
        }
        return viewModel.friends.filter { friend in
            let name = friend.displayName ?? friend.username ?? ""
            let username = friend.username ?? ""
            return name.localizedCaseInsensitiveContains(searchText) ||
                   username.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // Exclude already invited friends
    var availableFriends: [BackendUser] {
        let existingParticipantIds = Set(gathering.participants.map { $0.userId })
        return filteredFriends.filter { !existingParticipantIds.contains($0.clerkId) }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                searchBar
                
                // Selection Info
                if !selectedFriends.isEmpty {
                    selectionHeader
                }
                
                // Friends List
                if viewModel.isLoading {
                    loadingView
                } else if availableFriends.isEmpty {
                    emptyStateView
                } else {
                    friendsList
                }
            }
            .background(Color.appBackground)
            .navigationTitle("Invite Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondaryText)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Send") {
                        sendInvites()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(selectedFriends.isEmpty ? .secondaryText : .primaryBrand)
                    .disabled(selectedFriends.isEmpty || viewModel.isSending)
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
        .task {
            await viewModel.loadFriends()
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondaryText)
            
            TextField("Search friends...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondaryText)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.cardBackground)
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Selection Header
    
    private var selectionHeader: some View {
        HStack {
            Text("\(selectedFriends.count) friend\(selectedFriends.count == 1 ? "" : "s") selected")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primaryBrand)
            
            Spacer()
            
            Button("Clear") {
                selectedFriends.removeAll()
                HapticManager.shared.impact(.light)
            }
            .font(.subheadline)
            .foregroundColor(.secondaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.primaryBrand.opacity(0.1))
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading friends...")
                .font(.subheadline)
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: searchText.isEmpty ? "person.2.slash" : "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.tertiaryText)
            
            Text(searchText.isEmpty ? "No friends to invite" : "No friends found")
                .font(.headline)
                .foregroundColor(.primaryText)
            
            Text(searchText.isEmpty ? 
                 "All your friends are already part of this gathering, or you haven't added any friends yet." :
                 "Try searching with a different name")
                .font(.subheadline)
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Friends List
    
    private var friendsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(availableFriends, id: \.clerkId) { friend in
                    FriendInviteRow(
                        friend: friend,
                        isSelected: selectedFriends.contains(friend.clerkId),
                        onToggle: {
                            toggleSelection(friend.clerkId)
                        }
                    )
                    
                    Divider()
                        .padding(.leading, 76)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func toggleSelection(_ friendId: String) {
        HapticManager.shared.impact(.light)
        if selectedFriends.contains(friendId) {
            selectedFriends.remove(friendId)
        } else {
            selectedFriends.insert(friendId)
        }
    }
    
    private func sendInvites() {
        HapticManager.shared.impact(.medium)
        
        Task {
            let success = await viewModel.sendInvites(
                gatheringId: gathering.id,
                friendIds: Array(selectedFriends)
            )
            
            if success {
                HapticManager.shared.impact(.success)
                onInvitesSent?(Array(selectedFriends))
                dismiss()
            }
        }
    }
}

// MARK: - Friend Invite Row

struct FriendInviteRow: View {
    let friend: BackendUser
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Selection Indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.primaryBrand : Color.secondaryText.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.primaryBrand)
                            .frame(width: 16, height: 16)
                    }
                }
                
                // Avatar
                BackendUserAvatar(user: friend, size: 44)
                
                // User Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.displayName ?? friend.username ?? "Unknown")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                    
                    Text("@\(friend.username ?? "unknown")")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? Color.primaryBrand.opacity(0.05) : Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Gathering Invite View Model

@MainActor
class GatheringInviteViewModel: ObservableObject {
    @Published var friends: [BackendUser] = []
    @Published var isLoading = false
    @Published var isSending = false
    @Published var errorMessage: String?
    
    private let backendService = BackendService.shared
    
    func loadFriends() async {
        isLoading = true
        errorMessage = nil
        
        do {
            guard let currentUser = Clerk.shared.user else {
                errorMessage = "You must be logged in to invite friends"
                isLoading = false
                return
            }
            
            let response = try await backendService.getFriends(userId: currentUser.id, limit: 100)
            friends = response
            
        } catch {
            errorMessage = "Failed to load friends: \(error.localizedDescription)"
            print("❌ GatheringInviteViewModel: Failed to load friends: \(error)")
        }
        
        isLoading = false
    }
    
    func sendInvites(gatheringId: String, friendIds: [String]) async -> Bool {
        isSending = true
        errorMessage = nil
        
        do {
            guard let currentUser = Clerk.shared.user else {
                errorMessage = "You must be logged in to send invites"
                isSending = false
                return false
            }
            
            // Send invites to each friend
            for friendId in friendIds {
                _ = try await backendService.sendGatheringInvite(
                    gatheringId: gatheringId,
                    inviterId: currentUser.id,
                    inviteeId: friendId
                )
            }
            
            print("✅ GatheringInviteViewModel: Sent \(friendIds.count) gathering invites")
            isSending = false
            return true
            
        } catch {
            errorMessage = "Failed to send invites: \(error.localizedDescription)"
            print("❌ GatheringInviteViewModel: Failed to send invites: \(error)")
            isSending = false
            return false
        }
    }
}

// MARK: - Preview

#Preview {
    GatheringInviteView(
        gathering: GroupGathering(
            title: "Preview Gathering",
            description: "A sample gathering for preview",
            creatorId: "preview-user",
            type: .dinner,
            location: GatheringLocation()
        )
    )
}

