//
//  SmartCaching.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import Foundation
import SwiftUI

// MARK: - Smart Caching System

@MainActor
class SmartCachingManager: ObservableObject {
    static let shared = SmartCachingManager()
    
    @Published var cacheStats = CacheStatistics()
    @Published var isOptimizing = false
    
    private let imageCache = SmartImageCache()
    private let dataCache = SmartDataCache()
    private let postCache = SmartPostCache()
    private let userCache = SmartUserCache()
    
    private var cacheTimer: Timer?
    
    private init() {
        setupCacheMonitoring()
        startCacheOptimization()
    }
    
    // MARK: - Public Methods
    
    func preloadContent(for user: User) async {
        print("🔄 SmartCache: Preloading content for user")
        

        
        // Preload user's profile data
        await preloadUserProfile(user)
        
        // Preload user's favorite restaurants
        await preloadFavoriteRestaurants(for: user)
        
        updateCacheStats()
    }
    
    func cachePost(_ post: Post) async {
        await postCache.store(post)
        
        // Cache associated images
        for mediaURL in post.mediaURLs {
            await imageCache.preloadImage(from: mediaURL)
        }
        
        // Cache user data
        await userCache.store(post.author)
        
        updateCacheStats()
    }
    
    func getCachedPost(_ postId: String) -> Post? {
        return postCache.retrieve(postId)
    }
    
    func cacheUser(_ user: User) async {
        await userCache.store(user)
        updateCacheStats()
    }
    
    func getCachedUser(_ userId: String) -> User? {
        return userCache.retrieve(userId)
    }
    
    func optimizeCache() async {
        isOptimizing = true
        
        print("🧹 SmartCache: Starting cache optimization")
        
        // Remove expired items
        await imageCache.clearExpired()
        await dataCache.clearExpired()
        await postCache.clearExpired()
        await userCache.clearExpired()
        
        // Compress frequently accessed items
        await compressFrequentlyAccessed()
        
        // Update cache priorities
        await updateCachePriorities()
        
        updateCacheStats()
        isOptimizing = false
        
        print("✅ SmartCache: Optimization complete")
    }
    
    func clearAllCaches() async {
        await imageCache.clear()
        await dataCache.clear()
        await postCache.clear()
        await userCache.clear()
        
        updateCacheStats()
    }
    
    func getCacheReport() -> CacheReport {
        return CacheReport(
            statistics: cacheStats,
            imageCache: imageCache.getMetrics(),
            dataCache: dataCache.getMetrics(),
            postCache: postCache.getMetrics(),
            userCache: userCache.getMetrics()
        )
    }
    
    // MARK: - Private Methods
    
    private func setupCacheMonitoring() {
        // Monitor memory warnings
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.handleMemoryWarning()
            }
        }
    }
    
    private func startCacheOptimization() {
        cacheTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task {
                await self?.optimizeCache()
            }
        }
    }
    

    
    private func preloadUserProfile(_ user: User) async {
        await userCache.store(user)
        print("📦 SmartCache: Preloaded user profile")
    }
    
    private func preloadFavoriteRestaurants(for user: User) async {
        // Mock implementation - would load favorite restaurants
        print("📦 SmartCache: Preloading favorite restaurants")
    }
    
    private func compressFrequentlyAccessed() async {
        // Compress frequently accessed cache items
        await imageCache.compressFrequentItems()
        await dataCache.compressFrequentItems()
    }
    
    private func updateCachePriorities() async {
        // Update cache priorities based on usage patterns
        await postCache.updatePriorities()
        await userCache.updatePriorities()
    }
    
    private func handleMemoryWarning() async {
        print("⚠️ SmartCache: Memory warning - clearing low priority items")
        
        await imageCache.clearLowPriority()
        await dataCache.clearLowPriority()
        await postCache.clearLowPriority()
        await userCache.clearLowPriority()
        
        updateCacheStats()
    }
    
    private func updateCacheStats() {
        Task { @MainActor in
            cacheStats = CacheStatistics(
                totalSize: imageCache.size + dataCache.size + postCache.size + userCache.size,
                imageCacheSize: imageCache.size,
                dataCacheSize: dataCache.size,
                postCacheSize: postCache.size,
                userCacheSize: userCache.size,
                hitRate: calculateOverallHitRate(),
                itemCount: imageCache.count + dataCache.count + postCache.count + userCache.count
            )
        }
    }
    
    private func calculateOverallHitRate() -> Double {
        let totalHits = imageCache.hits + dataCache.hits + postCache.hits + userCache.hits
        let totalRequests = imageCache.requests + dataCache.requests + postCache.requests + userCache.requests
        
        return totalRequests > 0 ? Double(totalHits) / Double(totalRequests) : 0
    }
}

