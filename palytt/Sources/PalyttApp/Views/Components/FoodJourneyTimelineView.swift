//
//  FoodJourneyTimelineView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI
import Kingfisher

// MARK: - Food Journey Timeline View

struct FoodJourneyTimelineView: View {
    let user: User
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = FoodJourneyViewModel()
    @State private var selectedTimeframe: JourneyTimeframe = .allTime
    @State private var showStatistics = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                journeyHeader
                
                // Timeframe Selector
                timeframeSelector
                
                // Journey Content
                journeyContent
            }
            .background(Color.appBackground)
            .navigationTitle("Food Journey")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.primaryBrand)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showStatistics = true }) {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(.primaryBrand)
                    }
                }
            }
            .sheet(isPresented: $showStatistics) {
                JourneyStatisticsView(user: user, journeyData: viewModel.journeyData)
            }
        }
        .task {
            await viewModel.loadJourneyData(for: user, timeframe: selectedTimeframe)
        }
        .onChange(of: selectedTimeframe) { newTimeframe in
            Task {
                await viewModel.loadJourneyData(for: user, timeframe: newTimeframe)
            }
        }
    }
    
    // MARK: - Journey Header
    
    private var journeyHeader: some View {
        VStack(spacing: 16) {
            // User Avatar with Journey Ring
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.orange, .pink, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 4
                    )
                    .frame(width: 80, height: 80)
                
                UserAvatar(user: user, size: 72)
            }
            
            // Journey Summary
            VStack(spacing: 8) {
                Text("\(user.displayName)'s Food Journey")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
                
                if !viewModel.journeyData.isEmpty {
                    let totalExperiences = viewModel.journeyData.reduce(0) { $0 + $1.events.count }
                    Text("\(totalExperiences) culinary experiences")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                }
            }
            
            // Quick Stats
            if !viewModel.isLoading {
                quickStatsView
            }
        }
        .padding(20)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var quickStatsView: some View {
        HStack(spacing: 20) {
            QuickStat(
                icon: "fork.knife",
                title: "Cuisines",
                value: "\(viewModel.uniqueCuisines.count)",
                color: .orange
            )
            
            QuickStat(
                icon: "location.fill",
                title: "Places",
                value: "\(viewModel.uniqueRestaurants.count)",
                color: .green
            )
            
            QuickStat(
                icon: "calendar",
                title: "Days Active",
                value: "\(viewModel.activeDays)",
                color: .blue
            )
            
            QuickStat(
                icon: "flame.fill",
                title: "Best Streak",
                value: "\(viewModel.longestStreak)",
                color: .red
            )
        }
    }
    
    // MARK: - Timeframe Selector
    
    private var timeframeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(JourneyTimeframe.allCases, id: \.self) { timeframe in
                    TimeframeChip(
                        timeframe: timeframe,
                        isSelected: selectedTimeframe == timeframe
                    ) {
                        HapticManager.shared.impact(.light)
                        selectedTimeframe = timeframe
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
    }
    
    // MARK: - Journey Content
    
    private var journeyContent: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.journeyData.isEmpty {
                    emptyJourneyView
                } else {
                    journeyTimeline
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ForEach(0..<5, id: \.self) { _ in
                JourneyEventSkeleton()
            }
        }
    }
    
    private var emptyJourneyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "map")
                .font(.system(size: 60))
                .foregroundColor(.secondaryText)
            
            Text("No Journey Data")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primaryText)
            
            Text("Start sharing your food experiences to build your culinary journey!")
                .font(.body)
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 60)
    }
    
    private var journeyTimeline: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.journeyData.enumerated()), id: \.element.id) { index, period in
                JourneyPeriodView(
                    period: period,
                    isFirst: index == 0,
                    isLast: index == viewModel.journeyData.count - 1
                )
            }
        }
    }
}

// MARK: - Journey Period View

