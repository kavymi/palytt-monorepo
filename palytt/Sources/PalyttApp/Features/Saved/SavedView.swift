//
//  SavedView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI
import Clerk

// MARK: - Saved Tab Enum

enum SavedTab: Int, CaseIterable {
    case all = 0
    case posts = 1
    
    var title: String {
        switch self {
        case .all: return "Lists"
        case .posts: return "Posts"
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .posts: return "square.on.square"
        }
    }
}

struct SavedView: View {
    @StateObject private var viewModel = SavedViewModel()
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: SavedTab = .all
    @State private var showingCreateList = false
    @State private var isGridView = false
    @State private var showingSearchSheet = false
    @State private var searchText = ""
    @State private var showingShareSheet = false
    @State private var shareContent: [Any] = []
    @State private var selectedListForSharing: SavedList?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab Selector
                Picker("Content Type", selection: $selectedTab) {
                    Text("Lists").tag(0)
                    Text("Posts").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Tab Content
                switch selectedTab {
                case .all:
                    SavedListsView(
                        viewModel: viewModel, 
                        showCreateList: $showingCreateList,
                        onShareList: shareList
                    )
                case .posts:
                    SavedPostsView(viewModel: viewModel)
                }
            }
            .background(Color.background)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationTitle("My saved")
            .toolbar {
                // Create List Button (Top Left) - Only show on Lists tab
                if selectedTab == .all {
                    #if os(iOS)
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { 
                            HapticManager.shared.impact(.light)
                            showingCreateList = true 
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.primaryBrand)
                                .clipShape(Circle())
                        }
                    }
                    #else
                    ToolbarItem(placement: .automatic) {
                        Button(action: { 
                            HapticManager.shared.impact(.light)
                            showingCreateList = true 
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.primaryBrand)
                                .clipShape(Circle())
                        }
                    }
                    #endif
                }
                
                // Sort Menu (Top Right)
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { viewModel.sortBy = .recent }) {
                            Label("Most Recent", systemImage: viewModel.sortBy == .recent ? "checkmark" : "")
                        }
                        // Only show rating options for Posts tab
                        if selectedTab == .posts {
                            Button(action: { viewModel.sortBy = .rating }) {
                                Label("Highest Rated", systemImage: viewModel.sortBy == .rating ? "checkmark" : "")
                            }
                            Button(action: { viewModel.sortBy = .lowestRated }) {
                                Label("Lowest Rated", systemImage: viewModel.sortBy == .lowestRated ? "checkmark" : "")
                            }
                        }
                        // Only show Ascending/Descending for Lists tab (not Posts)
                        if selectedTab == .all {
                            Button(action: { viewModel.sortBy = .ascending }) {
                                Label("Ascending", systemImage: viewModel.sortBy == .ascending ? "checkmark" : "")
                            }
                            Button(action: { viewModel.sortBy = .descending }) {
                                Label("Descending", systemImage: viewModel.sortBy == .descending ? "checkmark" : "")
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundColor(.primaryBrand)
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Menu {
                        Button(action: { viewModel.sortBy = .recent }) {
                            Label("Most Recent", systemImage: viewModel.sortBy == .recent ? "checkmark" : "")
                        }
                        // Only show rating options for Posts tab
                        if selectedTab == .posts {
                            Button(action: { viewModel.sortBy = .rating }) {
                                Label("Highest Rated", systemImage: viewModel.sortBy == .rating ? "checkmark" : "")
                            }
                            Button(action: { viewModel.sortBy = .lowestRated }) {
                                Label("Lowest Rated", systemImage: viewModel.sortBy == .lowestRated ? "checkmark" : "")
                            }
                        }
                        // Only show Ascending/Descending for Lists tab (not Posts)
                        if selectedTab == .all {
                            Button(action: { viewModel.sortBy = .ascending }) {
                                Label("Ascending", systemImage: viewModel.sortBy == .ascending ? "checkmark" : "")
                            }
                            Button(action: { viewModel.sortBy = .descending }) {
                                Label("Descending", systemImage: viewModel.sortBy == .descending ? "checkmark" : "")
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundColor(.primaryBrand)
                    }
                }
                #endif
            }
            .sheet(isPresented: $showingCreateList) {
                CreateListView(onListCreated: { list in
                    viewModel.userLists.append(list)
                })
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(activityItems: shareContent)
            }
            .onAppear {
                Task {
                    await viewModel.loadSavedContent()
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func shareList(_ list: SavedList) {
        selectedListForSharing = list
        generateShareContent(for: list)
        showingShareSheet = true
        
        // Track the share action
        Task {
            await trackListShare(list)
        }
    }
    
    private func generateShareContent(for list: SavedList) {
        let listURL = generateListShareURL(for: list)
        let message = """
        Check out my food list "\(list.name)" on Palytt! 🍴
        
        \(list.description ?? "A collection of amazing food spots I've discovered.")
        
        \(list.postCount) amazing places to explore!
        
        \(listURL)
        """
        
        shareContent = [message, URL(string: listURL)].compactMap { $0 }
    }
    
    private func generateListShareURL(for list: SavedList) -> String {
        // Generate a deep link URL for the list
        let baseURL = "https://palytt.com/list"
        let listId = list.convexId ?? list.id
        return "\(baseURL)/\(listId)"
    }
    
    private func trackListShare(_ list: SavedList) async {
        // TODO: Implement list share tracking when public API is available
        // Currently commented out due to private performTRPCMutation method
        print("📊 List shared: \(list.name)")
    }
}

// MARK: - Saved Lists View
struct SavedListsView: View {
    @ObservedObject var viewModel: SavedViewModel
    @Binding var showCreateList: Bool
    let onShareList: (SavedList) -> Void
    
    var body: some View {
        Group {
            if viewModel.userLists.isEmpty {
                // Temporarily comment out EmptyStateView
                // EmptyStateView(
                //     icon: "folder",
                //     title: "No Lists Yet",
                //     message: "Create lists to organize your saved posts"
                // )
                VStack {
                    Image(systemName: "folder")
                        .font(.system(size: 40))
                        .foregroundColor(.milkTea)
                    Text("No Lists Yet")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Create lists to organize your saved posts")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if viewModel.isLoading {
                // Show skeleton loaders while loading
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(0..<4, id: \.self) { _ in
                            // Temporarily comment out ListCardSkeleton
                            // ListCardSkeleton()
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 100)
                        }
                    }
                    .padding()
                }
                .background(Color.background)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // User Lists (sorted)
                        ForEach(viewModel.sortedUserLists) { list in
                            NavigationLink(destination: ListDetailView(list: list)) {
                                ListCard(list: list, viewModel: viewModel, onShareList: onShareList)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
                .background(Color.background)
            }
        }
    }
}

// MARK: - List Card
struct ListCard: View {
    let list: SavedList
    @ObservedObject var viewModel: SavedViewModel
    let onShareList: (SavedList) -> Void
    @State private var showRenameAlert = false
    @State private var showDeleteAlert = false
    @State private var newListName = ""
    
    // Get the current list from viewModel to ensure we have the latest state
    private var currentList: SavedList? {
        viewModel.userLists.first { $0.id == list.id }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Cover Image
            if let coverImageURL = list.coverImageURL {
                AsyncImage(url: coverImageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(ProgressView())
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient.primaryGradient.opacity(0.3))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Text(list.name.prefix(2).uppercased())
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primaryBrand)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(currentList?.name ?? list.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if currentList?.isPrivate ?? list.isPrivate {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                }
                
                if let description = currentList?.description ?? list.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .lineLimit(2)
                }
                
                HStack {
                    Text("\(currentList?.postCount ?? list.postCount) posts")
                        .font(.caption2)
                        .foregroundColor(.tertiaryText)
                    
                    Spacer()
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                // Menu Button
                Menu {
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        onShareList(currentList ?? list)
                    }) {
                        Label("Share List", systemImage: "square.and.arrow.up")
                    }
                    
                    Divider()
                    
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        viewModel.toggleListPrivacy(list)
                    }) {
                        let isPrivate = currentList?.isPrivate ?? list.isPrivate
                        Label(isPrivate ? "Make Public" : "Make Private", 
                              systemImage: isPrivate ? "globe" : "lock")
                    }
                    
                    Button(action: {
                        newListName = currentList?.name ?? list.name
                        showRenameAlert = true
                    }) {
                        Label("Rename", systemImage: "pencil")
                    }
                    
                    Button(action: {
                        showDeleteAlert = true
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                    .foregroundColor(.red)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title3)
                        .foregroundColor(.secondaryText)
                        .frame(width: 24, height: 24)
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .alert("Rename List", isPresented: $showRenameAlert) {
            TextField("List name", text: $newListName)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                if !newListName.isEmpty {
                    viewModel.renameList(list, to: newListName)
                }
            }
        } message: {
            Text("Enter a new name for your list")
        }
        .alert("Delete List", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.deleteList(list)
            }
        } message: {
            Text("Are you sure you want to delete '\(currentList?.name ?? list.name)'? This action cannot be undone.")
        }
    }
}