// MARK: - Smart Image Cache

class SmartImageCache {
    private let cache = NSCache<NSString, CachedImage>()
    private let diskCache = DiskImageCache()
    private var accessLog: [String: CacheAccessInfo] = [:]
    
    var size: Double = 0
    var count: Int = 0
    var hits: Int = 0
    var requests: Int = 0
    
    init() {
        cache.countLimit = 200
        cache.totalCostLimit = 100 * 1024 * 1024 // 100MB
    }
    
    func preloadImage(from url: URL) async {
        requests += 1
        
        let key = url.absoluteString
        
        // Check memory cache
        if let cachedImage = cache.object(forKey: key as NSString) {
            hits += 1
            updateAccessLog(for: key)
            return
        }
        
        // Check disk cache
        if let image = await diskCache.image(for: key) {
            let cachedImage = CachedImage(image: image, url: url)
            cache.setObject(cachedImage, forKey: key as NSString)
            hits += 1
            updateAccessLog(for: key)
            return
        }
        
        // Download and cache
        await downloadAndCache(url: url)
    }
    
    func getImage(for url: URL) -> UIImage? {
        requests += 1
        let key = url.absoluteString
        
        if let cachedImage = cache.object(forKey: key as NSString) {
            hits += 1
            updateAccessLog(for: key)
            return cachedImage.image
        }
        
        return nil
    }
    
    func clearExpired() async {
        let cutoffDate = Date().addingTimeInterval(-86400 * 7) // 7 days
        
        let expiredKeys = accessLog.filter { $0.value.lastAccessed < cutoffDate }.map { $0.key }
        
        for key in expiredKeys {
            cache.removeObject(forKey: key as NSString)
            await diskCache.removeImage(for: key)
            accessLog.removeValue(forKey: key)
        }
        
        updateCacheSize()
    }
    
    func clearLowPriority() async {
        let sortedEntries = accessLog.sorted { $0.value.priority < $1.value.priority }
        let itemsToRemove = Array(sortedEntries.prefix(sortedEntries.count / 3))
        
        for (key, _) in itemsToRemove {
            cache.removeObject(forKey: key as NSString)
            await diskCache.removeImage(for: key)
            accessLog.removeValue(forKey: key)
        }
        
        updateCacheSize()
    }
    
    func compressFrequentItems() async {
        // Compress frequently accessed items to save memory
        let frequentItems = accessLog.filter { $0.value.accessCount > 10 }
        
        for (key, _) in frequentItems {
            if let cachedImage = cache.object(forKey: key as NSString) {
                // Store compressed version to disk
                await diskCache.storeCompressed(cachedImage.image, for: key)
            }
        }
    }
    
    func clear() async {
        cache.removeAllObjects()
        await diskCache.clear()
        accessLog.removeAll()
        updateCacheSize()
    }
    
    func getMetrics() -> CacheMetrics {
        return CacheMetrics(
            size: size,
            count: count,
            hitRate: requests > 0 ? Double(hits) / Double(requests) : 0,
            type: "Image Cache"
        )
    }
    
    private func downloadAndCache(url: URL) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else { return }
            
            let cachedImage = CachedImage(image: image, url: url)
            cache.setObject(cachedImage, forKey: url.absoluteString as NSString)
            
            await diskCache.store(image, for: url.absoluteString)
            updateAccessLog(for: url.absoluteString)
            updateCacheSize()
        } catch {
            print("❌ SmartCache: Failed to download image: \(error)")
        }
    }
    
    private func updateAccessLog(for key: String) {
        if var info = accessLog[key] {
            info.accessCount += 1
            info.lastAccessed = Date()
            info.priority += 1
            accessLog[key] = info
        } else {
            accessLog[key] = CacheAccessInfo(
                lastAccessed: Date(),
                accessCount: 1,
                priority: 1
            )
        }
    }
    
    private func updateCacheSize() {
        // Calculate cache size
        size = Double(cache.totalCostLimit)
        count = accessLog.count
    }
}

// MARK: - Smart Data Cache

