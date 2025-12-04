//
//  AddFriendsView.swift
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

struct AddFriendsView: View {
    @StateObject private var viewModel = AddFriendsViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var currentTab: FriendsTab = .suggested
    @State private var showingFilters = false
    @State private var searchFilters = SearchFilters()
    @FocusState private var isSearchFocused: Bool
    @State private var searchDebounceTask: Task<Void, Never>?
    @Namespace private var tabAnimation
    
    enum FriendsTab: CaseIterable {
        case suggested, contacts, search
        
        var title: String {
            switch self {
            case .suggested: return "For You"
            case .contacts: return "Contacts"
            case .search: return "Search"
            }
        }
        
        var icon: String {
            switch self {
            case .suggested: return "sparkles"
            case .contacts: return "person.crop.rectangle.stack"
            case .search: return "magnifyingglass"
            }
        }
        
        var description: String {
            switch self {
            case .suggested: return "People you may know"
            case .contacts: return "Find friends from contacts"
            case .search: return "Search by username"
            }
        }
    }
    
    struct SearchFilters {
        var onlyVerified = false
        var maxDistance: Double = 50.0 // km
        var includeNearby = false
        var dietaryPreferences: [String] = []
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Hero Header with Search
                headerSection
                
                // Tab Navigation
                tabNavigationSection
                
                // Content
                contentSection
            }
            .background(Color.appBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Add Friends")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        HapticManager.shared.impact(.light)
                        dismiss()
                    }
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryBrand)
                }
            }
            .sheet(isPresented: $showingFilters) {
                SearchFiltersView(filters: $searchFilters, onApply: {
                    if !searchText.isEmpty {
                        performSearch()
                    }
                })
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .onAppear {
                Task {
                    await viewModel.loadSuggestedUsers()
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Search Bar
            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondaryText)
                        .font(.system(size: 17, weight: .medium))
                    
                    TextField("Search by name or username", text: $searchText)
                        .foregroundColor(.primaryText)
                        .font(.system(size: 16))
                        .textFieldStyle(PlainTextFieldStyle())
                        .focused($isSearchFocused)
                        .submitLabel(.search)
                        .onSubmit {
                            performSearch()
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                searchText = ""
                                currentTab = .suggested
                                viewModel.clearSearch()
                            }
                            HapticManager.shared.impact(.light)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.tertiaryText)
                                .font(.system(size: 18))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.cardBackground)
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
                )
                
                // Filters Button
                Button(action: {
                    showingFilters = true
                    HapticManager.shared.impact(.light)
                }) {
                    ZStack {
                        Circle()
                            .fill(hasActiveFilters ? Color.primaryBrand.opacity(0.15) : Color.cardBackground)
                            .frame(width: 44, height: 44)
                            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
                        
                        Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "slider.horizontal.3")
                            .foregroundColor(hasActiveFilters ? .primaryBrand : .secondaryText)
                            .font(.system(size: 18, weight: .medium))
                    }
                }
            }
            .padding(.horizontal, 20)
            .onChange(of: searchText) { _, newValue in
                searchDebounceTask?.cancel()
                
                if newValue.isEmpty {
                    viewModel.clearSearch()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        currentTab = .suggested
                    }
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        currentTab = .search
                    }
                    searchDebounceTask = Task {
                        try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
                        if !Task.isCancelled && searchText == newValue {
                            performSearch()
                        }
                    }
                }
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    // MARK: - Tab Navigation
    
    private var tabNavigationSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(FriendsTab.allCases, id: \.self) { tab in
                    TabButton(
                        tab: tab,
                        isSelected: currentTab == tab,
                        namespace: tabAnimation
                    ) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            currentTab = tab
                        }
                        HapticManager.shared.impact(.light)
                        if tab == .suggested && viewModel.suggestedUsers.isEmpty {
                            Task {
                                await viewModel.loadSuggestedUsers()
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }
    
    // MARK: - Content Section
    
    @ViewBuilder
    private var contentSection: some View {
        switch currentTab {
        case .suggested:
            suggestedContent
        case .contacts:
            ContactsSyncView()
        case .search:
            searchContent
        }
    }
    
    // MARK: - Suggested Content
    
    @ViewBuilder
    private var suggestedContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if viewModel.isLoadingSuggested {
                    ForEach(0..<5, id: \.self) { index in
                        UserRowSkeleton()
                            .padding(.horizontal, 20)
                            .padding(.vertical, 6)
                    }
                } else if viewModel.suggestedUsers.isEmpty {
                    SuggestedEmptyState()
                        .padding(.top, 40)
                } else {
                    // Section header
                    HStack {
                        Text("People you may know")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondaryText)
                        Spacer()
                        Button(action: {
                            Task {
                                await viewModel.loadSuggestedUsers()
                            }
                            HapticManager.shared.impact(.light)
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primaryBrand)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    
                    ForEach(Array(viewModel.suggestedUsers.enumerated()), id: \.element.user.userId) { index, suggestion in
                        EnhancedAddFriendUserRowView(
                            suggestion: suggestion,
                            buttonText: "Add",
                            buttonAction: {
                                Task {
                                    await viewModel.sendFriendRequest(to: suggestion.user)
                                }
                            }
                        )
                        .padding(.horizontal, 20)
                        .padding(.vertical, 6)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity.combined(with: .scale(scale: 0.95))
                        ))
                    }
                }
            }
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Search Content
    
    @ViewBuilder
    private var searchContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if viewModel.isSearching {
                    ForEach(0..<3, id: \.self) { _ in
                        UserRowSkeleton()
                            .padding(.horizontal, 20)
                            .padding(.vertical, 6)
                    }
                } else if searchText.isEmpty {
                    SearchEmptyState()
                        .padding(.top, 60)
                } else if viewModel.searchResults.isEmpty {
                    NoResultsState(searchQuery: searchText)
                        .padding(.top, 60)
                } else {
                    // Results header
                    HStack {
                        Text("\(viewModel.searchResults.count) result\(viewModel.searchResults.count == 1 ? "" : "s")")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondaryText)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    
                    ForEach(viewModel.searchResults, id: \.userId) { user in
                        AddFriendUserRowView(
                            user: user,
                            buttonText: "Add",
                            buttonAction: {
                                Task {
                                    await viewModel.sendFriendRequest(to: user)
                                }
                            }
                        )
                        .padding(.horizontal, 20)
                        .padding(.vertical, 6)
                    }
                }
            }
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Helper Methods
    
    private var hasActiveFilters: Bool {
        searchFilters.onlyVerified || 
        searchFilters.includeNearby || 
        !searchFilters.dietaryPreferences.isEmpty
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            viewModel.clearSearch()
            return
        }
        
        currentTab = .search
        Task {
            await viewModel.searchUsers(query: searchText, filters: searchFilters)
        }
    }
}