// MARK: - List Detail View
struct ListDetailView: View {
    let list: SavedList
    @State private var posts: [Post] = []
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(posts) { post in
                    PostCard(post: post)
                }
            }
            .padding()
        }
        .background(Color.background)
        .navigationTitle(list.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationBarBackButtonHidden(true)
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primaryBrand)
                }
            }
            #else
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primaryBrand)
                }
            }
            #endif
        }
        .onAppear {
            loadPosts()
        }
    }
    
    private func loadPosts() {
        Task {
            // TODO: Load posts for this list from backend
            // For now, show empty until API is implemented
            posts = []
            print("ℹ️ List posts API not yet implemented")
        }
    }
}

// MARK: - Saved Posts View
struct SavedPostsView: View {
    @ObservedObject var viewModel: SavedViewModel
    
    var body: some View {
        if viewModel.savedPosts.isEmpty {
            // Temporarily comment out EmptyStateView
            // EmptyStateView(
            //     icon: "bookmark",
            //     title: "No Saved Posts",
            //     message: "Posts you save will appear here"
            // )
            VStack {
                Image(systemName: "bookmark")
                    .font(.system(size: 40))
                    .foregroundColor(.milkTea)
                Text("No Saved Posts")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("Posts you save will appear here")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 12) {
                    ForEach(viewModel.sortedSavedPosts) { post in
                        SavedPostCard(post: post)
                    }
                }
                .padding()
            }
            .background(Color.background)
        }
    }
}

