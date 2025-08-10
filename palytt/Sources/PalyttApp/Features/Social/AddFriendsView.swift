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
    
    enum FriendsTab {
        case suggested, search, nearby
        
        var title: String {
            switch self {
            case .suggested: return "Suggested"
            case .search: return "Search"
            case .nearby: return "Nearby"
            }
        }
        
        var icon: String {
            switch self {
            case .suggested: return "person.2"
            case .search: return "magnifyingglass"
            case .nearby: return "location"
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
                // Enhanced Search Bar
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondaryText)
                            .font(.system(size: 16))
                        
                        TextField("Search users...", text: $searchText)
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
                                searchText = ""
                                currentTab = .suggested
                                viewModel.clearSearch()
                                HapticManager.shared.impact(.light)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondaryText)
                                    .font(.system(size: 16))
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.cardBackground)
                    .cornerRadius(20)
                    
                    // Filters Button
                    Button(action: {
                        showingFilters = true
                        HapticManager.shared.impact(.light)
                    }) {
                        Image(systemName: hasActiveFilters ? "line.horizontal.3.decrease.circle.fill" : "line.horizontal.3.decrease.circle")
                            .foregroundColor(hasActiveFilters ? .primaryBrand : .secondaryText)
                            .font(.system(size: 20))
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                .onChange(of: searchText) { _, newValue in
                    searchDebounceTask?.cancel()
                    
                    if newValue.isEmpty {
                        viewModel.clearSearch()
                        currentTab = .suggested
                    } else {
                        currentTab = .search
                        searchDebounceTask = Task {
                            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                            if !Task.isCancelled && searchText == newValue {
                                await performSearch()
                            }
                        }
                    }
                }
                
                // Tab Picker
                HStack(spacing: 20) {
                    Button("Suggested") {
                        currentTab = .suggested
                        HapticManager.shared.impact(.light)
                        if viewModel.suggestedUsers.isEmpty {
                            Task {
                                await viewModel.loadSuggestedUsers()
                            }
                        }
                    }
                    .foregroundColor(currentTab == .suggested ? .primaryText : .secondaryText)
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(currentTab == .suggested ? Color.cardBackground : Color.clear)
                    .cornerRadius(20)
                    
                    Button("Search") {
                        currentTab = .search
                        HapticManager.shared.impact(.light)
                    }
                    .foregroundColor(currentTab == .search ? .primaryText : .secondaryText)
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(currentTab == .search ? Color.cardBackground : Color.clear)
                    .cornerRadius(20)
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                Divider()
                    .padding(.vertical, 8)
                
                // Content
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if currentTab == .suggested {
                            if viewModel.isLoadingSuggested {
                                ForEach(0..<5, id: \.self) { _ in
                                    UserRowSkeleton()
                                }
                            } else if viewModel.suggestedUsers.isEmpty {
                                EmptyStateView(
                                    icon: "person.2",
                                    title: "No Suggestions",
                                    message: "Check back later for friend suggestions"
                                )
                                .padding(.top, 60)
                            } else {
                                ForEach(viewModel.suggestedUsers, id: \.userId) { user in
                                    AddFriendUserRowView(
                                        user: user,
                                        buttonText: "Add Friend",
                                        buttonAction: {
                                            Task {
                                                await viewModel.sendFriendRequest(to: user)
                                            }
                                        }
                                    )
                                }
                            }
                        } else {
                            if viewModel.isSearching {
                                ForEach(0..<3, id: \.self) { _ in
                                    UserRowSkeleton()
                                }
                            } else if searchText.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 40))
                                        .foregroundColor(.milkTea)
                                    
                                    Text("Search for users")
                                        .font(.headline)
                                        .foregroundColor(.secondaryText)
                                    
                                    Text("Enter a username or display name to find users")
                                        .font(.subheadline)
                                        .foregroundColor(.tertiaryText)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.top, 60)
                            } else if viewModel.searchResults.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "person.fill.questionmark")
                                        .font(.system(size: 40))
                                        .foregroundColor(.milkTea)
                                    
                                    Text("No users found")
                                        .font(.headline)
                                        .foregroundColor(.secondaryText)
                                    
                                    Text("Try searching with a different username")
                                        .font(.subheadline)
                                        .foregroundColor(.tertiaryText)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.top, 60)
                            } else {
                                ForEach(viewModel.searchResults, id: \.userId) { user in
                                    AddFriendUserRowView(
                                        user: user,
                                        buttonText: "Add Friend",
                                        buttonAction: {
                                            Task {
                                                await viewModel.sendFriendRequest(to: user)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Add Friends")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        HapticManager.shared.impact(.light)
                        dismiss()
                    }
                    .foregroundColor(.primaryBrand)
                }
            }
            .sheet(isPresented: $showingFilters) {
                SearchFiltersView(filters: $searchFilters, onApply: {
                    if !searchText.isEmpty {
                        Task {
                            await performSearch()
                        }
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

// MARK: - User Row View
struct AddFriendUserRowView: View {
    let user: BackendUser
    let buttonText: String
    let buttonAction: () -> Void
    @State private var isLoading = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            BackendUserAvatar(user: user, size: 50)
            
            // User Info
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName ?? user.username ?? "Unknown User")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                Text("@\(user.username ?? "unknown")")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                
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
                HapticManager.shared.impact(.light)
                isLoading = true
                buttonAction()
                // Reset loading state after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    isLoading = false
                }
            }) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .primaryBrand))
                        .scaleEffect(0.8)
                        .frame(width: 80, height: 32)
                } else {
                    Text(buttonText)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.primaryBrand)
                        .cornerRadius(16)
                }
            }
            .disabled(isLoading)
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - User Row Skeleton
struct UserRowSkeleton: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar skeleton
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 50, height: 50)
                .shimmer(isAnimating: $isAnimating)
            
            // Info skeleton
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 120, height: 16)
                    .shimmer(isAnimating: $isAnimating)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 12)
                    .shimmer(isAnimating: $isAnimating)
            }
            
            Spacer()
            
            // Button skeleton
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 80, height: 32)
                .shimmer(isAnimating: $isAnimating)
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Add Friends View Model
@MainActor
class AddFriendsViewModel: ObservableObject {
    @Published var suggestedUsers: [BackendUser] = []
    @Published var searchResults: [BackendUser] = []
    @Published var isLoadingSuggested = false
    @Published var isSearching = false
    @Published var errorMessage: String?
    
    private let backendService = BackendService.shared
    
    func loadSuggestedUsers() async {
        isLoadingSuggested = true
        errorMessage = nil
        
        do {
            let users = try await backendService.getSuggestedUsers(limit: 20)
            suggestedUsers = users
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
                filteredUsers = filteredUsers.filter { $0.isVerified ?? false }
            }
            
            if !filters.dietaryPreferences.isEmpty {
                filteredUsers = filteredUsers.filter { user in
                    guard let userPreferences = user.dietaryPreferences else { return false }
                    return !Set(filters.dietaryPreferences).isDisjoint(with: Set(userPreferences))
                }
            }
            
            // TODO: Add location-based filtering for nearby users
            // if filters.includeNearby {
            //     filteredUsers = filterByLocation(filteredUsers, maxDistance: filters.maxDistance)
            // }
            
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
                // You could show a success message or update UI here
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