class SmartDataCache {
    private let cache = NSCache<NSString, CachedData>()
    private var accessLog: [String: CacheAccessInfo] = [:]
    
    var size: Double = 0
    var count: Int = 0
    var hits: Int = 0
    var requests: Int = 0
    
    init() {
        cache.countLimit = 500
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    func store<T: Codable>(_ data: T, for key: String, expiration: TimeInterval = 3600) {
        do {
            let encoded = try JSONEncoder().encode(data)
            let cachedData = CachedData(
                data: encoded,
                expiration: Date().addingTimeInterval(expiration)
            )
            
            cache.setObject(cachedData, forKey: key as NSString)
            updateAccessLog(for: key)
            updateCacheSize()
        } catch {
            print("❌ SmartCache: Failed to cache data: \(error)")
        }
    }
    
    func retrieve<T: Codable>(_ type: T.Type, for key: String) -> T? {
        requests += 1
        
        guard let cachedData = cache.object(forKey: key as NSString) else {
            return nil
        }
        
        // Check expiration
        if cachedData.expiration < Date() {
            cache.removeObject(forKey: key as NSString)
            accessLog.removeValue(forKey: key)
            return nil
        }
        
        do {
            let decoded = try JSONDecoder().decode(type, from: cachedData.data)
            hits += 1
            updateAccessLog(for: key)
            return decoded
        } catch {
            print("❌ SmartCache: Failed to decode cached data: \(error)")
            cache.removeObject(forKey: key as NSString)
            return nil
        }
    }
    
    func clearExpired() async {
        let now = Date()
        let expiredKeys = accessLog.compactMap { (key, info) -> String? in
            if let cachedData = cache.object(forKey: key as NSString),
               cachedData.expiration < now {
                return key
            }
            return nil
        }
        
        for key in expiredKeys {
            cache.removeObject(forKey: key as NSString)
            accessLog.removeValue(forKey: key)
        }
        
        updateCacheSize()
    }
    
    func clearLowPriority() async {
        let sortedEntries = accessLog.sorted { $0.value.priority < $1.value.priority }
        let itemsToRemove = Array(sortedEntries.prefix(sortedEntries.count / 4))
        
        for (key, _) in itemsToRemove {
            cache.removeObject(forKey: key as NSString)
            accessLog.removeValue(forKey: key)
        }
        
        updateCacheSize()
    }
    
    func compressFrequentItems() async {
        // For data cache, we could implement compression for large JSON objects
        print("🗜️ SmartCache: Compressing frequent data items")
    }
    
    func clear() async {
        cache.removeAllObjects()
        accessLog.removeAll()
        updateCacheSize()
    }
    
    func getMetrics() -> CacheMetrics {
        return CacheMetrics(
            size: size,
            count: count,
            hitRate: requests > 0 ? Double(hits) / Double(requests) : 0,
            type: "Data Cache"
        )
    }
    
    private func updateAccessLog(for key: String) {
        if var info = accessLog[key] {
            info.accessCount += 1
            info.lastAccessed = Date()
            info.priority += 1
            accessLog[key] = info
        } else {
            accessLog[key] = CacheAccessInfo(
                lastAccessed: Date(),
                accessCount: 1,
                priority: 1
            )
        }
    }
    
    private func updateCacheSize() {
        size = Double(cache.totalCostLimit)
        count = accessLog.count
    }
}

// MARK: - Specialized Caches

class SmartPostCache {
    private var posts: [String: Post] = [:]
    private var accessLog: [String: CacheAccessInfo] = [:]
    
    var size: Double { Double(posts.count * 1024) } // Estimate
    var count: Int { posts.count }
    var hits: Int = 0
    var requests: Int = 0
    
    func store(_ post: Post) async {
        posts[post.id.uuidString] = post
        updateAccessLog(for: post.id.uuidString)
    }
    
    func retrieve(_ postId: String) -> Post? {
        requests += 1
        
        if let post = posts[postId] {
            hits += 1
            updateAccessLog(for: postId)
            return post
        }
        
        return nil
    }
    
    func clearExpired() async {
        let cutoffDate = Date().addingTimeInterval(-3600) // 1 hour
        let expiredKeys = accessLog.filter { $0.value.lastAccessed < cutoffDate }.map { $0.key }
        
        for key in expiredKeys {
            posts.removeValue(forKey: key)
            accessLog.removeValue(forKey: key)
        }
    }
    