// MARK: - Tab Button

private struct TabButton: View {
    let tab: AddFriendsView.FriendsTab
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14, weight: .semibold))
                
                Text(tab.title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : .secondaryText)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.primaryBrand)
                        .matchedGeometryEffect(id: "tab_background", in: namespace)
                        .shadow(color: Color.primaryBrand.opacity(0.3), radius: 8, x: 0, y: 4)
                } else {
                    Capsule()
                        .fill(Color.cardBackground)
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Scale Button Style

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Empty States

private struct SuggestedEmptyState: View {
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.primaryBrand.opacity(0.15), Color.primaryBrand.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primaryBrand, .primaryBrand.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text("No Suggestions Yet")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                Text("We're finding people you might know.\nCheck back soon!")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            // Invite friends CTA
            Button(action: {
                HapticManager.shared.impact(.medium)
                // Could trigger share/invite flow
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Invite Friends")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.primaryBrand)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .strokeBorder(Color.primaryBrand, lineWidth: 1.5)
                )
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 32)
    }
}

private struct SearchEmptyState: View {
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.milkTea.opacity(0.15))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(.milkTea)
            }
            
            VStack(spacing: 8) {
                Text("Find Your Friends")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                Text("Search by username or display name\nto find people on Palytt")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
        .padding(.horizontal, 32)
    }
}

private struct NoResultsState: View {
    let searchQuery: String
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.secondaryText.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "person.fill.questionmark")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(.secondaryText)
            }
            
            VStack(spacing: 8) {
                Text("No Results")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                Text("We couldn't find anyone matching\n\"\(searchQuery)\"")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            // Try different search suggestion
            VStack(spacing: 12) {
                Text("Try searching for:")
                    .font(.caption)
                    .foregroundColor(.tertiaryText)
                
                HStack(spacing: 8) {
                    SuggestionChip(text: "Full name")
                    SuggestionChip(text: "Username")
                }
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 32)
    }
}

private struct SuggestionChip: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.secondaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.cardBackground)
            )
    }
}

// MARK: - User Row View
struct EnhancedAddFriendUserRowView: View {
    let suggestion: EnhancedUserSuggestion
    let buttonText: String
    let buttonAction: () -> Void
    @State private var isLoading = false
    @State private var requestSent = false
    
    var user: BackendUser { suggestion.user }
    
