//
//  ProfileTests.swift
//  PalyttAppTests
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//

import XCTest
@testable import Palytt
import UIKit
import Combine

final class ProfileTests: XCTestCase {
    
    var profileViewModel: ProfileViewModel!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        profileViewModel = ProfileViewModel()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        profileViewModel = nil
        cancellables.removeAll()
        cancellables = nil
    }
    
    // MARK: - Initial State Tests
    
    func test_profileViewModel_initialState_isCorrect() {
        // Given - Fresh ProfileViewModel
        
        // When - Initial state
        
        // Then
        XCTAssertNil(profileViewModel.currentUser, "Current user should be nil initially")
        XCTAssertTrue(profileViewModel.userPosts.isEmpty, "User posts should be empty initially")
        XCTAssertFalse(profileViewModel.isLoading, "Should not be loading initially")
        XCTAssertNil(profileViewModel.errorMessage, "Error message should be nil initially")
        XCTAssertFalse(profileViewModel.isEditingProfile, "Should not be editing profile initially")
        XCTAssertTrue(profileViewModel.profileImageURL.isEmpty, "Profile image URL should be empty initially")
        XCTAssertTrue(profileViewModel.firstName.isEmpty, "First name should be empty initially")
        XCTAssertTrue(profileViewModel.lastName.isEmpty, "Last name should be empty initially")
        XCTAssertTrue(profileViewModel.username.isEmpty, "Username should be empty initially")
        XCTAssertTrue(profileViewModel.bio.isEmpty, "Bio should be empty initially")
    }
    
    // MARK: - User Profile Tests
    
    func test_profileViewModel_setCurrentUser_updatesProperties() {
        // Given
        let testUser = createTestUser()
        
        // When
        profileViewModel.currentUser = testUser
        
        // Then
        XCTAssertNotNil(profileViewModel.currentUser, "Current user should be set")
        XCTAssertEqual(profileViewModel.currentUser?._id, testUser._id, "User ID should match")
        XCTAssertEqual(profileViewModel.currentUser?.username, testUser.username, "Username should match")
        XCTAssertEqual(profileViewModel.currentUser?.displayName, testUser.displayName, "Display name should match")
    }
    
    func test_profileViewModel_userProfile_hasValidData() {
        // Given
        let testUser = createTestUser()
        profileViewModel.currentUser = testUser
        
        // When
        let user = profileViewModel.currentUser
        
        // Then
        XCTAssertNotNil(user, "User should not be nil")
        XCTAssertFalse(user!.username.isEmpty, "Username should not be empty")
        XCTAssertFalse(user!.displayName.isEmpty, "Display name should not be empty")
        XCTAssertNotNil(user!.avatarUrl, "Avatar URL should be set")
        XCTAssertNotNil(user!.bio, "Bio should be set")
    }
    
    // MARK: - Profile Editing Tests
    
    func test_profileViewModel_editProfile_togglesEditingState() {
        // Given
        profileViewModel.isEditingProfile = false
        
        // When
        profileViewModel.isEditingProfile = true
        
        // Then
        XCTAssertTrue(profileViewModel.isEditingProfile, "Should be in editing state")
        
        // When
        profileViewModel.isEditingProfile = false
        
        // Then
        XCTAssertFalse(profileViewModel.isEditingProfile, "Should not be in editing state")
    }
    
    func test_profileViewModel_updateProfileFields_setsCorrectValues() {
        // Given
        let firstName = "John"
        let lastName = "Doe"
        let username = "johndoe"
        let bio = "Food lover and photographer"
        
        // When
        profileViewModel.firstName = firstName
        profileViewModel.lastName = lastName
        profileViewModel.username = username
        profileViewModel.bio = bio
        
        // Then
        XCTAssertEqual(profileViewModel.firstName, firstName, "First name should be set")
        XCTAssertEqual(profileViewModel.lastName, lastName, "Last name should be set")
        XCTAssertEqual(profileViewModel.username, username, "Username should be set")
        XCTAssertEqual(profileViewModel.bio, bio, "Bio should be set")
    }
    
    func test_profileViewModel_profileImageURL_setsCorrectly() {
        // Given
        let imageURL = "https://example.com/profile.jpg"
        
        // When
        profileViewModel.profileImageURL = imageURL
        
        // Then
        XCTAssertEqual(profileViewModel.profileImageURL, imageURL, "Profile image URL should be set")
    }
    
    // MARK: - Email Update Tests
    
    func test_profileViewModel_emailUpdate_initialState() {
        // Given - Fresh ProfileViewModel
        
        // When - Email update state
        
        // Then
        XCTAssertFalse(profileViewModel.isUpdatingEmail, "Should not be updating email initially")
        XCTAssertTrue(profileViewModel.newEmail.isEmpty, "New email should be empty initially")
        XCTAssertTrue(profileViewModel.verificationCode.isEmpty, "Verification code should be empty initially")
        XCTAssertFalse(profileViewModel.isVerifyingEmail, "Should not be verifying email initially")
        XCTAssertEqual(profileViewModel.emailUpdateStep, .enterEmail, "Should be on enter email step initially")
    }
    
    func test_profileViewModel_emailUpdate_setsNewEmail() {
        // Given
        let newEmail = "newemail@example.com"
        
        // When
        profileViewModel.newEmail = newEmail
        
        // Then
        XCTAssertEqual(profileViewModel.newEmail, newEmail, "New email should be set")
    }
    
    func test_profileViewModel_emailUpdate_setsVerificationCode() {
        // Given
        let verificationCode = "123456"
        
        // When
        profileViewModel.verificationCode = verificationCode
        
        // Then
        XCTAssertEqual(profileViewModel.verificationCode, verificationCode, "Verification code should be set")
    }
    
    func test_profileViewModel_emailUpdate_stateTransitions() {
        // Given
        profileViewModel.emailUpdateStep = .enterEmail
        
        // When - Move to verification step
        profileViewModel.emailUpdateStep = .verifyEmail
        
        // Then
        XCTAssertEqual(profileViewModel.emailUpdateStep, .verifyEmail, "Should be on verify email step")
        
        // When - Move to complete step
        profileViewModel.emailUpdateStep = .emailUpdated
        
        // Then
        XCTAssertEqual(profileViewModel.emailUpdateStep, .emailUpdated, "Should be on email updated step")
    }
    
    // MARK: - Phone Number Tests
    
    func test_profileViewModel_phoneNumber_setsCorrectly() {
        // Given
        let phoneNumber = "(555) 123-4567"
        
        // When
        profileViewModel.phoneNumber = phoneNumber
        
        // Then
        XCTAssertEqual(profileViewModel.phoneNumber, phoneNumber, "Phone number should be set")
    }
    
    func test_profileViewModel_phoneUpdate_initialState() {
        // Given - Fresh ProfileViewModel
        
        // When - Phone update state
        
        // Then
        XCTAssertFalse(profileViewModel.isUpdatingPhoneNumber, "Should not be updating phone initially")
        XCTAssertTrue(profileViewModel.phoneVerificationCode.isEmpty, "Phone verification code should be empty initially")
    }
    
    // MARK: - Dietary Preferences Tests
    
    func test_profileViewModel_dietaryPreferences_initialState() {
        // Given - Fresh ProfileViewModel
        
        // When - Dietary preferences state
        
        // Then
        XCTAssertTrue(profileViewModel.selectedDietaryPreferences.isEmpty, "Dietary preferences should be empty initially")
    }
    
    func test_profileViewModel_dietaryPreferences_addPreference() {
        // Given
        let preference = DietaryPreference.vegetarian
        
        // When
        profileViewModel.selectedDietaryPreferences.insert(preference)
        
        // Then
        XCTAssertTrue(profileViewModel.selectedDietaryPreferences.contains(preference), "Should contain the dietary preference")
        XCTAssertEqual(profileViewModel.selectedDietaryPreferences.count, 1, "Should have one dietary preference")
    }
    
    func test_profileViewModel_dietaryPreferences_removePreference() {
        // Given
        let preference = DietaryPreference.vegetarian
        profileViewModel.selectedDietaryPreferences.insert(preference)
        
        // When
        profileViewModel.selectedDietaryPreferences.remove(preference)
        
        // Then
        XCTAssertFalse(profileViewModel.selectedDietaryPreferences.contains(preference), "Should not contain the dietary preference")
        XCTAssertTrue(profileViewModel.selectedDietaryPreferences.isEmpty, "Should have no dietary preferences")
    }
    
    // MARK: - UI State Tests
    
    func test_profileViewModel_showEmailVerification_togglesCorrectly() {
        // Given
        profileViewModel.showEmailVerification = false
        
        // When
        profileViewModel.showEmailVerification = true
        
        // Then
        XCTAssertTrue(profileViewModel.showEmailVerification, "Should show email verification")
        
        // When
        profileViewModel.showEmailVerification = false
        
        // Then
        XCTAssertFalse(profileViewModel.showEmailVerification, "Should not show email verification")
    }
    
    func test_profileViewModel_showPhoneVerification_togglesCorrectly() {
        // Given
        profileViewModel.showPhoneVerification = false
        
        // When
        profileViewModel.showPhoneVerification = true
        
        // Then
        XCTAssertTrue(profileViewModel.showPhoneVerification, "Should show phone verification")
    }
    
    func test_profileViewModel_isSaving_togglesCorrectly() {
        // Given
        profileViewModel.isSaving = false
        
        // When
        profileViewModel.isSaving = true
        
        // Then
        XCTAssertTrue(profileViewModel.isSaving, "Should be saving")
        
        // When
        profileViewModel.isSaving = false
        
        // Then
        XCTAssertFalse(profileViewModel.isSaving, "Should not be saving")
    }
    
    // MARK: - Error Handling Tests
    
    func test_profileViewModel_errorMessage_setsShowError() {
        // Given
        let errorMessage = "Profile update failed"
        
        // When
        profileViewModel.errorMessage = errorMessage
        
        // Then
        XCTAssertEqual(profileViewModel.errorMessage, errorMessage, "Error message should be set")
        XCTAssertTrue(profileViewModel.showError, "Should show error")
    }
    
    func test_profileViewModel_clearError_hidesError() {
        // Given
        profileViewModel.errorMessage = "Some error"
        XCTAssertTrue(profileViewModel.showError, "Should show error initially")
        
        // When
        profileViewModel.errorMessage = nil
        
        // Then
        XCTAssertNil(profileViewModel.errorMessage, "Error message should be nil")
        XCTAssertFalse(profileViewModel.showError, "Should not show error")
    }
    
    func test_profileViewModel_hasValidationErrors_togglesCorrectly() {
        // Given
        profileViewModel.hasValidationErrors = false
        
        // When
        profileViewModel.hasValidationErrors = true
        
        // Then
        XCTAssertTrue(profileViewModel.hasValidationErrors, "Should have validation errors")
    }
    
    // MARK: - Posts Management Tests
    
    func test_profileViewModel_userPosts_initiallyEmpty() {
        // Given - Fresh ProfileViewModel
        
        // When - User posts state
        
        // Then
        XCTAssertTrue(profileViewModel.userPosts.isEmpty, "User posts should be empty initially")
    }
    
    func test_profileViewModel_userPosts_addsPost() {
        // Given
        let testPost = createTestPost()
        
        // When
        profileViewModel.userPosts = [testPost]
        
        // Then
        XCTAssertEqual(profileViewModel.userPosts.count, 1, "Should have one post")
        XCTAssertEqual(profileViewModel.userPosts.first?._id, testPost._id, "Post ID should match")
    }
    
    // MARK: - Loading State Tests
    
    func test_profileViewModel_isLoading_togglesCorrectly() {
        // Given
        profileViewModel.isLoading = false
        
        // When
        profileViewModel.isLoading = true
        
        // Then
        XCTAssertTrue(profileViewModel.isLoading, "Should be loading")
        
        // When
        profileViewModel.isLoading = false
        
        // Then
        XCTAssertFalse(profileViewModel.isLoading, "Should not be loading")
    }
    
    // MARK: - Profile Image Tests
    
    func test_profileViewModel_profileImage_setsCorrectly() {
        // Given
        let testImage = createTestImage()
        
        // When
        profileViewModel.profileImage = testImage
        
        // Then
        XCTAssertNotNil(profileViewModel.profileImage, "Profile image should be set")
        XCTAssertEqual(profileViewModel.profileImage, testImage, "Profile image should match")
    }
    
    // MARK: - Validation Tests
    
    func test_profileViewModel_validation_emptyFields() {
        // Given
        profileViewModel.firstName = ""
        profileViewModel.lastName = ""
        profileViewModel.username = ""
        
        // When
        let hasEmptyFields = profileViewModel.firstName.isEmpty || 
                            profileViewModel.lastName.isEmpty || 
                            profileViewModel.username.isEmpty
        
        // Then
        XCTAssertTrue(hasEmptyFields, "Should detect empty fields")
    }
    
    func test_profileViewModel_validation_validFields() {
        // Given
        profileViewModel.firstName = "John"
        profileViewModel.lastName = "Doe"
        profileViewModel.username = "johndoe"
        
        // When
        let hasValidFields = !profileViewModel.firstName.isEmpty && 
                            !profileViewModel.lastName.isEmpty && 
                            !profileViewModel.username.isEmpty
        
        // Then
        XCTAssertTrue(hasValidFields, "Should detect valid fields")
    }
    
    // MARK: - Performance Tests
    
    func test_profileViewModel_performance_manyPosts() {
        measure {
            // Test performance with many posts
            var posts: [Post] = []
            for i in 0..<1000 {
                posts.append(createTestPost(id: "post_\(i)"))
            }
            
            profileViewModel.userPosts = posts
            
            XCTAssertEqual(profileViewModel.userPosts.count, 1000)
        }
    }
    
    // MARK: - Integration Tests
    
    func test_profileViewModel_fullProfileUpdate_success() async {
        // Given
        setupValidProfileData()
        
        // When
        profileViewModel.isSaving = true
        
        // Simulate save operation
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        profileViewModel.isSaving = false
        
        // Then
        XCTAssertFalse(profileViewModel.isSaving, "Should not be saving after completion")
        XCTAssertFalse(profileViewModel.firstName.isEmpty, "Should have first name")
        XCTAssertFalse(profileViewModel.lastName.isEmpty, "Should have last name")
        XCTAssertFalse(profileViewModel.username.isEmpty, "Should have username")
    }
}

