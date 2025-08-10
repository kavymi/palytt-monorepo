//
//  AuthenticationView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI
import Clerk
import AuthenticationServices
import Foundation

struct AuthenticationView: View {
    @EnvironmentObject var appState: AppState
    @Environment(Clerk.self) var clerk
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            // Background
            Color.background
                .ignoresSafeArea()
            
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    Spacer() // Equal spacing above
                    
                    VStack(spacing: 24) {
                        // Logo
                        Image("palytt-logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 160, height: 160)
                        
                        // Auth Tabs
                        VStack(spacing: 24) {
                            // Tab Selector
                            HStack(spacing: 0) {
                                Button(action: { 
                                    withAnimation {
                                        selectedTab = 0
                                    }
                                }) {
                                    Text("Sign In")
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            selectedTab == 0 ? Color.primaryBrand : Color.clear
                                        )
                                        .foregroundColor(
                                            selectedTab == 0 ? .white : .primaryText
                                        )
                                }
                                
                                Button(action: { 
                                    withAnimation {
                                        selectedTab = 1
                                    }
                                }) {
                                    Text("Sign Up")
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            selectedTab == 1 ? Color.primaryBrand : Color.clear
                                        )
                                        .foregroundColor(
                                            selectedTab == 1 ? .white : .primaryText
                                        )
                                }
                            }
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 24)
                        
                        // Tab Content
                        if selectedTab == 0 {
                            ClerkSignInView()
                                .transition(.asymmetric(
                                    insertion: .move(edge: .leading),
                                    removal: .move(edge: .trailing)
                                ))
                        } else {
                            ClerkSignUpView()
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing),
                                    removal: .move(edge: .leading)
                                ))
                        }
                    }
                    
                    Spacer() // Equal spacing below
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }
}

// MARK: - Clerk Sign In View
struct ClerkSignInView: View {
    @Environment(Clerk.self) var clerk
    @EnvironmentObject var appState: AppState
    @State private var email = ""
    @State private var password = ""
    @State private var phoneNumber = ""
    @State private var verificationCode = ""
    @State private var username = ""
    @State private var isLoading = false
    @State private var signInMethod: SignInMethod = .email
    @State private var isCodeSent = false
    @State private var countdown = 0
    @State private var timer: Timer?
    @State private var signIn: SignIn?
    @State private var signUp: SignUp?
    @State private var phoneNumberId: String?
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var showUsernamePrompt = false
    @State private var pendingAppleUser: PendingAppleUser?
    @State private var promptUsername = ""
    @State private var isPasswordlessFlow = false
    @State private var isSigningUp = false
    @State private var needsUsername = false
    @State private var showPasswordRequirements = false
    
    // Check if we're running in preview mode
    private var isPreviewMode: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    private var isPhoneNumberValid: Bool {
        let cleanPhone = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return cleanPhone.count == 10
    }
    
    private var isPasswordValidForSignIn: Bool {
        password.count >= 8 &&
        password.range(of: "[a-z]", options: .regularExpression) != nil &&
        password.range(of: "[A-Z]", options: .regularExpression) != nil &&
        password.range(of: "[0-9]", options: .regularExpression) != nil
    }
    
    struct PendingAppleUser {
        let clerkId: String
        let appleId: String
        let email: String?
        let firstName: String?
        let lastName: String?
    }
    
    enum SignInMethod {
        case email, phone
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Error Message
            if showError {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 16, weight: .medium))
                    