    func clearLowPriority() async {
        let sortedEntries = accessLog.sorted { $0.value.priority < $1.value.priority }
        let itemsToRemove = Array(sortedEntries.prefix(sortedEntries.count / 3))
        
        for (key, _) in itemsToRemove {
            posts.removeValue(forKey: key)
            accessLog.removeValue(forKey: key)
        }
    }
    
    func updatePriorities() async {
        // Update priorities based on engagement
        for (postId, _) in posts {
            if var info = accessLog[postId] {
                // Boost priority for recently accessed posts
                if info.lastAccessed > Date().addingTimeInterval(-1800) {
                    info.priority += 2
                    accessLog[postId] = info
                }
            }
        }
    }
    
    func clear() async {
        posts.removeAll()
        accessLog.removeAll()
    }
    
    func getMetrics() -> CacheMetrics {
        return CacheMetrics(
            size: size,
            count: count,
            hitRate: requests > 0 ? Double(hits) / Double(requests) : 0,
            type: "Post Cache"
        )
    }
    
    private func updateAccessLog(for key: String) {
        if var info = accessLog[key] {
            info.accessCount += 1
            info.lastAccessed = Date()
            info.priority += 1
            accessLog[key] = info
        } else {
            accessLog[key] = CacheAccessInfo(
                lastAccessed: Date(),
                accessCount: 1,
                priority: 1
            )
        }
    }
}

class SmartUserCache {
    private var users: [String: User] = [:]
    private var accessLog: [String: CacheAccessInfo] = [:]
    
    var size: Double { Double(users.count * 512) } // Estimate
    var count: Int { users.count }
    var hits: Int = 0
    var requests: Int = 0
    
    func store(_ user: User) async {
        users[user.id] = user
        updateAccessLog(for: user.id)
    }
    
    func retrieve(_ userId: String) -> User? {
        requests += 1
        
        if let user = users[userId] {
            hits += 1
            updateAccessLog(for: userId)
            return user
        }
        
        return nil
    }
    
    func clearExpired() async {
        let cutoffDate = Date().addingTimeInterval(-7200) // 2 hours
        let expiredKeys = accessLog.filter { $0.value.lastAccessed < cutoffDate }.map { $0.key }
        
        for key in expiredKeys {
            users.removeValue(forKey: key)
            accessLog.removeValue(forKey: key)
        }
    }
    
    func clearLowPriority() async {
        let sortedEntries = accessLog.sorted { $0.value.priority < $1.value.priority }
        let itemsToRemove = Array(sortedEntries.prefix(sortedEntries.count / 4))
        
        for (key, _) in itemsToRemove {
            users.removeValue(forKey: key)
            accessLog.removeValue(forKey: key)
        }
    }
    
    func updatePriorities() async {
        // Boost priority for friends and frequently viewed users
        for (userId, _) in users {
            if var info = accessLog[userId] {
                // High priority for recently viewed users
                if info.accessCount > 5 {
                    info.priority += 3
                    accessLog[userId] = info
                }
            }
        }
    }
    
    func clear() async {
        users.removeAll()
        accessLog.removeAll()
    }
    
    func getMetrics() -> CacheMetrics {
        return CacheMetrics(
            size: size,
            count: count,
            hitRate: requests > 0 ? Double(hits) / Double(requests) : 0,
            type: "User Cache"
        )
    }
    
    private func updateAccessLog(for key: String) {
        if var info = accessLog[key] {
            info.accessCount += 1
            info.lastAccessed = Date()
            info.priority += 1
            accessLog[key] = info
        } else {
            accessLog[key] = CacheAccessInfo(
                lastAccessed: Date(),
                accessCount: 1,
                priority: 1
            )
        }
    }
}

// MARK: - Disk Image Cache

class DiskImageCache {
    private let cacheDirectory: URL
    
    init() {
        let urls = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = urls[0].appendingPathComponent("DiskImageCache")
        createCacheDirectory()
    }
    
    func store(_ image: UIImage, for key: String) async {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        
        let filename = key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        
        try? data.write(to: fileURL)
    }
    
    func storeCompressed(_ image: UIImage, for key: String) async {
        guard let data = image.jpegData(compressionQuality: 0.5) else { return }
        
        let filename = "\(key)_compressed".addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        
        try? data.write(to: fileURL)
    }
    
    func image(for key: String) async -> UIImage? {
        let filename = key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }
    
