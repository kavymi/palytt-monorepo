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
                // Search Section with improved spacing
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
                    
                    // Spacer between search and content
                    Rectangle()
                        .fill(Color.background)
                        .frame(height: 24)
                }
                
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
            HStack(spacing: 16) {
                // Profile image with improved design
                AsyncImage(url: URL(string: user.avatarUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                                .font(.system(size: 24, weight: .medium))
                        )
                }
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.divider.opacity(0.3), lineWidth: 1)
                )
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(user.displayName ?? user.username ?? "Unknown User")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primaryText)
                        .lineLimit(1)
                    
                    Text("@\(user.username ?? "unknown")")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondaryText)
                        .lineLimit(1)
                    
                    if let bio = user.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.tertiaryText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                Spacer()
                
                // Quick action button with improved design
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
            .padding(.vertical, 12)
            .padding(.horizontal, 4)
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
            VStack(spacing: 12) {
                // Profile image with modern design
                AsyncImage(url: URL(string: user.avatarUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                                .font(.system(size: 28, weight: .medium))
                        )
                }
                .frame(width: 70, height: 70)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.divider.opacity(0.3), lineWidth: 1.5)
                )
                
                VStack(spacing: 4) {
                    Text(user.displayName ?? user.username ?? "Unknown")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primaryText)
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                    
                    Text("@\(user.username ?? "unknown")")
                        .font(.system(size: 12, weight: .regular))
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
                        .scaleEffect(0.85)
                }
            }
            .frame(width: 120, height: 160)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.cardBackground)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
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
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.tertiaryText)
                        .font(.system(size: 16, weight: .medium))
                    
                    TextField("Search users...", text: $searchText)
                        .focused($isFocused)
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(.primaryText)
                        .font(.system(size: 16, weight: .regular))
                        .onSubmit(onSubmit)
                    
                    if !searchText.isEmpty {
                        Button(action: onClear) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.tertiaryText)
                                .font(.system(size: 16, weight: .medium))
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isFocused ? Color.accentColor : Color.clear, lineWidth: 2)
                )
                .cornerRadius(12)
                
                if isFocused {
                    Button("Cancel", action: onCancel)
                        .foregroundColor(.primaryBrand)
                        .font(.system(size: 16, weight: .medium))
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // Subtle divider
            if !isFocused {
                Rectangle()
                    .fill(Color.divider.opacity(0.3))
                    .frame(height: 0.5)
                    .padding(.horizontal, 20)
            }
        }
        .background(Color.background)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isFocused)
        .animation(.easeInOut(duration: 0.2), value: searchText.isEmpty)
    }
}

struct LoadingStateView: View {
    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.4)
                .tint(.primaryBrand)
            
            Text("Searching users...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }
}

struct UserSearchEmptyStateView: View {
    let suggestedUsers: [BackendUser]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 24) {
                    Image(systemName: "person.2.badge.gearshape")
                        .font(.system(size: 72))
                        .foregroundColor(.tertiaryText)
                        .symbolRenderingMode(.hierarchical)
                    
                    VStack(spacing: 12) {
                        Text("Discover People")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primaryText)
                        
                        Text("Search for users by name, username, or email to connect with friends and discover new food enthusiasts.")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.secondaryText)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.top, 40)
                
                if !suggestedUsers.isEmpty {
                    SuggestedUsersSection(users: suggestedUsers)
                }
                
                Spacer(minLength: 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SuggestedUsersSection: View {
    let users: [BackendUser]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Suggested for You")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primaryText)
                Spacer()
            }
            .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(users, id: \.clerkId) { user in
                        SuggestedUserCard(user: user)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

struct NoResultsStateView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 64))
                .foregroundColor(.tertiaryText)
                .symbolRenderingMode(.hierarchical)
            
            VStack(spacing: 12) {
                Text("No Users Found")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primaryText)
                
                Text("Try searching with a different name, username, or email address.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }
}

struct SearchResultsListView: View {
    let searchResults: [BackendUser]
    let hasMore: Bool
    let isLoading: Bool
    let onLoadMore: () -> Void
    
