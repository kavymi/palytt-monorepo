//
//  ContactsSyncView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import SwiftUI
import Contacts
import CryptoKit

// MARK: - Contacts Sync View

struct ContactsSyncView: View {
    @StateObject private var viewModel = ContactsSyncViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                if viewModel.permissionStatus == .notDetermined {
                    permissionRequestView
                } else if viewModel.permissionStatus == .denied {
                    permissionDeniedView
                } else if viewModel.isLoading {
                    loadingView
                } else if viewModel.matchedUsers.isEmpty {
                    noMatchesView
                } else {
                    matchedUsersList
                }
            }
            .navigationTitle("Find from Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.primaryBrand)
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
        .onAppear {
            viewModel.checkPermission()
        }
    }
    
    // MARK: - Permission Request View
    
    private var permissionRequestView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.primaryBrand.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 50))
                    .foregroundColor(.primaryBrand)
            }
            
            VStack(spacing: 12) {
                Text("Find Friends on Palytt")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
                
                Text("We'll check your contacts to find people you know who are already on Palytt. Your contacts are never stored on our servers.")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button(action: {
                HapticManager.shared.impact(.medium)
                viewModel.requestPermission()
            }) {
                Text("Allow Access to Contacts")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.primaryBrand)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            
            Button("Not Now") {
                dismiss()
            }
            .font(.subheadline)
            .foregroundColor(.secondaryText)
        }
        .padding()
    }
    
    // MARK: - Permission Denied View
    
    private var permissionDeniedView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "lock.shield")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)
            }
            
            VStack(spacing: 12) {
                Text("Contacts Access Needed")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
                
                Text("To find friends from your contacts, please enable access in Settings.")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button(action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("Open Settings")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.primaryBrand)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)
        }
        .padding()
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Finding friends...")
                .font(.subheadline)
                .foregroundColor(.secondaryText)
        }
    }
    
    // MARK: - No Matches View
    
    private var noMatchesView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.secondaryText.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "person.2.slash")
                    .font(.system(size: 50))
                    .foregroundColor(.secondaryText)
            }
            
            VStack(spacing: 12) {
                Text("No Friends Found")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
                
                Text("None of your contacts are on Palytt yet. Invite them to join!")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button(action: {
                // TODO: Open invite view
                HapticManager.shared.impact(.medium)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Invite Friends")
                }
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.primaryBrand)
                .cornerRadius(12)
            }
            .padding(.horizontal, 32)
        }
        .padding()
    }
    
    // MARK: - Matched Users List
    
    private var matchedUsersList: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("\(viewModel.matchedUsers.count) friends found")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondaryText)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.matchedUsers) { match in
                        ContactMatchRow(
                            match: match,
                            onAddFriend: {
                                Task {
                                    await viewModel.sendFriendRequest(to: match.user)
                                }
                            }
                        )
                        Divider()
                            .padding(.leading, 76)
                    }
                }
            }
        }
    }
}

// MARK: - Contact Match Row

struct ContactMatchRow: View {
    let match: ContactMatch
    let onAddFriend: () -> Void
    @State private var isLoading = false
    @State private var requestSent = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            BackendUserAvatar(user: match.backendUser, size: 50)
            
            // User Info
            VStack(alignment: .leading, spacing: 4) {
                Text(match.user.name ?? match.user.username ?? "Unknown")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                Text("@\(match.user.username ?? "unknown")")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                
                // Contact name if different
                if let contactName = match.contactName,
                   contactName != match.user.name {
                    Text("from contacts: \(contactName)")
                        .font(.caption2)
                        .foregroundColor(.tertiaryText)
                }
            }
            
            Spacer()
            
