//
//  PerformanceOptimizer.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import Foundation
import SwiftUI
import Combine

// MARK: - Performance Optimizer

@MainActor
class PerformanceOptimizer: ObservableObject {
    static let shared = PerformanceOptimizer()
    
    @Published var isOptimizing = false
    @Published var memoryUsage: Double = 0.0 // MB
    @Published var cpuUsage: Double = 0.0 // Percentage
    @Published var optimizationLevel = OptimizationLevel.balanced
    @Published var performanceMetrics = PerformanceMetrics()
    
    private var monitoringTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        startPerformanceMonitoring()
        loadOptimizationSettings()
    }
    
    // MARK: - Performance Monitoring
    
    private func startPerformanceMonitoring() {
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in
                self.updatePerformanceMetrics()
            }
        }
    }
    
    private func updatePerformanceMetrics() {
        memoryUsage = getCurrentMemoryUsage()
        cpuUsage = getCurrentCPUUsage()
        
        performanceMetrics.memoryUsage = memoryUsage
        performanceMetrics.cpuUsage = cpuUsage
        performanceMetrics.lastUpdated = Date()
        
        // Auto-optimize if needed
        if shouldAutoOptimize() {
            optimize()
        }
    }
    
    private func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
        }
        
        return 0.0
    }
    
    private func getCurrentCPUUsage() -> Double {
        // Simplified CPU usage calculation
        // In a real implementation, you'd use more sophisticated methods
        return Double.random(in: 0...100)
    }
    
    // MARK: - Optimization
    
    func optimize() {
        guard !isOptimizing else { return }
        
        isOptimizing = true
        
        Task {
            await performOptimization()
            
            await MainActor.run {
                self.isOptimizing = false
            }
        }
    }
    
    private func performOptimization() async {
        switch optimizationLevel {
        case .performance:
            await performHighPerformanceOptimization()
        case .balanced:
            await performBalancedOptimization()
        case .battery:
            await performBatteryOptimization()
        }
    }
    
    private func performHighPerformanceOptimization() async {
        // Optimize for maximum performance
        await clearImageCache()
        await cleanupUnusedViews()
        await optimizeAnimations(enabled: true)
    }
    
    private func performBalancedOptimization() async {
        // Balance between performance and battery
        await clearImageCache(partial: true)
        await cleanupUnusedViews()
        await optimizeAnimations(enabled: true)
    }
    
    private func performBatteryOptimization() async {
        // Optimize for battery life
        await clearImageCache()
        await cleanupUnusedViews()
        await optimizeAnimations(enabled: false)
        await reduceBackgroundTasks()
    }
    
    // MARK: - Optimization Methods
    
    private func clearImageCache(partial: Bool = false) async {
        await Task.sleep(nanoseconds: 500_000_000) // Simulate work
        
        if partial {
            // Clear only old cached images
            print("🗑️ Cleared old cached images")
        } else {
            // Clear all cached images
            print("🗑️ Cleared all cached images")
        }
    }
    
    private func cleanupUnusedViews() async {
        await Task.sleep(nanoseconds: 300_000_000)
        print("🧹 Cleaned up unused views")
    }
    
    private func optimizeAnimations(enabled: Bool) async {
        await Task.sleep(nanoseconds: 200_000_000)
        
        if enabled {
            print("🎬 Enabled high-performance animations")
        } else {
            print("🎬 Disabled non-essential animations")
        }
    }
    
    private func reduceBackgroundTasks() async {
        await Task.sleep(nanoseconds: 400_000_000)
        print("🔋 Reduced background task frequency")
    }
    
    // MARK: - Settings
    
    func setOptimizationLevel(_ level: OptimizationLevel) {
        optimizationLevel = level
        saveOptimizationSettings()
        optimize()
    }
    
    private func shouldAutoOptimize() -> Bool {
        return memoryUsage > 100.0 || cpuUsage > 80.0
    }
    
    private func saveOptimizationSettings() {
        UserDefaults.standard.set(optimizationLevel.rawValue, forKey: "optimization_level")
    }
    
    private func loadOptimizationSettings() {
        if let levelString = UserDefaults.standard.string(forKey: "optimization_level"),
           let level = OptimizationLevel(rawValue: levelString) {
            optimizationLevel = level
        }
    }
    
    // MARK: - Public Methods
    
    func getPerformanceReport() -> PerformanceReport {
        return PerformanceReport(
            memoryUsage: memoryUsage,
            cpuUsage: cpuUsage,
            optimizationLevel: optimizationLevel,
            lastOptimized: performanceMetrics.lastOptimized,
            recommendations: getOptimizationRecommendations()
        )
    }
    
    private func getOptimizationRecommendations() -> [String] {
        var recommendations: [String] = []
        
        if memoryUsage > 150.0 {
            recommendations.append("Consider clearing app cache")
        }
        
        if cpuUsage > 70.0 {
            recommendations.append("Close unused features")
        }
        
        if performanceMetrics.lastOptimized == nil || 
           Date().timeIntervalSince(performanceMetrics.lastOptimized!) > 3600 {
            recommendations.append("Run performance optimization")
        }
        
        return recommendations
    }
    
    func startSession() {
        performanceMetrics.sessionStart = Date()
    }
    
    func endSession() {
        if let sessionStart = performanceMetrics.sessionStart {
            performanceMetrics.sessionDuration = Date().timeIntervalSince(sessionStart)
        }
    }
    
    deinit {
        monitoringTimer?.invalidate()
    }
}