// MARK: - Saved Post Card
struct SavedPostCard: View {
    let post: Post
    
    var body: some View {
        NavigationLink(destination: PostDetailView(post: post)) {
            VStack(alignment: .leading, spacing: 8) {
                // Post Image
                if let firstImageURL = post.mediaURLs.first {
                    AsyncImage(url: firstImageURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .overlay(ProgressView())
                    }
                    .frame(height: 160)
                    .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 160)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    if let shop = post.shop {
                        Text(shop.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                    }
                    
                    Text(post.caption)
                        .font(.caption2)
                        .foregroundColor(.secondaryText)
                        .lineLimit(2)
                    
                    if let rating = post.rating {
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= Int(rating) ? "star.fill" : "star")
                                    .font(.system(size: 10))
                                    .foregroundColor(.warning)
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .background(Color.cardBackground)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - View Model
@MainActor
class SavedViewModel: ObservableObject {
    @Published var userLists: [SavedList] = []
    @Published var savedPosts: [Post] = []
    @Published var savedShops: [Shop] = []
    @Published var sortBy: SortOption = .recent {
        didSet {
            print("🔄 Sort option changed from \(oldValue) to \(sortBy)")
        }
    }
    @Published var isLoading = false
    
    init() {
        // Listen for bookmark changes
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("BookmarkChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🔄 SavedViewModel: Received BookmarkChanged notification, refreshing saved posts...")
            Task {
                await self?.refreshSavedPosts()
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    enum SortOption {
        case recent, rating, lowestRated, ascending, descending
    }
    
    // Computed property for sorted lists
    var sortedUserLists: [SavedList] {
        let result: [SavedList]
        switch sortBy {
        case .recent:
            result = userLists.sorted { $0.updatedAt > $1.updatedAt }
        case .ascending:
            result = userLists.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .descending:
            result = userLists.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        case .rating, .lowestRated:
            // For lists, fall back to recent sorting if rating options are somehow selected
            result = userLists.sorted { $0.updatedAt > $1.updatedAt }
        }
        
        print("📋 Lists sorted by \(sortBy): \(result.map { $0.name }.joined(separator: " → "))")
        return result
    }
    
    // Computed property for sorted posts
    var sortedSavedPosts: [Post] {
        let result: [Post]
        switch sortBy {
        case .recent:
            result = savedPosts.sorted { $0.createdAt > $1.createdAt }
        case .rating:
            result = savedPosts.sorted { 
                let rating1 = $0.rating ?? 0.0
                let rating2 = $1.rating ?? 0.0
                if rating1 == rating2 {
                    return $0.createdAt > $1.createdAt // Secondary sort by date
                }
                return rating1 > rating2
            }
        case .lowestRated:
            result = savedPosts.sorted { 
                let rating1 = $0.rating ?? 0.0
                let rating2 = $1.rating ?? 0.0
                if rating1 == rating2 {
                    return $0.createdAt > $1.createdAt // Secondary sort by date
                }
                return rating1 < rating2
            }
        case .ascending, .descending:
            // For posts, fall back to recent sorting if alphabetical options are somehow selected
            result = savedPosts.sorted { $0.createdAt > $1.createdAt }
        }
        
        print("📝 Posts sorted by \(sortBy): \(result.map { "\($0.caption.prefix(15))...(\($0.rating ?? 0.0))" }.joined(separator: " → "))")
        return result
    }
    
    func loadSavedContent() async {
        isLoading = true
        
        do {
            // Load bookmarked posts from backend
            let backendPosts = try await BackendService.shared.getBookmarkedPosts()
            
            // Convert BackendPost to Post using the existing conversion method
            savedPosts = backendPosts.map { backendPost in
                var post = Post.from(backendPost: backendPost)
                post.isSaved = true // Mark as saved since these are bookmarked posts
                return post
            }
            
            print("✅ Loaded \(savedPosts.count) bookmarked posts from backend")
            
        } catch {
            print("❌ Failed to load bookmarked posts: \(error)")
            savedPosts = [] // Fallback to empty array
        }
        
        // Load saved lists from backend
        do {
            guard let currentUserId = getCurrentUserId() else {
                print("⚠️ No current user ID available for loading lists")
                userLists = []
                return
            }
            
            let backendLists = try await BackendService.shared.getUserLists(userId: currentUserId)
            
            // Convert BackendList to SavedList model
            userLists = backendLists.map { backendList in
                SavedList(
                    id: UUID().uuidString,
                    convexId: backendList._id,
                    name: backendList.name,
                    description: backendList.description,
                    coverImageURL: nil as URL?, // Not available in backend model
                    userId: currentUserId,
                    postIds: [], // Would need separate call to load posts
                    isPrivate: backendList.isPrivate,
                    createdAt: Date(timeIntervalSince1970: Double(backendList.createdAt) / 1000),
                    updatedAt: Date(timeIntervalSince1970: Double(backendList.updatedAt) / 1000)
                )
            }
            
            print("✅ Loaded \(userLists.count) saved lists from backend")
            
        } catch {
            print("❌ Failed to load saved lists: \(error)")
            userLists = [] // Fallback to empty array
        }
        
        // Initialize savedShops as empty array for now
        savedShops = []
        
        print("🔄 Saved content loaded:")
        print("📋 Lists: \(userLists.map { "\($0.name) (updated: \($0.updatedAt.formatted(.dateTime.month().day())))" }.joined(separator: ", "))")
        print("📝 Posts: \(savedPosts.map { "\($0.caption.prefix(20))... (rating: \($0.rating ?? 0.0))" }.joined(separator: ", "))")
        
        isLoading = false
    }
    
    private func getCurrentUserId() -> String? {
        return Clerk.shared.user?.id
    }
    
    func refreshSavedPosts() async {
        print("🔄 SavedViewModel: Starting to refresh saved posts...")
        
        do {
            // Load bookmarked posts from backend
            let backendPosts = try await BackendService.shared.getBookmarkedPosts()
            
            // Convert BackendPost to Post using the existing conversion method
            savedPosts = backendPosts.map { backendPost in
                var post = Post.from(backendPost: backendPost)
                post.isSaved = true // Mark as saved since these are bookmarked posts
                return post
            }
            
            print("✅ SavedViewModel: Successfully refreshed \(savedPosts.count) bookmarked posts")
            
        } catch {
            print("❌ SavedViewModel: Failed to refresh bookmarked posts: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
        }
    }
    
    func toggleListPrivacy(_ list: SavedList) {
        if let index = userLists.firstIndex(where: { $0.id == list.id }) {
            let oldPrivacy = userLists[index].isPrivate
            userLists[index].isPrivate.toggle()
            userLists[index].updatedAt = Date()
            print("Privacy toggled for '\(userLists[index].name)': \(oldPrivacy) -> \(userLists[index].isPrivate)")
        } else {
            print("Could not find list with ID: \(list.id)")
        }
    }
    
    func renameList(_ list: SavedList, to newName: String) {
        if let index = userLists.firstIndex(where: { $0.id == list.id }) {
            let oldName = userLists[index].name
            userLists[index].name = newName
            userLists[index].updatedAt = Date()
            print("List renamed: '\(oldName)' -> '\(newName)'")
        } else {
            print("Could not find list with ID: \(list.id) for renaming")
        }
    }
    
    func deleteList(_ list: SavedList) {
        userLists.removeAll { $0.id == list.id }
    }
}

// MARK: - ShareSheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    SavedView()
        .environmentObject(MockAppState())
} 