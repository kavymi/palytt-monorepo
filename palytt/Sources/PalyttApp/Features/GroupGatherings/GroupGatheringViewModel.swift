//
//  GroupGatheringViewModel.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import Foundation
import SwiftUI
import EventKit
import Combine

@MainActor
class GroupGatheringViewModel: ObservableObject {
    @Published var gathering: GroupGathering
    @Published var currentUserId: String
    @Published var recentActivity: [GatheringActivity] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Voting state
    @Published var userTimeVotes: [String: TimeVote] = [:] // timeSlotId -> vote
    @Published var userVenueVotes: [String: VenueVote] = [:] // venueId -> vote
    
    // Calendar integration
    private let eventStore = EKEventStore()
    @Published var calendarAuthorizationStatus: EKAuthorizationStatus = .notDetermined
    
    // File upload state
    @Published var isUploadingFile = false
    @Published var uploadProgress: Double = 0.0
    
    private var cancellables = Set<AnyCancellable>()
    
    init(gathering: GroupGathering, currentUserId: String) {
        self.gathering = gathering
        self.currentUserId = currentUserId
        
        setupInitialState()
        checkCalendarAuthorization()
        loadRecentActivity()
    }
    
    // MARK: - Computed Properties
    
    var canCurrentUserVote: Bool {
        gathering.canUserVote(currentUserId)
    }
    
    var canCurrentUserArchive: Bool {
        gathering.canUserArchive(currentUserId)
    }
    
    var isCurrentUserCreator: Bool {
        gathering.creatorId == currentUserId
    }
    
    var completionPercentage: Int {
        var completed = 0
        var total = 0
        
        // Check if time is selected
        total += 1
        if gathering.finalDateTime != nil {
            completed += 1
        }
        
        // Check if venue is selected
        total += 1
        if gathering.finalVenue != nil {
            completed += 1
        }
        
        // Check if participants have joined
        total += 1
        if !gathering.participants.isEmpty {
            completed += 1
        }
        
        // Check if voting is complete
        if gathering.votingSettings.requireAllParticipantsToVote {
            total += 1
            let timeVotesComplete = gathering.proposedTimeSlots.allSatisfy { slot in
                slot.votes.count >= gathering.participants.count
            }
            let venueVotesComplete = gathering.venueRecommendations.allSatisfy { venue in
                gathering.venueVotes.filter { $0.venueId == venue.id }.count >= gathering.participants.count
            }
            if timeVotesComplete && venueVotesComplete {
                completed += 1
            }
        }
        
        return total > 0 ? Int((Double(completed) / Double(total)) * 100) : 0
    }
    
    // MARK: - Setup
    