    var body: some View {
        HStack(spacing: 14) {
            // Avatar with status indicator
            ZStack(alignment: .bottomTrailing) {
                BackendUserAvatar(user: user, size: 54)
                
                // Mutual friends indicator
                if suggestion.mutualFriendsCount > 0 {
                    Circle()
                        .fill(Color.primaryBrand)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Text("\(min(suggestion.mutualFriendsCount, 9))\(suggestion.mutualFriendsCount > 9 ? "+" : "")")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .offset(x: 4, y: 4)
                }
            }
            
            // User Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(user.displayName ?? user.username ?? "Unknown User")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                        .lineLimit(1)
                    
                    if user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.primaryBrand)
                    }
                }
                
                Text("@\(user.username ?? "unknown")")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                    .lineLimit(1)
                
                // Connection context
                if suggestion.mutualFriendsCount > 0 {
                    Text("\(suggestion.mutualFriendsCount) mutual friend\(suggestion.mutualFriendsCount == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundColor(.primaryBrand)
                        .fontWeight(.medium)
                } else if suggestion.connectionReason == "new_user" {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 10))
                        Text("New to Palytt")
                    }
                    .font(.caption2)
                    .foregroundColor(.matchaGreen)
                    .fontWeight(.medium)
                }
            }
            
            Spacer()
            
            // Action Button
            Button(action: {
                guard !requestSent else { return }
                HapticManager.shared.impact(.medium)
                isLoading = true
                buttonAction()
                // Animate to sent state
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isLoading = false
                        requestSent = true
                    }
                }
            }) {
                Group {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.7)
                    } else if requestSent {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                            Text("Sent")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    } else {
                        Text(buttonText)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
                .foregroundColor(requestSent ? .matchaGreen : .white)
                .frame(width: 72, height: 34)
                .background(
                    Capsule()
                        .fill(requestSent ? Color.matchaGreen.opacity(0.15) : Color.primaryBrand)
                )
            }
            .disabled(isLoading || requestSent)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: requestSent)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cardBackground)
                .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
        )
    }
}

struct AddFriendUserRowView: View {
    let user: BackendUser
    let buttonText: String
    let buttonAction: () -> Void
    @State private var isLoading = false
    @State private var requestSent = false
    
    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            BackendUserAvatar(user: user, size: 54)
            
            // User Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(user.displayName ?? user.username ?? "Unknown User")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                        .lineLimit(1)
                    
                    if user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.primaryBrand)
                    }
                }
                
                Text("@\(user.username ?? "unknown")")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                    .lineLimit(1)
                
                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.caption)
                        .foregroundColor(.tertiaryText)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Action Button
            Button(action: {
                guard !requestSent else { return }
                HapticManager.shared.impact(.medium)
                isLoading = true
                buttonAction()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isLoading = false
                        requestSent = true
                    }
                }
            }) {
                Group {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.7)
                    } else if requestSent {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                            Text("Sent")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    } else {
                        Text(buttonText)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
                .foregroundColor(requestSent ? .matchaGreen : .white)
                .frame(width: 72, height: 34)
                .background(
                    Capsule()
                        .fill(requestSent ? Color.matchaGreen.opacity(0.15) : Color.primaryBrand)
                )
            }
            .disabled(isLoading || requestSent)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: requestSent)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cardBackground)
                .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - User Row Skeleton
struct UserRowSkeleton: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 14) {
            // Avatar skeleton
            Circle()
                .fill(Color.gray.opacity(0.15))
                .frame(width: 54, height: 54)
                .shimmer(isAnimating: $isAnimating)
            
            // Info skeleton
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 130, height: 14)
                    .shimmer(isAnimating: $isAnimating)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 90, height: 12)
                    .shimmer(isAnimating: $isAnimating)
            }
            
            Spacer()
            
            // Button skeleton
            Capsule()
                .fill(Color.gray.opacity(0.15))
                .frame(width: 72, height: 34)
                .shimmer(isAnimating: $isAnimating)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cardBackground)
        )
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Add Friends View Model
// Enhanced user struct to include mutual friends info
struct EnhancedUserSuggestion {
    let user: BackendUser
    let mutualFriendsCount: Int
    let connectionReason: String
}

@MainActor
class AddFriendsViewModel: ObservableObject {
    @Published var suggestedUsers: [EnhancedUserSuggestion] = []
    @Published var searchResults: [BackendUser] = []
    @Published var isLoadingSuggested = false
    @Published var isSearching = false
    @Published var errorMessage: String?
    
    private let backendService = BackendService.shared
    
