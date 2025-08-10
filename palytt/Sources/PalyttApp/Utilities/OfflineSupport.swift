//
//  OfflineSupport.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import Foundation
import SwiftUI
import CoreData
import Network

// MARK: - Offline Support Manager

@MainActor
class OfflineSupportManager: ObservableObject {
    static let shared = OfflineSupportManager()
    
    @Published var isOffline = false
    @Published var offlinePosts: [Post] = []
    @Published var draftPosts: [DraftPost] = []
    @Published var pendingSyncItems: [PendingSyncItem] = []
    @Published var offlineStorageUsage: Double = 0
    
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    private let maxOfflineStorage: Double = 200 * 1024 * 1024 // 200MB
    
    private init() {
        setupNetworkMonitoring()
        loadOfflineData()
    }
    
    // MARK: - Public Methods
    
    func cachePostsForOffline(_ posts: [Post]) {
        Task {
            for post in posts {
                await cachePost(post)
            }
            await updateStorageUsage()
        }
    }
    
    func createDraftPost() -> DraftPost {
        let draft = DraftPost(
            id: UUID().uuidString,
            createdAt: Date(),
            lastModified: Date()
        )
        draftPosts.append(draft)
        saveDraftPosts()
        return draft
    }
    
    func saveDraftPost(_ draft: DraftPost) {
        if let index = draftPosts.firstIndex(where: { $0.id == draft.id }) {
            draftPosts[index] = draft
        } else {
            draftPosts.append(draft)
        }
        saveDraftPosts()
    }
    
    func deleteDraftPost(_ draft: DraftPost) {
        draftPosts.removeAll { $0.id == draft.id }
        saveDraftPosts()
    }
    
    func addPendingSyncItem(_ item: PendingSyncItem) {
        pendingSyncItems.append(item)
        savePendingSyncItems()
    }
    
    func syncWhenOnline() async {
        guard !isOffline else { return }
        
        print("🔄 OfflineSupport: Starting sync of pending items")
        
        // Sync draft posts
        for draft in draftPosts {
            if draft.isReadyToPublish {
                await publishDraftPost(draft)
            }
        }
        
        // Sync pending items
        for item in pendingSyncItems {
            await syncPendingItem(item)
        }
        
        // Clean up synced items
        cleanupSyncedItems()
        
        print("✅ OfflineSupport: Sync completed")
    }
    
    func getOfflineStorageInfo() -> OfflineStorageInfo {
        return OfflineStorageInfo(
            usedStorage: offlineStorageUsage,
            maxStorage: maxOfflineStorage,
            cachedPosts: offlinePosts.count,
            draftPosts: draftPosts.count,
            pendingSync: pendingSyncItems.count
        )
    }
    
    func clearOfflineCache() async {
        offlinePosts.removeAll()
        saveOfflinePosts()
        
        // Clear cached images and data
        try? FileManager.default.removeItem(at: offlineCacheDirectory)
        createOfflineCacheDirectory()
        
        await updateStorageUsage()
    }
    
    // MARK: - Private Methods
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let wasOffline = self?.isOffline ?? false
                self?.isOffline = path.status != .satisfied
                
                if wasOffline && !path.status != .satisfied {
                    // Came back online
                    await self?.syncWhenOnline()
                }
                