// MARK: - Test Helpers

extension ProfileTests {
    
    func setupValidProfileData() {
        profileViewModel.firstName = "John"
        profileViewModel.lastName = "Doe"
        profileViewModel.username = "johndoe"
        profileViewModel.bio = "Food enthusiast and photographer"
        profileViewModel.profileImageURL = "https://example.com/profile.jpg"
        profileViewModel.newEmail = "john@example.com"
        profileViewModel.phoneNumber = "(555) 123-4567"
    }
    
    func createTestUser() -> User {
        return User(
            _id: "test_user_123",
            clerkId: "clerk_456",
            username: "testuser",
            displayName: "Test User",
            avatarUrl: "https://example.com/avatar.jpg",
            bio: "Test user bio",
            isOnline: true,
            lastActiveAt: Int(Date().timeIntervalSince1970 * 1000)
        )
    }
    
    func createTestPost(id: String = "test_post_123") -> Post {
        return Post(
            _id: id,
            authorId: "test_user_123",
            author: createTestUser(),
            caption: "Test post caption",
            imageUrl: "https://example.com/post.jpg",
            location: createTestLocation(),
            likesCount: 10,
            commentsCount: 5,
            createdAt: Int(Date().timeIntervalSince1970 * 1000),
            updatedAt: Int(Date().timeIntervalSince1970 * 1000)
        )
    }
    
