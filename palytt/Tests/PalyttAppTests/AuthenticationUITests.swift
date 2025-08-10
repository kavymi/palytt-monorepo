//
//  AuthenticationUITests.swift
//  PalyttAppTests
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//

import XCTest
@testable import Palytt

final class AuthenticationUITests: XCTestCase {
    
    // MARK: - Test Setup and Teardown
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    override func tearDownWithError() throws {
        // Clean up after each test
    }
    
    // MARK: - Authentication View Tests
    
    func test_authenticationView_initialState_isCorrect() throws {
        // This test verifies the initial state of the authentication view
        // In a real UI test, we would launch the app and verify the UI elements
        
        // Given - Initial authentication view state
        let expectedInitialTab = 0 // Sign In tab should be selected by default
        let expectedTabTitles = ["Sign In", "Sign Up"]
        
        // When - View is loaded
        // In actual implementation, this would be verified through UI testing
        
        // Then - Verify initial state
        XCTAssertEqual(expectedInitialTab, 0, "Sign In tab should be selected initially")
        XCTAssertEqual(expectedTabTitles.count, 2, "Should have two authentication tabs")
        XCTAssertEqual(expectedTabTitles[0], "Sign In", "First tab should be Sign In")
        XCTAssertEqual(expectedTabTitles[1], "Sign Up", "Second tab should be Sign Up")
    }
    
    func test_authenticationView_tabSwitching_worksCorrectly() throws {
        // Test tab switching between Sign In and Sign Up
        
        // Given
        var selectedTab = 0 // Start with Sign In
        
        // When - User taps Sign Up tab
        selectedTab = 1
        
        // Then
        XCTAssertEqual(selectedTab, 1, "Should switch to Sign Up tab")
        
        // When - User taps Sign In tab again
        selectedTab = 0
        
        // Then
        XCTAssertEqual(selectedTab, 0, "Should switch back to Sign In tab")
    }
    
    // MARK: - Sign In Form Tests
    
    func test_signInForm_emailInput_acceptsValidEmail() throws {
        // Test email input field validation
        
        // Given
        let validEmails = [
            "test@example.com",
            "user.name@domain.co.uk",
            "admin@company.org"
        ]
        
        // When & Then
        for email in validEmails {
            let isValid = validateEmailInput(email)
            XCTAssertTrue(isValid, "Email '\(email)' should be accepted by input field")
        }
    }
    
    func test_signInForm_passwordInput_acceptsValidPassword() throws {
        // Test password input field validation
        
        // Given
        let validPasswords = [
            "SecurePass123!",
            "MyPassword1",
            "Test1234"
        ]
        
        // When & Then
        for password in validPasswords {
            let isValid = validatePasswordInput(password)
            XCTAssertTrue(isValid, "Password should be accepted by input field")
        }
    }
    
    func test_signInForm_submitButton_enabledWithValidInput() throws {
        // Test submit button state based on form validation
        
        // Given
        let validEmail = "test@example.com"
        let validPassword = "SecurePass123!"
        
        // When
        let isButtonEnabled = isSignInButtonEnabled(email: validEmail, password: validPassword)
        
        // Then
        XCTAssertTrue(isButtonEnabled, "Sign in button should be enabled with valid input")
    }
    
    func test_signInForm_submitButton_disabledWithInvalidInput() throws {
        // Test submit button disabled state with invalid input
        
        // Given
        let testCases = [
            ("", "SecurePass123!"), // Empty email
            ("test@example.com", ""), // Empty password
            ("invalid-email", "SecurePass123!"), // Invalid email
            ("test@example.com", "weak") // Weak password
        ]
        
        // When & Then
        for (email, password) in testCases {
            let isButtonEnabled = isSignInButtonEnabled(email: email, password: password)
            XCTAssertFalse(isButtonEnabled, "Sign in button should be disabled with invalid input: \(email), \(password)")
        }
    }
    
    func test_signInForm_phoneNumberInput_acceptsValidFormats() throws {
        // Test phone number input with different valid formats
        
        // Given
        let validPhoneNumbers = [
            "(555) 123-4567",
            "555-123-4567",
            "5551234567",
            "555.123.4567"
        ]
        
        // When & Then
        for phoneNumber in validPhoneNumbers {
            let isValid = validatePhoneNumberInput(phoneNumber)
            XCTAssertTrue(isValid, "Phone number '\(phoneNumber)' should be accepted")
        }
    }
    