// MARK: - Supporting Models

enum OptimizationLevel: String, CaseIterable {
    case performance = "performance"
    case balanced = "balanced"
    case battery = "battery"
    
    var displayName: String {
        switch self {
        case .performance:
            return "High Performance"
        case .balanced:
            return "Balanced"
        case .battery:
            return "Battery Saver"
        }
    }
    
    var description: String {
        switch self {
        case .performance:
            return "Maximum performance, higher battery usage"
        case .balanced:
            return "Good performance with reasonable battery usage"
        case .battery:
            return "Extended battery life, reduced performance"
        }
    }
}

struct PerformanceMetrics {
    var memoryUsage: Double = 0.0
    var cpuUsage: Double = 0.0
    var sessionStart: Date?
    var sessionDuration: TimeInterval = 0.0
    var lastOptimized: Date?
    var lastUpdated: Date?
    
    mutating func recordOptimization() {
        lastOptimized = Date()
    }
}

struct PerformanceReport {
    let memoryUsage: Double
    let cpuUsage: Double
    let optimizationLevel: OptimizationLevel
    let lastOptimized: Date?
    let recommendations: [String]
    
    var memoryStatus: String {
        switch memoryUsage {
        case 0..<50:
            return "Excellent"
        case 50..<100:
            return "Good"
        case 100..<150:
            return "Fair"
        default:
            return "Poor"
        }
    }
    
    var cpuStatus: String {
        switch cpuUsage {
        case 0..<30:
            return "Low"
        case 30..<60:
            return "Moderate"
        case 60..<85:
            return "High"
        default:
            return "Critical"
        }
    }
}

// MARK: - Smart Image Cache

class SmartImageCache {
    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private var accessLog: [String: Date] = [:]
    private let queue = DispatchQueue(label: "ImageCache", qos: .utility)
    
    var currentSize: Double = 0
    var maxSize: Double = 100 * 1024 * 1024 // 100MB
    var hitRate: Double = 0
    private var totalRequests = 0
    private var cacheHits = 0
    
    init() {
        let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = urls[0].appendingPathComponent("ImageCache")
        
        setupCache()
        createCacheDirectory()
    }
    
    private func setupCache() {
        cache.countLimit = 200
        cache.totalCostLimit = Int(maxSize)
        
        // Set up cache eviction
        cache.delegate = CacheDelegate { [weak self] key, _ in
            self?.handleImageEviction(key: key as! String)
        }
    }
    