                    Text(errorMessage)
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Button(action: hideError) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red.opacity(0.6))
                            .font(.system(size: 18))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red.opacity(0.2), lineWidth: 1)
                        )
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity.combined(with: .scale(scale: 0.95))
                ))
            }
            
            // Sign In Method Selector
            HStack(spacing: 12) {
                Button(action: { 
                    HapticManager.shared.impact(.light)
                    withAnimation(.easeInOut(duration: 0.3)) {
                        signInMethod = .email
                        resetPhoneState()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 16))
                        Text("Email")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(
                        signInMethod == .email ? 
                        Color.primaryBrand : Color.clear
                    )
                    .foregroundColor(
                        signInMethod == .email ? .white : .secondaryText
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                signInMethod == .email ? Color.clear : Color.gray.opacity(0.3),
                                lineWidth: 1
                            )
                    )
                    .cornerRadius(12)
                    .shadow(
                        color: signInMethod == .email ? Color.primaryBrand.opacity(0.3) : Color.clear,
                        radius: 4,
                        x: 0,
                        y: 2
                    )
                }
                
                Button(action: { 
                    HapticManager.shared.impact(.light)
                    withAnimation(.easeInOut(duration: 0.3)) {
                        signInMethod = .phone
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 16))
                        Text("Phone")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(
                        signInMethod == .phone ? 
                        Color.primaryBrand : Color.clear
                    )
                    .foregroundColor(
                        signInMethod == .phone ? .white : .secondaryText
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                signInMethod == .phone ? Color.clear : Color.gray.opacity(0.3),
                                lineWidth: 1
                            )
                    )
                    .cornerRadius(12)
                    .shadow(
                        color: signInMethod == .phone ? Color.primaryBrand.opacity(0.3) : Color.clear,
                        radius: 4,
                        x: 0,
                        y: 2
                    )
                }
            }
            
            if signInMethod == .email {
                EmailSignInForm()
            } else {
                PhoneSignInForm()
            }
            
            // Social Sign In
            VStack(spacing: 12) {
                Text("or continue with")
                    .font(.caption)
                    .foregroundColor(.tertiaryText)
                
                HStack(spacing: 16) {
                    // Apple Sign In Button
                    appleSignInButton()
                    
                    // Google Sign In Button
                    Button(action: {
                        HapticManager.shared.impact(.medium)
                        Task {
                            await signInWithGoogle()
                        }
                    }) {
                        Image(systemName: "g.circle.fill")
                            .font(.title2)
                            .frame(width: 50, height: 50)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                            .foregroundColor(.primaryText)
                    }
                }
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 24)
        .onDisappear {
            // Clean up timer when view disappears
            timer?.invalidate()
            timer = nil
        }
        .overlay(
            // Username prompt overlay for Apple Sign In
            Group {
                if showUsernamePrompt {
                    UsernamePromptView(
                        username: $promptUsername,
                        isLoading: $isLoading,
                        onComplete: {
                            Task {
                                await completeAppleSignInWithUsername()
                            }
                        },
                        onCancel: {
                            pendingAppleUser = nil
                            showUsernamePrompt = false
                            promptUsername = ""
                        }
                    )
                    .transition(.opacity.combined(with: .scale))
                }
            }
        )
    }
    
    @ViewBuilder
    private func EmailSignInForm() -> some View {
        VStack(spacing: 16) {
            // Email Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                
                TextField("Enter your email", text: $email)
                    .textFieldStyle(.plain)
                    #if os(iOS)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    #endif
                    .padding()
                    .background(Color.gray.opacity(email.isEmpty ? 0.1 : 0.15))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                email.isEmpty ? Color.clear : Color.primaryBrand.opacity(0.3),
                                lineWidth: 1
                            )
                    )
                    .accessibilityLabel("Email Address")
                    .accessibilityHint("Enter your email address to sign in")
                    .animation(.easeInOut(duration: 0.2), value: email.isEmpty)
            }
            
            // Password Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                
                SecureField("Enter your password", text: $password)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(Color.gray.opacity(password.isEmpty ? 0.1 : 0.15))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                password.isEmpty ? Color.clear : Color.primaryBrand.opacity(0.3),
                                lineWidth: 1
                            )
                    )
                    .accessibilityLabel("Password")
                    .accessibilityHint("Enter your password to sign in")
                    .animation(.easeInOut(duration: 0.2), value: password.isEmpty)
            }
            
            // Forgot Password
            HStack {
                Spacer()
                Button("Forgot Password?") {
                    Task {
                        await resetPassword()
                    }
                }
                .font(.caption)
                .foregroundColor(.primaryBrand)
            }
            .padding(.top, -8)
            
            // Sign In Button
            Button(action: {
                HapticManager.shared.impact(.medium)
                Task {
                    await signInWithEmail()
                }
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Text("Sign In")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .padding(.horizontal, 24)
                .background(Color.primaryBrand)
                .foregroundColor(.white)
                .cornerRadius(16)
            }
            .disabled(isLoading || (!isPreviewMode && (email.isEmpty || password.isEmpty)))
            .opacity(isLoading || (!isPreviewMode && (email.isEmpty || password.isEmpty)) ? 0.6 : 1)
            .scaleEffect(isLoading ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isLoading)
        }
    }
    
    @ViewBuilder
    private func PhoneSignInForm() -> some View {
        VStack(spacing: 16) {
            if !isCodeSent {
                // Phone Number Field
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Phone Number")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                        
                        if !phoneNumber.isEmpty {
                            Image(systemName: isPhoneNumberValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(isPhoneNumberValid ? .green : .red)
                        }
                    }
                    
                    TextField("Enter your phone number", text: $phoneNumber)
                        .textFieldStyle(.plain)
                        #if os(iOS)
                        .keyboardType(.phonePad)
                        #endif
                        .padding()
                        .background(Color.gray.opacity(phoneNumber.isEmpty ? 0.1 : 0.15))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    !phoneNumber.isEmpty && !isPhoneNumberValid ? Color.red.opacity(0.5) : 
                                    !phoneNumber.isEmpty ? Color.primaryBrand.opacity(0.3) : Color.clear,
                                    lineWidth: 1
                                )
                        )
                        .onChange(of: phoneNumber) { _, newValue in
                            phoneNumber = formatPhoneNumber(newValue)
                        }
                        .animation(.easeInOut(duration: 0.2), value: phoneNumber.isEmpty)
                    
                    if !phoneNumber.isEmpty && !isPhoneNumberValid {
                        Text("Please enter a valid 10-digit US phone number")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
                
                // Username Field (for new users)
                if needsUsername {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                        
                        TextField("Choose a username", text: $username)
                            .textFieldStyle(.plain)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    
                    // Password Field (for new users)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                        
                        SecureField("Create a password", text: $password)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                            .onTapGesture {
                                showPasswordRequirements = true
                            }
                            .onChange(of: password) { _, _ in
                                if !password.isEmpty {
                                    showPasswordRequirements = true
                                }
                            }
                        
                        // Password Requirements
                        if showPasswordRequirements {
                            VStack(alignment: .leading, spacing: 4) {
                                PasswordRequirementRow(
                                    text: "8+ characters minimum length",
                                    isValid: password.count >= 8
                                )
                                PasswordRequirementRow(
                                    text: "1 lowercase letter (a-z)",
                                    isValid: password.range(of: "[a-z]", options: .regularExpression) != nil
                                )
                                PasswordRequirementRow(
                                    text: "1 uppercase letter (A-Z)",
                                    isValid: password.range(of: "[A-Z]", options: .regularExpression) != nil
                                )
                                PasswordRequirementRow(
                                    text: "1 number (0-9)",
                                    isValid: password.range(of: "[0-9]", options: .regularExpression) != nil
                                )
                            }
                            .padding(.top, 4)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // Send Code Button
                Button(action: {
                    Task {
                        await sendPhoneVerificationCode()
                    }
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Text(needsUsername ? "Create Account" : "Continue with Phone")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(Color.primaryBrand)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                .disabled(isLoading || (!isPreviewMode && (!isPhoneNumberValid || (needsUsername && (username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty || !isPasswordValidForSignIn)))))
                .opacity(isLoading || (!isPreviewMode && (!isPhoneNumberValid || (needsUsername && (username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty || !isPasswordValidForSignIn)))) ? 0.6 : 1)
            } else {
                // Verification Code Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Verification Code")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    
                    TextField("Enter 6-digit code", text: $verificationCode)
                        .textFieldStyle(.plain)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        .textInputAutocapitalization(.never)
                        #endif
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .onChange(of: verificationCode) { _, newValue in
                            if newValue.count > 6 {
                                verificationCode = String(newValue.prefix(6))
                            }
                        }
                }
                
                // Code sent message with status
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Code sent to \(phoneNumber)")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                        
                        Spacer()
                        
                        if countdown > 0 {
                            Text("Resend in \(countdown)s")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        } else {
                            Button("Resend Code") {
                                Task {
                                    await sendPhoneVerificationCode()
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.primaryBrand)
                        }
                    }
                    
                    HStack {
                        Image(systemName: isSigningUp ? "person.badge.plus" : "person.crop.circle")
                            .font(.system(size: 10))
                            .foregroundColor(.primaryBrand)
                        Text(isSigningUp ? "Creating new account" : "Signing into existing account")
                            .font(.caption2)
                            .foregroundColor(.primaryBrand)
                    }
                }
                .padding(.top, -8)
                
                // Verify Button
                Button(action: {
                    Task {
                        await verifyPhoneCode()
                    }
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Text(isSigningUp ? "Verify & Create Account" : "Verify & Sign In")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(Color.primaryBrand)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                .disabled(isLoading || verificationCode.count != 6)
                .opacity(isLoading || verificationCode.count != 6 ? 0.6 : 1)
                
                // Back button
                Button("← Change Phone Number") {
                    withAnimation {
                        resetPhoneState()
                    }
                }
                .font(.caption)
                .foregroundColor(.primaryBrand)
            }
        }
    }
    
    private func resetPhoneState() {
        isCodeSent = false
        isPasswordlessFlow = false
        isSigningUp = false
        verificationCode = ""
        username = ""
        password = ""
        needsUsername = false
        showPasswordRequirements = false
        countdown = 0
        timer?.invalidate()
        timer = nil
        signIn = nil
        phoneNumberId = nil
        hideError()
    }
    
    private func formatPhoneNumber(_ number: String) -> String {
        // Remove all non-numeric characters
        let cleaned = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        // Limit to 10 digits
        let limited = String(cleaned.prefix(10))
        
        // Format as (XXX) XXX-XXXX
        if limited.count >= 6 {
            let areaCode = String(limited.prefix(3))
            let middle = String(limited.dropFirst(3).prefix(3))
            let last = String(limited.dropFirst(6))
            return "(\(areaCode)) \(middle)-\(last)"
        } else if limited.count >= 3 {
            let areaCode = String(limited.prefix(3))
            let remaining = String(limited.dropFirst(3))
            return "(\(areaCode)) \(remaining)"
        } else if !limited.isEmpty {
            return limited
        }
        
        return ""
    }
    
    private func socialButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 50, height: 50)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .foregroundColor(.primaryText)
        }
    }
    
    @ViewBuilder
    private func appleSignInButton() -> some View {
        Button(action: {
            HapticManager.shared.impact(.medium)
            Task {
                await signInWithApple()
            }
        }) {
            Image(systemName: "apple.logo")
                .font(.title2)
                .frame(width: 50, height: 50)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .foregroundColor(.primaryText)
        }
    }
    
    // MARK: - Authentication Methods
    
    private func signInWithEmail() async {
        // In preview mode, allow bypass even with empty fields
        // In production, require fields to be filled
        guard isPreviewMode || (!email.isEmpty && !password.isEmpty) else { return }
        
        isLoading = true
        hideError()
        
        // Preview mode bypass - simulate successful authentication
        if isPreviewMode {
            // Simulate loading delay
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // Set up mock user and authenticate
            await MainActor.run {
                setupPreviewUser()
                isLoading = false
            }
            return
        }
        
        do {
            // Create sign-in with email using modern API
            let signIn = try await SignIn.create(strategy: .identifier(email))
            try await signIn.attemptFirstFactor(strategy: .password(password: password))
            // The authentication state will be automatically updated via the onChange in PalyttApp
        } catch {
            showError("Failed to sign in: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    private func sendPhoneVerificationCode() async {
        // In preview mode, allow bypass even with empty phone number
        // In production, require phone number to be filled
        guard isPreviewMode || !phoneNumber.isEmpty else { return }
        
        isLoading = true
        hideError()
        
        // Preview mode bypass
        if isPreviewMode {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            await MainActor.run {
                isCodeSent = true
                isPasswordlessFlow = true
                startCountdown()
                isLoading = false
            }
            return
        }
        
        // Clean and validate phone number for Clerk (E.164 format)
        let cleanPhone = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        // Validate phone number length (US numbers should be 10 digits)
        guard cleanPhone.count == 10 else {
            showError("Please enter a valid 10-digit phone number")
            isLoading = false
            return
        }
        
        // Format as E.164 for US numbers
        let formattedPhone = "+1\(cleanPhone)"
        
        // Try to sign in first (for existing users)
        do {
            signIn = try await SignIn.create(strategy: .identifier(formattedPhone))
            
            // Check the status to see what's needed
            if signIn?.status == .needsFirstFactor {
                // Get the phone number ID from the available factors
                if let phoneNumberId = signIn?.supportedFirstFactors?.first(where: { 
                    $0.strategy == "phone_code" 
                })?.phoneNumberId {
                    // Prepare the phone code verification with the phone number ID
                    signIn = try await signIn!.prepareFirstFactor(
                        strategy: .phoneCode(phoneNumberId: phoneNumberId)
                    )
                    
                    await MainActor.run {
                        withAnimation {
                            isCodeSent = true
                            isPasswordlessFlow = true
                            isSigningUp = false
                        }
                        startCountdown()
                    }
                } else {
                    // Fallback: try phone sign-up if no phone code option
                    await attemptPhoneSignUp(formattedPhone: formattedPhone)
                }
            } else {
                await MainActor.run {
                    withAnimation {
                        isCodeSent = true
                        isPasswordlessFlow = true
                        isSigningUp = false
                    }
                    startCountdown()
                }
            }
        } catch {
            // If sign-in fails, phone number doesn't exist - user needs to sign up
            
            // Check if we need username and password for sign-up
            if username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty || !isPasswordValidForSignIn {
                await MainActor.run {
                    withAnimation {
                        needsUsername = true
                    }
                }
                isLoading = false
                return
            }
            
            // Username and password provided, proceed with sign-up
            await attemptPhoneSignUp(formattedPhone: formattedPhone)
        }
        
        isLoading = false
    }
    
    private func attemptPhoneSignUp(formattedPhone: String) async {
        do {
            // Create a sign-up using phone number, username, and password
            let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
            signUp = try await SignUp.create(strategy: .standard(
                password: password,
                username: trimmedUsername.isEmpty ? nil : trimmedUsername, 
                phoneNumber: formattedPhone
            ))
            
            // Prepare phone number verification for sign-up
            signUp = try await signUp!.prepareVerification(strategy: .phoneCode)
            
            await MainActor.run {
                withAnimation {
                    isCodeSent = true
                    isPasswordlessFlow = false // No longer passwordless
                    isSigningUp = true
                }
                startCountdown()
            }
        } catch {
            await MainActor.run {
                showError("Failed to send verification code: \(error.localizedDescription)")
            }
        }
    }
    
    private func verifyPhoneCode() async {
        guard verificationCode.count == 6 else { return }
        
        isLoading = true
        hideError()
        
        // Preview mode bypass
        if isPreviewMode {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            await MainActor.run {
                setupPreviewUser()
                isLoading = false
            }
            return
        }
        
        do {
            if isSigningUp {
                // Handle phone sign-up verification
                guard let signUp = signUp else { 
                    showError("Sign-up session not found. Please try again.")
                    isLoading = false
                    return 
                }
                
                // Verify the phone number for sign-up
                let signUpAttempt = try await signUp.attemptVerification(strategy: .phoneCode(code: verificationCode))
                
                switch signUpAttempt.status {
                case .complete:
                    // The authentication state will be automatically updated via the onChange in PalyttApp
                    break
                case .missingRequirements:
                    print("signUpAttempt: \(signUpAttempt)")
                    // User might need to provide additional information
                    showError("Additional information required. Please complete your profile.")
                default:
                    showError("Sign-up incomplete. Please try again.")
                }
            } else {
                // Handle sign-in verification
                guard let signIn = signIn else {
                    showError("Sign-in session not found. Please try again.")
                    isLoading = false
                    return
                }
                
                // Use the code provided by the user and attempt first factor verification
                let signInAttempt = try await signIn.attemptFirstFactor(strategy: .phoneCode(code: verificationCode))
                
                // Check if verification was completed
                switch signInAttempt.status {
                case .complete:
                    // The authentication state will be automatically updated via the onChange in PalyttApp
                    break
                default:
                    // If the status is not complete, check why. User may need to complete further steps.
                    showError("Sign-in incomplete. Please try again.")
                }
            }
        } catch {
            showError("Invalid verification code. Please try again.")
        }
        
        isLoading = false
    }
    
    private func resetPassword() async {
        guard !email.isEmpty else {
            showError("Please enter your email address first")
            return
        }
        
        do {
            let signIn = try await SignIn.create(strategy: .identifier(email))
            try await signIn.prepareFirstFactor(strategy: .resetPasswordEmailCode())
            showError("Password reset email sent to \(email)")
        } catch {
            showError("Failed to send reset email: \(error.localizedDescription)")
        }
    }
    
    private func signInWithApple() async {
        // Preview mode bypass
        if isPreviewMode {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            await MainActor.run {
                setupPreviewUser()
            }
            return
        }
        
        do {
            // Create an instance of the helper and get the Apple ID credential.
            let appleIdCredential = try await SignInWithAppleHelper.getAppleIdCredential()
            
            // Extract the ID token from the credential.
            guard let idToken = appleIdCredential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else {
                showError("Failed to get Apple ID token")
                return
            }
            
            // Authenticate with Clerk
            _ = try await SignIn.authenticateWithIdToken(provider: .apple, idToken: idToken)
            
            // After successful authentication, get the current user from Clerk
            guard let clerkUser = clerk.user else {
                showError("Authentication succeeded but user not found")
                return
            }
            
            // Get user information from Apple credential
            let appleUserId = appleIdCredential.user
            let email = appleIdCredential.email
            let firstName = appleIdCredential.fullName?.givenName
            let lastName = appleIdCredential.fullName?.familyName
            
            // Sync with backend using Apple ID
            await syncAppleUserWithBackend(
                clerkId: clerkUser.id,
                appleId: appleUserId,
                email: email,
                firstName: firstName,
                lastName: lastName
            )
            
        } catch {
            showError("Apple Sign In failed: \(error.localizedDescription)")
        }
    }
    
    private func syncAppleUserWithBackend(
        clerkId: String,
        appleId: String,
        email: String?,
        firstName: String?,
        lastName: String?
    ) async {
        do {
            let response = try await BackendService.shared.upsertUserByAppleId(
                appleId: appleId,
                clerkId: clerkId,
                email: email,
                firstName: firstName,
                lastName: lastName,
                username: nil
            )
            
            // Check if username is needed
            if response.needsUsername == true {
                // User needs to provide username
                await MainActor.run {
                    pendingAppleUser = PendingAppleUser(
                        clerkId: clerkId,
                        appleId: appleId,
                        email: email,
                        firstName: firstName,
                        lastName: lastName
                    )
                    showUsernamePrompt = true
                }
            } else {
                // Authentication is complete, the app state will update automatically
            }
        } catch {
            // Don't block sign in for backend issues
        }
    }
    
    private func completeAppleSignInWithUsername() async {
        guard let pendingUser = pendingAppleUser,
              !promptUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showError("Please enter a username")
            return
        }
        
        isLoading = true
        hideError()
        
        do {
            // Update user with username using BackendService
            let _ = try await BackendService.shared.upsertUserByAppleId(
                appleId: pendingUser.appleId,
                clerkId: pendingUser.clerkId,
                email: pendingUser.email,
                firstName: pendingUser.firstName,
                lastName: pendingUser.lastName,
                username: promptUsername.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
            await MainActor.run {
                // Clear pending state
                pendingAppleUser = nil
                showUsernamePrompt = false
                promptUsername = ""
                isLoading = false
            }
            
            // Authentication is now complete
        } catch {
            showError("Failed to save username: \(error.localizedDescription)")
            isLoading = false
        }
    }
    
    private func signInWithGoogle() async {
        // Preview mode bypass
        if isPreviewMode {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            await MainActor.run {
                setupPreviewUser()
            }
            return
        }
        
        do {
            // Clerk supports Google Sign In via OAuth redirect
            try await SignIn.authenticateWithRedirect(strategy: .oauth(provider: .google))
        } catch {
            showError("Google Sign In failed: \(error.localizedDescription)")
        }
    }
    
    private func startCountdown() {
        countdown = 60
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if countdown > 0 {
                countdown -= 1
            } else {
                timer?.invalidate()
                timer = nil
            }
        }
    }
    
    private func showError(_ message: String) {
        // Add haptic feedback for errors
        HapticManager.shared.impact(.light)
        
        errorMessage = message
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showError = true
        }
        
        // Auto-hide error after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            hideError()
        }
    }
    
    private func hideError() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showError = false
        }
    }
    
    private func setupPreviewUser() {
        // Add success haptic feedback
        HapticManager.shared.impact(.success)
        
        appState.isAuthenticated = true
        
        // Use email or phone for contact info
        let contactEmail = email.isEmpty ? "preview@palytt.com" : email
        let displayUsername = username.isEmpty ? "previewuser" : username
        let displayName = "Preview User"
        
        appState.currentUser = User(
            id: UUID(),
            email: contactEmail,
            username: displayUsername,
            displayName: displayName
        )
    }
}

