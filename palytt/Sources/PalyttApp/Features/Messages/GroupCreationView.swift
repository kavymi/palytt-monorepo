//
//  GroupCreationView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI
import Kingfisher
import Clerk

struct GroupCreationView: View {
    @StateObject private var viewModel = GroupCreationViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var groupName = ""
    @State private var groupDescription = ""
    @State private var searchText = ""
    @State private var selectedUsers: Set<BackendService.User> = []
    @State private var showingChat = false
    
    private var canCreateGroup: Bool {
        !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedUsers.count >= 1
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Group details section
                groupDetailsSection
                
                Divider()
                    .background(Color.divider)
                    .padding(.vertical, 8)
                
                // Search and select members
                searchSection
                
                // Selected members preview
                if !selectedUsers.isEmpty {
                    selectedMembersSection
                }
                
                Divider()
                    .background(Color.divider)
                
                // Search results
                searchResultsSection
            }
            .background(Color.background)
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        HapticManager.shared.impact(.light)
                        dismiss()
                    }
                    .foregroundColor(.primaryText)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createGroup()
                    }
                    .foregroundColor(canCreateGroup ? .primaryBrand : .tertiaryText)
                    .disabled(!canCreateGroup)
                    .fontWeight(.semibold)
                }
            }
        }
        .onChange(of: searchText) { _, newValue in
            if !newValue.isEmpty {
                viewModel.searchUsers(query: newValue)
            } else {
                viewModel.clearSearchResults()
            }
        }
        .sheet(isPresented: $showingChat) {
            if let chatroom = viewModel.createdChatroom {
                ChatView(chatroom: chatroom)
            }
        }
        .onChange(of: viewModel.createdChatroom) { _, newChatroom in
            if newChatroom != nil {
                showingChat = true
                dismiss()
            }
        }
    }
    
    private var groupDetailsSection: some View {
        VStack(spacing: 16) {
            // Group name
            VStack(alignment: .leading, spacing: 8) {
                Text("Group Name")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                TextField("Enter group name...", text: $groupName)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.body)
                    .foregroundColor(.primaryText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.cardBackground)
                            .stroke(Color.divider.opacity(0.5), lineWidth: 1)
                    )
            }
            
            // Group description (optional)
            VStack(alignment: .leading, spacing: 8) {
                Text("Description (Optional)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                TextField("What's this group about?", text: $groupDescription, axis: .vertical)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.body)
                    .foregroundColor(.primaryText)
                    .lineLimit(3)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.cardBackground)
                            .stroke(Color.divider.opacity(0.5), lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add Members")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primaryText)
                .padding(.horizontal, 16)
            
            SearchBar(text: $searchText, placeholder: "Search for friends...")
                .padding(.horizontal, 16)
        }
        .padding(.top, 8)
    }
    
    private var selectedMembersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Selected Members (\(selectedUsers.count))")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondaryText)
                    .padding(.horizontal, 16)
                
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(selectedUsers), id: \.clerkId) { user in
                        SelectedMemberChip(user: user) {
                            removeUser(user)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var searchResultsSection: some View {
        Group {
            if let errorMessage = viewModel.errorMessage {
                ErrorStateView(message: errorMessage) {
                    viewModel.clearError()
                    if !searchText.isEmpty {
                        viewModel.searchUsers(query: searchText)
                    }
                }
            } else if viewModel.isLoading && viewModel.searchResults.isEmpty && !searchText.isEmpty {
                LoadingStateView()
            } else if viewModel.searchResults.isEmpty && !searchText.isEmpty {
                EmptySearchStateView(searchText: searchText)
            } else if searchText.isEmpty {
                InitialGroupSearchStateView()
            } else {
                GroupSearchResultsView(
                    users: viewModel.searchResults,
                    selectedUsers: selectedUsers,
                    onUserToggle: toggleUser
                )
            }
        }
    }
    
    private func toggleUser(_ user: BackendService.User) {
        HapticManager.shared.impact(.light)
        
        if selectedUsers.contains(user) {
            selectedUsers.remove(user)
        } else {
            selectedUsers.insert(user)
        }
    }
    
    private func removeUser(_ user: BackendService.User) {
        HapticManager.shared.impact(.light)
        selectedUsers.remove(user)
    }
    
    private func createGroup() {
        guard canCreateGroup else { return }
        
        HapticManager.shared.impact(.medium)
        
        let participantIds = Array(selectedUsers).map { $0.clerkId }
        viewModel.createGroup(
            name: groupName.trimmingCharacters(in: .whitespacesAndNewlines),
            description: groupDescription.isEmpty ? nil : groupDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            participantIds: participantIds
        )
    }
}

// MARK: - Selected Member Chip
struct SelectedMemberChip: View {
    let user: BackendService.User
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            // Avatar
            AsyncImage(url: URL(string: user.avatarUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(LinearGradient.primaryGradient.opacity(0.3))
                    .overlay(
                        Text((user.displayName ?? user.username ?? "?").prefix(1).uppercased())
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primaryBrand)
                    )
            }
            .frame(width: 24, height: 24)
            .clipShape(Circle())
            
            Text(user.displayName ?? user.username ?? "Unknown")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primaryText)
                .lineLimit(1)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.tertiaryText)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cardBackground)
                .stroke(Color.divider.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Group Search Results View
struct GroupSearchResultsView: View {
    let users: [BackendService.User]
    let selectedUsers: Set<BackendService.User>
    let onUserToggle: (BackendService.User) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(users, id: \.clerkId) { user in
                    GroupUserRowView(
                        user: user,
                        isSelected: selectedUsers.contains(user),
                        onToggle: {
                            onUserToggle(user)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .background(Color.background)
    }
}

// MARK: - Group User Row View
struct GroupUserRowView: View {
    let user: BackendService.User
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Profile image
                AsyncImage(url: URL(string: user.avatarUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(LinearGradient.primaryGradient.opacity(0.3))
                        .overlay(
                            Text((user.displayName ?? user.username ?? "?").prefix(1).uppercased())
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primaryBrand)
                        )
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName ?? user.username ?? "Unknown User")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                        .lineLimit(1)
                    
                    Text("@\(user.username ?? "unknown")")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Circle()
                        .fill(Color.primaryBrand)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        )
                } else {
                    Circle()
                        .stroke(Color.divider, lineWidth: 2)
                        .frame(width: 24, height: 24)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Initial Group Search State
struct InitialGroupSearchStateView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Circle()
                .fill(LinearGradient.primaryGradient.opacity(0.2))
                .frame(width: 120, height: 120)
                .overlay(
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.primaryBrand)
                )
            
            VStack(spacing: 12) {
                Text("Add Friends to Group")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
                
                Text("Search for friends to add to your new group conversation.")
                    .font(.body)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.background)
    }
}

// MARK: - Error State View
struct ErrorStateView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Circle()
                .fill(Color.red.opacity(0.2))
                .frame(width: 120, height: 120)
                .overlay(
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                )
            
            VStack(spacing: 12) {
                Text("Search Failed")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button(action: onRetry) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Try Again")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient.primaryGradient
                        .cornerRadius(25)
                )
                .shadow(color: .primaryBrand.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(HapticButtonStyle(haptic: .medium, sound: .tap))
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.background)
    }
}

// MARK: - Loading State View
struct LoadingStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(0.8)
                    .progressViewStyle(CircularProgressViewStyle(tint: .primaryBrand))
                
                Text("Searching for friends...")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
            }
            .padding(.top, 24)
            
            ForEach(0..<3, id: \.self) { _ in
                UserRowSkeleton()
            }
        }
        .padding()
    }
}

// MARK: - Preview
#Preview {
    GroupCreationView()
}
