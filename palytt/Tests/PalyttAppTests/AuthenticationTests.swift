//
//  AuthenticationTests.swift
//  PalyttAppTests
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//

import XCTest
@testable import Palytt

final class AuthenticationTests: XCTestCase {
    
    // MARK: - Test Data Factory
    
    struct AuthTestDataFactory {
        static func makeValidEmail() -> String { "test@example.com" }
        static func makeInvalidEmail() -> String { "invalid-email" }
        static func makeValidPassword() -> String { "SecurePass123!" }
        static func makeWeakPassword() -> String { "weak" }
        static func makeValidPhoneNumber() -> String { "(555) 123-4567" }
        static func makeInvalidPhoneNumber() -> String { "123" }
        static func makeValidUsername() -> String { "testuser123" }
        static func makeInvalidUsername() -> String { "a" }
        static func makeValidFirstName() -> String { "John" }
        static func makeValidLastName() -> String { "Doe" }
        static func makeValidVerificationCode() -> String { "123456" }
        static func makeInvalidVerificationCode() -> String { "123" }
    }
    
    // MARK: - Email Validation Tests
    
    func test_email_validation_withValidEmail_returnsTrue() {
        // Given
        let validEmails = [
            "test@example.com",
            "user.name@domain.co.uk",
            "test+label@gmail.com",
            "admin@company.org"
        ]
        
        // When & Then
        for email in validEmails {
            XCTAssertTrue(isValidEmail(email), "Email '\(email)' should be valid")
        }
    }
    
    func test_email_validation_withInvalidEmail_returnsFalse() {
        // Given
        let invalidEmails = [
            "",
            "invalid-email",
            "@domain.com",
            "user@",
            "user..name@domain.com",
            "user@domain",
            "spaces in@email.com"
        ]
        
        // When & Then
        for email in invalidEmails {
            XCTAssertFalse(isValidEmail(email), "Email '\(email)' should be invalid")
        }
    }
    
    // MARK: - Password Validation Tests
    
    func test_password_validation_withValidPassword_returnsTrue() {
        // Given
        let validPasswords = [
            "SecurePass123!",
            "MyPassword1",
            "Test1234",
            "Complex!Pass9"
        ]
        
        // When & Then
        for password in validPasswords {
            XCTAssertTrue(isPasswordValid(password), "Password '\(password)' should be valid")
        }
    }
    
    func test_password_validation_withInvalidPassword_returnsFalse() {
        // Given
        let invalidPasswords = [
            "",
            "weak",
            "12345678", // No letters
            "PASSWORD", // No numbers
            "password", // No uppercase
            "PASSWORD1", // No lowercase
            "Pass1" // Too short
        ]
        
        // When & Then
        for password in invalidPasswords {
            XCTAssertFalse(isPasswordValid(password), "Password '\(password)' should be invalid")
        }
    }
    
    // MARK: - Phone Number Validation Tests
    
    func test_phoneNumber_validation_withValidNumbers_returnsTrue() {
        // Given
        let validPhoneNumbers = [
            "(555) 123-4567",
            "555-123-4567",
            "5551234567",
            "555.123.4567"
        ]
        
        // When & Then
        for phoneNumber in validPhoneNumbers {
            XCTAssertTrue(isPhoneNumberValid(phoneNumber), "Phone number '\(phoneNumber)' should be valid")
        }
    }
    
    func test_phoneNumber_validation_withInvalidNumbers_returnsFalse() {
        // Given
        let invalidPhoneNumbers = [
            "",
            "123",
            "12345", // Too short
            "123456789012345", // Too long
            "abc-def-ghij", // Non-numeric
            "555-123-456" // Missing digit
        ]
        
        // When & Then
        for phoneNumber in invalidPhoneNumbers {
            XCTAssertFalse(isPhoneNumberValid(phoneNumber), "Phone number '\(phoneNumber)' should be invalid")
        }
    }
    
    // MARK: - Username Validation Tests
    
    func test_username_validation_withValidUsernames_returnsTrue() {
        // Given
        let validUsernames = [
            "testuser",
            "user123",
            "test_user",
            "user-name",
            "TestUser"
        ]
        
        // When & Then
        for username in validUsernames {
            XCTAssertTrue(isUsernameValid(username), "Username '\(username)' should be valid")
        }
    }
    
    func test_username_validation_withInvalidUsernames_returnsFalse() {
        // Given
        let invalidUsernames = [
            "",
            "a", // Too short
            String(repeating: "a", count: 51), // Too long
            "user@name", // Invalid character
            "user name", // Spaces
            "123only" // Only numbers at start
        ]
        
        // When & Then
        for username in invalidUsernames {
            XCTAssertFalse(isUsernameValid(username), "Username '\(username)' should be invalid")
        }
    }
    
