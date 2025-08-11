//
//  NewMessageView.swift
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
#if !targetEnvironment(simulator)
// import ConvexMobile // temporarily disabled
#endif

struct NewMessageView: View {
    @StateObject private var viewModel = NewMessageViewModel()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var selectedUser: BackendService.User?
    @State private var showingChat = false
    @State private var showingGroupCreation = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBarSection
                
                Divider()
                    .background(Color.divider)
                    .padding(.top, 8)
                
                contentSection
                
                Spacer()
            }
            .background(Color.background)
            .navigationTitle("New Message")
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
                    Button("New Group") {
                        HapticManager.shared.impact(.light)
                        showingGroupCreation = true
                    }
                    .foregroundColor(.primaryBrand)
                    .fontWeight(.semibold)
                }
            }
        }
        .onChange(of: searchText) { _, newValue in
            viewModel.searchUsers(query: newValue)
        }
        .sheet(isPresented: $showingChat) {
            if let chatroom = viewModel.createdChatroom {
                ChatView(chatroom: chatroom)
            }
        }
        .onChange(of: viewModel.createdChatroom) { _, newChatroom in
            if newChatroom != nil {
                showingChat = true
            }
        }
        .sheet(isPresented: $showingGroupCreation) {
            GroupCreationView()
        }
    }
    
    private var searchBarSection: some View {
        SearchBar(text: $searchText, placeholder: "Search for friends...")
            .padding(.horizontal, 16)
            .padding(.top, 8)
    }
    
    @ViewBuilder
    private var contentSection: some View {
        if let errorMessage = viewModel.errorMessage {
            errorStateView(errorMessage)
        } else if viewModel.isLoading && viewModel.searchResults.isEmpty && !searchText.isEmpty {
            loadingStateView
        } else if viewModel.searchResults.isEmpty && !searchText.isEmpty {
            EmptySearchStateView(searchText: searchText)
        } else if searchText.isEmpty {
            InitialSearchStateView()
        } else {
            searchResultsView
        }
    }
    
    private func errorStateView(_ message: String) -> some View {
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
            
            Button(action: {
                HapticManager.shared.impact(.medium)
                viewModel.clearError()
                if !searchText.isEmpty {
                    viewModel.searchUsers(query: searchText)
                }
            }) {
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
    
    private var loadingStateView: some View {
        VStack(spacing: 16) {
            // Loading message with spinner
            HStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(0.8)
                    .progressViewStyle(CircularProgressViewStyle(tint: .primaryBrand))
                
                Text("Searching for friends...")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
            }
            .padding(.top, 24)
            
            // Skeleton loading rows
            ForEach(0..<3, id: \.self) { _ in
                UserRowSkeleton()
            }
        }
        .padding()
    }
    
    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.searchResults, id: \.clerkId) { user in
                    MessageUserRowView(user: user) {
                        HapticManager.shared.impact(.medium)
                        selectedUser = user
                        createChatroom(with: user)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .background(Color.background)
    }
    
    private func createChatroom(with user: BackendService.User) {
        viewModel.createChatroom(with: user)
    }
}

// MARK: - Message User Row View
struct MessageUserRowView: View {
    let user: BackendService.User
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
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
                    
                    if let bio = user.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.caption)
                            .foregroundColor(.tertiaryText)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Message icon
                Image(systemName: "message")
                    .font(.system(size: 16))
                    .foregroundColor(.primaryBrand)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Search Bar
struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondaryText)
                .font(.system(size: 16, weight: .medium))
            
            TextField(placeholder, text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.body)
                .foregroundColor(.primaryText)
                .focused($isFocused)
                .submitLabel(.search)
            
            if !text.isEmpty {
                Button(action: {
                    HapticManager.shared.impact(.light)
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.tertiaryText)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cardBackground)
                .stroke(isFocused ? Color.primaryBrand : Color.divider.opacity(0.5), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - Empty Search State
struct EmptySearchStateView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Circle()
                .fill(LinearGradient.primaryGradient.opacity(0.2))
                .frame(width: 120, height: 120)
                .overlay(
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 40))
                        .foregroundColor(.primaryBrand)
                )
            
            VStack(spacing: 12) {
                Text("No Results Found")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
                
                Text("No users found for \"\(searchText)\". Try searching with a different name or username.")
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

// MARK: - Initial Search State
struct InitialSearchStateView: View {
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
                Text("Find Your Friends")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
                
                Text("Search for friends by name or username to start a conversation.")
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

// MARK: - Preview
#Preview {
    NewMessageView()
        .environmentObject(MockAppState())
} 