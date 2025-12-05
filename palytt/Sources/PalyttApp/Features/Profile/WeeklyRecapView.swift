//
//  WeeklyRecapView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import SwiftUI
import Clerk

// MARK: - Weekly Recap View

struct WeeklyRecapView: View {
    @StateObject private var viewModel = WeeklyRecapViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: [Color.primaryBrand.opacity(0.8), Color.purple.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Page indicator
                    HStack(spacing: 8) {
                        ForEach(0..<4, id: \.self) { index in
                            Capsule()
                                .fill(currentPage == index ? Color.white : Color.white.opacity(0.3))
                                .frame(width: currentPage == index ? 24 : 8, height: 4)
                                .animation(.spring(response: 0.3), value: currentPage)
                        }
                    }
                    .padding(.top, 12)
                    
                    // Content pages
                    TabView(selection: $currentPage) {
                        // Page 1: Overview
                        recapOverviewPage
                            .tag(0)
                        
                        // Page 2: Posts & Engagement
                        postsEngagementPage
                            .tag(1)
                        
                        // Page 3: Social Highlights
                        socialHighlightsPage
                            .tag(2)
                        
                        // Page 4: Share & Summary
                        shareSummaryPage
                            .tag(3)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
                
                if viewModel.isLoading {
                    loadingOverlay
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = shareImage {
                    ShareSheet(activityItems: [image, "Check out my Palytt weekly recap! 🍕 #Palytt #FoodieLife"])
                }
            }
        }
        .task {
            await viewModel.loadRecapData()
        }
    }
    
    // MARK: - Page 1: Overview
    
    private var recapOverviewPage: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Animated emoji
            Text("🎉")
                .font(.system(size: 80))
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            
            VStack(spacing: 16) {
                Text("Your Week in Review")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                Text(viewModel.weekDateRange)
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            // Quick stats teaser
            HStack(spacing: 32) {
                quickStatBubble(value: "\(viewModel.totalPosts)", label: "Posts")
                quickStatBubble(value: "\(viewModel.totalLikesReceived)", label: "Likes")
                quickStatBubble(value: "\(viewModel.newFriends)", label: "Friends")
            }
            
            Spacer()
            
            // Swipe hint
            swipeHint
        }
        .padding()
    }
    
    // MARK: - Page 2: Posts & Engagement
    
    private var postsEngagementPage: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Text("📸")
                .font(.system(size: 60))
            
            Text("Your Food Journey")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            // Stats cards
            VStack(spacing: 16) {
                statCard(
                    icon: "camera.fill",
                    title: "\(viewModel.totalPosts) Posts",
                    subtitle: viewModel.postsChangeText,
                    color: .orange
                )
                
                statCard(
                    icon: "heart.fill",
                    title: "\(viewModel.totalLikesReceived) Likes Received",
                    subtitle: "Your food inspired others!",
                    color: .red
                )
                
                statCard(
                    icon: "message.fill",
                    title: "\(viewModel.totalComments) Comments",
                    subtitle: "Conversations started",
                    color: .blue
                )
                
                if viewModel.currentStreak > 0 {
                    statCard(
                        icon: "flame.fill",
                        title: "\(viewModel.currentStreak) Day Streak",
                        subtitle: viewModel.streakMessage,
                        color: .orange
                    )
                }
            }
            
            Spacer()
            
            swipeHint
        }
        .padding()
    }
    
    // MARK: - Page 3: Social Highlights
    
    private var socialHighlightsPage: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Text("👥")
                .font(.system(size: 60))
            
            Text("Social Highlights")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            VStack(spacing: 16) {
                statCard(
                    icon: "person.badge.plus",
                    title: "\(viewModel.newFriends) New Friends",
                    subtitle: "Your network is growing!",
                    color: .green
                )
                
                statCard(
                    icon: "mappin.circle.fill",
                    title: "\(viewModel.restaurantsVisited) Restaurants",
                    subtitle: "Places discovered this week",
                    color: .purple
                )
                
                statCard(
                    icon: "fork.knife",
                    title: "\(viewModel.cuisinesExplored) Cuisines",
                    subtitle: "Variety is the spice of life!",
                    color: .cyan
                )
                
                if !viewModel.topCuisine.isEmpty {
                    statCard(
                        icon: "star.fill",
                        title: viewModel.topCuisine,
                        subtitle: "Your favorite cuisine this week",
                        color: .yellow
                    )
                }
            }
            
            Spacer()
            
            swipeHint
        }
        .padding()
    }
    
    // MARK: - Page 4: Share Summary
    
    private var shareSummaryPage: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Shareable card preview
            shareableRecapCard
                .id("shareCard")
            
            Text("Share your week!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Show off your foodie journey")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            
            // Share button
            Button(action: {
                generateShareImage()
                HapticManager.shared.impact(.medium)
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.headline)
                    Text("Share Recap")
                        .font(.headline)
                }
                .foregroundColor(.primaryBrand)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(Color.white)
                )
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Shareable Recap Card
    
    private var shareableRecapCard: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.title2)
                    .foregroundColor(.primaryBrand)
                
                Text("Palytt")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
                
                Spacer()
                
                Text(viewModel.weekDateRange)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            
            Divider()
            
            // Stats grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                miniStatCard(value: "\(viewModel.totalPosts)", label: "Posts", icon: "camera.fill")
                miniStatCard(value: "\(viewModel.totalLikesReceived)", label: "Likes", icon: "heart.fill")
                miniStatCard(value: "\(viewModel.restaurantsVisited)", label: "Places", icon: "mappin.circle.fill")
                miniStatCard(value: "🔥 \(viewModel.currentStreak)", label: "Streak", icon: nil)
            }
            
            // Footer
            HStack {
                Text("My Week on Palytt")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryBrand)
                
                Spacer()
                
                Text("palytt.com")
                    .font(.caption2)
                    .foregroundColor(.secondaryText)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        )
        .frame(width: 300)
    }
    
    // MARK: - Helper Views
    
    private func quickStatBubble(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.2))
        )
    }
    
    private func statCard(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.15))
        )
    }
    
    private func miniStatCard(value: String, label: String, icon: String?) -> some View {
        VStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.primaryBrand)
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primaryText)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondaryText)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
    
    private var swipeHint: some View {
        HStack(spacing: 4) {
            Text("Swipe to continue")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.bottom, 32)
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            ProgressView()
                .tint(.white)
                .scaleEffect(1.5)
        }
    }
    
    // MARK: - Share Image Generation
    
    private func generateShareImage() {
        // Create a snapshot of the shareable card
        let renderer = ImageRenderer(content: shareableRecapCard)
        renderer.scale = UIScreen.main.scale
        
        if let image = renderer.uiImage {
            shareImage = image
            showShareSheet = true
        }
    }
}