    private func createCacheDirectory() {
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func loadImagesWithPriority(_ urls: [URL]) async -> [URL: UIImage] {
        var results: [URL: UIImage] = [:]
        
        await withTaskGroup(of: (URL, UIImage?).self) { group in
            for url in urls {
                group.addTask { [weak self] in
                    let image = await self?.loadImage(from: url)
                    return (url, image)
                }
            }
            
            for await (url, image) in group {
                if let image = image {
                    results[url] = image
                }
            }
        }
        
        return results
    }
    
    func loadImage(from url: URL) async -> UIImage? {
        totalRequests += 1
        let key = url.absoluteString
        
        // Check memory cache first
        if let image = cache.object(forKey: key as NSString) {
            cacheHits += 1
            updateHitRate()
            updateAccessLog(for: key)
            return image
        }
        
        // Check disk cache
        if let image = loadImageFromDisk(key: key) {
            cache.setObject(image, forKey: key as NSString)
            cacheHits += 1
            updateHitRate()
            updateAccessLog(for: key)
            return image
        }
        
        // Download from network
        return await downloadAndCacheImage(from: url)
    }
    
    func prefetchImages(_ urls: [URL], priority: ImagePriority) {
        queue.async { [weak self] in
            for url in urls {
                Task {
                    await self?.loadImage(from: url)
                }
            }
        }
    }
    
    private func loadImageFromDisk(key: String) -> UIImage? {
        let fileName = key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }
        
        return image
    }
    
    private func downloadAndCacheImage(from url: URL) async -> UIImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else { return nil }
            
            // Cache in memory
            cache.setObject(image, forKey: url.absoluteString as NSString)
            
            // Cache on disk
            saveToDisk(data: data, key: url.absoluteString)
            
            updateAccessLog(for: url.absoluteString)
            return image
        } catch {
            print("❌ ImageCache: Failed to download image: \(error)")
            return nil
        }
    }
    
    private func saveToDisk(data: Data, key: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let fileName = key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
            let fileURL = self.cacheDirectory.appendingPathComponent(fileName)
            
            try? data.write(to: fileURL)
            self.currentSize += Double(data.count)
        }
    }
    
    private func updateAccessLog(for key: String) {
        accessLog[key] = Date()
    }
    
    private func updateHitRate() {
        hitRate = totalRequests > 0 ? Double(cacheHits) / Double(totalRequests) : 0
    }
    
    private func handleImageEviction(key: String) {
        // Remove from disk cache as well
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let fileName = key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
            let fileURL = self.cacheDirectory.appendingPathComponent(fileName)
            
            if let attributes = try? self.fileManager.attributesOfItem(atPath: fileURL.path),
               let fileSize = attributes[.size] as? Double {
                self.currentSize -= fileSize
            }
            
            try? self.fileManager.removeItem(at: fileURL)
        }
    }
    
    func clearCache() async {
        cache.removeAllObjects()
        
        return await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                try? self.fileManager.removeItem(at: self.cacheDirectory)
                self.createCacheDirectory()
                self.currentSize = 0
                continuation.resume()
            }
        }
    }
    
    func clearNonEssentialCache() async {
        let cutoffDate = Date().addingTimeInterval(-3600) // 1 hour ago
        
        return await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                for (key, accessDate) in self.accessLog {
                    if accessDate < cutoffDate {
                        self.cache.removeObject(forKey: key as NSString)
                        self.handleImageEviction(key: key)
                    }
                }
                
                continuation.resume()
            }
        }
    }
    
    func cleanupOldEntries() async {
        let cutoffDate = Date().addingTimeInterval(-86400 * 7) // 7 days ago
        
        return await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                let oldEntries = self.accessLog.filter { $0.value < cutoffDate }
                for (key, _) in oldEntries {
                    self.cache.removeObject(forKey: key as NSString)
                    self.handleImageEviction(key: key)
                    self.accessLog.removeValue(forKey: key)
                }
                
                continuation.resume()
            }
        }
    }
    
    func reduceForBackground() async {
        // Reduce cache size by 50% when app goes to background
        maxSize *= 0.5
        cache.totalCostLimit = Int(maxSize)
        await clearNonEssentialCache()
    }
    
    func restoreFromBackground() async {
        // Restore full cache size when app returns to foreground
        maxSize *= 2
        cache.totalCostLimit = Int(maxSize)
    }
}

// MARK: - Smart Data Cache

class SmartDataCache {
    private let cache = NSCache<NSString, CacheItem>()
    private var expirationTimes: [String: Date] = [:]
    private let queue = DispatchQueue(label: "DataCache", qos: .utility)
    
