//
//  AnalyticsService.swift
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

// MARK: - Analytics Service

@MainActor
class AnalyticsService: ObservableObject {
    static let shared = AnalyticsService()
    
    @Published var sessionMetrics = SessionMetrics()
    @Published var userBehaviorMetrics = UserBehaviorMetrics()
    @Published var performanceMetrics = PerformanceMetrics()
    @Published var crashReports: [CrashReport] = []
    @Published var isTrackingEnabled = true
    @Published var sessionId = UUID().uuidString
    @Published var eventsCount = 0
    
    private var sessionStartTime = Date()
    private var screenViewStartTime = Date()
    private var currentScreen = ""
    private var analyticsQueue = DispatchQueue(label: "AnalyticsQueue", qos: .utility)
    private var batchedEvents: [AnalyticsEvent] = []
    private var batchTimer: Timer?
    private var events: [AnalyticsEvent] = []
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        startSession()
        setupBatchProcessing()
        setupCrashHandling()
        setupSession()
    }
    
    // MARK: - Public Methods
    
    func trackEvent(_ type: AnalyticsEventType, properties: [String: Any] = [:]) {
        guard isTrackingEnabled else { return }
        
        let event = AnalyticsEvent(
            type: type,
            properties: properties,
            sessionId: sessionId
        )
        
        events.append(event)
        eventsCount = events.count
        
        print("📊 Analytics: \(type.rawValue) - \(properties)")
        
        // Auto-upload batch if too many events
        if events.count >= 50 {
            uploadEvents()
        }
        
        // Update metrics based on event type
        updateMetricsForEvent(event)
    }
    
    func trackScreenView(_ screenName: String) {
        // End previous screen view
        if !currentScreen.isEmpty {
            trackScreenTime(screen: currentScreen, duration: Date().timeIntervalSince(screenViewStartTime))
        }
        
        // Start new screen view
        currentScreen = screenName
        screenViewStartTime = Date()
        
        trackEvent(.screenView, properties: ["screen_name": screenName])
    }
    
    func trackUserAction(_ action: String, properties: [String: Any] = [:]) {
        var eventProperties = properties
        eventProperties["action"] = action
        trackEvent(.userAction, properties: eventProperties)
        
        // Update user behavior metrics
        updateUserBehaviorMetrics(for: UserAction(rawValue: action) ?? .postLike)
    }
    
    func trackPerformance(_ metric: String, value: Double, properties: [String: Any] = [:]) {
        var eventProperties = properties
        eventProperties["metric"] = metric
        eventProperties["value"] = value
        trackEvent(.performance, properties: eventProperties)
        
        // Update performance metrics
        updatePerformanceMetrics(PerformanceMetric(name: metric, value: value, unit: ""))
    }
    
    func trackError(_ error: Error, context: String = "") {
        trackEvent(.error, properties: [
            "error_message": error.localizedDescription,
            "context": context
        ])
    }
    
    func trackCrash(_ crashReport: CrashReport) {
        crashReports.append(crashReport)
        
        trackEvent(.crash, properties: [
            "crash_reason": crashReport.reason,
            "crash_location": crashReport.location,
            "app_version": crashReport.appVersion
        ])
        
        // Save crash report to disk
        saveCrashReport(crashReport)
    }
    
    func getAnalyticsSummary() -> AnalyticsSummary {
        return AnalyticsSummary(
            sessionMetrics: sessionMetrics,
            userBehaviorMetrics: userBehaviorMetrics,
            performanceMetrics: performanceMetrics,
            totalEvents: events.count,
            crashCount: crashReports.count
        )
    }
    
    func exportAnalyticsData() async -> URL? {
        return await withCheckedContinuation { continuation in
            analyticsQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let exportData = AnalyticsExportData(
                    sessionMetrics: self.sessionMetrics,
                    userBehaviorMetrics: self.userBehaviorMetrics,
                    performanceMetrics: self.performanceMetrics,
                    events: self.events,
                    crashReports: self.crashReports
                )
                
                do {
                    let data = try JSONEncoder().encode(exportData)
                    let url = self.saveExportData(data)
                    continuation.resume(returning: url)
                } catch {
                    print("❌ Analytics: Failed to export data: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func startSession() {
        sessionStartTime = Date()
        sessionMetrics = SessionMetrics()
        
        trackEvent(.sessionStart, properties: [
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            "device_model": UIDevice.current.model,
            "os_version": UIDevice.current.systemVersion
        ])
    }
    
    private func setupBatchProcessing() {
        batchTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.processBatchedEvents()
            }
        }
    }
    
    private func setupCrashHandling() {
        NSSetUncaughtExceptionHandler { exception in
            let crashReport = CrashReport(
                id: UUID().uuidString,
                timestamp: Date(),
                reason: exception.reason ?? "Unknown exception",
                location: exception.callStackSymbols.first ?? "Unknown location",
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
            )
            
            Task { @MainActor in
                AnalyticsService.shared.trackCrash(crashReport)
            }
        }
    }
    
    private func processBatchedEvents() async {
        guard !events.isEmpty else { return }
        
        let eventsToProcess = events
        events.removeAll()
        
        // In a real implementation, this would send events to your analytics backend
        print("📊 Analytics: Processing batch of \(eventsToProcess.count) events")
        
        // For now, just save to local storage
        saveEventsToLocalStorage(eventsToProcess)
    }
    
    private func updateMetricsForEvent(_ event: AnalyticsEvent) {
        Task { @MainActor in
            sessionMetrics.totalEvents += 1
            sessionMetrics.sessionDuration = Date().timeIntervalSince(sessionStartTime)
            
            switch event.type {
            case .userAction:
                sessionMetrics.userInteractions += 1
            case .screenView:
                sessionMetrics.screenViews += 1
            case .error:
                sessionMetrics.errors += 1
            default:
                break
            }
        }
    }
    
    private func updateUserBehaviorMetrics(for action: UserAction) {
        Task { @MainActor in
            userBehaviorMetrics.totalActions += 1
            
            switch action {
            case .postLike:
                userBehaviorMetrics.likesGiven += 1
            case .postComment:
                userBehaviorMetrics.commentsCreated += 1
            case .postShare:
                userBehaviorMetrics.postsShared += 1
            case .postCreate:
                userBehaviorMetrics.postsCreated += 1
            case .userFollow:
                userBehaviorMetrics.followsGiven += 1
            case .searchPerformed:
                userBehaviorMetrics.searchesPerformed += 1
            case .messagesSent:
                userBehaviorMetrics.messagesSent += 1
            }
        }
    }
    
    private func updatePerformanceMetrics(_ metric: PerformanceMetric) {
        Task { @MainActor in
            switch metric.name {
            case "app_launch_time":
                performanceMetrics.averageLaunchTime = (performanceMetrics.averageLaunchTime + metric.value) / 2
            case "api_response_time":
                performanceMetrics.averageAPIResponseTime = (performanceMetrics.averageAPIResponseTime + metric.value) / 2
            case "memory_usage":
                performanceMetrics.memoryUsage = metric.value
            case "cpu_usage":
                performanceMetrics.cpuUsage = metric.value
            default:
                break
            }
        }
    }
    
    private func trackScreenTime(screen: String, duration: TimeInterval) {
        trackEvent(.screenTime, properties: [
            "screen_name": screen,
            "duration": duration
        ])
    }
    
    private func saveEventsToLocalStorage(_ events: [AnalyticsEvent]) {
        do {
            let data = try JSONEncoder().encode(events)
            let filename = "analytics_\(Date().timeIntervalSince1970).json"
            let url = analyticsDirectory.appendingPathComponent(filename)
            try data.write(to: url)
        } catch {
            print("❌ Analytics: Failed to save events: \(error)")
        }
    }
    
    private func saveCrashReport(_ crashReport: CrashReport) {
        do {
            let data = try JSONEncoder().encode(crashReport)
            let filename = "crash_\(crashReport.id).json"
            let url = analyticsDirectory.appendingPathComponent(filename)
            try data.write(to: url)
        } catch {
            print("❌ Analytics: Failed to save crash report: \(error)")
        }
    }
    
    private func saveExportData(_ data: Data) -> URL {
        let filename = "analytics_export_\(Date().timeIntervalSince1970).json"
        let url = analyticsDirectory.appendingPathComponent(filename)
        try? data.write(to: url)
        return url
    }
    
    private var analyticsDirectory: URL {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let analyticsDir = urls[0].appendingPathComponent("Analytics")
        try? FileManager.default.createDirectory(at: analyticsDir, withIntermediateDirectories: true)
        return analyticsDir
    }
    
    // MARK: - Session Management
    
    private func setupSession() {
        // Start new session
        sessionId = UUID().uuidString
        trackEvent(.sessionStart)
    }
    
    func endSession() {
        trackEvent(.sessionEnd)
        uploadEvents()
    }
    
    // MARK: - Data Management
    
    private func uploadEvents() {
        guard !events.isEmpty else { return }
        
        // In a real app, this would upload to your analytics backend
        print("📤 Uploading \(events.count) analytics events")
        
        // Clear events after upload
        events.removeAll()
        eventsCount = 0
    }
    
    func toggleTracking() {
        isTrackingEnabled.toggle()
        trackEvent(isTrackingEnabled ? .trackingEnabled : .trackingDisabled)
    }
    
    // MARK: - User Properties
    
    func setUserProperty(_ key: String, value: Any) {
        trackEvent(.userProperty, properties: [key: value])
    }
    
    func setUserId(_ userId: String) {
        trackEvent(.userIdentified, properties: ["user_id": userId])
    }
}

