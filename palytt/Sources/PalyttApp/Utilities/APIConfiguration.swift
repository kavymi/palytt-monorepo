//
//  APIConfiguration.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import Foundation
import Combine

// MARK: - API Environment
enum APIEnvironment: String, CaseIterable, Codable {
    case local = "local"
    case production = "production"
    
    var displayName: String {
        switch self {
        case .local: return "Local (Development)"
        case .production: return "Production"
        }
    }
    
    var baseURL: String {
        switch self {
        case .local: 
            // Use 127.0.0.1 instead of localhost to avoid IPv6 resolution issues on iOS Simulator
            return "http://127.0.0.1:4000"
        case .production: 
            return "https://palytt-backend-production-dbbd.up.railway.app"
        }
    }
    
    var trpcURL: String {
        return "\(baseURL)/trpc"
    }
    
    var healthURL: String {
        return "\(baseURL)/health"
    }
    
    var webSocketURL: String {
        switch self {
        case .local:
            return "ws://127.0.0.1:4000"
        case .production:
            return "wss://palytt-backend-production-dbbd.up.railway.app"
        }
    }
    
    var convexURL: String {
        switch self {
        case .local: return "http://127.0.0.1:3210" // Local self-hosted Convex
        case .production: return "https://convex-backend-production-9e36.up.railway.app" // Railway self-hosted Convex
        }
    }
    
    var convexDeploymentURL: String {
        // We need to provide the full URL with https:// for the ConvexClient
        return convexURL
    }
    
    var statusIcon: String {
        switch self {
        case .local: return "laptopcomputer"
        case .production: return "cloud.fill"
        }
    }
    
    var statusColor: String {
        switch self {
        case .local: return "orange"
        case .production: return "green"
        }
    }
}

// MARK: - API Configuration Manager
@MainActor
class APIConfigurationManager: ObservableObject {
    static let shared = APIConfigurationManager()
    
    @Published var currentEnvironment: APIEnvironment = {
        #if DEBUG
        return .local
        #else
        return .production
        #endif
    }()
    @Published var isHealthy: Bool = false
    @Published var lastHealthCheck: Date?
    @Published var healthCheckError: String?
    
    private let userDefaults = UserDefaults.standard
    private let environmentKey = "api_environment"
    private var healthCheckTimer: Timer?
    
    private init() {
        // Configure environment based on build type
        #if DEBUG
        // Development builds use local environment
        userDefaults.removeObject(forKey: environmentKey) // Clear any saved preference
        currentEnvironment = .local
        saveEnvironment()
        #else
        // Production builds load saved environment or default to production
        loadSavedEnvironment()
        #endif
        
        startHealthChecking()
    }
    
    deinit {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }
    
    // MARK: - Environment Management
    
    func resetToDefault() {
        userDefaults.removeObject(forKey: environmentKey)
        loadSavedEnvironment()
        
        // Notify BackendService about the change
        NotificationCenter.default.post(
            name: .apiEnvironmentChanged,
            object: currentEnvironment
        )
        
        print("🔄 Reset environment to build default: \(currentEnvironment.displayName)")
    }
    
    func switchEnvironment(to environment: APIEnvironment, userRole: UserRole) {
        guard userRole.hasAdminAccess else {
            print("⚠️ Access denied: Only admin users can switch API environments")
            return
        }
        
        guard environment != currentEnvironment else {
            print("🔄 Already using \(environment.displayName) environment")
            return
        }
        
        print("🔄 Switching API environment from \(currentEnvironment.displayName) to \(environment.displayName)")
        
        currentEnvironment = environment
        saveEnvironment()
        
        // Reset health status when switching
        isHealthy = false
        healthCheckError = nil
        lastHealthCheck = nil
        
        // Perform immediate health check
        Task {
            await performHealthCheck()
        }
        
        // Notify BackendService about the change
        NotificationCenter.default.post(
            name: .apiEnvironmentChanged,
            object: environment
        )
    }
    
    private func loadSavedEnvironment() {
        if let savedValue = userDefaults.string(forKey: environmentKey),
           let environment = APIEnvironment(rawValue: savedValue) {
            currentEnvironment = environment
        } else {
            // Default to production backend for release builds
            currentEnvironment = .production
        }
    }
    
    private func saveEnvironment() {
        userDefaults.set(currentEnvironment.rawValue, forKey: environmentKey)
    }
    
    // MARK: - Health Checking
    
    private func startHealthChecking() {
        // Perform initial health check
        Task {
            await performHealthCheck()
        }
        
        // Schedule periodic health checks every 30 seconds
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.performHealthCheck()
            }
        }
    }
    
    private func stopHealthChecking() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }
    
    func performHealthCheck() async {
        do {
            let url = URL(string: currentEnvironment.healthURL)!
            let (_, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                let isHealthy = httpResponse.statusCode == 200
                
                await MainActor.run {
                    self.isHealthy = isHealthy
                    self.lastHealthCheck = Date()
                    self.healthCheckError = isHealthy ? nil : "Health check failed with status \(httpResponse.statusCode)"
                }
            }
        } catch {
            await MainActor.run {
                self.isHealthy = false
                self.lastHealthCheck = Date()
                self.healthCheckError = error.localizedDescription
            }
        }
    }
    
    // MARK: - Current Configuration
    
    var currentBaseURL: String {
        return currentEnvironment.baseURL
    }
    
    var currentTRPCURL: String {
        return currentEnvironment.trpcURL
    }
    
    var currentHealthURL: String {
        return currentEnvironment.healthURL
    }
    
    var currentConvexURL: String {
        return currentEnvironment.convexURL
    }
    
    var currentWebSocketURL: String {
        return currentEnvironment.webSocketURL
    }
    
    var convexDeploymentURL: String {
        return currentEnvironment.convexDeploymentURL
    }
    
    // MARK: - Debugging Information
    
    var debugInfo: String {
        var info = """
        🔧 API Configuration Debug Info
        Environment: \(currentEnvironment.displayName)
        Base URL: \(currentBaseURL)
        tRPC URL: \(currentTRPCURL)
        Health URL: \(currentHealthURL)
        Convex URL: \(currentConvexURL)
        Health Status: \(isHealthy ? "✅ Healthy" : "❌ Unhealthy")
        """
        
        if let lastCheck = lastHealthCheck {
            info += "\nLast Health Check: \(DateFormatter.localizedString(from: lastCheck, dateStyle: .none, timeStyle: .medium))"
        }
        
        if let error = healthCheckError {
            info += "\nError: \(error)"
        }
        
        return info
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let apiEnvironmentChanged = Notification.Name("apiEnvironmentChanged")
}

// MARK: - Mock Data for Previews
extension APIConfigurationManager {
    static func createMockManager(
        environment: APIEnvironment = .local,
        isHealthy: Bool = true
    ) -> APIConfigurationManager {
        let manager = APIConfigurationManager()
        manager.currentEnvironment = environment
        manager.isHealthy = isHealthy
        manager.lastHealthCheck = Date()
        return manager
    }
} 