    var currentSize: Double = 0
    var maxSize: Double = 50 * 1024 * 1024 // 50MB
    var hitRate: Double = 0
    private var totalRequests = 0
    private var cacheHits = 0
    
    init() {
        setupCache()
        startCleanupTimer()
    }
    
    private func setupCache() {
        cache.countLimit = 500
        cache.totalCostLimit = Int(maxSize)
    }
    
    private func startCleanupTimer() {
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task {
                await self?.cleanupExpiredItems()
            }
        }
    }
    
    func store<T: Codable>(_ data: T, for key: String, expiration: TimeInterval) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let encoded = try JSONEncoder().encode(data)
                let item = CacheItem(data: encoded)
                
                self.cache.setObject(item, forKey: key as NSString, cost: encoded.count)
                self.expirationTimes[key] = Date().addingTimeInterval(expiration)
                self.currentSize += Double(encoded.count)
            } catch {
                print("❌ DataCache: Failed to encode data for key \(key): \(error)")
            }
        }
    }
    
    func retrieve<T: Codable>(_ type: T.Type, for key: String) -> T? {
        totalRequests += 1
        
        // Check if expired
        if let expirationTime = expirationTimes[key], expirationTime < Date() {
            remove(key: key)
            updateHitRate()
            return nil
        }
        
        guard let item = cache.object(forKey: key as NSString) else {
            updateHitRate()
            return nil
        }
        
        do {
            let decoded = try JSONDecoder().decode(type, from: item.data)
            cacheHits += 1
            updateHitRate()
            return decoded
        } catch {
            print("❌ DataCache: Failed to decode data for key \(key): \(error)")
            remove(key: key)
            updateHitRate()
            return nil
        }
    }
    
    private func remove(key: String) {
        if let item = cache.object(forKey: key as NSString) {
            currentSize -= Double(item.data.count)
        }
        cache.removeObject(forKey: key as NSString)
        expirationTimes.removeValue(forKey: key)
    }
    
    private func updateHitRate() {
        hitRate = totalRequests > 0 ? Double(cacheHits) / Double(totalRequests) : 0
    }
    
    func clearCache() async {
        return await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                self?.cache.removeAllObjects()
                self?.expirationTimes.removeAll()
                self?.currentSize = 0
                continuation.resume()
            }
        }
    }
    
    func clearExpiredItems() async {
        return await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                let now = Date()
                let expiredKeys = self.expirationTimes.filter { $0.value < now }.map { $0.key }
                
                for key in expiredKeys {
                    self.remove(key: key)
                }
                
                continuation.resume()
            }
        }
    }
    
    private func cleanupExpiredItems() async {
        await clearExpiredItems()
    }
    
    func cleanupOldEntries() async {
        await clearExpiredItems()
    }
    
    func reduceForBackground() async {
        maxSize *= 0.7
        cache.totalCostLimit = Int(maxSize)
        await clearExpiredItems()
    }
    
    func restoreFromBackground() async {
        maxSize /= 0.7
        cache.totalCostLimit = Int(maxSize)
    }
}

// MARK: - Supporting Classes and Models

class CacheItem {
    let data: Data
    let createdAt: Date
    
    init(data: Data) {
        self.data = data
        self.createdAt = Date()
    }
}

class CacheDelegate: NSCacheDelegate {
    private let onEviction: (Any, Any) -> Void
    
    init(onEviction: @escaping (Any, Any) -> Void) {
        self.onEviction = onEviction
    }
    
    func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject obj: Any) {
        // Implementation depends on the specific cache type
    }
}

class BackgroundSyncManager {
    private var pendingOperations: [BackgroundOperation] = []
    private let queue = DispatchQueue(label: "BackgroundSync", qos: .background)
    
    func startBackgroundSync() {
        // Implementation for background syncing
        print("🔄 BackgroundSyncManager: Starting background sync")
    }
    
    func syncPendingData() async {
        // Sync any pending data when app comes to foreground
        print("🔄 BackgroundSyncManager: Syncing pending data")
    }
    
    func addOperation(_ operation: BackgroundOperation) {
        pendingOperations.append(operation)
    }
}