// MARK: - Data Models

struct AnalyticsEvent: Identifiable {
    let id = UUID()
    let type: AnalyticsEventType
    let properties: [String: Any]
    let timestamp: Date
    let sessionId: String
    
    init(type: AnalyticsEventType, properties: [String: Any] = [:], sessionId: String) {
        self.type = type
        self.properties = properties
        self.sessionId = sessionId
        self.timestamp = Date()
    }
}

enum AnalyticsEventType: String, CaseIterable {
    case sessionStart = "session_start"
    case sessionEnd = "session_end"
    case screenView = "screen_view"
    case userAction = "user_action"
    case postCreate = "post_create"
    case postLike = "post_like"
    case postShare = "post_share"
    case postComment = "post_comment"
    case userFollow = "user_follow"
    case userUnfollow = "user_unfollow"
    case profileView = "profile_view"
    case searchPerformed = "search_performed"
    case messagesSent = "message_sent"
    case performance = "performance"
    case error = "error"
    case trackingEnabled = "tracking_enabled"
    case trackingDisabled = "tracking_disabled"
    case userProperty = "user_property"
    case userIdentified = "user_identified"
    case featureUsed = "feature_used"
    case screenTime = "screen_time"
}

enum UserAction: String, CaseIterable {
    case postLike = "post_like"
    case postComment = "post_comment"
    case postShare = "post_share"
    case postCreate = "post_create"
    case userFollow = "user_follow"
    case searchPerformed = "search_performed"
    case messagesSent = "messages_sent"
    case profileView = "profile_view"
    case mapInteraction = "map_interaction"
    case achievementViewed = "achievement_viewed"
}