    var body: some View {
        List {
            Section {
                ForEach(searchResults, id: \.clerkId) { user in
                    SearchResultUserRow(user: user)
                        .listRowBackground(Color.background)
                        .listRowSeparator(.hidden)
                        .padding(.vertical, 4)
                }
            }
            
            if hasMore && !isLoading {
                Section {
                    HStack {
                        Spacer()
                        Button("Load More") {
                            onLoadMore()
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primaryBrand)
                        .padding(.vertical, 12)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            } else if isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.primaryBrand)
                        Spacer()
                    }
                    .padding(.vertical, 16)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.background)
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
    NavigationStack {
        SearchResultsListView(
            searchResults: MockData.sampleUsers.prefix(5).map { user in
                BackendUser(
                    id: user.id.uuidString,
                    userId: user.id.uuidString,
                    clerkId: user.clerkId ?? "clerk_\(user.id.uuidString)",
                    email: user.email,
                    firstName: user.firstName,
                    lastName: user.lastName,
                    username: user.username,
                    displayName: "\(user.firstName ?? "") \(user.lastName ?? "")".trimmingCharacters(in: .whitespaces),
                    bio: user.bio,
                    avatarUrl: user.avatarURL?.absoluteString,
                    role: "user",
                    appleId: nil,
                    googleId: nil,
                    dietaryPreferences: [],
                    followersCount: 0,
                    followingCount: 0,
                    postsCount: 0,
                    isVerified: false,
                    isActive: true,
                    createdAt: Int(Date().timeIntervalSince1970),
                    updatedAt: Int(Date().timeIntervalSince1970)
                )
            },
            hasMore: true,
            isLoading: false,
            onLoadMore: {}
        )
    }
    .environmentObject(MockAppState())
}

#Preview("Suggested Users Section") {
    NavigationStack {
        VStack {
            SuggestedUsersSection(users: Array(MockData.sampleUsers.prefix(4).map { user in
                BackendUser(
                    id: user.id.uuidString,
                    userId: user.id.uuidString,
                    clerkId: user.clerkId ?? "clerk_\(user.id.uuidString)",
                    email: user.email,
                    firstName: user.firstName,
                    lastName: user.lastName,
                    username: user.username,
                    displayName: "\(user.firstName ?? "") \(user.lastName ?? "")".trimmingCharacters(in: .whitespaces),
                    bio: user.bio,
                    avatarUrl: user.avatarURL?.absoluteString,
                    role: "user",
                    appleId: nil,
                    googleId: nil,
                    dietaryPreferences: [],
                    followersCount: 0,
                    followingCount: 0,
                    postsCount: 0,
                    isVerified: false,
                    isActive: true,
                    createdAt: Int(Date().timeIntervalSince1970),
                    updatedAt: Int(Date().timeIntervalSince1970)
                )
            }))
            Spacer()
        }
    }
    .environmentObject(MockAppState())
}

#Preview("Empty State") {
    NavigationStack {
        UserSearchEmptyStateView(suggestedUsers: Array(MockData.sampleUsers.prefix(6).map { user in
            BackendUser(
                id: user.id.uuidString,
                userId: user.id.uuidString,
                clerkId: user.clerkId ?? "clerk_\(user.id.uuidString)",
                email: user.email,
                firstName: user.firstName,
                lastName: user.lastName,
                username: user.username,
                displayName: "\(user.firstName ?? "") \(user.lastName ?? "")".trimmingCharacters(in: .whitespaces),
                bio: user.bio,
                avatarUrl: user.avatarURL?.absoluteString,
                role: "user",
                appleId: nil,
                googleId: nil,
                dietaryPreferences: [],
                followersCount: 0,
                followingCount: 0,
                postsCount: 0,
                isVerified: false,
                isActive: true,
                createdAt: Int(Date().timeIntervalSince1970),
                updatedAt: Int(Date().timeIntervalSince1970)
            )
        }))
    }
    .environmentObject(MockAppState())
}

#Preview("No Results State") {
    NavigationStack {
        NoResultsStateView()
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