struct JourneyPeriodView: View {
    let period: JourneyPeriod
    let isFirst: Bool
    let isLast: Bool
    @State private var isExpanded = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Period Header
            HStack(spacing: 16) {
                // Timeline Line
                VStack(spacing: 0) {
                    if !isFirst {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 2, height: 20)
                    }
                    
                    ZStack {
                        Circle()
                            .fill(period.color)
                            .frame(width: 20, height: 20)
                        
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                    }
                    
                    if !isLast {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 2, height: 20)
                    }
                }
                
                // Period Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(period.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                    
                    Text(period.subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                    
                    if !period.highlights.isEmpty {
                        Text(period.highlights.joined(separator: " • "))
                            .font(.caption)
                            .foregroundColor(.tertiaryText)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Expand/Collapse Button
                Button(action: {
                    HapticManager.shared.impact(.light)
                    withAnimation(.spring(response: 0.5)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .frame(width: 24, height: 24)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.cardBackground)
            .cornerRadius(12)
            
            // Period Events
            if isExpanded && !period.events.isEmpty {
                VStack(spacing: 12) {
                    ForEach(period.events, id: \.id) { event in
                        JourneyEventView(event: event)
                    }
                }
                .padding(.top, 12)
                .padding(.leading, 36) // Align with timeline
            }
        }
    }
}

// MARK: - Journey Event View

struct JourneyEventView: View {
    let event: JourneyEvent
    
    var body: some View {
        HStack(spacing: 12) {
            // Event Icon
            ZStack {
                Circle()
                    .fill(event.type.color.opacity(0.2))
                    .frame(width: 32, height: 32)
                
                Image(systemName: event.type.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(event.type.color)
            }
            
            // Event Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(event.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primaryText)
                    
                    Spacer()
                    
                    Text(event.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.tertiaryText)
                }
                
                if let description = event.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .lineLimit(2)
                }
                
                if !event.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(event.tags.prefix(3), id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                    .foregroundColor(.secondaryText)
                            }
                        }
                    }
                }
            }
            
            // Event Image (if available)
            if let imageURL = event.imageURL {
                KFImage(imageURL)
                    .placeholder {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 40, height: 40)
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(12)
        .background(Color.cardBackground)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Supporting Views

struct QuickStat: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primaryText)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

struct TimeframeChip: View {
    let timeframe: JourneyTimeframe
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(timeframe.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? LinearGradient.primaryGradient : 
                              AnyShapeStyle(Color.gray.opacity(0.1)))
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

struct JourneyEventSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            SkeletonLoader(cornerRadius: 16)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 6) {
                SkeletonLoader()
                    .frame(width: 120, height: 16)
                
                SkeletonLoader()
                    .frame(width: 200, height: 12)
                
                HStack(spacing: 6) {
                    SkeletonLoader()
                        .frame(width: 60, height: 20)
                    SkeletonLoader()
                        .frame(width: 80, height: 20)
                }
            }
            
            Spacer()
            
            SkeletonLoader(cornerRadius: 8)
                .frame(width: 40, height: 40)
        }
        .padding(12)
        .background(Color.cardBackground)
        .cornerRadius(10)
    }
}

// MARK: - Data Models

struct JourneyPeriod: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let highlights: [String]
    let events: [JourneyEvent]
    let color: Color
}

struct JourneyEvent: Identifiable {
    let id = UUID()
    let type: JourneyEventType
    let title: String
    let description: String?
    let timestamp: Date
    let imageURL: URL?
    let tags: [String]
}

enum JourneyEventType {
    case post, achievement, milestone, firstTry, favorite
    
    var icon: String {
        switch self {
        case .post: return "camera.fill"
        case .achievement: return "trophy.fill"
        case .milestone: return "flag.fill"
        case .firstTry: return "sparkles"
        case .favorite: return "heart.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .post: return .blue
        case .achievement: return .yellow
        case .milestone: return .purple
        case .firstTry: return .green
        case .favorite: return .red
        }
    }
}

enum JourneyTimeframe: String, CaseIterable {
    case thisWeek = "thisWeek"
    case thisMonth = "thisMonth"
    case last3Months = "last3Months"
    case thisYear = "thisYear"
    case allTime = "allTime"
    
    var title: String {
        switch self {
        case .thisWeek: return "This Week"
        case .thisMonth: return "This Month"
        case .last3Months: return "Last 3 Months"
        case .thisYear: return "This Year"
        case .allTime: return "All Time"
        }
    }
}

// MARK: - Food Journey View Model

@MainActor
class FoodJourneyViewModel: ObservableObject {
    @Published var journeyData: [JourneyPeriod] = []
    @Published var uniqueCuisines: Set<String> = []
    @Published var uniqueRestaurants: Set<String> = []
    @Published var activeDays: Int = 0
    @Published var longestStreak: Int = 0
    @Published var isLoading = false
    
    func loadJourneyData(for user: User, timeframe: JourneyTimeframe) async {
        isLoading = true
        
        // Simulate loading - in real app, this would fetch from backend
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // Generate mock journey data
        let mockData = generateMockJourneyData(for: user, timeframe: timeframe)
        
        journeyData = mockData.periods
        uniqueCuisines = mockData.uniqueCuisines
        uniqueRestaurants = mockData.uniqueRestaurants
        activeDays = mockData.activeDays
        longestStreak = mockData.longestStreak
        
        isLoading = false
    }
    