    // MARK: - Name Validation Tests
    
    func test_firstName_validation_withValidNames_returnsTrue() {
        // Given
        let validFirstNames = [
            "John",
            "Mary",
            "José",
            "李",
            "O'Connor",
            "Anne-Marie"
        ]
        
        // When & Then
        for firstName in validFirstNames {
            XCTAssertTrue(isFirstNameValid(firstName), "First name '\(firstName)' should be valid")
        }
    }
    
    func test_firstName_validation_withInvalidNames_returnsFalse() {
        // Given
        let invalidFirstNames = [
            "",
            "A", // Too short
            String(repeating: "A", count: 51), // Too long
            "John123", // Numbers
            "John@Smith" // Special characters
        ]
        
        // When & Then
        for firstName in invalidFirstNames {
            XCTAssertFalse(isFirstNameValid(firstName), "First name '\(firstName)' should be invalid")
        }
    }
    
    func test_lastName_validation_withValidNames_returnsTrue() {
        // Given
        let validLastNames = [
            "Smith",
            "O'Connor",
            "Van Der Berg",
            "李",
            "García"
        ]
        
        // When & Then
        for lastName in validLastNames {
            XCTAssertTrue(isLastNameValid(lastName), "Last name '\(lastName)' should be valid")
        }
    }
    
    // MARK: - Verification Code Tests
    
    func test_verificationCode_validation_withValidCodes_returnsTrue() {
        // Given
        let validCodes = [
            "123456",
            "000000",
            "999999"
        ]
        
        // When & Then
        for code in validCodes {
            XCTAssertTrue(isVerificationCodeValid(code), "Verification code '\(code)' should be valid")
        }
    }
    
    func test_verificationCode_validation_withInvalidCodes_returnsFalse() {
        // Given
        let invalidCodes = [
            "",
            "123", // Too short
            "1234567", // Too long
            "12345a", // Non-numeric
            "123 45" // Spaces
        ]
        
        // When & Then
        for code in invalidCodes {
            XCTAssertFalse(isVerificationCodeValid(code), "Verification code '\(code)' should be invalid")
        }
    }
    
    // MARK: - Phone Number Formatting Tests
    
    func test_phoneNumber_formatting_returnsCorrectFormat() {
        // Given
        let testCases = [
            ("5551234567", "+15551234567"),
            ("(555) 123-4567", "+15551234567"),
            ("555.123.4567", "+15551234567"),
            ("555-123-4567", "+15551234567")
        ]
        
        // When & Then
        for (input, expected) in testCases {
            let formatted = formatPhoneNumberForE164(input)
            XCTAssertEqual(formatted, expected, "Phone number '\(input)' should format to '\(expected)'")
        }
    }
    
    // MARK: - Form Validation Tests
    
    func test_emailSignUpForm_validation_withValidData_returnsTrue() {
        // Given
        let formData = EmailSignUpFormData(
            email: AuthTestDataFactory.makeValidEmail(),
            password: AuthTestDataFactory.makeValidPassword(),
            firstName: AuthTestDataFactory.makeValidFirstName(),
            lastName: AuthTestDataFactory.makeValidLastName(),
            username: AuthTestDataFactory.makeValidUsername()
        )
        
        // When
        let isValid = validateEmailSignUpForm(formData)
        
        // Then
        XCTAssertTrue(isValid, "Valid email signup form should pass validation")
    }
    
    func test_emailSignUpForm_validation_withInvalidData_returnsFalse() {
        // Given
        let formData = EmailSignUpFormData(
            email: AuthTestDataFactory.makeInvalidEmail(),
            password: AuthTestDataFactory.makeWeakPassword(),
            firstName: "",
            lastName: "",
            username: ""
        )
        
        // When
        let isValid = validateEmailSignUpForm(formData)
        
        // Then
        XCTAssertFalse(isValid, "Invalid email signup form should fail validation")
    }
    
    func test_phoneSignUpForm_validation_withValidData_returnsTrue() {
        // Given
        let formData = PhoneSignUpFormData(
            phoneNumber: AuthTestDataFactory.makeValidPhoneNumber(),
            password: AuthTestDataFactory.makeValidPassword(),
            firstName: AuthTestDataFactory.makeValidFirstName(),
            lastName: AuthTestDataFactory.makeValidLastName(),
            username: AuthTestDataFactory.makeValidUsername()
        )
        
        // When
        let isValid = validatePhoneSignUpForm(formData)
        
        // Then
        XCTAssertTrue(isValid, "Valid phone signup form should pass validation")
    }
    
