//
//  AdminDashboardView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI

// MARK: - Admin Dashboard View

struct AdminDashboardView: View {
    @StateObject private var contentModeration = ContentModerationService.shared
    @StateObject private var analyticsService = AnalyticsService.shared
    @StateObject private var performanceOptimizer = PerformanceOptimizer.shared
    @StateObject private var cacheManager = SmartCachingManager.shared
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: AdminTab = .overview
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab picker
                adminTabPicker
                
                // Content based on selected tab
                TabView(selection: $selectedTab) {
                    OverviewTabView()
                        .tag(AdminTab.overview)
                    
                    ModerationTabView()
                        .tag(AdminTab.moderation)
                    
                    AnalyticsTabView()
                        .tag(AdminTab.analytics)
                    
                    PerformanceTabView()
                        .tag(AdminTab.performance)
                    
                    SystemTabView()
                        .tag(AdminTab.system)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Admin Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                analyticsService.trackScreenView("Admin Dashboard")
            }
        }
    }
    
    private var adminTabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AdminTab.allCases, id: \.self) { tab in
                    AdminTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab
                    ) {
                        withAnimation(.spring()) {
                            selectedTab = tab
                        }
                        analyticsService.trackUserAction(.profileView, properties: [
                            "admin_tab": tab.rawValue
                        ])
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color.cardBackground)
    }
}

// MARK: - Admin Tabs

enum AdminTab: String, CaseIterable {
    case overview = "overview"
    case moderation = "moderation"
    case analytics = "analytics" 
    case performance = "performance"
    case system = "system"
    
    var title: String {
        switch self {
        case .overview: return "Overview"
        case .moderation: return "Moderation"
        case .analytics: return "Analytics"
        case .performance: return "Performance"
        case .system: return "System"
        }
    }
    
    var icon: String {
        switch self {
        case .overview: return "chart.bar.fill"
        case .moderation: return "shield.fill"
        case .analytics: return "chart.line.uptrend.xyaxis"
        case .performance: return "speedometer"
        case .system: return "gearshape.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .overview: return .blue
        case .moderation: return .red
        case .analytics: return .green
        case .performance: return .orange
        case .system: return .purple
        }
    }
}

struct AdminTabButton: View {
    let tab: AdminTab
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.caption)
                
                Text(tab.title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? tab.color : Color.gray.opacity(0.1))
            )
            .foregroundColor(isSelected ? .white : .primaryText)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Overview Tab

struct OverviewTabView: View {
    @StateObject private var contentModeration = ContentModerationService.shared
    @StateObject private var analyticsService = AnalyticsService.shared
    @StateObject private var performanceOptimizer = PerformanceOptimizer.shared
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // System Health Cards
                systemHealthSection
                
                // Quick Actions
                quickActionsSection
                
                // Recent Activity
                recentActivitySection
            }
            .padding()
        }
    }
    
    private var systemHealthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System Health")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                HealthCard(
                    title: "Performance Score",
                    value: "\(Int(performanceOptimizer.performanceScore))",
                    subtitle: "Overall",
                    color: performanceOptimizer.performanceScore > 80 ? .green : .orange,
                    icon: "speedometer"
                )
                
                HealthCard(
                    title: "Pending Reports",
                    value: "\(contentModeration.pendingReports.count)",
                    subtitle: "Requires Review",
                    color: contentModeration.pendingReports.count > 10 ? .red : .blue,
                    icon: "flag.fill"
                )
                
                HealthCard(
                    title: "Active Users",
                    value: "1.2K",
                    subtitle: "Last 24h",
                    color: .green,
                    icon: "person.3.fill"
                )
                
                HealthCard(
                    title: "Memory Usage",
                    value: "\(Int(performanceOptimizer.memoryUsage.usagePercentage))%",
                    subtitle: "System Memory",
                    color: performanceOptimizer.memoryUsage.usagePercentage > 80 ? .red : .green,
                    icon: "memorychip"
                )
            }
        }
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                QuickActionCard(
                    title: "Moderation Queue",
                    subtitle: "\(contentModeration.moderationQueue.count) items",
                    icon: "tray.full.fill",
                    color: .orange
                ) {
                    // Navigate to moderation tab
                }
                
                QuickActionCard(
                    title: "Performance Report",
                    subtitle: "Generate Report",
                    icon: "chart.bar.doc.horizontal.fill",
                    color: .blue
                ) {
                    // Generate performance report
                }
                
                QuickActionCard(
                    title: "Clear Cache",
                    subtitle: "System Cleanup",
                    icon: "trash.fill",
                    color: .red
                ) {
                    Task {
                        await performanceOptimizer.clearAllCaches()
                    }
                }
                
                QuickActionCard(
                    title: "Analytics Export",
                    subtitle: "Download Data",
                    icon: "square.and.arrow.down.fill",
                    color: .green
                ) {
                    Task {
                        _ = await analyticsService.exportAnalyticsData()
                    }
                }
            }
        }
    }
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { index in
                    ActivityRow(
                        title: "User reported inappropriate content",
                        subtitle: "2 minutes ago",
                        icon: "flag.fill",
                        color: .red
                    )
                }
            }
            .padding()
            .background(Color.cardBackground)
            .cornerRadius(12)
        }
    }
}

// MARK: - Moderation Tab

struct ModerationTabView: View {
    var body: some View {
        ModerationQueueView()
    }
}

// MARK: - Analytics Tab

struct AnalyticsTabView: View {
    var body: some View {
        AnalyticsDashboardView()
    }
}

// MARK: - Performance Tab

struct PerformanceTabView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                PerformanceMonitorView()
                CacheDashboardView()
            }
            .padding()
        }
    }
}

// MARK: - System Tab

struct SystemTabView: View {
    @StateObject private var performanceOptimizer = PerformanceOptimizer.shared
    @StateObject private var cacheManager = SmartCachingManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // System Information
                systemInfoSection
                
                // Storage Management
                OfflineStorageView()
                
                // System Actions
                systemActionsSection
            }
            .padding()
        }
    }
    
    private var systemInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                SystemInfoRow(label: "App Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                SystemInfoRow(label: "Build Number", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
                SystemInfoRow(label: "iOS Version", value: UIDevice.current.systemVersion)
                SystemInfoRow(label: "Device Model", value: UIDevice.current.model)
                SystemInfoRow(label: "Memory Usage", value: "\(Int(performanceOptimizer.memoryUsage.used))MB / \(Int(performanceOptimizer.memoryUsage.available))MB")
            }
            .padding()
            .background(Color.cardBackground)
            .cornerRadius(12)
        }
    }
    
    private var systemActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System Actions")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                SystemActionButton(
                    title: "Optimize Performance",
                    subtitle: "Run system optimization",
                    icon: "speedometer",
                    color: .blue
                ) {
                    Task {
                        await performanceOptimizer.optimizeMemoryUsage()
                    }
                }
                
                SystemActionButton(
                    title: "Clear All Caches",
                    subtitle: "Free up storage space",
                    icon: "trash.fill",
                    color: .red
                ) {
                    Task {
                        await cacheManager.clearAllCaches()
                    }
                }
                
                SystemActionButton(
                    title: "Generate Report",
                    subtitle: "Create system health report",
                    icon: "doc.text.fill",
                    color: .green
                ) {
                    // Generate system report
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct HealthCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.tertiaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
}

struct QuickActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                VStack(spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.cardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct ActivityRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primaryText)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            
            Spacer()
        }
    }
}

struct SystemInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondaryText)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primaryText)
        }
    }
}

struct SystemActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.tertiaryText)
            }
            .padding()
            .background(Color.cardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AdminDashboardView()
} 