struct SessionMetrics: Codable {
    var sessionDuration: TimeInterval = 0
    var screenViews: Int = 0
    var userInteractions: Int = 0
    var totalEvents: Int = 0
    var errors: Int = 0
}

struct UserBehaviorMetrics: Codable {
    var totalActions: Int = 0
    var postsCreated: Int = 0
    var likesGiven: Int = 0
    var commentsCreated: Int = 0
    var postsShared: Int = 0
    var followsGiven: Int = 0
    var searchesPerformed: Int = 0
    var messagesSent: Int = 0
}

struct PerformanceMetrics: Codable {
    var averageLaunchTime: Double = 0
    var averageAPIResponseTime: Double = 0
    var memoryUsage: Double = 0
    var cpuUsage: Double = 0
    var crashRate: Double = 0
}

struct PerformanceMetric {
    let name: String
    let value: Double
    let unit: String
    let timestamp: Date = Date()
}

struct CrashReport: Codable, Identifiable {
    let id: String
    let timestamp: Date
    let reason: String
    let location: String
    let appVersion: String
}

struct AnalyticsSummary {
    let sessionMetrics: SessionMetrics
    let userBehaviorMetrics: UserBehaviorMetrics
    let performanceMetrics: PerformanceMetrics
    let totalEvents: Int
    let crashCount: Int
}

struct AnalyticsExportData: Codable {
    let sessionMetrics: SessionMetrics
    let userBehaviorMetrics: UserBehaviorMetrics
    let performanceMetrics: PerformanceMetrics
    let events: [AnalyticsEvent]
    let crashReports: [CrashReport]
    let exportTimestamp: Date = Date()
}

// MARK: - Analytics Dashboard View

struct AnalyticsDashboardView: View {
    @StateObject private var analytics = AnalyticsService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTimeframe: TimeFrame = .today
    @State private var showingExportSheet = false
    @State private var exportURL: URL?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Timeframe Picker
                    timeframePicker
                    
                    // Key Metrics Cards
                    keyMetricsSection
                    