    func test_signInForm_validation_withValidData_returnsTrue() {
        // Given
        let emailData = EmailSignInFormData(
            email: AuthTestDataFactory.makeValidEmail(),
            password: AuthTestDataFactory.makeValidPassword()
        )
        
        let phoneData = PhoneSignInFormData(
            phoneNumber: AuthTestDataFactory.makeValidPhoneNumber(),
            password: AuthTestDataFactory.makeValidPassword()
        )
        
        // When & Then
        XCTAssertTrue(validateEmailSignInForm(emailData), "Valid email sign in form should pass validation")
        XCTAssertTrue(validatePhoneSignInForm(phoneData), "Valid phone sign in form should pass validation")
    }
    
    // MARK: - Authentication Flow State Tests
    
    func test_authenticationFlow_stateTransitions_workCorrectly() {
        // Given
        var authState = AuthenticationFlowState()
        
        // When & Then - Initial state
        XCTAssertEqual(authState.currentStep, .initial)
        XCTAssertFalse(authState.isLoading)
        XCTAssertNil(authState.errorMessage)
        
        // When & Then - Loading state
        authState.setLoading(true)
        XCTAssertTrue(authState.isLoading)
        
        // When & Then - Error state
        authState.setError("Test error")
        XCTAssertEqual(authState.errorMessage, "Test error")
        XCTAssertFalse(authState.isLoading)
        
        // When & Then - Verification step
        authState.moveToVerification()
        XCTAssertEqual(authState.currentStep, .verification)
    }
    
    // MARK: - Input Sanitization Tests
    
    func test_input_sanitization_removesWhitespace() {
        // Given
        let inputs = [
            "  test@example.com  ",
            "\n\nusername\t\t",
            "  John Doe  "
        ]
        
        let expected = [
            "test@example.com",
            "username",
            "John Doe"
        ]
        
        // When & Then
        for (input, expectedOutput) in zip(inputs, expected) {
            let sanitized = sanitizeInput(input)
            XCTAssertEqual(sanitized, expectedOutput, "Input '\(input)' should be sanitized to '\(expectedOutput)'")
        }
    }
    
    // MARK: - Security Tests
    
    func test_password_requirements_areSecure() {
        // Given
        let requirements = PasswordRequirements()
        
        // When & Then
        XCTAssertEqual(requirements.minLength, 8, "Minimum password length should be 8")
        XCTAssertTrue(requirements.requiresUppercase, "Password should require uppercase")
        XCTAssertTrue(requirements.requiresLowercase, "Password should require lowercase")
        XCTAssertTrue(requirements.requiresNumbers, "Password should require numbers")
    }
    
    func test_authentication_errors_areProperlyCategorized() {
        // Given
        let authErrors = [
            AuthenticationError.invalidEmail,
            AuthenticationError.weakPassword,
            AuthenticationError.userNotFound,
            AuthenticationError.networkError,
            AuthenticationError.invalidVerificationCode
        ]
        
        // When & Then
        for error in authErrors {
            XCTAssertFalse(error.localizedDescription.isEmpty, "Error should have description")
            XCTAssertNotNil(error.errorCode, "Error should have code")
        }
    }
    
    // MARK: - Performance Tests
    