    private func generateMockJourneyData(for user: User, timeframe: JourneyTimeframe) -> (
        periods: [JourneyPeriod],
        uniqueCuisines: Set<String>,
        uniqueRestaurants: Set<String>,
        activeDays: Int,
        longestStreak: Int
    ) {
        // Mock data generation - in real app, this would be calculated from actual user data
        let periods = [
            JourneyPeriod(
                title: "This Week",
                subtitle: "3 new experiences • 2 achievements",
                highlights: ["First Italian", "Local Expert"],
                events: [
                    JourneyEvent(
                        type: .post,
                        title: "Amazing pasta at Mario's",
                        description: "Discovered this hidden gem downtown",
                        timestamp: Date().addingTimeInterval(-86400),
                        imageURL: nil,
                        tags: ["Italian", "Pasta", "Downtown"]
                    ),
                    JourneyEvent(
                        type: .achievement,
                        title: "First Italian Cuisine",
                        description: "Unlocked by trying authentic Italian food",
                        timestamp: Date().addingTimeInterval(-86400),
                        imageURL: nil,
                        tags: ["Achievement", "Italian"]
                    )
                ],
                color: .green
            ),
            JourneyPeriod(
                title: "Last Month",
                subtitle: "12 experiences • 5 new cuisines",
                highlights: ["Foodie Explorer", "Social Butterfly"],
                events: [
                    JourneyEvent(
                        type: .milestone,
                        title: "10th Post Milestone",
                        description: "Shared your 10th food experience",
                        timestamp: Date().addingTimeInterval(-604800),
                        imageURL: nil,
                        tags: ["Milestone", "10 Posts"]
                    )
                ],
                color: .blue
            )
        ]
        
        return (
            periods: periods,
            uniqueCuisines: Set(["Italian", "Mexican", "Japanese", "Thai", "Indian"]),
            uniqueRestaurants: Set(["Mario's", "Taco Bell", "Sushi House", "Thai Garden"]),
            activeDays: 15,
            longestStreak: 7
        )
    }
}

// MARK: - Compact Food Journey View

struct FoodJourneyCompactView: View {
    let user: User
    let posts: [Post]
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Food Journey")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                Spacer()
                
                NavigationLink(destination: FoodJourneyTimelineView(user: user)) {
                    Text("View All")
                        .font(.subheadline)
                        .foregroundColor(.primaryBrand)
                }
            }
            
            if posts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "map")
                        .font(.system(size: 30))
                        .foregroundColor(.secondaryText)
                    
                    Text("No journey yet")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                    
                    Text("Start sharing food experiences to build your culinary journey!")
                        .font(.caption)
                        .foregroundColor(.tertiaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 120)
            } else {
                // Journey Preview
                journeyPreview
            }
        }
    }
    
    private var journeyPreview: some View {
        VStack(spacing: 12) {
            // Quick Stats
            HStack(spacing: 20) {
                let uniqueCuisines = Set(posts.flatMap { $0.menuItems }).count
                let uniquePlaces = Set(posts.compactMap { $0.shop?.name }).count
                
                CompactStat(title: "Cuisines", value: "\(uniqueCuisines)", icon: "fork.knife")
                CompactStat(title: "Places", value: "\(uniquePlaces)", icon: "location.fill")
                CompactStat(title: "Posts", value: "\(posts.count)", icon: "camera.fill")
            }
            
            // Recent Activity Timeline
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(posts.prefix(5).sorted { $0.createdAt > $1.createdAt }, id: \.id) { post in
                        CompactJourneyEvent(post: post)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
}

struct CompactStat: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.primaryBrand)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primaryText)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

struct CompactJourneyEvent: View {
    let post: Post
    
    var body: some View {
        VStack(spacing: 6) {
            if let imageURL = post.mediaURLs.first {
                KFImage(imageURL)
                    .placeholder {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 50, height: 50)
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient.primaryGradient)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "camera.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                    )
            }
            
            Text(post.createdAt, style: .relative)
                .font(.caption2)
                .foregroundColor(.secondaryText)
                .lineLimit(1)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FoodJourneyTimelineView(user: User.preview)
    }
}

#Preview("Compact Journey") {
    FoodJourneyCompactView(user: User.preview, posts: [])
        .padding()
} 