                    // User Behavior Section
                    userBehaviorSection
                    
                    // Performance Section
                    performanceSection
                    
                    // Error & Crash Section
                    if analytics.sessionMetrics.errors > 0 || !analytics.crashReports.isEmpty {
                        errorSection
                    }
                }
                .padding()
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export") {
                        Task {
                            exportURL = await analytics.exportAnalyticsData()
                            showingExportSheet = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showingExportSheet) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }
    
    private var timeframePicker: some View {
        Picker("Timeframe", selection: $selectedTimeframe) {
            ForEach(TimeFrame.allCases, id: \.self) { timeframe in
                Text(timeframe.displayName).tag(timeframe)
            }
        }
        .pickerStyle(.segmented)
    }
    
    private var keyMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Overview")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                MetricCard(
                    title: "Session Duration",
                    value: formatDuration(analytics.sessionMetrics.sessionDuration),
                    icon: "clock",
                    color: .blue
                )
                
                MetricCard(
                    title: "Screen Views",
                    value: "\(analytics.sessionMetrics.screenViews)",
                    icon: "eye",
                    color: .green
                )
                
                MetricCard(
                    title: "Interactions",
                    value: "\(analytics.sessionMetrics.userInteractions)",
                    icon: "hand.tap",
                    color: .orange
                )
                
                MetricCard(
                    title: "Total Events",
                    value: "\(analytics.sessionMetrics.totalEvents)",
                    icon: "chart.bar",
                    color: .purple
                )
            }
        }
    }
    
    private var userBehaviorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("User Behavior")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                BehaviorRow(
                    title: "Posts Created",
                    value: analytics.userBehaviorMetrics.postsCreated,
                    icon: "photo",
                    color: .blue
                )
                
                BehaviorRow(
                    title: "Likes Given",
                    value: analytics.userBehaviorMetrics.likesGiven,
                    icon: "heart.fill",
                    color: .red
                )
                
                BehaviorRow(
                    title: "Comments",
                    value: analytics.userBehaviorMetrics.commentsCreated,
                    icon: "bubble.left.fill",
                    color: .green
                )
                
                BehaviorRow(
                    title: "Searches",
                    value: analytics.userBehaviorMetrics.searchesPerformed,
                    icon: "magnifyingglass",
                    color: .orange
                )
            }
            .padding()
            .background(Color.cardBackground)
            .cornerRadius(12)
        }
    }
    
    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                PerformanceRow(
                    title: "Launch Time",
                    value: "\(Int(analytics.performanceMetrics.averageLaunchTime))ms",
                    progress: min(analytics.performanceMetrics.averageLaunchTime / 3000, 1.0),
                    color: analytics.performanceMetrics.averageLaunchTime < 1000 ? .green : .orange
                )
                
                PerformanceRow(
                    title: "API Response",
                    value: "\(Int(analytics.performanceMetrics.averageAPIResponseTime))ms",
                    progress: min(analytics.performanceMetrics.averageAPIResponseTime / 2000, 1.0),
                    color: analytics.performanceMetrics.averageAPIResponseTime < 500 ? .green : .orange
                )
                
                PerformanceRow(
                    title: "Memory Usage",
                    value: "\(Int(analytics.performanceMetrics.memoryUsage))MB",
                    progress: analytics.performanceMetrics.memoryUsage / 500,
                    color: analytics.performanceMetrics.memoryUsage < 200 ? .green : .red
                )
            }
            .padding()
            .background(Color.cardBackground)
            .cornerRadius(12)
        }
    }
    
    private var errorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Errors & Crashes")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.red)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Errors")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                    
                    Text("\(analytics.sessionMetrics.errors)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Crashes")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                    
                    Text("\(analytics.crashReports.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return "\(minutes)m \(seconds)s"
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primaryText)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
}

struct BehaviorRow: View {
    let title: String
    let value: Int
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primaryText)
            
            Spacer()
            
            Text("\(value)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primaryText)
        }
    }
}

struct PerformanceRow: View {
    let title: String
    let value: String
    let progress: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primaryText)
                
                Spacer()
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: color))
        }
    }
}

enum TimeFrame: String, CaseIterable {
    case today = "today"
    case week = "week"
    case month = "month"
    case all = "all"
    
    var displayName: String {
        switch self {
        case .today: return "Today"
        case .week: return "Week"
        case .month: return "Month"
        case .all: return "All Time"
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    AnalyticsDashboardView()
} 