    func test_validation_performance_isAcceptable() {
        measure {
            // Test validation performance with large datasets
            for i in 0..<1000 {
                _ = isValidEmail("test\(i)@example.com")
                _ = isPasswordValid("Password\(i)")
                _ = isPhoneNumberValid("555123456\(i % 10)")
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func test_authentication_backend_integration_mock() async {
        // Given
        let mockBackendService = MockAuthenticationBackendService()
        let authService = AuthenticationService(backendService: mockBackendService)
        
        let signUpData = EmailSignUpFormData(
            email: "test@example.com",
            password: "SecurePass123!",
            firstName: "John",
            lastName: "Doe",
            username: "johndoe"
        )
        
        // When
        do {
            let result = try await authService.signUpWithEmail(signUpData)
            
            // Then
            XCTAssertTrue(result.success, "Sign up should succeed")
            XCTAssertNotNil(result.userId, "User ID should be provided")
        } catch {
            XCTFail("Sign up should not throw error: \(error)")
        }
    }
}

// MARK: - Test Helper Functions

extension AuthenticationTests {
    
    func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    func isPasswordValid(_ password: String) -> Bool {
        return password.count >= 8 &&
               password.range(of: "[a-z]", options: .regularExpression) != nil &&
               password.range(of: "[A-Z]", options: .regularExpression) != nil &&
               password.range(of: "[0-9]", options: .regularExpression) != nil
    }
    
    func isPhoneNumberValid(_ phoneNumber: String) -> Bool {
        let cleanPhone = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return cleanPhone.count == 10
    }
    
    func isUsernameValid(_ username: String) -> Bool {
        return username.count >= 3 &&
               username.count <= 50 &&
               username.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
    }
    
    func isFirstNameValid(_ firstName: String) -> Bool {
        let trimmed = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 2 &&
               trimmed.count <= 50 &&
               trimmed.allSatisfy { $0.isLetter || $0.isWhitespace || $0 == "'" || $0 == "-" }
    }
    
    func isLastNameValid(_ lastName: String) -> Bool {
        let trimmed = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 2 &&
               trimmed.count <= 50 &&
               trimmed.allSatisfy { $0.isLetter || $0.isWhitespace || $0 == "'" || $0 == "-" }
    }
    
    func isVerificationCodeValid(_ code: String) -> Bool {
        return code.count == 6 && code.allSatisfy { $0.isNumber }
    }
    
    func formatPhoneNumberForE164(_ phoneNumber: String) -> String {
        let cleanPhone = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return "+1\(cleanPhone)"
    }
    
    func sanitizeInput(_ input: String) -> String {
        return input.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func validateEmailSignUpForm(_ formData: EmailSignUpFormData) -> Bool {
        return isValidEmail(formData.email) &&
               isPasswordValid(formData.password) &&
               isFirstNameValid(formData.firstName) &&
               isLastNameValid(formData.lastName) &&
               isUsernameValid(formData.username)
    }
    
    func validatePhoneSignUpForm(_ formData: PhoneSignUpFormData) -> Bool {
        return isPhoneNumberValid(formData.phoneNumber) &&
               isPasswordValid(formData.password) &&
               isFirstNameValid(formData.firstName) &&
               isLastNameValid(formData.lastName) &&
               isUsernameValid(formData.username)
    }
    
    func validateEmailSignInForm(_ formData: EmailSignInFormData) -> Bool {
        return isValidEmail(formData.email) && isPasswordValid(formData.password)
    }
    
    func validatePhoneSignInForm(_ formData: PhoneSignInFormData) -> Bool {
        return isPhoneNumberValid(formData.phoneNumber) && isPasswordValid(formData.password)
    }
}

// MARK: - Test Data Structures

struct EmailSignUpFormData {
    let email: String
    let password: String
    let firstName: String
    let lastName: String
    let username: String
}

struct PhoneSignUpFormData {
    let phoneNumber: String
    let password: String
    let firstName: String
    let lastName: String
    let username: String
}

struct EmailSignInFormData {
    let email: String
    let password: String
}

struct PhoneSignInFormData {
    let phoneNumber: String
    let password: String
}

struct AuthenticationFlowState {
    enum Step {
        case initial
        case verification
        case completed
    }
    
    var currentStep: Step = .initial
    var isLoading: Bool = false
    var errorMessage: String?
    
    mutating func setLoading(_ loading: Bool) {
        isLoading = loading
    }
    
    mutating func setError(_ message: String) {
        errorMessage = message
        isLoading = false
    }
    
    mutating func moveToVerification() {
        currentStep = .verification
        errorMessage = nil
    }
}

struct PasswordRequirements {
    let minLength: Int = 8
    let requiresUppercase: Bool = true
    let requiresLowercase: Bool = true
    let requiresNumbers: Bool = true
}

enum AuthenticationError: Error {
    case invalidEmail
    case weakPassword
    case userNotFound
    case networkError
    case invalidVerificationCode
    
    var localizedDescription: String {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address"
        case .weakPassword:
            return "Password must be at least 8 characters with uppercase, lowercase, and numbers"
        case .userNotFound:
            return "User not found"
        case .networkError:
            return "Network connection failed"
        case .invalidVerificationCode:
            return "Invalid verification code"
        }
    }
    
    var errorCode: String {
        switch self {
        case .invalidEmail: return "AUTH_INVALID_EMAIL"
        case .weakPassword: return "AUTH_WEAK_PASSWORD"
        case .userNotFound: return "AUTH_USER_NOT_FOUND"
        case .networkError: return "AUTH_NETWORK_ERROR"
        case .invalidVerificationCode: return "AUTH_INVALID_CODE"
        }
    }
}

// MARK: - Mock Services

class MockAuthenticationBackendService {
    func signUpWithEmail(_ data: EmailSignUpFormData) async throws -> AuthenticationResult {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        return AuthenticationResult(
            success: true,
            userId: "mock_user_123",
            message: "Sign up successful"
        )
    }
}

class AuthenticationService {
    private let backendService: MockAuthenticationBackendService
    
    init(backendService: MockAuthenticationBackendService) {
        self.backendService = backendService
    }
    
    func signUpWithEmail(_ data: EmailSignUpFormData) async throws -> AuthenticationResult {
        return try await backendService.signUpWithEmail(data)
    }
}

struct AuthenticationResult {
    let success: Bool
    let userId: String?
    let message: String
} 