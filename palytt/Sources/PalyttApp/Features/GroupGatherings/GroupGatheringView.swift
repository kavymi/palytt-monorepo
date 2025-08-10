//
//  GroupGatheringView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import SwiftUI
import MapKit
import EventKit

struct GroupGatheringView: View {
    @ObservedObject var viewModel: GroupGatheringViewModel
    @State private var selectedTab: GatheringTab = .overview
    @State private var showingCreatePost = false
    @State private var showingAddManualVenue = false
    @State private var showingArchiveConfirmation = false
    
    enum GatheringTab: String, CaseIterable {
        case overview = "Overview"
        case timeVoting = "Time"
        case venueVoting = "Venues"
        case chat = "Chat"
        case files = "Files"
        case posts = "Posts"
        
        var icon: String {
            switch self {
            case .overview: return "info.circle.fill"
            case .timeVoting: return "clock.fill"
            case .venueVoting: return "location.fill"
            case .chat: return "bubble.left.and.bubble.right.fill"
            case .files: return "folder.fill"
            case .posts: return "photo.fill"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with gathering info
                gatheringHeader
                
                // Tab selector
                gatheringTabs
                
                // Content based on selected tab
                TabView(selection: $selectedTab) {
                    overviewTab.tag(GatheringTab.overview)
                    timeVotingTab.tag(GatheringTab.timeVoting)
                    venueVotingTab.tag(GatheringTab.venueVoting)
                    chatTab.tag(GatheringTab.chat)
                    filesTab.tag(GatheringTab.files)
                    postsTab.tag(GatheringTab.posts)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle(viewModel.gathering.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if viewModel.canCurrentUserArchive {
                            Button(role: .destructive) {
                                showingArchiveConfirmation = true
                            } label: {
                                Label("Archive Gathering", systemImage: "archivebox.fill")
                            }
                        }
                        
                        Button {
                            viewModel.shareGathering()
                        } label: {
                            Label("Share Gathering", systemImage: "square.and.arrow.up")
                        }
                        
                        if viewModel.gathering.calendarSyncEnabled {
                            Button {
                                viewModel.syncToCalendar()
                            } label: {
                                Label("Sync to Calendar", systemImage: "calendar.badge.plus")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .alert("Archive Gathering", isPresented: $showingArchiveConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Archive", role: .destructive) {
                viewModel.archiveGathering()
            }
        } message: {
            Text("This will permanently archive the gathering. Participants will still be able to view it, but no further changes can be made.")
        }
        .sheet(isPresented: $showingCreatePost) {
            CreatePostLinkedToGatheringView(
                gathering: viewModel.gathering,
                onPostCreated: { linkedPost in
                    viewModel.addLinkedPost(linkedPost)
                }
            )
        }
        .sheet(isPresented: $showingAddManualVenue) {
            AddManualVenueView(
                gathering: viewModel.gathering,
                onVenueAdded: { venue in
                    viewModel.addManualVenue(venue)
                }
            )
        }
    }
    
    // MARK: - Header
    
    private var gatheringHeader: some View {
        VStack(spacing: 12) {
            HStack {
                // Gathering type icon
                Image(systemName: viewModel.gathering.gatheringType.icon)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.gathering.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(viewModel.gathering.gatheringType.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status badge
                statusBadge
            }
            
            // Progress indicator
            if !viewModel.gathering.isArchived {
                gatheringProgress
            }
            
            // Participants preview
            participantsPreview
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: viewModel.gathering.status.icon)
                .font(.caption)
            Text(viewModel.gathering.status.displayName)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.1))
        .foregroundColor(.accentColor)
        .cornerRadius(8)
    }
    
    private var gatheringProgress: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Progress")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Text("\(viewModel.completionPercentage)%")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            ProgressView(value: Double(viewModel.completionPercentage) / 100.0)
                .tint(.accentColor)
        }
    }
    
    private var participantsPreview: some View {
        HStack {
            Text("\(viewModel.gathering.participants.count) participants")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Show first few participant avatars
            HStack(spacing: -8) {
                ForEach(viewModel.gathering.participants.prefix(5), id: \.id) { participant in
                    UserAvatar(
                        user: User(
                            id: UUID(),
                            email: "user@example.com",
                            username: participant.userName,
                            displayName: participant.userName,
                            avatarURL: URL(string: participant.userAvatar ?? "")
                        ),
                        size: 24
                    )
                }
                
                if viewModel.gathering.participants.count > 5 {
                    Text("+\(viewModel.gathering.participants.count - 5)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
            }
        }
    }
    
    // MARK: - Tabs
    
    private var gatheringTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(GatheringTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 16, weight: .medium))
                            Text(tab.rawValue)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTab == tab ? Color.accentColor.opacity(0.1) : Color.clear)
                        )
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Tab Content
    