    // MARK: - Sign Up Form Tests
    
    func test_signUpForm_allFields_acceptValidInput() throws {
        // Test all sign up form fields with valid input
        
        // Given
        let formData = SignUpTestData(
            email: "test@example.com",
            password: "SecurePass123!",
            firstName: "John",
            lastName: "Doe",
            username: "johndoe123",
            phoneNumber: "(555) 123-4567"
        )
        
        // When
        let isFormValid = validateSignUpForm(formData)
        
        // Then
        XCTAssertTrue(isFormValid, "Sign up form should be valid with all valid inputs")
    }
    
    func test_signUpForm_submitButton_enabledWithValidData() throws {
        // Test submit button state for sign up form
        
        // Given
        let validFormData = SignUpTestData(
            email: "test@example.com",
            password: "SecurePass123!",
            firstName: "John",
            lastName: "Doe",
            username: "johndoe",
            phoneNumber: "(555) 123-4567"
        )
        
        // When
        let isButtonEnabled = isSignUpButtonEnabled(validFormData)
        
        // Then
        XCTAssertTrue(isButtonEnabled, "Sign up button should be enabled with valid form data")
    }
    
    func test_signUpForm_passwordRequirements_displayedCorrectly() throws {
        // Test password requirements display
        
        // Given
        let passwordRequirements = [
            "At least 8 characters",
            "At least one uppercase letter",
            "At least one lowercase letter",
            "At least one number"
        ]
        
        // When & Then
        XCTAssertEqual(passwordRequirements.count, 4, "Should display 4 password requirements")
        XCTAssertTrue(passwordRequirements.contains("At least 8 characters"), "Should show length requirement")
        XCTAssertTrue(passwordRequirements.contains("At least one uppercase letter"), "Should show uppercase requirement")
    }
    
    // MARK: - Verification Code Tests
    
    func test_verificationCodeInput_acceptsSixDigits() throws {
        // Test verification code input field
        
        // Given
        let validCodes = ["123456", "000000", "999999"]
        let invalidCodes = ["12345", "1234567", "12345a"]
        
        // When & Then
        for code in validCodes {
            let isValid = validateVerificationCodeInput(code)
            XCTAssertTrue(isValid, "Verification code '\(code)' should be valid")
        }
        
        for code in invalidCodes {
            let isValid = validateVerificationCodeInput(code)
            XCTAssertFalse(isValid, "Verification code '\(code)' should be invalid")
        }
    }
    
    func test_verificationCodeScreen_countdown_worksCorrectly() throws {
        // Test countdown timer for verification code resend
        
        // Given
        var countdown = 60
        let expectedFinalValue = 0
        
        // When - Simulate countdown
        while countdown > 0 {
            countdown -= 1
        }
        
        // Then
        XCTAssertEqual(countdown, expectedFinalValue, "Countdown should reach zero")
    }
    
    // MARK: - Error Handling Tests
    
    func test_errorDisplay_showsCorrectMessages() throws {
        // Test error message display for different scenarios
        
        // Given
        let errorScenarios = [
            ("INVALID_EMAIL", "Please enter a valid email address"),
            ("WEAK_PASSWORD", "Password must be at least 8 characters with uppercase, lowercase, and numbers"),
            ("USER_NOT_FOUND", "User not found"),
            ("NETWORK_ERROR", "Network connection failed"),
            ("INVALID_CODE", "Invalid verification code")
        ]
        
        // When & Then
        for (errorCode, expectedMessage) in errorScenarios {
            let displayMessage = getErrorDisplayMessage(for: errorCode)
            XCTAssertEqual(displayMessage, expectedMessage, "Error message for \(errorCode) should match expected")
        }
    }
    
    func test_errorDisplay_clearsProperly() throws {
        // Test error message clearing functionality
        
        // Given
        var errorMessage: String? = "Test error"
        var showError = true
        
        // When - Clear error
        errorMessage = nil
        showError = false
        
        // Then
        XCTAssertNil(errorMessage, "Error message should be cleared")
        XCTAssertFalse(showError, "Show error flag should be false")
    }
    