// MARK: - Clerk Sign Up View
struct ClerkSignUpView: View {
    @Environment(Clerk.self) var clerk
    @EnvironmentObject var appState: AppState
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phoneNumber = ""
    @State private var verificationCode = ""
    @State private var isLoading = false
    @State private var signUpMethod: SignUpMethod = .email
    @State private var isCodeSent = false
    @State private var countdown = 0
    @State private var timer: Timer?

    @State private var errorMessage = ""
    @State private var showError = false
    @State private var showPasswordRequirements = false
    
    // Keyboard and focus management
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case firstName, lastName, username, email, password, phoneNumber, verificationCode
    }
    
    // Check if we're running in preview mode
    private var isPreviewMode: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    private var isPhoneNumberValid: Bool {
        let cleanPhone = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return cleanPhone.count == 10
    }
    
    private var isPasswordValidForSignIn: Bool {
        password.count >= 8 &&
        password.range(of: "[a-z]", options: .regularExpression) != nil &&
        password.range(of: "[A-Z]", options: .regularExpression) != nil &&
        password.range(of: "[0-9]", options: .regularExpression) != nil
    }
    
    enum SignUpMethod {
        case email, phone
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Error Message
                if showError {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 16, weight: .medium))
                        
                        Text(errorMessage)
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        
                        Button(action: hideError) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red.opacity(0.6))
                                .font(.system(size: 18))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.red.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                    ))
                }
                
                // Sign Up Method Selector
                HStack(spacing: 12) {
                    Button(action: { 
                        withAnimation(.easeInOut(duration: 0.3)) {
                            signUpMethod = .email
                            resetState()
                            focusedField = nil
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 16))
                            Text("Email")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(
                            signUpMethod == .email ? 
                            Color.primaryBrand : Color.clear
                        )
                        .foregroundColor(
                            signUpMethod == .email ? .white : .secondaryText
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    signUpMethod == .email ? Color.clear : Color.gray.opacity(0.3),
                                    lineWidth: 1
                                )
                        )
                        .cornerRadius(12)
                        .shadow(
                            color: signUpMethod == .email ? Color.primaryBrand.opacity(0.3) : Color.clear,
                            radius: 4,
                            x: 0,
                            y: 2
                        )
                    }
                    
                    Button(action: { 
                        withAnimation(.easeInOut(duration: 0.3)) {
                            signUpMethod = .phone
                            resetState()
                            focusedField = nil
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 16))
                            Text("Phone")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(
                            signUpMethod == .phone ? 
                            Color.primaryBrand : Color.clear
                        )
                        .foregroundColor(
                            signUpMethod == .phone ? .white : .secondaryText
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    signUpMethod == .phone ? Color.clear : Color.gray.opacity(0.3),
                                    lineWidth: 1
                                )
                        )
                        .cornerRadius(12)
                        .shadow(
                            color: signUpMethod == .phone ? Color.primaryBrand.opacity(0.3) : Color.clear,
                            radius: 4,
                            x: 0,
                            y: 2
                        )
                    }
                }
                
                if signUpMethod == .email {
                    EmailSignUpForm()
                } else {
                    PhoneSignUpForm()
                }
                
                // Terms
                HStack(spacing: 0) {
                    Text("By signing up, you agree to our ")
                        .font(.caption2)
                        .foregroundColor(.warmAccentText)
                    
                    NavigationLink(destination: TermsOfServiceView()) {
                        Text("Terms of Service")
                            .font(.caption2)
                            .foregroundColor(.primaryBrand)
                            .underline()
                    }
                    
                    Text(" and ")
                        .font(.caption2)
                        .foregroundColor(.warmAccentText)
                    
                    NavigationLink(destination: PrivacyPolicyView()) {
                        Text("Privacy Policy")
                            .font(.caption2)
                            .foregroundColor(.primaryBrand)
                            .underline()
                    }
                    
                    Text(". Please review our ")
                        .font(.caption2)
                        .foregroundColor(.warmAccentText)
                    
                    NavigationLink(destination: DisclaimerView()) {
                        Text("Disclaimer")
                            .font(.caption2)
                            .foregroundColor(.primaryBrand)
                            .underline()
                    }
                    
                    Text(" for important usage information.")
                        .font(.caption2)
                        .foregroundColor(.warmAccentText)
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture {
            // Dismiss keyboard when tapping outside
            focusedField = nil
        }
        .onDisappear {
            // Clean up timer when view disappears
            timer?.invalidate()
            timer = nil
        }
    }
    
    @ViewBuilder
    private func EmailSignUpForm() -> some View {
        VStack(spacing: 16) {
            if !isCodeSent {
                // Name Fields
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("First Name")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                            
                            if !firstName.isEmpty {
                                Image(systemName: isFirstNameValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(isFirstNameValid ? .green : .red)
                            }
                        }
                        
                        TextField("First name", text: $firstName)
                            .textFieldStyle(.plain)
                            .focused($focusedField, equals: .firstName)
                            #if os(iOS)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.next)
                            #endif
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        !firstName.isEmpty && !isFirstNameValid ? Color.red.opacity(0.5) : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                            .onSubmit {
                                focusedField = .lastName
                            }
                        
                        if !firstName.isEmpty && !isFirstNameValid {
                            Text("Name must be 2-50 letters only")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Last Name")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                            
                            if !lastName.isEmpty {
                                Image(systemName: isLastNameValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(isLastNameValid ? .green : .red)
                            }
                        }
                        
                        TextField("Last name", text: $lastName)
                            .textFieldStyle(.plain)
                            .focused($focusedField, equals: .lastName)
                            #if os(iOS)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.next)
                            #endif
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        !lastName.isEmpty && !isLastNameValid ? Color.red.opacity(0.5) : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                            .onSubmit {
                                focusedField = .username
                            }
                        
                        if !lastName.isEmpty && !isLastNameValid {
                            Text("Name must be 2-50 letters only")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                // Username Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Username")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    
                    TextField("Choose a username", text: $username)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .username)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .submitLabel(.next)
                        #endif
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .onSubmit {
                            focusedField = .email
                        }
                }
                
                // Email Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    
                    TextField("Enter your email", text: $email)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .email)
                        #if os(iOS)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .submitLabel(.next)
                        #endif
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .onSubmit {
                            focusedField = .password
                        }
                }
                
                // Password Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    
                    SecureField("Create a password", text: $password)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .password)
                        #if os(iOS)
                        .submitLabel(.done)
                        #endif
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .onTapGesture {
                            showPasswordRequirements = true
                            focusedField = .password
                        }
                        .onChange(of: password) { _, _ in
                            if !password.isEmpty {
                                showPasswordRequirements = true
                            }
                        }
                        .onChange(of: focusedField) { _, newValue in
                            if newValue == .password {
                                showPasswordRequirements = true
                            }
                        }
                        .onSubmit {
                            focusedField = nil
                        }
                    
                    // Password Requirements
                    if showPasswordRequirements {
                        VStack(alignment: .leading, spacing: 4) {
                            PasswordRequirementRow(
                                text: "8+ characters minimum length",
                                isValid: password.count >= 8
                            )
                            PasswordRequirementRow(
                                text: "1 lowercase letter (a-z)",
                                isValid: password.range(of: "[a-z]", options: .regularExpression) != nil
                            )
                            PasswordRequirementRow(
                                text: "1 uppercase letter (A-Z)",
                                isValid: password.range(of: "[A-Z]", options: .regularExpression) != nil
                            )
                            PasswordRequirementRow(
                                text: "1 number (0-9)",
                                isValid: password.range(of: "[0-9]", options: .regularExpression) != nil
                            )
                        }
                        .padding(.top, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                
                // Sign Up Button
                Button(action: {
                    Task {
                        await signUpWithEmail()
                    }
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Text("Create Account")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(Color.primaryBrand)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                .disabled(isLoading || (!isPreviewMode && !isEmailSignUpFormValid))
                .opacity(isLoading || (!isPreviewMode && !isEmailSignUpFormValid) ? 0.6 : 1)
            } else {
                // Email Verification Code Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Verification Code")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    
                    TextField("Enter 6-digit code", text: $verificationCode)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .verificationCode)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        .textInputAutocapitalization(.never)
                        .submitLabel(.done)
                        #endif
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .onChange(of: verificationCode) { _, newValue in
                            if newValue.count > 6 {
                                verificationCode = String(newValue.prefix(6))
                            }
                            if newValue.count == 6 {
                                focusedField = nil
                            }
                        }
                        .onSubmit {
                            focusedField = nil
                        }
                }
                
                // Code sent message
                HStack {
                    Text("Verification email sent to \(email)")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    
                    Spacer()
                    
                    if countdown > 0 {
                        Text("Resend in \(countdown)s")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    } else {
                        Button("Resend Email") {
                            Task {
                                await resendEmailVerification()
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.primaryBrand)
                    }
                }
                .padding(.top, -8)
                
                // Verify & Create Account Button
                Button(action: {
                    Task {
                        await verifyEmailAndCompleteSignUp()
                    }
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Text("Verify & Complete")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(Color.primaryBrand)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                .disabled(isLoading || verificationCode.count != 6)
                .opacity(isLoading || verificationCode.count != 6 ? 0.6 : 1)
                
                // Back button
                Button("← Change Email") {
                    withAnimation {
                        resetState()
                    }
                }
                .font(.caption)
                .foregroundColor(.primaryBrand)
            }
        }
    }
    
    @ViewBuilder
    private func PhoneSignUpForm() -> some View {
        VStack(spacing: 16) {
            if !isCodeSent {
                // Name Fields (same as email signup)
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("First Name")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                            
                            if !firstName.isEmpty {
                                Image(systemName: isFirstNameValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(isFirstNameValid ? .green : .red)
                            }
                        }
                        
                        TextField("First name", text: $firstName)
                            .textFieldStyle(.plain)
                            .focused($focusedField, equals: .firstName)
                            #if os(iOS)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.next)
                            #endif
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                            .onSubmit {
                                focusedField = .lastName
                            }
                        
                        if !firstName.isEmpty && !isFirstNameValid {
                            Text("Name must be 2-50 letters only")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Last Name")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                            
                            if !lastName.isEmpty {
                                Image(systemName: isLastNameValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(isLastNameValid ? .green : .red)
                            }
                        }
                        
                        TextField("Last name", text: $lastName)
                            .textFieldStyle(.plain)
                            .focused($focusedField, equals: .lastName)
                            #if os(iOS)
                            .submitLabel(.next)
                            #endif
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                            .onSubmit {
                                focusedField = .username
                            }
                    }
                }
                
                // Username Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Username")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    
                    TextField("Choose a username", text: $username)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .username)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .submitLabel(.next)
                        #endif
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .onSubmit {
                            focusedField = .phoneNumber
                        }
                }
                
                // Phone Number Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Phone Number")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    
                    TextField("(555) 123-4567", text: $phoneNumber)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .phoneNumber)
                        #if os(iOS)
                        .keyboardType(.phonePad)
                        .submitLabel(.next)
                        #endif
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .onSubmit {
                            focusedField = .password
                        }
                    
                    if !phoneNumber.isEmpty && !isPhoneNumberValid {
                        Text("Please enter a valid 10-digit US phone number")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
                
                // Password Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    
                    SecureField("Create a password", text: $password)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .password)
                        #if os(iOS)
                        .submitLabel(.done)
                        #endif
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .onTapGesture {
                            showPasswordRequirements = true
                            focusedField = .password
                        }
                        .onChange(of: password) { _, _ in
                            if !password.isEmpty {
                                showPasswordRequirements = true
                            }
                        }
                        .onChange(of: focusedField) { _, newValue in
                            if newValue == .password {
                                showPasswordRequirements = true
                            }
                        }
                        .onSubmit {
                            focusedField = nil
                        }
                    
                    // Password Requirements
                    if showPasswordRequirements {
                        VStack(alignment: .leading, spacing: 4) {
                            PasswordRequirementRow(
                                text: "8+ characters minimum length",
                                isValid: password.count >= 8
                            )
                            PasswordRequirementRow(
                                text: "1 lowercase letter (a-z)",
                                isValid: password.range(of: "[a-z]", options: .regularExpression) != nil
                            )
                            PasswordRequirementRow(
                                text: "1 uppercase letter (A-Z)",
                                isValid: password.range(of: "[A-Z]", options: .regularExpression) != nil
                            )
                            PasswordRequirementRow(
                                text: "1 number (0-9)",
                                isValid: password.range(of: "[0-9]", options: .regularExpression) != nil
                            )
                        }
                        .padding(.top, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                
                // Create Account Button
                Button(action: {
                    Task {
                        await signUpWithPhone()
                    }
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Text("Create Account")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(Color.primaryBrand)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                .disabled(isLoading || (!isPreviewMode && !isPhoneSignUpFormValid))
                .opacity(isLoading || (!isPreviewMode && !isPhoneSignUpFormValid) ? 0.6 : 1)
            } else {
                // Phone Verification Code Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Verification Code")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    
                    TextField("Enter 6-digit code", text: $verificationCode)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .verificationCode)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        .textInputAutocapitalization(.never)
                        .submitLabel(.done)
                        #endif
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .onChange(of: verificationCode) { _, newValue in
                            if newValue.count > 6 {
                                verificationCode = String(newValue.prefix(6))
                            }
                            if newValue.count == 6 {
                                focusedField = nil
                            }
                        }
                        .onSubmit {
                            focusedField = nil
                        }
                }
                
                // Code sent message
                HStack {
                    Text("Verification code sent to \(phoneNumber)")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    
                    Spacer()
                    
                    if countdown > 0 {
                        Text("Resend in \(countdown)s")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    } else {
                        Button("Resend Code") {
                            Task {
                                await resendPhoneVerification()
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.primaryBrand)
                    }
                }
                .padding(.top, -8)
                
                // Verify & Create Account Button
                Button(action: {
                    Task {
                        await verifyPhoneAndCompleteSignUp()
                    }
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Text("Verify & Complete")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(Color.primaryBrand)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                .disabled(isLoading || verificationCode.count != 6)
                .opacity(isLoading || verificationCode.count != 6 ? 0.6 : 1)
                
                // Back button
                Button("← Change Phone Number") {
                    withAnimation {
                        resetState()
                    }
                }
                .font(.caption)
                .foregroundColor(.primaryBrand)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var isEmailSignUpFormValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.isEmpty &&
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !username.trimmingCharacters(in: .whitespaces).isEmpty &&
        isPasswordValid &&
        isFirstNameValid &&
        isLastNameValid
    }
    
    private var isPhoneSignUpFormValid: Bool {
        isPhoneNumberValid &&
        !password.isEmpty &&
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !username.trimmingCharacters(in: .whitespaces).isEmpty &&
        isPasswordValid &&
        isFirstNameValid &&
        isLastNameValid
    }
    

    
    private var isPasswordValid: Bool {
        password.count >= 8 &&
        password.range(of: "[a-z]", options: .regularExpression) != nil &&
        password.range(of: "[A-Z]", options: .regularExpression) != nil &&
        password.range(of: "[0-9]", options: .regularExpression) != nil
    }
    
    private var isFirstNameValid: Bool {
        let trimmed = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 2 && 
               trimmed.count <= 50 &&
               trimmed.allSatisfy { $0.isLetter || $0.isWhitespace }
    }
    
    private var isLastNameValid: Bool {
        let trimmed = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 2 && 
               trimmed.count <= 50 &&
               trimmed.allSatisfy { $0.isLetter || $0.isWhitespace }
    }
    
    // MARK: - Authentication Methods
    
    private func syncUserWithBackend(
        email: String,
        firstName: String,
        lastName: String, 
        username: String,
        clerkId: String
    ) async {
        do {
            print("🔄 Starting backend user sync for Clerk ID: \(clerkId)")
            
            // Values are already sanitized before calling this method
            let finalFirstName = firstName.isEmpty ? nil : firstName
            let finalLastName = lastName.isEmpty ? nil : lastName
            let finalUsername = username.isEmpty ? nil : username
            let finalEmail = email.isEmpty ? nil : email
            
            // Use BackendService to sync user
            let result = try await BackendService.shared.upsertUser(
                email: finalEmail,
                firstName: finalFirstName,
                lastName: finalLastName,
                username: finalUsername,
                avatarUrl: nil,
                clerkId: clerkId,
                appleId: nil
            )
            
            print("✅ Backend user sync successful: \(result)")
        } catch {
            // Don't show error to user as this is non-critical for authentication flow
            print("⚠️ Backend user sync failed (non-blocking): \(error.localizedDescription)")
        }
    }
    
    private func signUpWithEmail() async {
        // In preview mode, allow bypass even with invalid form
        // In production, require valid form data
        guard isPreviewMode || isEmailSignUpFormValid else { return }
        
        isLoading = true
        hideError()
        
        // Preview mode bypass - simulate successful authentication
        if isPreviewMode {
            // Simulate loading delay
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // Set up mock user and authenticate
            await MainActor.run {
                setupPreviewUser()
                isLoading = false
            }
            return
        }
        
        do {
            // Sanitize input data
            let sanitizedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
            let sanitizedLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
            let sanitizedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Create SignUp with email and all user data using the official Clerk iOS SDK pattern
            var signUp = try await SignUp.create(
                strategy: .standard(
                    emailAddress: email,
                    password: password,
                    firstName: sanitizedFirstName.isEmpty ? nil : sanitizedFirstName,
                    lastName: sanitizedLastName.isEmpty ? nil : sanitizedLastName,
                    username: sanitizedUsername.isEmpty ? nil : sanitizedUsername
                )
            )
            
            // Check if the SignUp needs the email address verified and send an OTP code via email
            if signUp.unverifiedFields.contains("email_address") {
                signUp = try await signUp.prepareVerification(strategy: .emailCode)
            }
            
            withAnimation {
                isCodeSent = true
            }
            startCountdown()
        } catch {
            showError("Failed to create account: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    private func verifyEmailAndCompleteSignUp() async {
        guard verificationCode.count == 6 else { return }
        
        isLoading = true
        hideError()
        
        do {
            // Access the in progress sign up stored on the client object
            guard let inProgressSignUp = clerk.client?.signUp else {
                showError("Session expired. Please start over.")
                resetState()
                isLoading = false
                return
            }
            
            // Use the code provided by the user and attempt verification
            let completedSignUp = try await inProgressSignUp.attemptVerification(strategy: .emailCode(code: verificationCode))
            
            // Check if the signup was truly completed
            if completedSignUp.status == .complete {
                // Send user data to backend using form data (already sanitized during signup creation)
                let userClerkId = completedSignUp.createdUserId ?? completedSignUp.id
                let sanitizedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
                let sanitizedLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
                let sanitizedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
                
                await syncUserWithBackend(
                    email: email,
                    firstName: sanitizedFirstName,
                    lastName: sanitizedLastName,
                    username: sanitizedUsername,
                    clerkId: userClerkId
                )
                
                // Signup completed successfully - the authentication state will be automatically updated via the onChange in PalyttApp
            } else {
                // Handle different signup statuses more specifically
                switch completedSignUp.status {
                case .missingRequirements:
                    print("completedSignUp: \(completedSignUp)")
                    showError("Additional information required. Please complete your profile.")
                case .abandoned:
                    showError("Signup session expired. Please start over.")
                    resetState()
                default:
                    showError("Verification successful but signup incomplete. Please try signing in.")
                }
                isLoading = false
                return
            }
            
        } catch {
            let errorMessage = error.localizedDescription
            if errorMessage.contains("verification") || errorMessage.contains("code") {
                showError("Invalid verification code. Please try again.")
            } else {
                showError("Verification failed: \(errorMessage)")
            }
            isLoading = false
            return
        }
        
        isLoading = false
    }
    
    private func resendEmailVerification() async {
        do {
            // Access the in progress sign up stored on the client object
            guard let inProgressSignUp = clerk.client?.signUp else {
                showError("Session expired. Please start over.")
                resetState()
                return
            }
            
            // Prepare verification again to resend the email
            try await inProgressSignUp.prepareVerification(strategy: .emailCode)
            startCountdown()
        } catch {
            showError("Failed to resend verification email: \(error.localizedDescription)")
        }
    }
    
    private func signUpWithPhone() async {
        // In preview mode, allow bypass even with invalid form
        // In production, require valid form data
        guard isPreviewMode || isPhoneSignUpFormValid else { return }
        
        isLoading = true
        hideError()
        
        // Preview mode bypass - simulate successful authentication
        if isPreviewMode {
            // Simulate loading delay
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // Set up mock user and authenticate
            await MainActor.run {
                setupPreviewUser()
                isLoading = false
            }
            return
        }
        
        do {
            // Clean and validate phone number for Clerk (E.164 format)
            let cleanPhone = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            
            // Validate phone number length (US numbers should be 10 digits)
            guard cleanPhone.count == 10 else {
                showError("Please enter a valid 10-digit phone number")
                isLoading = false
                return
            }
            
            // Format as E.164 for US numbers
            let formattedPhone = "+1\(cleanPhone)"
            
            // Sanitize input data
            let sanitizedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
            let sanitizedLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
            let sanitizedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Create SignUp with phone number and all user data using the official Clerk iOS SDK pattern
            var signUp = try await SignUp.create(
                strategy: .standard(
                    password: password,
                    firstName: sanitizedFirstName.isEmpty ? nil : sanitizedFirstName,
                    lastName: sanitizedLastName.isEmpty ? nil : sanitizedLastName,
                    username: sanitizedUsername.isEmpty ? nil : sanitizedUsername,
                    phoneNumber: formattedPhone
                )
            )
            
            // Check if the SignUp needs the phone number verified and send an OTP code via SMS
            if signUp.unverifiedFields.contains("phone_number") {
                signUp = try await signUp.prepareVerification(strategy: .phoneCode)
            }
            
            withAnimation {
                isCodeSent = true
            }
            startCountdown()
        } catch {
            showError("Failed to create account: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    private func verifyPhoneAndCompleteSignUp() async {
        guard verificationCode.count == 6 else { return }
        
        isLoading = true
        hideError()
        
        // Preview mode bypass
        if isPreviewMode {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            await MainActor.run {
                setupPreviewUser()
                isLoading = false
            }
            return
        }
        
        do {
            // Access the in progress sign up stored on the client object
            guard let inProgressSignUp = clerk.client?.signUp else {
                showError("Session expired. Please start over.")
                resetState()
                isLoading = false
                return
            }
            
            // Use the code provided by the user and attempt verification
            let signUp = try await inProgressSignUp.attemptVerification(strategy: .phoneCode(code: verificationCode))
            
            // Send user data to backend if signup is complete (profile already set during creation)
            if signUp.status == .complete {
                // Send user data to backend using form data (already sanitized during signup creation)
                let userClerkId = signUp.createdUserId ?? signUp.id
                let sanitizedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
                let sanitizedLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
                let sanitizedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
                
                await syncUserWithBackend(
                    email: "", // No email for phone signup
                    firstName: sanitizedFirstName,
                    lastName: sanitizedLastName,
                    username: sanitizedUsername,
                    clerkId: userClerkId
                )
                
                // Signup completed successfully - the authentication state will be automatically updated via the onChange in PalyttApp
            } else {
                // Handle different signup statuses more specifically
                switch signUp.status {
                case .missingRequirements:
                    print("signUp: \(signUp)")
                    showError("Additional information required. Please complete your profile.")
                case .abandoned:
                    showError("Signup session expired. Please start over.")
                    resetState()
                default:
                    showError("Verification successful but signup incomplete. Please try signing in.")
                }
                isLoading = false
                return
            }
            
        } catch {
            let errorMessage = error.localizedDescription
            if errorMessage.contains("verification") || errorMessage.contains("code") {
                showError("Invalid verification code. Please try again.")
            } else {
                showError("Verification failed: \(errorMessage)")
            }
            isLoading = false
            return
        }
        
        isLoading = false
    }
    
    private func resendPhoneVerification() async {
        do {
            // Access the in progress sign up stored on the client object
            guard let inProgressSignUp = clerk.client?.signUp else {
                showError("Session expired. Please start over.")
                resetState()
                return
            }
            
            // Prepare verification again to resend the SMS
            try await inProgressSignUp.prepareVerification(strategy: .phoneCode)
            startCountdown()
        } catch {
            showError("Failed to resend verification code: \(error.localizedDescription)")
        }
    }
    
    private func resetState() {
        isCodeSent = false
        verificationCode = ""
        countdown = 0
        timer?.invalidate()
        timer = nil
        hideError()
    }
    
    private func startCountdown() {
        countdown = 60
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if countdown > 0 {
                countdown -= 1
            } else {
                timer?.invalidate()
                timer = nil
            }
        }
    }
    
    private func showError(_ message: String) {
        // Add haptic feedback for errors
        HapticManager.shared.impact(.light)
        
        errorMessage = message
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showError = true
        }
        
        // Auto-hide error after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            hideError()
        }
    }
    
    private func hideError() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showError = false
        }
    }
    
    private func formatPhoneNumber(_ number: String) -> String {
        // Remove all non-numeric characters
        let cleaned = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        // Limit to 10 digits
        let limited = String(cleaned.prefix(10))
        
        // Format as (XXX) XXX-XXXX
        if limited.count >= 6 {
            let areaCode = String(limited.prefix(3))
            let middle = String(limited.dropFirst(3).prefix(3))
            let last = String(limited.dropFirst(6))
            return "(\(areaCode)) \(middle)-\(last)"
        } else if limited.count >= 3 {
            let areaCode = String(limited.prefix(3))
            let remaining = String(limited.dropFirst(3))
            return "(\(areaCode)) \(remaining)"
        } else if !limited.isEmpty {
            return limited
        }
        
        return ""
    }
    
    private func setupPreviewUser() {
        // Add success haptic feedback
        HapticManager.shared.impact(.success)
        
        appState.isAuthenticated = true
        
        // Use email or phone for contact info
        let contactEmail = email.isEmpty ? "preview@palytt.com" : email
        let displayUsername = username.isEmpty ? "previewuser" : username
        let displayName = firstName.isEmpty && lastName.isEmpty ? 
            "Preview User" : "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        
        appState.currentUser = User(
            id: UUID(),
            email: contactEmail,
            username: displayUsername,
            displayName: displayName
        )
    }
}

// MARK: - Helper Views

struct PasswordRequirementRow: View {
    let text: String
    let isValid: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isValid ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 12))
                .foregroundColor(isValid ? .primaryBrand : .tertiaryText)
            
            Text(text)
                .font(.caption2)
                .foregroundColor(isValid ? .primaryBrand : .tertiaryText)
            
            Spacer()
        }
        .animation(.easeInOut(duration: 0.2), value: isValid)
    }
}