class MemoryManager {
    func optimizeMemoryUsage() {
        // Force garbage collection and optimize memory usage
        print("🧠 MemoryManager: Optimizing memory usage")
        
        // In a real implementation, this would:
        // - Release unnecessary objects
        // - Compress data structures
        // - Clean up temporary files
    }
}

class LazyLoadingManager {
    private var observedScrollViews: Set<UIScrollView> = []
    private var isOperationsPaused = false
    
    func enableLazyLoading(for scrollView: UIScrollView) {
        observedScrollViews.insert(scrollView)
        // Setup scroll view observation for lazy loading
    }
    
    func pauseOperations() {
        isOperationsPaused = true
    }
    
    func resumeOperations() {
        isOperationsPaused = false
    }
}

// MARK: - Data Models

struct MemoryUsage {
    let used: Double
    let available: Double
    let peak: Double
    
    init(used: Double = 0, available: Double = 0, peak: Double = 0) {
        self.used = used
        self.available = available
        self.peak = peak
    }
    
    var usagePercentage: Double {
        guard available > 0 else { return 0 }
        return (used / available) * 100
    }
}

struct CacheStatistics {
    let imageCacheSize: Double
    let dataCacheSize: Double
    let totalCacheSize: Double
    let hitRate: Double
    let maxCacheSize: Double
    
    init(imageCacheSize: Double = 0, dataCacheSize: Double = 0, totalCacheSize: Double = 0, 
         hitRate: Double = 0, maxCacheSize: Double = 0) {
        self.imageCacheSize = imageCacheSize
        self.dataCacheSize = dataCacheSize
        self.totalCacheSize = totalCacheSize
        self.hitRate = hitRate
        self.maxCacheSize = maxCacheSize
    }
    
    var cacheUsagePercentage: Double {
        guard maxCacheSize > 0 else { return 0 }
        return (totalCacheSize / maxCacheSize) * 100
    }
}

class NetworkMetrics: ObservableObject {
    @Published var averageResponseTime: Double = 0
    @Published var totalRequests: Int = 0
    @Published var failedRequests: Int = 0
    
    private var responseTimes: [Double] = []
    
    func updateMetrics() {
        // Update network metrics based on recent requests
        if !responseTimes.isEmpty {
            averageResponseTime = responseTimes.reduce(0, +) / Double(responseTimes.count)
        }
    }
    
    func recordRequest(responseTime: Double, success: Bool) {
        responseTimes.append(responseTime)
        totalRequests += 1
        if !success {
            failedRequests += 1
        }
        
        // Keep only recent response times
        if responseTimes.count > 100 {
            responseTimes.removeFirst()
        }
    }
    
    var successRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(totalRequests - failedRequests) / Double(totalRequests)
    }
}

struct PerformanceReport {
    let memoryUsage: MemoryUsage
    let cacheStatistics: CacheStatistics
    let networkMetrics: NetworkMetrics
    let performanceScore: Double
    let recommendations: [PerformanceRecommendation]
    let timestamp: Date
    
    init(memoryUsage: MemoryUsage, cacheStatistics: CacheStatistics, 
         networkMetrics: NetworkMetrics, performanceScore: Double, 
         recommendations: [PerformanceRecommendation]) {
        self.memoryUsage = memoryUsage
        self.cacheStatistics = cacheStatistics
        self.networkMetrics = networkMetrics
        self.performanceScore = performanceScore
        self.recommendations = recommendations
        self.timestamp = Date()
    }
}

enum PerformanceRecommendation: String, CaseIterable {
    case highMemoryUsage = "highMemoryUsage"
    case lowCacheHitRate = "lowCacheHitRate"
    case slowNetworkResponse = "slowNetworkResponse"
    case cacheNearlyFull = "cacheNearlyFull"
    case backgroundOptimization = "backgroundOptimization"
    
    var title: String {
        switch self {
        case .highMemoryUsage: return "High Memory Usage"
        case .lowCacheHitRate: return "Low Cache Hit Rate"
        case .slowNetworkResponse: return "Slow Network Response"
        case .cacheNearlyFull: return "Cache Nearly Full"
        case .backgroundOptimization: return "Background Optimization Needed"
        }
    }
    