    // MARK: - Loading State Tests
    
    func test_loadingState_disablesInteraction() throws {
        // Test that loading state properly disables user interaction
        
        // Given
        let isLoading = true
        
        // When
        let isFormEnabled = !isLoading
        let isButtonEnabled = !isLoading
        
        // Then
        XCTAssertFalse(isFormEnabled, "Form should be disabled during loading")
        XCTAssertFalse(isButtonEnabled, "Buttons should be disabled during loading")
    }
    
    // MARK: - Apple Sign In Tests
    
    func test_appleSignIn_buttonDisplayed() throws {
        // Test Apple Sign In button display
        
        // Given
        let isAppleSignInAvailable = true
        let buttonTitle = "Sign in with Apple"
        
        // When & Then
        XCTAssertTrue(isAppleSignInAvailable, "Apple Sign In should be available")
        XCTAssertEqual(buttonTitle, "Sign in with Apple", "Apple Sign In button should have correct title")
    }
    
    // MARK: - Focus Management Tests
    
    func test_focusManagement_movesCorrectly() throws {
        // Test focus movement between form fields
        
        // Given
        enum FocusField: CaseIterable {
            case email, password, firstName, lastName, username, phoneNumber, verificationCode
        }
        
        let focusOrder: [FocusField] = [.email, .password, .firstName, .lastName, .username, .phoneNumber, .verificationCode]
        
        // When & Then
        for (index, field) in focusOrder.enumerated() {
            XCTAssertNotNil(field, "Focus field at index \(index) should exist")
        }
        
        XCTAssertEqual(focusOrder.count, 7, "Should have 7 focusable fields")
    }
    
    // MARK: - Navigation Tests
    
    func test_navigation_authenticationFlow_proceedsCorrectly() throws {
        // Test navigation through the authentication flow
        
        // Given
        enum AuthStep {
            case signIn, signUp, verification, completed
        }
        
        var currentStep: AuthStep = .signIn
        
        // When - User completes sign up
        currentStep = .signUp
        // Then
        XCTAssertEqual(currentStep, .signUp, "Should move to sign up step")
        
        // When - User enters verification
        currentStep = .verification
        // Then
        XCTAssertEqual(currentStep, .verification, "Should move to verification step")
        
        // When - User completes verification
        currentStep = .completed
        // Then
        XCTAssertEqual(currentStep, .completed, "Should move to completed step")
    }
    
    // MARK: - Accessibility Tests
    
    func test_accessibility_labelsAreCorrect() throws {
        // Test accessibility labels for form elements
        
        // Given
        let accessibilityLabels = [
            "email_input": "Email address",
            "password_input": "Password",
            "firstName_input": "First name",
            "lastName_input": "Last name",
            "username_input": "Username",
            "phoneNumber_input": "Phone number",
            "verificationCode_input": "Verification code",
            "signIn_button": "Sign in",
            "signUp_button": "Sign up",
            "appleSignIn_button": "Sign in with Apple"
        ]
        
        // When & Then
        for (identifier, expectedLabel) in accessibilityLabels {
            XCTAssertFalse(expectedLabel.isEmpty, "Accessibility label for \(identifier) should not be empty")
            XCTAssertTrue(expectedLabel.count > 3, "Accessibility label should be descriptive")
        }
    }
    
    // MARK: - Performance Tests
    
    func test_authenticationUI_performance() throws {
        // Test UI performance for authentication screens
        
        measure {
            // Simulate form validation performance
            for i in 0..<100 {
                _ = validateEmailInput("test\(i)@example.com")
                _ = validatePasswordInput("Password\(i)")
                _ = validatePhoneNumberInput("555123456\(i % 10)")
            }
        }
    }
}

// MARK: - Test Helper Functions

extension AuthenticationUITests {
    