// MARK: - Weekly Recap View Model

@MainActor
class WeeklyRecapViewModel: ObservableObject {
    @Published var totalPosts: Int = 0
    @Published var totalLikesReceived: Int = 0
    @Published var totalComments: Int = 0
    @Published var newFriends: Int = 0
    @Published var restaurantsVisited: Int = 0
    @Published var cuisinesExplored: Int = 0
    @Published var currentStreak: Int = 0
    @Published var topCuisine: String = ""
    @Published var isLoading = false
    
    private let backendService = BackendService.shared
    
    var weekDateRange: String {
        let calendar = Calendar.current
        let today = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        return "\(formatter.string(from: weekAgo)) - \(formatter.string(from: today))"
    }
    
    var postsChangeText: String {
        if totalPosts > 7 {
            return "More than one post per day! 🔥"
        } else if totalPosts >= 5 {
            return "Great posting frequency!"
        } else if totalPosts > 0 {
            return "Keep sharing your food adventures!"
        } else {
            return "Start posting to build your recap!"
        }
    }
    
    var streakMessage: String {
        if currentStreak >= 30 {
            return "Legendary consistency! 👑"
        } else if currentStreak >= 14 {
            return "Two weeks strong! 💪"
        } else if currentStreak >= 7 {
            return "One week milestone!"
        } else {
            return "Keep it going!"
        }
    }
    
    func loadRecapData() async {
        isLoading = true
        
        // TODO: Fetch from backend when endpoint is ready
        // For now, generate mock data
        try? await Task.sleep(nanoseconds: 800_000_000)
        
        totalPosts = Int.random(in: 3...12)
        totalLikesReceived = Int.random(in: 20...150)
        totalComments = Int.random(in: 5...40)
        newFriends = Int.random(in: 0...8)
        restaurantsVisited = Int.random(in: 2...10)
        cuisinesExplored = Int.random(in: 2...6)
        currentStreak = Int.random(in: 0...21)
        
        let cuisines = ["Japanese", "Italian", "Mexican", "Thai", "American", "Indian", "Korean", "Chinese"]
        topCuisine = cuisines.randomElement() ?? "Japanese"
        
        isLoading = false
    }
}

// MARK: - Preview

#Preview {
    WeeklyRecapView()
}