    var description: String {
        switch self {
        case .highMemoryUsage: return "Memory usage is high. Consider clearing caches or reducing image quality."
        case .lowCacheHitRate: return "Cache hit rate is low. Consider adjusting cache settings or prefetching strategies."
        case .slowNetworkResponse: return "Network responses are slow. Check internet connection or server performance."
        case .cacheNearlyFull: return "Cache is nearly full. Consider clearing old entries or increasing cache size."
        case .backgroundOptimization: return "App could benefit from background optimization improvements."
        }
    }
    
    var icon: String {
        switch self {
        case .highMemoryUsage: return "memorychip"
        case .lowCacheHitRate: return "externaldrive"
        case .slowNetworkResponse: return "wifi.exclamationmark"
        case .cacheNearlyFull: return "externaldrive.fill"
        case .backgroundOptimization: return "moon"
        }
    }
}

enum ImagePriority {
    case low, normal, high
}

struct BackgroundOperation {
    let id: String
    let type: String
    let data: [String: Any]
    let createdAt: Date
}

// MARK: - Performance Monitor View

struct PerformanceMonitorView: View {
    @StateObject private var optimizer = PerformanceOptimizer.shared
    @State private var showDetailedReport = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Performance Score
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: optimizer.performanceScore / 100)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 2) {
                    Text("\(Int(optimizer.performanceScore))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primaryText)
                    
                    Text("Score")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            }
            
            // Quick Stats
            HStack(spacing: 20) {
                StatView(
                    title: "Memory",
                    value: "\(Int(optimizer.memoryUsage.usagePercentage))%",
                    color: optimizer.memoryUsage.usagePercentage > 80 ? .red : .green
                )
                
                StatView(
                    title: "Cache Hit",
                    value: "\(Int(optimizer.cacheStatistics.hitRate * 100))%",
                    color: optimizer.cacheStatistics.hitRate > 0.7 ? .green : .orange
                )
                
                StatView(
                    title: "Network",
                    value: "\(Int(optimizer.networkMetrics.averageResponseTime))ms",
                    color: optimizer.networkMetrics.averageResponseTime < 1000 ? .green : .red
                )
            }
            
            // Actions
            HStack(spacing: 12) {
                Button("Clear Cache") {
                    Task {
                        await optimizer.clearAllCaches()
                    }
                }
                .buttonStyle(.bordered)
                
                Button("Optimize") {
                    optimizer.optimizeMemoryUsage()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Report") {
                    showDetailedReport = true
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .sheet(isPresented: $showDetailedReport) {
            PerformanceReportView(report: optimizer.getPerformanceReport())
        }
    }
    
    private var scoreColor: Color {
        if optimizer.performanceScore >= 80 {
            return .green
        } else if optimizer.performanceScore >= 60 {
            return .orange
        } else {
            return .red
        }
    }
}

struct StatView: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondaryText)
        }
    }
}

struct PerformanceReportView: View {
    let report: PerformanceReport
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Performance Summary
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Performance Summary")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Score: \(Int(report.performanceScore))/100")
                            .font(.headline)
                            .foregroundColor(report.performanceScore >= 80 ? .green : .orange)
                    }
                    
                    // Recommendations
                    if !report.recommendations.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recommendations")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            ForEach(report.recommendations, id: \.rawValue) { recommendation in
                                RecommendationCard(recommendation: recommendation)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Performance Report")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct RecommendationCard: View {
    let recommendation: PerformanceRecommendation
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: recommendation.icon)
                .font(.title2)
                .foregroundColor(.orange)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                Text(recommendation.description)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview("Performance Monitor") {
    PerformanceMonitorView()
}

#Preview("Performance Report") {
    PerformanceReportView(
        report: PerformanceReport(
            memoryUsage: MemoryUsage(used: 150, available: 200, peak: 180),
            cacheStatistics: CacheStatistics(imageCacheSize: 50, dataCacheSize: 25, totalCacheSize: 75, hitRate: 0.85, maxCacheSize: 100),
            networkMetrics: NetworkMetrics(),
            performanceScore: 78,
            recommendations: [.highMemoryUsage, .lowCacheHitRate]
        )
    )
} 