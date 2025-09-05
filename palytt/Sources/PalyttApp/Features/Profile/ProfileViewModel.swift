//
//  ProfileViewModel.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI
import Clerk
import Foundation
import Combine
#if os(iOS)
import UIKit
#endif

@MainActor
class ProfileViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var currentUser: User?
    @Published var userPosts: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage: String? {
        didSet {
            showError = errorMessage != nil
        }
    }
    
    // Edit Profile Properties
    @Published var isEditingProfile = false
    @Published var profileImageURL: String = ""
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var username: String = ""
    @Published var bio: String = ""
    @Published var selectedDietaryPreferences: Set<DietaryPreference> = []
    
    // Email Update Properties
    @Published var isUpdatingEmail = false
    @Published var newEmail: String = ""
    @Published var verificationCode: String = ""
    @Published var isVerifyingEmail = false
    @Published var emailUpdateStep: EmailUpdateStep = .enterEmail
    
    // Phone Number Properties
    @Published var phoneNumber: String = ""
    @Published var isUpdatingPhoneNumber = false
    @Published var phoneVerificationCode: String = ""
    
    // UI State Properties
    #if os(iOS)
    @Published var profileImage: UIImage?
    #else
    @Published var profileImage: NSImage?
    #endif
    @Published var showEmailVerification = false
    @Published var showPhoneVerification = false
    @Published var isSaving = false
    @Published var showError = false
    @Published var hasValidationErrors = false
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var currentEmail: String {
        currentUser?.email ?? ""
    }
    
    var currentPhoneNumber: String {
        if let clerkUser = Clerk.shared.user,
           let primaryPhone = clerkUser.primaryPhoneNumber {
            return primaryPhone.phoneNumber
        }
        return "Not set"
    }
    
    var avatarURL: URL? {
        if !profileImageURL.isEmpty {
            return URL(string: profileImageURL)
        }
        return currentUser?.avatarURL
    }
    
    var canSaveProfile: Bool {
        !username.isEmpty && !isSaving && isBioValid && !hasValidationErrors
    }
    
    var bioCharacterCount: Int {
        bio.count
    }
    
    var bioCharacterLimit: Int {
        160
    }
    
    var isBioValid: Bool {
        bio.count <= bioCharacterLimit
    }
    
    enum EmailUpdateStep {
        case enterEmail
        case verifyCode
        case completed
    }
    
    // MARK: - Initialization
    init() {
        // currentUser will be loaded from Clerk when loadUserProfile() is called
    }
    
    // MARK: - Profile Management
    
    func loadUserProfile() async {
        isLoading = true
        errorMessage = nil
        
        // Try to get user from Clerk first
        if let clerkUser = Clerk.shared.user {
            // Create initial User object from Clerk data
            await MainActor.run {
                currentUser = User(
                    email: clerkUser.primaryEmailAddress?.emailAddress ?? "",
                    firstName: clerkUser.firstName,
                    lastName: clerkUser.lastName,
                    username: clerkUser.username ?? "user",
                    clerkId: clerkUser.id
                )
            }
            
            // Update local properties from Clerk
            firstName = clerkUser.firstName ?? ""
            lastName = clerkUser.lastName ?? ""
            username = clerkUser.username ?? ""
            
            // Load phone number if available
            if let primaryPhone = clerkUser.primaryPhoneNumber {
                phoneNumber = primaryPhone.phoneNumber
            }
            
            // Auto-sync user to backend first
            await autoSyncUserToBackend()
            
            // Then load the synced data
            await syncWithBackend()
        } else {
            errorMessage = "Please sign in to view your profile"
        }
        
        isLoading = false
    }
    
    func loadOtherUserProfile(_ targetUser: User) async {
        isLoading = true
        errorMessage = nil
        
        // Set the target user data
        await MainActor.run {
            currentUser = targetUser
        }
        
        // Try to load additional data from backend if available
        if let clerkId = targetUser.clerkId {
            do {
                let backendUser = try await BackendService.shared.getUserByClerkId(clerkId: clerkId)
                let user = backendUser.toUser()
                
                // Update with full backend data
                await MainActor.run {
                    currentUser = User(
                        id: user.id,
                        email: user.email,
                        firstName: user.firstName,
                        lastName: user.lastName,
                        username: user.username,
                        displayName: user.displayName,
                        bio: user.bio,
                        avatarURL: user.avatarURL,
                        clerkId: user.clerkId,
                        role: user.role,
                        dietaryPreferences: user.dietaryPreferences,
                        location: user.location,
                        joinedAt: user.joinedAt,
                        followersCount: user.followersCount,
                        followingCount: user.followingCount,
                        postsCount: user.postsCount
                    )
                }
                
                // Load user's posts
                await loadUserPosts(for: user.clerkId ?? "")
                
            } catch {
                print("⚠️ Failed to load full user profile from backend: \(error)")
                // Continue with the provided user data
            }
        }
        
        isLoading = false
    }
    
    private func loadUserPosts(for clerkId: String) async {
        guard !clerkId.isEmpty else {
            print("⚠️ ProfileViewModel: Cannot load posts - clerkId is empty")
            await MainActor.run {
                userPosts = []
            }
            return
        }
        
        do {
            print("📝 ProfileViewModel: Loading user posts for clerkId: \(clerkId)")
            
            // Load user's posts from the backend with improved error handling
            let backendPosts = try await BackendService.shared.getPostsByUser(userId: clerkId)
            
            print("📝 ProfileViewModel: Received \(backendPosts.count) posts from backend")
            
            // Convert backend posts to Post objects
            let posts = backendPosts.compactMap { backendPost in
                return Post.from(backendPost: backendPost)
            }
            
            await MainActor.run {
                userPosts = posts
                errorMessage = nil // Clear any previous error
                print("📝 ProfileViewModel: Successfully updated userPosts with \(posts.count) posts")
            }
            
        } catch {
            print("❌ ProfileViewModel: Failed to load user posts for clerkId \(clerkId): \(error)")
            
            await MainActor.run {
                // Handle different error types appropriately
                if let backendError = error as? BackendError {
                    switch backendError {
                    case .networkError:
                        errorMessage = "No internet connection. Please check your network."
                        // Don't clear existing posts for network errors
                    default:
                        userPosts = []
                        errorMessage = error.localizedDescription
                    }
                } else {
                    userPosts = []
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Public Methods
    
    func refreshUserPosts() async {
        guard let clerkId = currentUser?.clerkId else {
            print("⚠️ No clerk ID available for refreshing posts")
            return
        }
        await loadUserPosts(for: clerkId)
    }
    
    func refreshProfile() async {
        await loadUserProfile()
    }
    
    private func autoSyncUserToBackend() async {
        do {
            // This will create the user if they don't exist, or update if they do
            let syncedUser = try await BackendService.shared.syncUserFromClerk()
            print("✅ User synced to backend: \(syncedUser.username ?? "unknown")")
        } catch {
            print("⚠️ Failed to sync user to backend: \(error)")
            // Continue anyway - we'll try to load existing data
        }
    }
    
    private func syncWithBackend() async {
        guard let existingUser = currentUser, let clerkId = existingUser.clerkId else {
            print("⚠️ No current user or Clerk ID available for sync")
            return
        }
        
        do {
            let backendUser = try await BackendService.shared.getUserByClerkId(clerkId: clerkId)
            let user = backendUser.toUser()
            
            print("🔍 Backend user role: \(backendUser.role ?? "nil")")
            print("🔍 Converted user role: \(user.role)")
            print("🔍 User isAdmin: \(user.isAdmin)")
            
            // Update local state with backend data
            self.currentUser = User(
                id: user.id,
                email: user.email,
                firstName: user.firstName,
                lastName: user.lastName,
                username: user.username,
                displayName: user.displayName,
                bio: user.bio,
                avatarURL: user.avatarURL,
                clerkId: user.clerkId,
                role: user.role, // Make sure role is preserved
                dietaryPreferences: user.dietaryPreferences,
                location: user.location,
                joinedAt: user.joinedAt,
                followersCount: user.followersCount,
                followingCount: user.followingCount,
                postsCount: user.postsCount
            )
            
            print("🔍 Final currentUser role: \(self.currentUser?.role ?? .user)")
            print("🔍 Final currentUser isAdmin: \(self.currentUser?.isAdmin ?? false)")
            
            // Update form fields
            bio = user.bio ?? ""
            selectedDietaryPreferences = Set(user.dietaryPreferences)
            
            // Load user's posts
            await loadUserPosts(for: clerkId)
            
        } catch {
            print("⚠️ Failed to sync with backend: \(error)")
            // Continue with Clerk data if backend sync fails
        }
    }
    
    // MARK: - Profile Updates
    
    func saveProfile() async {
        isSaving = true
        isLoading = true
        errorMessage = nil
        
        do {
            // Validate before saving
            await validateAllFields()
            
            if hasValidationErrors {
                errorMessage = "Please fix validation errors before saving."
                HapticManager.shared.haptic(.error)
                isSaving = false
                isLoading = false
                return
            }
            
            // Upload profile image if needed
            var uploadedImageURL: String? = nil
            if let profileImage = profileImage {
                uploadedImageURL = await uploadProfileImage(profileImage)
            }
            
            // Update Clerk profile first
            try await updateClerkProfile(with: uploadedImageURL)
            
            // Then sync with backend
            await updateBackendProfile(with: uploadedImageURL)
            
            // Update local user object
            if let existingUser = currentUser {
                currentUser = User(
                    id: existingUser.id,
                    email: existingUser.email,
                    firstName: firstName.isEmpty ? nil : firstName,
                    lastName: lastName.isEmpty ? nil : lastName,
                    username: username,
                    displayName: nil, // Will be auto-generated from firstName/lastName
                    bio: bio.isEmpty ? nil : bio,
                    avatarURL: uploadedImageURL != nil ? URL(string: uploadedImageURL!) : existingUser.avatarURL,
                    clerkId: existingUser.clerkId,
                    role: existingUser.role,
                    dietaryPreferences: Array(selectedDietaryPreferences),
                    location: existingUser.location,
                    joinedAt: existingUser.joinedAt,
                    followersCount: existingUser.followersCount,
                    followingCount: existingUser.followingCount,
                    postsCount: existingUser.postsCount
                )
            }
            
            HapticManager.shared.haptic(.success)
            
        } catch {
            errorMessage = "Failed to save profile: \(error.localizedDescription)"
            HapticManager.shared.haptic(.error)
            print("❌ Profile save error: \(error)")
        }
        
        isSaving = false
        isLoading = false
    }
    
    private func validateAllFields() async {
        hasValidationErrors = false
        
        // Validate username if changed
        if !username.isEmpty && username != currentUser?.username {
            let isUsernameAvailable = await checkUsernameAvailability(username)
            if !isUsernameAvailable {
                hasValidationErrors = true
                return
            }
        }
        
        // Validate email if changed
        if !newEmail.isEmpty && newEmail != currentEmail {
            let isEmailAvailable = await checkEmailAvailability(newEmail)
            if !isEmailAvailable {
                hasValidationErrors = true
                return
            }
        }
        
        // Validate phone if changed
        if !phoneNumber.isEmpty && phoneNumber != currentPhoneNumber && phoneNumber != "Not set" {
            let isPhoneAvailable = await checkPhoneAvailability(phoneNumber)
            if !isPhoneAvailable {
                hasValidationErrors = true
                return
            }
        }
    }
    
    private func checkUsernameAvailability(_ username: String) async -> Bool {
        do {
            return try await BackendService.shared.checkUsernameAvailability(username: username)
        } catch {
            print("❌ Username validation error: \(error)")
            return false // Assume unavailable if error occurs
        }
    }
    
    private func checkEmailAvailability(_ email: String) async -> Bool {
        do {
            return try await BackendService.shared.checkEmailAvailability(email: email)
        } catch {
            print("❌ Email validation error: \(error)")
            return false // Assume unavailable if error occurs
        }
    }
    
    private func checkPhoneAvailability(_ phoneNumber: String) async -> Bool {
        do {
            return try await BackendService.shared.checkPhoneAvailability(phoneNumber: phoneNumber)
        } catch {
            print("❌ Phone validation error: \(error)")
            return false // Assume unavailable if error occurs
        }
    }
    
    #if os(iOS)
    private func uploadProfileImage(_ image: UIImage) async -> String? {
        // Convert image to data
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("❌ Failed to convert image to data")
            return nil
        }
        
        // Generate unique filename
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "profile_\(currentUser?.clerkId ?? "unknown")_\(timestamp).jpg"
        
        // Upload using BunnyNetService
        return await withCheckedContinuation { continuation in
            BunnyNetService.shared.uploadImage(data: imageData, fileName: fileName) { response in
                if response.success, let url = response.url {
                    print("✅ Profile image uploaded successfully: \(url)")
                    continuation.resume(returning: url)
                } else {
                    print("❌ Profile image upload failed: \(response.error ?? "Unknown error")")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    #else
    private func uploadProfileImage(_ image: NSImage) async -> String? {
        // Convert NSImage to Data
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let imageData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            print("❌ Failed to convert NSImage to data")
            return nil
        }
        
        // Generate unique filename
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "profile_\(currentUser?.clerkId ?? "unknown")_\(timestamp).jpg"
        
        // Upload using BunnyNetService
        return await withCheckedContinuation { continuation in
            BunnyNetService.shared.uploadImage(data: imageData, fileName: fileName) { response in
                if response.success, let url = response.url {
                    print("✅ Profile image uploaded successfully: \(url)")
                    continuation.resume(returning: url)
                } else {
                    print("❌ Profile image upload failed: \(response.error ?? "Unknown error")")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    #endif
    
    private func updateClerkProfile(with imageURL: String? = nil) async throws {
        guard let user = Clerk.shared.user else {
            throw ProfileError.noClerkUser
        }
        
        // Update first and last name in Clerk
        if !firstName.isEmpty || !lastName.isEmpty {
            try await user.update(.init(
                firstName: firstName.isEmpty ? nil : firstName,
                lastName: lastName.isEmpty ? nil : lastName
            ))
        }
        
        // Update username if changed
        if !username.isEmpty && username != user.username {
            // Note: Username updates might require additional verification
            try await user.update(.init(username: username))
        }
        
        // Update avatar URL if provided
        if imageURL != nil {
            // Note: Clerk SDK setProfileImage method may not support URL strings directly
            // The profile image URL will be stored in our backend instead
            // try await user.setProfileImage(.init(file: imageURL))
        }
    }
    
    private func updateBackendProfile(with imageURL: String? = nil) async {
        guard let existingUser = currentUser, let clerkId = existingUser.clerkId else {
            print("⚠️ No current user or Clerk ID for backend update")
            return
        }
        
        do {
            _ = try await BackendService.shared.updateUserByClerkId(
                clerkId: clerkId,
                firstName: firstName.isEmpty ? nil : firstName,
                lastName: lastName.isEmpty ? nil : lastName,
                username: username.isEmpty ? nil : username,
                bio: bio.isEmpty ? nil : bio,
                avatarUrl: imageURL,
                dietaryPreferences: Array(selectedDietaryPreferences).map { $0.rawValue }
            )
        } catch {
            print("⚠️ Backend update failed: \(error)")
            // Don't throw here - Clerk update succeeded
        }
    }
    
    // MARK: - Email Update Flow
    
    func updateEmail() {
        Task {
            showEmailVerification = true
            await sendEmailVerification()
        }
    }
    
    func startEmailUpdate() {
        isUpdatingEmail = true
        emailUpdateStep = .enterEmail
        newEmail = ""
        verificationCode = ""
    }
    
    func cancelEmailUpdate() {
        isUpdatingEmail = false
        emailUpdateStep = .enterEmail
        newEmail = ""
        verificationCode = ""
    }
    
    func sendEmailVerification() async {
        guard !newEmail.isEmpty else {
            errorMessage = "Please enter a valid email address"
            return
        }
        
        isVerifyingEmail = true
        errorMessage = nil
        
        do {
            guard let user = Clerk.shared.user else {
                throw ProfileError.noClerkUser
            }
            
            // Create new email address and prepare verification
            let emailAddress = try await user.createEmailAddress(newEmail)
            try await emailAddress.prepareVerification(strategy: .emailCode)
            
            emailUpdateStep = .verifyCode
            HapticManager.shared.haptic(.success)
            
        } catch {
            errorMessage = "Failed to send verification email: \(error.localizedDescription)"
            HapticManager.shared.haptic(.error)
        }
        
        isVerifyingEmail = false
    }
    
    func verifyEmailCode() async {
        guard !verificationCode.isEmpty else {
            errorMessage = "Please enter the verification code"
            return
        }
        
        isVerifyingEmail = true
        errorMessage = nil
        
        do {
            guard let user = Clerk.shared.user else {
                throw ProfileError.noClerkUser
            }
            
            // Find the email address we're trying to verify
            guard let emailAddress = user.emailAddresses.first(where: { $0.emailAddress == newEmail }) else {
                throw ProfileError.emailNotFound
            }
            
            // Verify with the code
            try await emailAddress.attemptVerification(strategy: .emailCode(code: verificationCode))
            
            // Set as primary if verification successful
            try await user.update(.init(primaryEmailAddressId: emailAddress.id))
            
            // Update local state
            if let existingUser = currentUser {
                currentUser = User(
                    id: existingUser.id,
                    email: newEmail,
                    firstName: existingUser.firstName,
                    lastName: existingUser.lastName,
                    username: existingUser.username,
                    displayName: existingUser.displayName,
                    bio: existingUser.bio,
                    avatarURL: existingUser.avatarURL,
                    clerkId: existingUser.clerkId,
                    role: existingUser.role,
                    dietaryPreferences: existingUser.dietaryPreferences,
                    location: existingUser.location,
                    joinedAt: existingUser.joinedAt,
                    followersCount: existingUser.followersCount,
                    followingCount: existingUser.followingCount,
                    postsCount: existingUser.postsCount
                )
            }
            
            emailUpdateStep = .completed
            HapticManager.shared.haptic(.success)
            
            // Auto-close after success
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.cancelEmailUpdate()
            }
            
        } catch {
            errorMessage = "Invalid verification code. Please try again."
            HapticManager.shared.haptic(.error)
        }
        
        isVerifyingEmail = false
    }
    
    // MARK: - Phone Number Update Flow
    
    func updatePhoneNumber() {
        Task {
            showPhoneVerification = true
            await sendPhoneVerification()
        }
    }
    
    func startPhoneUpdate() {
        isUpdatingPhoneNumber = true
        phoneNumber = ""
        phoneVerificationCode = ""
    }
    
    func cancelPhoneUpdate() {
        isUpdatingPhoneNumber = false
        showPhoneVerification = false
        phoneNumber = ""
        phoneVerificationCode = ""
    }
    
    func sendPhoneVerification() async {
        guard !phoneNumber.isEmpty else {
            errorMessage = "Please enter a valid phone number"
            return
        }
        
        isUpdatingPhoneNumber = true
        errorMessage = nil
        
        do {
            guard let user = Clerk.shared.user else {
                throw ProfileError.noClerkUser
            }
            
            // Create new phone number and prepare verification
            let phoneNumberObject = try await user.createPhoneNumber(phoneNumber)
            try await phoneNumberObject.prepareVerification()
            
            HapticManager.shared.haptic(.success)
            
        } catch {
            errorMessage = "Failed to send verification SMS: \(error.localizedDescription)"
            HapticManager.shared.haptic(.error)
            showPhoneVerification = false
        }
        
        isUpdatingPhoneNumber = false
    }
    
    func verifyPhoneCode() async {
        guard !phoneVerificationCode.isEmpty else {
            errorMessage = "Please enter the verification code"
            return
        }
        
        isUpdatingPhoneNumber = true
        errorMessage = nil
        
        do {
            guard let user = Clerk.shared.user else {
                throw ProfileError.noClerkUser
            }
            
            // Find the phone number we're trying to verify
            guard let phoneNumberObject = user.phoneNumbers.first(where: { $0.phoneNumber == phoneNumber }) else {
                throw ProfileError.phoneNotFound
            }
            
            // Verify with the code
            try await phoneNumberObject.attemptVerification(code: phoneVerificationCode)
            
            HapticManager.shared.haptic(.success)
            showPhoneVerification = false
            
            // Auto-close after success
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.cancelPhoneUpdate()
            }
            
        } catch {
            errorMessage = "Invalid verification code. Please try again."
            HapticManager.shared.haptic(.error)
        }
        
        isUpdatingPhoneNumber = false
    }
    
    // MARK: - Dietary Preferences
    
    func toggleDietaryPreference(_ preference: DietaryPreference) {
        if selectedDietaryPreferences.contains(preference) {
            selectedDietaryPreferences.remove(preference)
        } else {
            selectedDietaryPreferences.insert(preference)
        }
        HapticManager.shared.impact(.light)
    }
}

// MARK: - Profile Errors

enum ProfileError: LocalizedError {
    case noClerkUser
    case emailNotFound
    case verificationFailed
    case phoneNotFound
    
    var errorDescription: String? {
        switch self {
        case .noClerkUser:
            return "No authenticated user found"
        case .emailNotFound:
            return "Email address not found"
        case .verificationFailed:
            return "Email verification failed"
        case .phoneNotFound:
            return "Phone number not found"
        }
    }
}

// MARK: - Backend Request Models
struct UpdateUserRequest: Codable {
    let firstName: String?
    let lastName: String?
    let bio: String?
    let dietaryPreferences: [String]
} 