                print("📶 OfflineSupport: Network status: \(path.status == .satisfied ? "Online" : "Offline")")
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }
    
    private func loadOfflineData() {
        loadOfflinePosts()
        loadDraftPosts()
        loadPendingSyncItems()
        
        Task {
            await updateStorageUsage()
        }
    }
    
    private func cachePost(_ post: Post) async {
        // Cache post data
        savePostToCache(post)
        
        // Cache post images
        for imageURL in post.mediaURLs {
            await cacheImage(from: imageURL, for: post.id.uuidString)
        }
        
        // Update offline posts if not already cached
        if !offlinePosts.contains(where: { $0.id == post.id }) {
            offlinePosts.append(post)
            saveOfflinePosts()
        }
    }
    
    private func cacheImage(from url: URL, for postId: String) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let fileName = "\(postId)_\(url.lastPathComponent)"
            let fileURL = offlineCacheDirectory.appendingPathComponent(fileName)
            try data.write(to: fileURL)
        } catch {
            print("❌ OfflineSupport: Failed to cache image: \(error)")
        }
    }
    
    private func savePostToCache(_ post: Post) {
        do {
            let data = try JSONEncoder().encode(post)
            let fileName = "\(post.id.uuidString).json"
            let fileURL = offlineCacheDirectory.appendingPathComponent(fileName)
            try data.write(to: fileURL)
        } catch {
            print("❌ OfflineSupport: Failed to cache post: \(error)")
        }
    }
    
    private func publishDraftPost(_ draft: DraftPost) async {
        do {
            guard let currentUser = Clerk.shared.user else {
                throw NSError(domain: "OfflineSupport", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            }
            
            // Upload images if any
            var imageUrls: [String] = []
            for imageData in draft.imageData {
                let fileName = "draft_\(UUID().uuidString).jpg"
                let uploadResponse = await withCheckedContinuation { continuation in
                    BunnyNetService.shared.uploadImage(data: imageData, fileName: fileName) { response in
                        continuation.resume(returning: response)
                    }
                }
                
                if uploadResponse.success, let url = uploadResponse.url {
                    imageUrls.append(url)
                }
            }
            
            // Create the post via backend
            let postId = try await BackendService.shared.createPostViaConvex(
                userId: currentUser.id,
                title: draft.productName,
                content: draft.caption,
                imageUrl: imageUrls.first,
                imageUrls: imageUrls,
                location: draft.location,
                tags: draft.menuItems,
                isPublic: true,
                metadata: BackendService.ConvexPostMetadata(
                    category: draft.selectedFoodCategory?.rawValue ?? "food",
                    rating: draft.rating ?? 5.0
                )
            )
            
            // Remove from drafts
            draftPosts.removeAll { $0.id == draft.id }
            saveDraftPosts()
            
            print("✅ OfflineSupport: Published draft post with ID: \(postId)")
            
        } catch {
            print("❌ OfflineSupport: Failed to publish draft: \(error)")
            throw error
        }
    }
    
    private func syncPendingItem(_ item: PendingSyncItem) async {
        do {
            switch item.type {
            case .like:
                try await syncLike(item)
            case .comment:
                try await syncComment(item)
            case .follow:
                try await syncFollow(item)
            case .bookmark:
                try await syncBookmark(item)
            }
            
            // Mark as synced
            if let index = pendingSyncItems.firstIndex(where: { $0.id == item.id }) {
                pendingSyncItems[index].isSynced = true
            }
            
        } catch {
            print("❌ OfflineSupport: Failed to sync item: \(error)")
        }
    }
    
    private func syncLike(_ item: PendingSyncItem) async throws {
        guard let postId = item.data["postId"] else {
            throw NSError(domain: "OfflineSupport", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing postId for like sync"])
        }
        
        _ = try await BackendService.shared.togglePostLike(postId: postId)
        print("✅ OfflineSupport: Synced like for post: \(postId)")
    }
    
    private func syncComment(_ item: PendingSyncItem) async throws {
        guard let postId = item.data["postId"],
              let content = item.data["content"] else {
            throw NSError(domain: "OfflineSupport", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing data for comment sync"])
        }
        
        _ = try await BackendService.shared.submitComment(postId: postId, content: content)
        print("✅ OfflineSupport: Synced comment for post: \(postId)")
    }
    
    private func syncFollow(_ item: PendingSyncItem) async throws {
        guard let followerId = item.data["followerId"],
              let followingId = item.data["followingId"],
              let action = item.data["action"] else {
            throw NSError(domain: "OfflineSupport", code: 4, userInfo: [NSLocalizedDescriptionKey: "Missing data for follow sync"])
        }
        
        if action == "follow" {
            _ = try await BackendService.shared.followUser(followerId: followerId, followingId: followingId)
        } else {
            _ = try await BackendService.shared.unfollowUser(followerId: followerId, followingId: followingId)
        }
        
        print("✅ OfflineSupport: Synced \(action) action between \(followerId) and \(followingId)")
    }
    
    private func syncBookmark(_ item: PendingSyncItem) async throws {
        guard let postId = item.data["postId"] else {
            throw NSError(domain: "OfflineSupport", code: 5, userInfo: [NSLocalizedDescriptionKey: "Missing postId for bookmark sync"])
        }
        
        _ = try await BackendService.shared.toggleBookmark(postId: postId)
        print("✅ OfflineSupport: Synced bookmark for post: \(postId)")
    }
    
    // MARK: - Public Methods for Adding Offline Actions
    
    func addOfflineLike(postId: String) {
        let item = PendingSyncItem(
            id: UUID().uuidString,
            type: .like,
            data: ["postId": postId],
            createdAt: Date()
        )
        
        pendingSyncItems.append(item)
        savePendingSyncItems()
        
        // Try to sync immediately if online
        if isOnline {
            Task {
                await syncPendingItem(item)
                cleanupSyncedItems()
            }
        }
    }
    
    func addOfflineComment(postId: String, content: String) {
        let item = PendingSyncItem(
            id: UUID().uuidString,
            type: .comment,
            data: ["postId": postId, "content": content],
            createdAt: Date()
        )
        
        pendingSyncItems.append(item)
        savePendingSyncItems()
        
        // Try to sync immediately if online
        if isOnline {
            Task {
                await syncPendingItem(item)
                cleanupSyncedItems()
            }
        }
    }
    
    func addOfflineFollow(followerId: String, followingId: String, action: String) {
        let item = PendingSyncItem(
            id: UUID().uuidString,
            type: .follow,
            data: [
                "followerId": followerId,
                "followingId": followingId,
                "action": action
            ],
            createdAt: Date()
        )
        
        pendingSyncItems.append(item)
        savePendingSyncItems()
        
        // Try to sync immediately if online
        if isOnline {
            Task {
                await syncPendingItem(item)
                cleanupSyncedItems()
            }
        }
    }
    
    func addOfflineBookmark(postId: String) {
        let item = PendingSyncItem(
            id: UUID().uuidString,
            type: .bookmark,
            data: ["postId": postId],
            createdAt: Date()
        )
        
        pendingSyncItems.append(item)
        savePendingSyncItems()
        
        // Try to sync immediately if online
        if isOnline {
            Task {
                await syncPendingItem(item)
                cleanupSyncedItems()
            }
        }
    }
    
    private func cleanupSyncedItems() {
        pendingSyncItems.removeAll { $0.isSynced }
        savePendingSyncItems()
    }
    
    private func updateStorageUsage() async {
        do {
            let resourceValues = try offlineCacheDirectory.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
            
            if let isDirectory = resourceValues.isDirectory, isDirectory {
                offlineStorageUsage = try calculateDirectorySize(offlineCacheDirectory)
            }
        } catch {
            print("❌ OfflineSupport: Failed to calculate storage usage: \(error)")
        }
    }
    
    private func calculateDirectorySize(_ directory: URL) throws -> Double {
        let resourceKeys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey]
        let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles],
            errorHandler: nil
        )
        
        var totalSize: Double = 0
        
        for case let fileURL as URL in enumerator ?? [] {
            let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
            
            if let isDirectory = resourceValues.isDirectory, !isDirectory,
               let fileSize = resourceValues.fileSize {
                totalSize += Double(fileSize)
            }
        }
        
        return totalSize
    }
    
    // MARK: - Data Persistence
    
    private var offlineCacheDirectory: URL {
        let urls = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let cacheDir = urls[0].appendingPathComponent("OfflineCache")
        createOfflineCacheDirectory()
        return cacheDir
    }
    
    private func createOfflineCacheDirectory() {
        try? FileManager.default.createDirectory(
            at: offlineCacheDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
    
    private func loadOfflinePosts() {
        guard let data = UserDefaults.standard.data(forKey: "offline_posts"),
              let posts = try? JSONDecoder().decode([Post].self, from: data) else {
            return
        }
        offlinePosts = posts
    }
    
    private func saveOfflinePosts() {
        guard let data = try? JSONEncoder().encode(offlinePosts) else { return }
        UserDefaults.standard.set(data, forKey: "offline_posts")
    }
    
    private func loadDraftPosts() {
        guard let data = UserDefaults.standard.data(forKey: "draft_posts"),
              let drafts = try? JSONDecoder().decode([DraftPost].self, from: data) else {
            return
        }
        draftPosts = drafts
    }
    
    private func saveDraftPosts() {
        guard let data = try? JSONEncoder().encode(draftPosts) else { return }
        UserDefaults.standard.set(data, forKey: "draft_posts")
    }
    
    private func loadPendingSyncItems() {
        guard let data = UserDefaults.standard.data(forKey: "pending_sync"),
              let items = try? JSONDecoder().decode([PendingSyncItem].self, from: data) else {
            return
        }
        pendingSyncItems = items
    }
    
    private func savePendingSyncItems() {
        guard let data = try? JSONEncoder().encode(pendingSyncItems) else { return }
        UserDefaults.standard.set(data, forKey: "pending_sync")
    }
}

// MARK: - Data Models

struct DraftPost: Identifiable, Codable {
    let id: String
    let createdAt: Date
    var lastModified: Date
    
    var caption: String = ""
    var mediaURLs: [URL] = []
    var location: Location?
    var shop: Shop?
    var menuItems: [String] = []
    var dietaryInfo: [DietaryPreference] = []
    var rating: Double = 0
    var isPrivate: Bool = false
    
    var isReadyToPublish: Bool {
        !caption.isEmpty && !mediaURLs.isEmpty
    }
    
    var wordCount: Int {
        caption.split(separator: " ").count
    }
}

struct PendingSyncItem: Identifiable, Codable {
    let id: String
    let type: SyncItemType
    let data: [String: String]
    let createdAt: Date
    var isSynced: Bool = false
    
    enum SyncItemType: String, Codable {
        case like = "like"
        case comment = "comment"
        case follow = "follow"
        case bookmark = "bookmark"
    }
}

struct OfflineStorageInfo {
    let usedStorage: Double
    let maxStorage: Double
    let cachedPosts: Int
    let draftPosts: Int
    let pendingSync: Int
    
    var usagePercentage: Double {
        guard maxStorage > 0 else { return 0 }
        return (usedStorage / maxStorage) * 100
    }
    
    var availableStorage: Double {
        maxStorage - usedStorage
    }
    
    var formattedUsedStorage: String {
        ByteCountFormatter.string(fromByteCount: Int64(usedStorage), countStyle: .file)
    }
    
    var formattedMaxStorage: String {
        ByteCountFormatter.string(fromByteCount: Int64(maxStorage), countStyle: .file)
    }
}

// MARK: - Backend Service Extensions

extension BackendService {
    func createPost(from draft: DraftPost) async throws -> Post {
        guard let currentUser = Clerk.shared.user else {
            throw NSError(domain: "OfflineSupport", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Upload images
        var imageUrls: [String] = []
        for imageData in draft.imageData {
            let fileName = "draft_\(UUID().uuidString).jpg"
            let uploadResponse = await withCheckedContinuation { continuation in
                BunnyNetService.shared.uploadImage(data: imageData, fileName: fileName) { response in
                    continuation.resume(returning: response)
                }
            }
            
            if uploadResponse.success, let url = uploadResponse.url {
                imageUrls.append(url)
            }
        }
        
        // Create post via backend
        let postId = try await createPostViaConvex(
            userId: currentUser.id,
            title: draft.productName,
            content: draft.caption,
            imageUrl: imageUrls.first,
            imageUrls: imageUrls,
            location: draft.location,
            tags: draft.menuItems,
            isPublic: true,
            metadata: ConvexPostMetadata(
                category: draft.selectedFoodCategory?.rawValue ?? "food",
                rating: draft.rating ?? 5.0
            )
        )
        
        // Convert to Post model (simplified - in real app would fetch the created post)
        return Post(
            id: UUID(),
            convexId: postId,
            title: draft.productName,
            caption: draft.caption,
            mediaURLs: imageUrls,
            author: User(
                id: UUID(),
                clerkId: currentUser.id,
                username: currentUser.username ?? "Unknown",
                displayName: currentUser.firstName ?? "Unknown User",
                bio: nil,
                avatarURL: URL(string: currentUser.imageUrl),
                followersCount: 0,
                followingCount: 0,
                postsCount: 0,
                isVerified: false,
                isPrivate: false,
                isAdmin: false
            ),
            location: draft.location,
            tags: draft.menuItems,
            likesCount: 0,
            commentsCount: 0,
            isLiked: false,
            isBookmarked: false,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    func syncLike(_ item: PendingSyncItem) async throws {
        guard let postId = item.data["postId"] else {
            throw NSError(domain: "BackendService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing postId"])
        }
        
        _ = try await togglePostLike(postId: postId)
    }
    
    func syncComment(_ item: PendingSyncItem) async throws {
        guard let postId = item.data["postId"],
              let content = item.data["content"] else {
            throw NSError(domain: "BackendService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing comment data"])
        }
        
        _ = try await submitComment(postId: postId, content: content)
    }
    
    func syncFollow(_ item: PendingSyncItem) async throws {
        guard let followerId = item.data["followerId"],
              let followingId = item.data["followingId"],
              let action = item.data["action"] else {
            throw NSError(domain: "BackendService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing follow data"])
        }
        
        if action == "follow" {
            _ = try await followUser(followerId: followerId, followingId: followingId)
        } else {
            _ = try await unfollowUser(followerId: followerId, followingId: followingId)
        }
    }
    
    func syncBookmark(_ item: PendingSyncItem) async throws {
        guard let postId = item.data["postId"] else {
            throw NSError(domain: "BackendService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Missing postId"])
        }
        
        _ = try await toggleBookmark(postId: postId)
    }
}

// MARK: - Post Model Extensions

extension Post {
    static func fromBackendPost(_ backendPost: BackendService.BackendPost) -> Post? {
        guard let postId = UUID(uuidString: backendPost.id) else { return nil }
        
        let author = User(
            id: UUID(),
            clerkId: backendPost.authorClerkId,
            username: backendPost.authorDisplayName ?? "Unknown",
            displayName: backendPost.authorDisplayName ?? "Unknown User",
            bio: nil,
            avatarURL: nil,
            followersCount: 0,
            followingCount: 0,
            postsCount: 0,
            isVerified: false,
            isPrivate: false,
            isAdmin: false
        )
        
        let location = backendPost.location.map { loc in
            Location(
                latitude: loc.latitude,
                longitude: loc.longitude,
                address: loc.address,
                city: loc.city,
                state: nil,
                country: loc.country,
                formattedAddress: loc.address
            )
        }
        
        return Post(
            id: postId,
            convexId: backendPost.id,
            title: backendPost.title,
            caption: backendPost.content,
            mediaURLs: backendPost.imageUrls,
            author: author,
            location: location,
            tags: backendPost.tags,
            likesCount: backendPost.likesCount,
            commentsCount: backendPost.commentsCount,
            isLiked: backendPost.isLiked ?? false,
            isBookmarked: backendPost.isBookmarked ?? false,
            createdAt: ISO8601DateFormatter().date(from: backendPost.createdAt) ?? Date(),
            updatedAt: ISO8601DateFormatter().date(from: backendPost.updatedAt) ?? Date()
        )
    }
    
    static func fromPlaceSearchResult(_ place: BackendService.PlaceSearchResult) -> Post? {
        let postId = UUID()
        
        let location = Location(
            latitude: place.geometry?.location?.lat ?? 0,
            longitude: place.geometry?.location?.lng ?? 0,
            address: place.formatted_address ?? "",
            city: nil,
            state: nil,
            country: nil,
            formattedAddress: place.formatted_address ?? ""
        )
        
        let author = User(
            id: UUID(),
            clerkId: "system",
            username: "palytt",
            displayName: "Palytt",
            bio: nil,
            avatarURL: nil,
            followersCount: 0,
            followingCount: 0,
            postsCount: 0,
            isVerified: true,
            isPrivate: false,
            isAdmin: false
        )
        
        return Post(
            id: postId,
            convexId: place.place_id,
            title: place.name,
            caption: "Discover \(place.name) - \(place.formatted_address ?? "")",
            mediaURLs: [],
            author: author,
            location: location,
            tags: place.types ?? [],
            likesCount: 0,
            commentsCount: 0,
            isLiked: false,
            isBookmarked: false,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

// MARK: - Offline Indicator View

struct OfflineIndicatorView: View {
    @StateObject private var offlineManager = OfflineSupportManager.shared
    
    var body: some View {
        if offlineManager.isOffline {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.caption)
                    .foregroundColor(.white)
                
                Text("Offline Mode")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                if !offlineManager.pendingSyncItems.isEmpty {
                    Text("(\(offlineManager.pendingSyncItems.count) pending)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.orange)
            .cornerRadius(16)
            .transition(.slide)
        }
    }
}

// MARK: - Draft Posts View

struct DraftPostsView: View {
    @StateObject private var offlineManager = OfflineSupportManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingDraftDetail = false
    @State private var selectedDraft: DraftPost?
    
    var body: some View {
        NavigationStack {
            VStack {
                if offlineManager.draftPosts.isEmpty {
                    emptyStateView
                } else {
                    draftsList
                }
            }
            .navigationTitle("Draft Posts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("New Draft") {
                        let newDraft = offlineManager.createDraftPost()
                        selectedDraft = newDraft
                        showingDraftDetail = true
                    }
                }
            }
            .sheet(isPresented: $showingDraftDetail) {
                if let draft = selectedDraft {
                    DraftPostDetailView(draft: draft)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundColor(.secondaryText)
            
            Text("No Draft Posts")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primaryText)
            
            Text("Create draft posts to work on them offline and publish when you're ready.")
                .font(.body)
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Create Draft") {
                let newDraft = offlineManager.createDraftPost()
                selectedDraft = newDraft
                showingDraftDetail = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var draftsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(offlineManager.draftPosts) { draft in
                    DraftPostCard(draft: draft) {
                        selectedDraft = draft
                        showingDraftDetail = true
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct DraftPostCard: View {
    let draft: DraftPost
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Draft preview image or placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "doc.text")
                            .foregroundColor(.gray)
                    )
                
                // Draft info
                VStack(alignment: .leading, spacing: 4) {
                    Text(draft.caption.isEmpty ? "Untitled Draft" : draft.caption)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primaryText)
                        .lineLimit(2)
                    
                    Text("Modified \(draft.lastModified, style: .relative) ago")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    
                    HStack(spacing: 8) {
                        if draft.isReadyToPublish {
                            Label("Ready to publish", systemImage: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.green)
                        } else {
                            Label("Draft", systemImage: "pencil.circle")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                        
                        Text("\(draft.wordCount) words")
                            .font(.caption2)
                            .foregroundColor(.tertiaryText)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            .padding(12)
            .background(Color.cardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct DraftPostDetailView: View {
    @State var draft: DraftPost
    @StateObject private var offlineManager = OfflineSupportManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Caption editor
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Caption")
                            .font(.headline)
                            .foregroundColor(.primaryText)
                        
                        TextEditor(text: $draft.caption)
                            .frame(minHeight: 120)
                            .padding(12)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    // Media section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Photos")
                            .font(.headline)
                            .foregroundColor(.primaryText)
                        
                        if draft.mediaURLs.isEmpty {
                            Button("Add Photos") {
                                // Add photo picker
                            }
                            .frame(height: 100)
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    
                    // Location section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location")
                            .font(.headline)
                            .foregroundColor(.primaryText)
                        
                        Button(draft.location?.name ?? "Add Location") {
                            // Add location picker
                        }
                        .frame(height: 44)
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Edit Draft")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        draft.lastModified = Date()
                        offlineManager.saveDraftPost(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Offline Storage View

struct OfflineStorageView: View {
    @StateObject private var offlineManager = OfflineSupportManager.shared
    @State private var storageInfo: OfflineStorageInfo?
    
    var body: some View {
        VStack(spacing: 20) {
            if let info = storageInfo {
                // Storage Usage
                VStack(spacing: 12) {
                    Text("Offline Storage")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    // Progress ring
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                            .frame(width: 120, height: 120)
                        
                        Circle()
                            .trim(from: 0, to: info.usagePercentage / 100)
                            .stroke(storageColor(for: info.usagePercentage), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(-90))
                        
                        VStack(spacing: 2) {
                            Text("\(Int(info.usagePercentage))%")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primaryText)
                            
                            Text("Used")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                    }
                    
                    Text("\(info.formattedUsedStorage) of \(info.formattedMaxStorage)")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                }
                
                // Storage breakdown
                VStack(spacing: 12) {
                    StorageItemView(
                        title: "Cached Posts",
                        count: info.cachedPosts,
                        icon: "doc.text",
                        color: .blue
                    )
                    
                    StorageItemView(
                        title: "Draft Posts",
                        count: info.draftPosts,
                        icon: "pencil",
                        color: .orange
                    )
                    
                    StorageItemView(
                        title: "Pending Sync",
                        count: info.pendingSync,
                        icon: "arrow.clockwise",
                        color: .green
                    )
                }
                
                // Actions
                VStack(spacing: 12) {
                    Button("Clear Cache") {
                        Task {
                            await offlineManager.clearOfflineCache()
                            updateStorageInfo()
                        }
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                    
                    if !offlineManager.isOffline && !offlineManager.pendingSyncItems.isEmpty {
                        Button("Sync Now") {
                            Task {
                                await offlineManager.syncWhenOnline()
                                updateStorageInfo()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(20)
        .onAppear {
            updateStorageInfo()
        }
    }
    
    private func updateStorageInfo() {
        storageInfo = offlineManager.getOfflineStorageInfo()
    }
    
    private func storageColor(for percentage: Double) -> Color {
        if percentage < 70 {
            return .green
        } else if percentage < 90 {
            return .orange
        } else {
            return .red
        }
    }
}

struct StorageItemView: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primaryText)
            
            Spacer()
            
            Text("\(count)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primaryText)
        }
        .padding(12)
        .background(Color.cardBackground)
        .cornerRadius(8)
    }
}

#Preview("Offline Indicator") {
    OfflineIndicatorView()
}

#Preview("Draft Posts") {
    DraftPostsView()
}

#Preview("Offline Storage") {
    OfflineStorageView()
} 