    private func setupInitialState() {
        // Load user's existing votes
        loadUserVotes()
        
        // Set up real-time updates (in a real app, this would connect to websockets)
        // For now, we'll simulate with a timer
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshGatheringData()
            }
            .store(in: &cancellables)
    }
    
    private func loadUserVotes() {
        // Load time votes
        for timeSlot in gathering.proposedTimeSlots {
            if let vote = timeSlot.votes.first(where: { $0.userId == currentUserId }) {
                userTimeVotes[timeSlot.id] = vote
            }
        }
        
        // Load venue votes
        for vote in gathering.venueVotes {
            if vote.userId == currentUserId {
                userVenueVotes[vote.venueId] = vote
            }
        }
    }
    
    private func loadRecentActivity() {
        // Generate recent activity based on gathering data
        var activities: [GatheringActivity] = []
        
        // Add recent votes
        let recentTimeVotes = gathering.proposedTimeSlots.flatMap { $0.votes }
            .sorted { $0.votedAt > $1.votedAt }
            .prefix(3)
        
        for vote in recentTimeVotes {
            activities.append(GatheringActivity(
                id: UUID().uuidString,
                description: "\(getUserName(vote.userId)) voted on a time slot",
                icon: "clock.fill",
                timestamp: vote.votedAt
            ))
        }
        
        // Add recent venue votes
        let recentVenueVotes = gathering.venueVotes
            .sorted { $0.votedAt > $1.votedAt }
            .prefix(3)
        
        for vote in recentVenueVotes {
            activities.append(GatheringActivity(
                id: UUID().uuidString,
                description: "\(getUserName(vote.userId)) voted on a venue",
                icon: "location.fill",
                timestamp: vote.votedAt
            ))
        }
        
        // Add recent file uploads
        let recentFiles = gathering.attachedFiles
            .sorted { $0.uploadedAt > $1.uploadedAt }
            .prefix(2)
        
        for file in recentFiles {
            activities.append(GatheringActivity(
                id: UUID().uuidString,
                description: "\(getUserName(file.uploadedBy)) shared \(file.originalName)",
                icon: "doc.fill",
                timestamp: file.uploadedAt
            ))
        }
        
        // Sort by timestamp and take most recent
        recentActivity = activities
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(10)
            .map { $0 }
    }
    
    private func getUserName(_ userId: String) -> String {
        if userId == currentUserId {
            return "You"
        }
        return gathering.participants.first { $0.userId == userId }?.userName ?? "Someone"
    }
    
    // MARK: - Voting Actions
    
    func voteOnTimeSlot(_ timeSlotId: String, vote: TimeVote.VoteType, notes: String? = nil) {
        guard canCurrentUserVote else { return }
        
        let newVote = TimeVote(
            id: UUID().uuidString,
            timeSlotId: timeSlotId,
            userId: currentUserId,
            vote: vote,
            availabilityStatus: .free, // Would check calendar in real implementation
            votedAt: Date(),
            notes: notes
        )
        
        // Update local state
        userTimeVotes[timeSlotId] = newVote
        
        // Update gathering
        if let index = gathering.proposedTimeSlots.firstIndex(where: { $0.id == timeSlotId }) {
            // Remove existing vote if any
            gathering.proposedTimeSlots[index].votes.removeAll { $0.userId == currentUserId }
            // Add new vote
            gathering.proposedTimeSlots[index].votes.append(newVote)
        }
        
        // Update history
        gathering.gatheringHistory.incrementTotalVotes()
        
        // In a real app, this would sync to backend
        syncVoteToBackend(newVote)
    }
    
    func voteOnVenue(_ venueId: String, vote: VenueVote.VoteType, notes: String? = nil) {
        guard canCurrentUserVote else { return }
        
        let newVote = VenueVote(
            id: UUID().uuidString,
            venueId: venueId,
            userId: currentUserId,
            vote: vote,
            votedAt: Date(),
            notes: notes
        )
        
        // Update local state
        userVenueVotes[venueId] = newVote
        
        // Update gathering
        // Remove existing vote if any
        gathering.venueVotes.removeAll { $0.userId == currentUserId && $0.venueId == venueId }
        // Add new vote
        gathering.venueVotes.append(newVote)
        
        // Update history
        gathering.gatheringHistory.incrementTotalVotes()
        
        // In a real app, this would sync to backend
        syncVoteToBackend(newVote)
    }
    
    private func syncVoteToBackend<T: Codable>(_ vote: T) {
        // In a real implementation, this would make an API call
        print("Syncing vote to backend: \(vote)")
    }
    
    // MARK: - Gathering Management
    
    func archiveGathering() {
        guard canCurrentUserArchive else { return }
        
        gathering.archive(by: currentUserId)
        
        // Update user history
        updateUserHistory()
        
        // In a real app, this would sync to backend
        syncGatheringToBackend()
    }
    
    func shareGathering() {
        // Create share content
        let shareText = """
        Join my gathering: \(gathering.title)
        
        \(gathering.gatheringType.displayName) gathering
        \(gathering.participants.count) participants
        
        \(gathering.gatheringHashtag ?? "")
        """
        
        // In a real app, this would present the system share sheet
        print("Sharing gathering: \(shareText)")
    }
    
    func addLinkedPost(_ linkedPost: LinkedPost) {
        gathering.linkedPosts.append(linkedPost)
        gathering.gatheringHistory.incrementLinkedPosts()
        
        // In a real app, this would sync to backend
        syncGatheringToBackend()
    }
    
    func addManualVenue(_ venue: ManualVenue) {
        gathering.manualVenues.append(venue)
        
        // In a real app, this would sync to backend
        syncGatheringToBackend()
    }
    
    private func updateUserHistory() {
        // In a real app, this would update the user's gathering history
        print("Updating user history for gathering completion")
    }
    
    private func syncGatheringToBackend() {
        // In a real app, this would sync the gathering to the backend
        print("Syncing gathering to backend")
    }
    
    private func refreshGatheringData() {
        // In a real app, this would fetch latest data from backend
        print("Refreshing gathering data")
    }
    
    func loadGatheringDetails() {
        // Reload gathering details after updates (e.g., invites sent)
        refreshGatheringData()
        loadRecentActivity()
    }
    
    // MARK: - Calendar Integration
    
    private func checkCalendarAuthorization() {
        calendarAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }
    
    func requestCalendarPermission() async {
        do {
            if #available(iOS 17.0, *) {
                let granted = try await eventStore.requestFullAccessToEvents()
                await MainActor.run {
                    calendarAuthorizationStatus = granted ? .fullAccess : .denied
                }
            } else {
                let granted = try await eventStore.requestAccess(to: .event)
                await MainActor.run {
                    calendarAuthorizationStatus = granted ? .authorized : .denied
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to request calendar permission: \(error.localizedDescription)"
            }
        }
    }
    
    func syncToCalendar() {
        // Check for both old and new authorization statuses
        let isAuthorized = if #available(iOS 17.0, *) {
            calendarAuthorizationStatus == .fullAccess || calendarAuthorizationStatus == .authorized
        } else {
            calendarAuthorizationStatus == .authorized
        }
        
        guard isAuthorized,
              let finalDateTime = gathering.finalDateTime else {
            return
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = gathering.title
        event.startDate = finalDateTime
        event.endDate = finalDateTime.addingTimeInterval(gathering.duration)
        event.notes = gathering.description
        
        if let venue = gathering.finalVenue {
            event.location = venue.address
        }
        
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        do {
            try eventStore.save(event, span: .thisEvent)
            
            // Update gathering with calendar event ID
            gathering.calendarEventId = event.eventIdentifier
            
            print("Successfully added to calendar")
        } catch {
            errorMessage = "Failed to add to calendar: \(error.localizedDescription)"
        }
    }
    
    // MARK: - File Management
    
    func uploadFile(_ fileData: Data, fileName: String, fileType: GatheringFile.FileType) async {
        guard !isUploadingFile else { return }
        
        isUploadingFile = true
        uploadProgress = 0.0
        
        do {
            // Simulate file upload with progress
            for i in 1...10 {
                try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                await MainActor.run {
                    uploadProgress = Double(i) / 10.0
                }
            }
            
            // Create file record
            let file = GatheringFile(
                fileName: UUID().uuidString + "_" + fileName,
                originalName: fileName,
                fileUrl: "https://example.com/files/\(UUID().uuidString)",
                fileType: fileType,
                fileSize: Int64(fileData.count),
                uploadedBy: currentUserId
            )
            
            await MainActor.run {
                gathering.attachedFiles.append(file)
                gathering.gatheringHistory.incrementFilesShared()
                isUploadingFile = false
                uploadProgress = 0.0
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to upload file: \(error.localizedDescription)"
                isUploadingFile = false
                uploadProgress = 0.0
            }
        }
    }
}

// MARK: - Supporting Types

struct GatheringActivity: Identifiable, Hashable {
    let id: String
    let description: String
    let icon: String
    let timestamp: Date
}

// MARK: - Preview Extension

extension GroupGatheringViewModel {
    static var preview: GroupGatheringViewModel {
        let gathering = GroupGathering(
            title: "Team Lunch at The Grove",
            description: "Let's grab lunch together and catch up!",
            creatorId: "user1",
            type: .lunch,
            location: GatheringLocation(
                centerPoint: GatheringLocation.LocationPoint(
                    latitude: 34.0522,
                    longitude: -118.2437,
                    name: "Los Angeles",
                    address: "Los Angeles, CA"
                )
            )
        )
        
        return GroupGatheringViewModel(gathering: gathering, currentUserId: "user1")
    }
}