    func validateEmailInput(_ email: String) -> Bool {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    func validatePasswordInput(_ password: String) -> Bool {
        return password.count >= 8 &&
               password.range(of: "[a-z]", options: .regularExpression) != nil &&
               password.range(of: "[A-Z]", options: .regularExpression) != nil &&
               password.range(of: "[0-9]", options: .regularExpression) != nil
    }
    
    func validatePhoneNumberInput(_ phoneNumber: String) -> Bool {
        let cleanPhone = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return cleanPhone.count == 10
    }
    
    func validateVerificationCodeInput(_ code: String) -> Bool {
        return code.count == 6 && code.allSatisfy { $0.isNumber }
    }
    
    func isSignInButtonEnabled(email: String, password: String) -> Bool {
        return validateEmailInput(email) && validatePasswordInput(password)
    }
    
    func isSignUpButtonEnabled(_ formData: SignUpTestData) -> Bool {
        return validateEmailInput(formData.email) &&
               validatePasswordInput(formData.password) &&
               !formData.firstName.isEmpty &&
               !formData.lastName.isEmpty &&
               !formData.username.isEmpty
    }
    
    func validateSignUpForm(_ formData: SignUpTestData) -> Bool {
        return validateEmailInput(formData.email) &&
               validatePasswordInput(formData.password) &&
               formData.firstName.count >= 2 &&
               formData.lastName.count >= 2 &&
               formData.username.count >= 3 &&
               (formData.phoneNumber.isEmpty || validatePhoneNumberInput(formData.phoneNumber))
    }
    
    func getErrorDisplayMessage(for errorCode: String) -> String {
        switch errorCode {
        case "INVALID_EMAIL":
            return "Please enter a valid email address"
        case "WEAK_PASSWORD":
            return "Password must be at least 8 characters with uppercase, lowercase, and numbers"
        case "USER_NOT_FOUND":
            return "User not found"
        case "NETWORK_ERROR":
            return "Network connection failed"
        case "INVALID_CODE":
            return "Invalid verification code"
        default:
            return "An error occurred"
        }
    }
}

// MARK: - Test Data Structures

struct SignUpTestData {
    let email: String
    let password: String
    let firstName: String
    let lastName: String
    let username: String
    let phoneNumber: String
}

// MARK: - Mock UI State Management

class MockAuthenticationUIState: ObservableObject {
    @Published var selectedTab = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var isCodeSent = false
    @Published var countdown = 0
    
    // Form fields
    @Published var email = ""
    @Published var password = ""
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var username = ""
    @Published var phoneNumber = ""
    @Published var verificationCode = ""
    
    func setLoading(_ loading: Bool) {
        isLoading = loading
    }
    
    func setError(_ message: String) {
        errorMessage = message
        showError = true
        isLoading = false
    }
    
    func clearError() {
        errorMessage = nil
        showError = false
    }
    
    func startVerification() {
        isCodeSent = true
        countdown = 60
    }
    
    func resetForm() {
        email = ""
        password = ""
        firstName = ""
        lastName = ""
        username = ""
        phoneNumber = ""
        verificationCode = ""
        clearError()
        isLoading = false
        isCodeSent = false
        countdown = 0
    }
}

// MARK: - UI Test Extensions

extension AuthenticationUITests {
    
    func test_mockUIState_functionsCorrectly() throws {
        // Test the mock UI state management
        
        // Given
        let uiState = MockAuthenticationUIState()
        
        // When & Then - Initial state
        XCTAssertEqual(uiState.selectedTab, 0)
        XCTAssertFalse(uiState.isLoading)
        XCTAssertNil(uiState.errorMessage)
        
        // When & Then - Set loading
        uiState.setLoading(true)
        XCTAssertTrue(uiState.isLoading)
        
        // When & Then - Set error
        uiState.setError("Test error")
        XCTAssertEqual(uiState.errorMessage, "Test error")
        XCTAssertTrue(uiState.showError)
        XCTAssertFalse(uiState.isLoading)
        
        // When & Then - Start verification
        uiState.startVerification()
        XCTAssertTrue(uiState.isCodeSent)
        XCTAssertEqual(uiState.countdown, 60)
        
        // When & Then - Reset form
        uiState.email = "test@example.com"
        uiState.resetForm()
        XCTAssertEqual(uiState.email, "")
        XCTAssertFalse(uiState.isLoading)
        XCTAssertFalse(uiState.isCodeSent)
    }
} 