//
//  UserSearchView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI

struct UserSearchView: View {
    @StateObject private var viewModel = UserSearchViewModel()
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SearchBarSection(
                    searchText: $searchText,
                    onClear: {
                        searchText = ""
                        viewModel.clearSearch()
                    },
                    onCancel: {
                        searchText = ""
                        isSearchFocused = false
                        viewModel.clearSearch()
                    },
                    onSubmit: performSearch
                )
                
                contentView
                errorView
            }
            .navigationTitle("Find Friends")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.primaryBrand)
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.primaryBrand)
                }
                #endif
            }
            .background(Color.background)
        }
        .onAppear {
            Task {
                await viewModel.loadSuggestedUsers()
            }
        }
        .onChange(of: searchText) { _, newValue in
            if newValue.isEmpty {
                viewModel.clearSearch()
            } else if newValue.count >= 2 {
                // Debounce search to avoid too many API calls
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    if searchText == newValue { // Still the same search term
                        await viewModel.searchUsers(query: newValue)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading && viewModel.searchResults.isEmpty {
            LoadingStateView()
        } else if searchText.isEmpty && viewModel.searchResults.isEmpty {
            UserSearchEmptyStateView(suggestedUsers: viewModel.suggestedUsers)
        } else if viewModel.searchResults.isEmpty && !searchText.isEmpty {
            NoResultsStateView()
        } else {
            SearchResultsListView(
                searchResults: viewModel.searchResults,
                hasMore: viewModel.hasMore,
                isLoading: viewModel.isLoading,
                onLoadMore: {
                    Task {
                        await viewModel.loadMoreResults()
                    }
                }
            )
            .listStyle(PlainListStyle())
            .refreshable {
                await viewModel.refreshSearch()
            }
        }
    }
    
    @ViewBuilder
    private var errorView: some View {
        if let errorMessage = viewModel.errorMessage {
            VStack(spacing: 12) {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                
                Button("Try Again") {
                    performSearch()
                }
                .font(.caption)
                .foregroundColor(.primaryBrand)
            }
            .padding()
            .background(Color.cardBackground)
        }
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        Task {
            await viewModel.searchUsers(query: searchText)
        }
    }
}

// MARK: - Search Result User Row
struct SearchResultUserRow: View {
    let user: BackendUser
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationLink(destination: ProfileView(targetUser: User(
            id: UUID(uuidString: user.clerkId) ?? UUID(),
            email: "",
            firstName: user.displayName?.components(separatedBy: " ").first ?? "",
            lastName: user.displayName?.components(separatedBy: " ").dropFirst().joined(separator: " ") ?? "",
            username: user.username ?? "",
            displayName: user.displayName ?? "",
            bio: user.bio ?? "",
            avatarURL: user.avatarUrl != nil ? URL(string: user.avatarUrl!) : nil,
            clerkId: user.clerkId,
            role: .user,
            dietaryPreferences: [],
            location: nil,
            joinedAt: Date(),
            followersCount: 0,
            followingCount: 0,
            postsCount: 0
        ))) {
            HStack(spacing: 12) {
                // Profile image
                AsyncImage(url: URL(string: user.avatarUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
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
                
                // Quick action button
                if user.clerkId != appState.currentUser?.clerkId {
                    QuickFollowButton(targetUser: User(
                        id: UUID(uuidString: user.clerkId) ?? UUID(),
                        email: "",
                        firstName: user.displayName?.components(separatedBy: " ").first ?? "",
                        lastName: user.displayName?.components(separatedBy: " ").dropFirst().joined(separator: " ") ?? "",
                        username: user.username ?? "",
                        displayName: user.displayName ?? "",
                        bio: user.bio ?? "",
                        avatarURL: user.avatarUrl != nil ? URL(string: user.avatarUrl!) : nil,
                        clerkId: user.clerkId,
                        role: .user,
                        dietaryPreferences: [],
                        location: nil,
                        joinedAt: Date(),
                        followersCount: 0,
                        followingCount: 0,
                        postsCount: 0
                    ))
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Suggested User Card
struct SuggestedUserCard: View {
    let user: BackendUser
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationLink(destination: ProfileView(targetUser: User(
            id: UUID(uuidString: user.clerkId) ?? UUID(),
            email: "",
            firstName: user.displayName?.components(separatedBy: " ").first ?? "",
            lastName: user.displayName?.components(separatedBy: " ").dropFirst().joined(separator: " ") ?? "",
            username: user.username ?? "",
            displayName: user.displayName ?? "",
            bio: user.bio ?? "",
            avatarURL: user.avatarUrl != nil ? URL(string: user.avatarUrl!) : nil,
            clerkId: user.clerkId,
            role: .user,
            dietaryPreferences: [],
            location: nil,
            joinedAt: Date(),
            followersCount: 0,
            followingCount: 0,
            postsCount: 0
        ))) {
            VStack(spacing: 8) {
                // Profile image
                AsyncImage(url: URL(string: user.avatarUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 60, height: 60)
                .clipShape(Circle())
                
                VStack(spacing: 2) {
                    Text(user.displayName ?? user.username ?? "Unknown")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                        .lineLimit(1)
                    
                    Text("@\(user.username ?? "unknown")")
                        .font(.caption2)
                        .foregroundColor(.secondaryText)
                        .lineLimit(1)
                }
                
                if user.clerkId != appState.currentUser?.clerkId {
                    QuickFollowButton(targetUser: User(
                        id: UUID(uuidString: user.clerkId) ?? UUID(),
                        email: "",
                        firstName: user.displayName?.components(separatedBy: " ").first ?? "",
                        lastName: user.displayName?.components(separatedBy: " ").dropFirst().joined(separator: " ") ?? "",
                        username: user.username ?? "",
                        displayName: user.displayName ?? "",
                        bio: user.bio ?? "",
                        avatarURL: user.avatarUrl != nil ? URL(string: user.avatarUrl!) : nil,
                        clerkId: user.clerkId,
                        role: .user,
                        dietaryPreferences: [],
                        location: nil,
                        joinedAt: Date(),
                        followersCount: 0,
                        followingCount: 0,
                        postsCount: 0
                    ))
                        .scaleEffect(0.8)
                }
            }
            .frame(width: 100)
            .padding(.vertical, 8)
            .background(Color.cardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - User Search ViewModel
@MainActor
class UserSearchViewModel: ObservableObject {
    @Published var searchResults: [BackendUser] = []
    @Published var suggestedUsers: [BackendUser] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasMore = true
    
    private let backendService = BackendService.shared
    private var currentPage = 1
    private let pageSize = 20
    private var currentQuery = ""
    
    func searchUsers(query: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            clearSearch()
            return
        }
        
        currentQuery = query
        currentPage = 1
        hasMore = true
        
        isLoading = true
        errorMessage = nil
        
        do {
            // For now, we'll search in the followers/following lists
            // In a real app, you'd have a dedicated user search endpoint
            let users = try await backendService.searchUsers(query: query, limit: pageSize)
            searchResults = users
            hasMore = users.count == pageSize
        } catch {
            errorMessage = "Failed to search users: \(error.localizedDescription)"
            print("❌ Error searching users: \(error)")
        }
        
        isLoading = false
    }
    
    func loadMoreResults() async {
        guard hasMore && !isLoading && !currentQuery.isEmpty else { return }
        
        currentPage += 1
        isLoading = true
        
        do {
            let newUsers = try await backendService.searchUsers(
                query: currentQuery,
                limit: pageSize
            )
            
            searchResults.append(contentsOf: newUsers)
            hasMore = newUsers.count == pageSize
        } catch {
            errorMessage = "Failed to load more users: \(error.localizedDescription)"
            currentPage -= 1 // Revert page increment
            print("❌ Error loading more users: \(error)")
        }
        
        isLoading = false
    }
    
    func refreshSearch() async {
        guard !currentQuery.isEmpty else { return }
        await searchUsers(query: currentQuery)
    }
    
    func clearSearch() {
        searchResults = []
        currentQuery = ""
        currentPage = 1
        hasMore = true
        errorMessage = nil
    }
    
    func loadSuggestedUsers() async {
        do {
            // Load suggested users (you might want to implement a specific endpoint for this)
            suggestedUsers = try await backendService.searchUsers(query: "", limit: 10)
        } catch {
            print("❌ Error loading suggested users: \(error)")
            // Don't show error for suggested users as it's not critical
        }
    }
}

// MARK: - Component Views

struct SearchBarSection: View {
    @Binding var searchText: String
    let onClear: () -> Void
    let onCancel: () -> Void
    let onSubmit: () -> Void
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.tertiaryText)
                
                TextField("Search users...", text: $searchText)
                    .focused($isFocused)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.primaryText)
                    .onSubmit(onSubmit)
                
                if !searchText.isEmpty {
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.tertiaryText)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.cardBackground)
            .cornerRadius(10)
            
            if isFocused {
                Button("Cancel", action: onCancel)
                    .foregroundColor(.primaryBrand)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

struct LoadingStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Searching users...")
                .font(.subheadline)
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct UserSearchEmptyStateView: View {
    let suggestedUsers: [BackendUser]
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.badge.gearshape")
                .font(.system(size: 60))
                .foregroundColor(.tertiaryText)
            
            VStack(spacing: 8) {
                Text("Discover People")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                Text("Search for users by name, username, or email to connect with friends and discover new food enthusiasts.")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if !suggestedUsers.isEmpty {
                SuggestedUsersSection(users: suggestedUsers)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SuggestedUsersSection: View {
    let users: [BackendUser]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggested for You")
                .font(.headline)
                .foregroundColor(.primaryText)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(users, id: \.clerkId) { user in
                        SuggestedUserCard(user: user)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct NoResultsStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 50))
                .foregroundColor(.tertiaryText)
            
            Text("No Users Found")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primaryText)
            
            Text("Try searching with a different name, username, or email address.")
                .font(.subheadline)
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SearchResultsListView: View {
    let searchResults: [BackendUser]
    let hasMore: Bool
    let isLoading: Bool
    let onLoadMore: () -> Void
    
    var body: some View {
        List {
            ForEach(searchResults, id: \.clerkId) { user in
                SearchResultUserRow(user: user)
                    .listRowBackground(Color.cardBackground)
                    .listRowSeparatorTint(Color.divider)
            }
            
            if hasMore && !isLoading {
                HStack {
                    Spacer()
                    Button("Load More", action: onLoadMore)
                        .font(.subheadline)
                        .foregroundColor(.primaryBrand)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        }
    }
} 

// MARK: - SwiftUI Previews
#Preview("User Search View") {
    NavigationStack {
        UserSearchView()
    }
    .environmentObject(MockAppState())
}

#Preview("Search Results") {
    let mockUsers = MockData.sampleUsers.prefix(3)
    
    NavigationStack {
        VStack {
            ForEach(Array(mockUsers), id: \.clerkId) { user in
                Text("User: \(user.displayName)")
                    .padding(.horizontal)
            }
            Spacer()
        }
    }
    .environmentObject(MockAppState())
}

#Preview("Search Bar Section") {
    @Previewable @State var searchText = "Sarah"
    
    VStack {
        SearchBarSection(
            searchText: $searchText,
            onClear: { searchText = "" },
            onCancel: { searchText = "" },
            onSubmit: { print("Search submitted") }
        )
        Spacer()
    }
    .padding()
} 