    func removeImage(for key: String) async {
        let filename = key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    func clear() async {
        try? FileManager.default.removeItem(at: cacheDirectory)
        createCacheDirectory()
    }
    
    private func createCacheDirectory() {
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}

// MARK: - Data Models

struct CacheStatistics {
    let totalSize: Double
    let imageCacheSize: Double
    let dataCacheSize: Double
    let postCacheSize: Double
    let userCacheSize: Double
    let hitRate: Double
    let itemCount: Int
    
    init(totalSize: Double = 0, imageCacheSize: Double = 0, dataCacheSize: Double = 0,
         postCacheSize: Double = 0, userCacheSize: Double = 0, hitRate: Double = 0, itemCount: Int = 0) {
        self.totalSize = totalSize
        self.imageCacheSize = imageCacheSize
        self.dataCacheSize = dataCacheSize
        self.postCacheSize = postCacheSize
        self.userCacheSize = userCacheSize
        self.hitRate = hitRate
        self.itemCount = itemCount
    }
    
    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
    }
    
    var hitRatePercentage: String {
        "\(Int(hitRate * 100))%"
    }
}

struct CacheMetrics {
    let size: Double
    let count: Int
    let hitRate: Double
    let type: String
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
    
    var hitRatePercentage: String {
        "\(Int(hitRate * 100))%"
    }
}

struct CacheReport {
    let statistics: CacheStatistics
    let imageCache: CacheMetrics
    let dataCache: CacheMetrics
    let postCache: CacheMetrics
    let userCache: CacheMetrics
}

struct CacheAccessInfo {
    var lastAccessed: Date
    var accessCount: Int
    var priority: Int
}

class CachedImage {
    let image: UIImage
    let url: URL
    let cachedAt: Date
    
    init(image: UIImage, url: URL) {
        self.image = image
        self.url = url
        self.cachedAt = Date()
    }
}

class CachedData {
    let data: Data
    let expiration: Date
    
    init(data: Data, expiration: Date) {
        self.data = data
        self.expiration = expiration
    }
}

// MARK: - Cache Dashboard View

struct CacheDashboardView: View {
    @StateObject private var cacheManager = SmartCachingManager.shared
    @State private var showingClearConfirmation = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Cache Overview
                    cacheOverviewSection
                    
                    // Cache Details
                    cacheDetailsSection
                    
                    // Cache Actions
                    cacheActionsSection
                }
                .padding()
            }
            .navigationTitle("Cache Management")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await cacheManager.optimizeCache()
            }
        }
        .alert("Clear All Caches", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                Task {
                    await cacheManager.clearAllCaches()
                }
            }
        } message: {
            Text("This will clear all cached data. The app may need to reload content.")
        }
    }
    
    private var cacheOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cache Overview")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Total Size")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    
                    Text(cacheManager.cacheStats.formattedTotalSize)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primaryText)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Hit Rate")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    
                    Text(cacheManager.cacheStats.hitRatePercentage)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(cacheManager.cacheStats.hitRate > 0.7 ? .green : .orange)
                }
            }
            .padding()
            .background(Color.cardBackground)
            .cornerRadius(12)
        }
    }
    
    private var cacheDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cache Details")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                CacheDetailRow(
                    title: "Images",
                    size: cacheManager.cacheStats.imageCacheSize,
                    color: .blue
                )
                
                CacheDetailRow(
                    title: "Posts",
                    size: cacheManager.cacheStats.postCacheSize,
                    color: .green
                )
                
                CacheDetailRow(
                    title: "Users",
                    size: cacheManager.cacheStats.userCacheSize,
                    color: .orange
                )
                
                CacheDetailRow(
                    title: "Data",
                    size: cacheManager.cacheStats.dataCacheSize,
                    color: .purple
                )
            }
            .padding()
            .background(Color.cardBackground)
            .cornerRadius(12)
        }
    }
    
    private var cacheActionsSection: some View {
        VStack(spacing: 12) {
            Button("Optimize Cache") {
                Task {
                    await cacheManager.optimizeCache()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(cacheManager.isOptimizing)
            
            Button("Clear All Caches") {
                showingClearConfirmation = true
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
            
            if cacheManager.isOptimizing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    Text("Optimizing cache...")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            }
        }
    }
}

struct CacheDetailRow: View {
    let title: String
    let size: Double
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primaryText)
            
            Spacer()
            
            Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondaryText)
        }
    }
}

#Preview {
    CacheDashboardView()
} 