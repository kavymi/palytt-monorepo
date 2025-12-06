//
//  FriendRequestsView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI

struct FriendRequestsView: View {
    @StateObject private var viewModel = FriendRequestsViewModel()
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.isLoading && viewModel.friendRequests.isEmpty {
                    // Loading state
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading friend requests...")
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.friendRequests.isEmpty && !viewModel.isLoading {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.badge.gearshape")
                            .font(.system(size: 50))
                            .foregroundColor(.tertiaryText)
                        
                        Text("No Friend Requests")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primaryText)
                        
                        Text("When people send you friend requests, they'll appear here.")
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Friend requests list
                    List {
                        ForEach(viewModel.friendRequests, id: \._id) { request in
                            FriendRequestRowView(
                                request: request,
                                onAccept: {
                                    Task {
                                        await viewModel.acceptRequest(request._id)
                                    }
                                },
                                onDecline: {
                                    Task {
                                        await viewModel.rejectRequest(request._id)
                                    }
                                }
                            )
                            .listRowBackground(Color.cardBackground)
                            .listRowSeparatorTint(Color.divider)
                        }
                    }
                    .listStyle(PlainListStyle())
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
                
                // Error message
                if let errorMessage = viewModel.errorMessage {
                    VStack(spacing: 12) {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                        
                        Button("Try Again") {
                            Task {
                                await viewModel.loadFriendRequests(for: appState.currentUser?.clerkId ?? "")
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.primaryBrand)
                    }
                    .padding()
                    .background(Color.cardBackground)
                }
            }
            .navigationTitle("Friend Requests")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.primaryBrand)
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.primaryBrand)
                }
                #endif
            }
            .background(Color.background)
        }
        .task {
            await viewModel.loadFriendRequests(for: appState.currentUser?.clerkId ?? "")
        }
    }
}

// MARK: - Friend Request Row View
struct FriendRequestRowView: View {
    let request: BackendService.FriendRequest
    let onAccept: () -> Void
    let onDecline: () -> Void
    @State private var isProcessing = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Profile image
                AsyncImage(url: URL(string: request.sender?.avatarUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(LinearGradient.primaryGradient)
                        .overlay(
                            Text((request.sender?.displayName ?? request.sender?.username ?? "U").prefix(2).uppercased())
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(request.sender?.displayName ?? request.sender?.username ?? "Unknown User")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                        .lineLimit(1)
                    
                    Text("@\(request.sender?.username ?? "unknown")")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .lineLimit(1)
                    
                    Text("Sent \(relativeTime(from: request.createdAt))")
                        .font(.caption2)
                        .foregroundColor(.tertiaryText)
                }
                
                Spacer()
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: {
                    isProcessing = true
                    onDecline()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isProcessing = false
                    }
                }) {
                    Text("Decline")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red, lineWidth: 1)
                        )
                }
                .disabled(isProcessing)
                
                Button(action: {
                    isProcessing = true
                    onAccept()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isProcessing = false
                    }
                }) {
                    Text("Accept")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.primaryBrand)
                        )
                }
                .disabled(isProcessing)
            }
        }
        .padding(.vertical, 8)
        .opacity(isProcessing ? 0.6 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isProcessing)
    }
    
    private func relativeTime(from timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Friend Requests ViewModel
@MainActor
class FriendRequestsViewModel: ObservableObject {
    @Published var friendRequests: [BackendService.FriendRequest] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let backendService = BackendService.shared
    
    private var currentUserId: String = ""
    
    func loadFriendRequests(for userId: String) async {
        guard !userId.isEmpty else {
            errorMessage = "Please sign in to view friend requests"
            return
        }
        
        currentUserId = userId
        isLoading = true
        errorMessage = nil
        
        do {
            let requests = try await backendService.getPendingFriendRequests(userId: userId)
            friendRequests = requests
        } catch {
            errorMessage = "Failed to load friend requests: \(error.localizedDescription)"
            print("❌ Error loading friend requests: \(error)")
        }
        
        isLoading = false
    }
    
    func refresh() async {
        await loadFriendRequests(for: currentUserId)
    }
    
    func acceptRequest(_ requestId: String) async {
        errorMessage = nil
        
        do {
            _ = try await backendService.acceptFriendRequest(requestId: requestId)
            
            // Remove from list
            friendRequests.removeAll { $0._id == requestId }
            
            HapticManager.shared.haptic(.success)
        } catch {
            errorMessage = "Failed to accept friend request: \(error.localizedDescription)"
            HapticManager.shared.haptic(.error)
            print("❌ Error accepting friend request: \(error)")
        }
    }
    
    func rejectRequest(_ requestId: String) async {
        errorMessage = nil
        
        do {
            _ = try await backendService.rejectFriendRequest(requestId: requestId)
            
            // Remove from list
            friendRequests.removeAll { $0._id == requestId }
            
            HapticManager.shared.haptic(.selection)
        } catch {
            errorMessage = "Failed to reject friend request: \(error.localizedDescription)"
            HapticManager.shared.haptic(.error)
            print("❌ Error rejecting friend request: \(error)")
        }
    }
} 

// MARK: - SwiftUI Previews
#Preview("Friend Requests View") {
    NavigationStack {
        FriendRequestsView()
    }
    .environmentObject(MockAppState())
}

#Preview("Friend Request Row") {
    let mockUser = BackendUser(
        id: "user_456",
        userId: "user_456",
        clerkId: "user_456",
        email: "jane@example.com",
        firstName: "Jane",
        lastName: "Smith",
        username: "janesmith",
        displayName: "Jane Smith",
        name: "Jane Smith",
        bio: "Coffee lover and photographer",
        avatarUrl: nil,
        profileImage: nil,
        role: "user",
        appleId: nil,
        googleId: nil,
        dietaryPreferences: nil,
        followerCount: 89,
        followingCount: 145,
        postsCount: 12,
        isVerified: false,
        isActive: true,
        createdAt: .timestamp(Int(Date().timeIntervalSince1970 * 1000)),
        updatedAt: .timestamp(Int(Date().timeIntervalSince1970 * 1000))
    )
    
    VStack(spacing: 16) {
        HStack {
            Text("Friend Request from \(mockUser.displayName ?? "Unknown")")
            Spacer()
            Button("Accept") { }
            Button("Decline") { }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(8)
    }
    .padding()
    .environmentObject(MockAppState())
} 