            // Add Friend Button
            if requestSent {
                Text("Sent")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondaryText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.cardBackground)
                    .cornerRadius(16)
            } else {
                Button(action: {
                    HapticManager.shared.impact(.light)
                    isLoading = true
                    onAddFriend()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        isLoading = false
                        requestSent = true
                    }
                }) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .primaryBrand))
                            .scaleEffect(0.8)
                            .frame(width: 80, height: 32)
                    } else {
                        Text("Add")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.primaryBrand)
                            .cornerRadius(16)
                    }
                }
                .disabled(isLoading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Contact Match Model

struct ContactMatch: Identifiable {
    let id = UUID()
    let user: BackendService.PhoneMatchedUser
    let contactName: String?
    let phoneNumber: String?
    
    /// Convert PhoneMatchedUser to BackendUser for compatibility with existing views
    var backendUser: BackendUser {
        BackendUser(
            id: user.id,
            userId: user.id,
            clerkId: user.clerkId,
            email: nil,
            firstName: user.name,
            lastName: nil,
            username: user.username,
            displayName: user.name,
            bio: user.bio,
            avatarUrl: user.profileImage,
            role: nil,
            appleId: nil,
            googleId: nil,
            dietaryPreferences: nil,
            followersCount: user.followerCount,
            followingCount: user.followingCount,
            postsCount: user.postsCount,
            isVerified: user.isVerified,
            isActive: user.isActive,
            createdAt: Int(Date().timeIntervalSince1970),
            updatedAt: Int(Date().timeIntervalSince1970)
        )
    }
}

// MARK: - Contacts Sync View Model

@MainActor
class ContactsSyncViewModel: ObservableObject {
    @Published var permissionStatus: CNAuthorizationStatus = .notDetermined
    @Published var matchedUsers: [ContactMatch] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let backendService = BackendService.shared
    private let contactStore = CNContactStore()
    
    func checkPermission() {
        permissionStatus = CNContactStore.authorizationStatus(for: .contacts)
        
        if permissionStatus == .authorized {
            Task {
                await syncContacts()
            }
        }
    }
    
    func requestPermission() {
        contactStore.requestAccess(for: .contacts) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.permissionStatus = granted ? .authorized : .denied
                
                if granted {
                    Task {
                        await self?.syncContacts()
                    }
                }
            }
        }
    }
    
    func syncContacts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch contacts with phone numbers
            let keysToFetch = [
                CNContactGivenNameKey,
                CNContactFamilyNameKey,
                CNContactPhoneNumbersKey
            ] as [CNKeyDescriptor]
            
            let request = CNContactFetchRequest(keysToFetch: keysToFetch)
            var phoneNumbers: [(hash: String, name: String, phone: String)] = []
            
            try contactStore.enumerateContacts(with: request) { contact, _ in
                let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                
                for phoneNumber in contact.phoneNumbers {
                    let number = phoneNumber.value.stringValue
                    let normalizedNumber = self.normalizePhoneNumber(number)
                    if !normalizedNumber.isEmpty {
                        let hash = self.hashPhoneNumber(normalizedNumber)
                        phoneNumbers.append((hash: hash, name: name, phone: normalizedNumber))
                    }
                }
            }
            
            // Get unique hashes
            let uniqueHashes = Array(Set(phoneNumbers.map { $0.hash }))
            
            if uniqueHashes.isEmpty {
                matchedUsers = []
                isLoading = false
                return
            }
            
            // Call backend to find users by hashed phone numbers
            let response = try await backendService.findUsersByPhoneHashes(phoneHashes: uniqueHashes)
            
            // Match users with contact names
            matchedUsers = response.users.compactMap { user in
                guard let matchedHash = response.matchedHashes.first(where: { hash in
                    user.phoneHash == hash
                }) else {
                    return ContactMatch(user: user, contactName: nil, phoneNumber: nil)
                }
                
                let contactInfo = phoneNumbers.first { $0.hash == matchedHash }
                return ContactMatch(
                    user: user,
                    contactName: contactInfo?.name,
                    phoneNumber: contactInfo?.phone
                )
            }
            
            print("✅ ContactsSyncViewModel: Found \(matchedUsers.count) matching users")
            
        } catch {
            print("❌ ContactsSyncViewModel: Failed to sync contacts: \(error)")
            errorMessage = "Failed to sync contacts: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func sendFriendRequest(to user: BackendService.PhoneMatchedUser) async {
        do {
            let response = try await backendService.sendFriendRequest(
                senderId: "", // Will be filled by backend from auth context
                receiverId: user.clerkId
            )
            
            if response.success {
                HapticManager.shared.impact(.success)
            }
        } catch {
            errorMessage = "Failed to send friend request: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Helper Methods
    
    private func normalizePhoneNumber(_ phone: String) -> String {
        // Remove all non-digit characters
        let digits = phone.filter { $0.isNumber }
        
        // Ensure we have at least 10 digits
        guard digits.count >= 10 else { return "" }
        
        // Take last 10 digits (removes country code variations)
        return String(digits.suffix(10))
    }
    
    private func hashPhoneNumber(_ phone: String) -> String {
        // Use SHA256 for hashing
        let data = Data(phone.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Preview

#Preview {
    ContactsSyncView()
}