    private var overviewTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Key information
                gatheringInfoCard
                
                // Quick actions
                quickActionsCard
                
                // Recent activity
                recentActivityCard
            }
            .padding()
        }
    }
    
    private var timeVotingTab: some View {
        Text("Time Voting - Coming Soon")
            .foregroundColor(.secondary)
            .padding()
    }
    
    private var venueVotingTab: some View {
        Text("Venue Voting - Coming Soon")
            .foregroundColor(.secondary)
            .padding()
    }
    
    private var chatTab: some View {
        Text("Group Chat - Coming Soon")
            .foregroundColor(.secondary)
            .padding()
    }
    
    private var filesTab: some View {
        Text("Files & Media - Coming Soon")
            .foregroundColor(.secondary)
            .padding()
    }
    
    private var postsTab: some View {
        Text("Linked Posts - Coming Soon")
            .foregroundColor(.secondary)
            .padding()
    }
    
    // MARK: - Overview Cards
    
    private var gatheringInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.accentColor)
                Text("Gathering Details")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if let description = viewModel.gathering.description {
                Text(description)
                    .font(.body)
                    .foregroundColor(.primary)
            }
            
            // Time and date if set
            if let finalDateTime = viewModel.gathering.finalDateTime {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.secondary)
                    Text(finalDateTime, style: .date)
                        .font(.subheadline)
                    
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                    Text(finalDateTime, style: .time)
                        .font(.subheadline)
                }
            }
            
            // Venue if set
            if let finalVenue = viewModel.gathering.finalVenue {
                HStack {
                    Image(systemName: "location")
                        .foregroundColor(.secondary)
                    Text(finalVenue.name)
                        .font(.subheadline)
                }
            }
            
            // Hashtag
            if let hashtag = viewModel.gathering.gatheringHashtag {
                Text(hashtag)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .foregroundColor(.accentColor)
                    .cornerRadius(6)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.accentColor)
                Text("Quick Actions")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                if viewModel.canCurrentUserVote {
                    quickActionButton(
                        title: "Vote on Time",
                        icon: "clock.fill",
                        color: .blue
                    ) {
                        selectedTab = .timeVoting
                    }
                    
                    quickActionButton(
                        title: "Vote on Venue",
                        icon: "location.fill",
                        color: .green
                    ) {
                        selectedTab = .venueVoting
                    }
                }
                
                quickActionButton(
                    title: "Create Post",
                    icon: "photo.fill",
                    color: .purple
                ) {
                    showingCreatePost = true
                }
                
                quickActionButton(
                    title: "Add Files",
                    icon: "folder.fill",
                    color: .orange
                ) {
                    selectedTab = .files
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func quickActionButton(
        title: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
    }
    
    private var recentActivityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.accentColor)
                Text("Recent Activity")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            // Show recent activity items
            if viewModel.recentActivity.isEmpty {
                Text("No recent activity")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(viewModel.recentActivity.prefix(5), id: \.id) { activity in
                    recentActivityItem(activity)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func recentActivityItem(_ activity: GatheringActivity) -> some View {
        HStack(spacing: 12) {
            Image(systemName: activity.icon)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.description)
                    .font(.caption)
                    .foregroundColor(.primary)
                
                Text(activity.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Supporting Views

struct CreatePostLinkedToGatheringView: View {
    let gathering: GroupGathering
    let onPostCreated: (LinkedPost) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Text("Create Post Linked to \(gathering.title)")
                .navigationTitle("Create Post")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

struct AddManualVenueView: View {
    let gathering: GroupGathering
    let onVenueAdded: (ManualVenue) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Text("Add Manual Venue for \(gathering.title)")
                .navigationTitle("Add Venue")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

// MARK: - Preview

struct GroupGatheringView_Previews: PreviewProvider {
    static var previews: some View {
        GroupGatheringView(viewModel: GroupGatheringViewModel.preview)
    }
}