// MARK: - Username Prompt View for Apple Sign In

struct UsernamePromptView: View {
    @Binding var username: String
    @Binding var isLoading: Bool
    let onComplete: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }
            
            // Prompt card
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    // Icon
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.primaryBrand)
                    
                    // Title
                    Text("Choose Your Username")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primaryText)
                    
                    // Description
                    Text("We need a username to complete your profile")
                        .font(.body)
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.center)
                }
                
                // Username field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Username")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    
                    TextField("Enter username", text: $username)
                        .textFieldStyle(.plain)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primaryBrand.opacity(0.3), lineWidth: 1)
                        )
                }
                
                // Buttons
                HStack(spacing: 12) {
                    // Cancel button
                    Button("Cancel") {
                        onCancel()
                    }
                    .font(.headline)
                    .foregroundColor(.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Complete button
                    Button(action: onComplete) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text("Complete")
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.primaryBrand)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(isLoading || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1)
                }
            }
            .padding(24)
            .background(Color.background)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 32)
        }
        .animation(.easeInOut(duration: 0.3), value: isLoading)
    }
}

#Preview("Username Prompt") {
    UsernamePromptView(
        username: .constant(""),
        isLoading: .constant(false),
        onComplete: {},
        onCancel: {}
    )
}

#Preview {
    // Create a configured Clerk instance for preview
    let previewClerk = Clerk.shared
    previewClerk.configure(publishableKey: "pk_test_bmF0dXJhbC13YWxsZXllLTQ4LmNsZXJrLmFjY291bnRzLmRldiQ")
    
    return     AuthenticationView()
        .environmentObject(MockAppState())
        .environment(previewClerk)
} 