    func loadSuggestedUsers() async {
        isLoadingSuggested = true
        errorMessage = nil
        
        do {
            let response = try await backendService.getFriendSuggestions(limit: 20, excludeRequested: true)
            suggestedUsers = response.suggestions.map { suggestion in
                let user = BackendUser(
                    id: suggestion.id,
                    userId: nil,
                    clerkId: suggestion.clerkId,
                    email: nil,
                    firstName: nil,
                    lastName: nil,
                    username: suggestion.username,
                    displayName: suggestion.name,
                    bio: suggestion.bio,
                    avatarUrl: suggestion.profileImage,
                    role: nil,
                    appleId: nil,
                    googleId: nil,
                    dietaryPreferences: nil,
                    followersCount: suggestion.followerCount,
                    followingCount: 0,
                    postsCount: 0,
                    isVerified: false,
                    isActive: true,
                    createdAt: 0,
                    updatedAt: 0
                )
                return EnhancedUserSuggestion(
                    user: user,
                    mutualFriendsCount: suggestion.mutualFriendsCount,
                    connectionReason: suggestion.connectionReason
                )
            }
        } catch {
            errorMessage = "Failed to load suggested users: \(error.localizedDescription)"
            print("❌ Failed to load suggested users: \(error)")
        }
        
        isLoadingSuggested = false
    }
    
    func searchUsers(query: String, filters: AddFriendsView.SearchFilters) async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        errorMessage = nil
        
        do {
            let users = try await backendService.searchBackendUsers(query: query, limit: 20)
            
            // Apply filters
            var filteredUsers = users
            
            if filters.onlyVerified {
                filteredUsers = filteredUsers.filter { $0.isVerified }
            }
            
            if !filters.dietaryPreferences.isEmpty {
                filteredUsers = filteredUsers.filter { user in
                    guard let userPreferences = user.dietaryPreferences else { return false }
                    return !Set(filters.dietaryPreferences).isDisjoint(with: Set(userPreferences))
                }
            }
            
            searchResults = filteredUsers
        } catch {
            errorMessage = "Failed to search users: \(error.localizedDescription)"
            searchResults = []
            print("❌ Failed to search users: \(error)")
        }

        isSearching = false
    }
    
    func sendFriendRequest(to user: BackendUser) async {
        guard let currentUser = Clerk.shared.user else {
            errorMessage = "You must be logged in to send friend requests"
            return
        }
        
        do {
            let response = try await backendService.sendFriendRequest(
                senderId: currentUser.id,
                receiverId: user.clerkId
            )
            
            if response.success {
                HapticManager.shared.impact(.success)
                print("✅ Friend request sent to \(user.username ?? "unknown")")
            } else {
                errorMessage = response.message ?? "Failed to send friend request"
            }
            
        } catch {
            errorMessage = "Failed to send friend request: \(error.localizedDescription)"
            print("❌ Failed to send friend request: \(error)")
        }
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    func clearSearch() {
        searchResults = []
        isSearching = false
    }
}

#Preview {
    AddFriendsView()
} 

// MARK: - Search Filters View

struct SearchFiltersView: View {
    typealias SearchFilters = AddFriendsView.SearchFilters
    @Binding var filters: SearchFilters
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    private let dietaryOptions = [
        "Vegetarian", "Vegan", "Gluten-Free", "Dairy-Free", 
        "Keto", "Paleo", "Halal", "Kosher"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("User Preferences") {
                    Toggle("Verified users only", isOn: $filters.onlyVerified)
                        .toggleStyle(SwitchToggleStyle(tint: .primaryBrand))
                }
                
                Section("Location") {
                    Toggle("Include nearby users", isOn: $filters.includeNearby)
                        .toggleStyle(SwitchToggleStyle(tint: .primaryBrand))
                    
                    if filters.includeNearby {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Maximum distance: \(Int(filters.maxDistance)) km")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                            
                            Slider(value: $filters.maxDistance, in: 1...100, step: 1)
                                .tint(.primaryBrand)
                        }
                    }
                }
                
                Section("Dietary Preferences") {
                    ForEach(dietaryOptions, id: \.self) { option in
                        HStack {
                            Text(option)
                            Spacer()
                            if filters.dietaryPreferences.contains(option) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.primaryBrand)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if filters.dietaryPreferences.contains(option) {
                                filters.dietaryPreferences.removeAll { $0 == option }
                            } else {
                                filters.dietaryPreferences.append(option)
                            }
                            HapticManager.shared.impact(.light)
                        }
                    }
                }
                
                Section {
                    Button("Clear All Filters") {
                        filters = SearchFilters()
                        HapticManager.shared.impact(.medium)
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Search Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        onApply()
                        dismiss()
                        HapticManager.shared.impact(.medium)
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryBrand)
                }
            }
        }
    }
}