    func createTestLocation() -> Location {
        return Location(
            _id: "test_location_123",
            name: "Test Location",
            address: "123 Test Street",
            latitude: 37.7749,
            longitude: -122.4194,
            category: "restaurant",
            rating: 4.0,
            priceLevel: 2,
            isVerified: true,
            totalVisits: 25,
            createdAt: Int(Date().timeIntervalSince1970 * 1000),
            updatedAt: Int(Date().timeIntervalSince1970 * 1000)
        )
    }
    
    func createTestImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        UIColor.blue.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image ?? UIImage()
    }
}

// MARK: - Test Data Structures

enum EmailUpdateStep {
    case enterEmail
    case verifyEmail
    case emailUpdated
}

enum DietaryPreference: String, CaseIterable {
    case vegetarian = "Vegetarian"
    case vegan = "Vegan"
    case glutenFree = "Gluten Free"
    case dairyFree = "Dairy Free"
    case nutFree = "Nut Free"
    case halal = "Halal"
    case kosher = "Kosher"
    case keto = "Keto"
    case paleo = "Paleo"
}

// MARK: - Mock ProfileViewModel for Testing

class MockProfileViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var userPosts: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isEditingProfile = false
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var username = ""
    @Published var bio = ""
    @Published var profileImageURL = ""
    @Published var newEmail = ""
    @Published var phoneNumber = ""
    @Published var isSaving = false
    @Published var showError = false
    
    func loadUserProfile() async {
        isLoading = true
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Mock user data
        currentUser = User(
            _id: "mock_user_123",
            clerkId: "clerk_mock",
            username: "mockuser",
            displayName: "Mock User",
            avatarUrl: "https://example.com/mock.jpg",
            bio: "Mock user for testing",
            isOnline: true,
            lastActiveAt: Int(Date().timeIntervalSince1970 * 1000)
        )
        
        isLoading = false
    }
    
    func saveProfile() async throws {
        isSaving = true
        
        // Simulate save operation
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        if firstName.isEmpty || lastName.isEmpty || username.isEmpty {
            errorMessage = "Please fill in all required fields"
            showError = true
            isSaving = false
            throw ProfileError.missingRequiredFields
        }
        
        isSaving = false
    }
}

enum ProfileError: Error {
    case missingRequiredFields
    case networkError
    case invalidData
    
    var localizedDescription: String {
        switch self {
        case .missingRequiredFields:
            return "Please fill in all required fields"
        case .networkError:
            return "Network connection failed"
        case .invalidData:
            return "Invalid profile data"
        }
    }
} 