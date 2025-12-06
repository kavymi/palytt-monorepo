//
//  UnifiedAuthView.swift
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

// MARK: - Unified Auth View

struct UnifiedAuthView: View {
    @Environment(Clerk.self) var clerk
    @EnvironmentObject var appState: AppState
    
    // Phone state
    @State private var phoneNumber = ""
    @State private var verificationCode = ""
    @State private var isCodeSent = false
    @State private var countdown = 0
    @State private var timer: Timer?
    
    // Sign in/up state
    @State private var signIn: SignIn?
    @State private var signUp: SignUp?
    @State private var isSigningUp = false
    @State private var needsUsername = false
    @State private var username = ""
    @State private var password = ""
    @State private var showPasswordRequirements = false
    
    // UI state
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    // Animation state
    @State private var contentOpacity: Double = 0
    @State private var contentOffset: CGFloat = 20
    
    // Check if we're running in preview mode
    private var isPreviewMode: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    private var isPhoneNumberValid: Bool {
        let cleanPhone = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return cleanPhone.count == 10
    }
    
    private var isPasswordValid: Bool {
        password.count >= 8 &&
        password.range(of: "[a-z]", options: .regularExpression) != nil &&
        password.range(of: "[A-Z]", options: .regularExpression) != nil &&
        password.range(of: "[0-9]", options: .regularExpression) != nil
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.lightBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    // Header with logo
                    headerSection
                    
                    // Error message
                    if showError {
                        errorBanner
                    }
                    
                    // Main auth content
                    if !isCodeSent {
                        phoneInputSection
                    } else {
                        verificationSection
                    }
                    
                    // Social sign-in options
                    if !isCodeSent && !needsUsername {
                        socialSignInSection
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 40)
            }
            .opacity(contentOpacity)
            .offset(y: contentOffset)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                contentOpacity = 1
                contentOffset = 0
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image("palytt-logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
            
            VStack(spacing: 8) {
                Text(isCodeSent ? "Verify Your Phone" : "Welcome Back")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
                
                Text(isCodeSent 
                     ? "Enter the code we sent to \(phoneNumber)"
                     : "Enter your phone number to continue")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Error Banner
    
    private var errorBanner: some View {
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
    
    // MARK: - Phone Input Section
    
    private var phoneInputSection: some View {
        VStack(spacing: 20) {
            // Phone Number Field
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Phone Number")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondaryText)
                    
                    Spacer()
                    
                    if !phoneNumber.isEmpty {
                        Image(systemName: isPhoneNumberValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(isPhoneNumberValid ? .green : .red)
                    }
                }
                
                HStack(spacing: 12) {
                    // Country code
                    Text("🇺🇸 +1")
                        .font(.body)
                        .foregroundColor(.primaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 16)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    
                    // Phone input
                    TextField("(555) 555-5555", text: $phoneNumber)
                        .font(.body)
                        #if os(iOS)
                        .keyboardType(.phonePad)
                        #endif
                        .padding()
                        .background(Color.gray.opacity(0.1))
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
                }
            }
            
            // Username field (for new users)
            if needsUsername {
                newUserFields
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Continue Button
            Button(action: {
                HapticManager.shared.impact(.medium)
                Task {
                    await sendVerificationCode()
                }
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Text(needsUsername ? "Create Account" : "Continue")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(canContinue ? LinearGradient.primaryGradient : LinearGradient(colors: [Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
                )
                .foregroundColor(.white)
            }
            .disabled(!canContinue || isLoading)
            .animation(.easeInOut(duration: 0.2), value: canContinue)
        }
    }
    
    private var canContinue: Bool {
        if needsUsername {
            return isPhoneNumberValid && 
                   !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && 
                   isPasswordValid
        }
        return isPhoneNumberValid
    }
    
    // MARK: - New User Fields
    
    private var newUserFields: some View {
        VStack(spacing: 16) {
            // Divider with message
            HStack {
                Rectangle()
                    .fill(Color.divider)
                    .frame(height: 1)
                
                Text("New user? Complete your profile")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                    .fixedSize()
                
                Rectangle()
                    .fill(Color.divider)
                    .frame(height: 1)
            }
            
            // Username Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Username")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondaryText)
                
                TextField("Choose a username", text: $username)
                    .font(.body)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    #endif
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
            }
            
            // Password Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondaryText)
                
                SecureField("Create a password", text: $password)
                    .font(.body)
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
                
                // Password requirements
                if showPasswordRequirements {
                    VStack(alignment: .leading, spacing: 4) {
                        PasswordRequirementRow(text: "8+ characters", isValid: password.count >= 8)
                        PasswordRequirementRow(text: "1 lowercase (a-z)", isValid: password.range(of: "[a-z]", options: .regularExpression) != nil)
                        PasswordRequirementRow(text: "1 uppercase (A-Z)", isValid: password.range(of: "[A-Z]", options: .regularExpression) != nil)
                        PasswordRequirementRow(text: "1 number (0-9)", isValid: password.range(of: "[0-9]", options: .regularExpression) != nil)
                    }
                    .padding(.top, 4)
                }
            }
        }
    }
    
    // MARK: - Verification Section
    
    private var verificationSection: some View {
        VStack(spacing: 20) {
            // Status indicator
            HStack(spacing: 8) {
                Image(systemName: isSigningUp ? "person.badge.plus" : "person.crop.circle.badge.checkmark")
                    .font(.system(size: 14))
                    .foregroundColor(.primaryBrand)
                
                Text(isSigningUp ? "Creating new account" : "Signing into existing account")
                    .font(.caption)
                    .foregroundColor(.primaryBrand)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.primaryBrand.opacity(0.1))
            )
            
            // Verification Code Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Verification Code")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondaryText)
                
                TextField("000000", text: $verificationCode)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(16)
                    .onChange(of: verificationCode) { _, newValue in
                        if newValue.count > 6 {
                            verificationCode = String(newValue.prefix(6))
                        }
                    }
            }
            
            // Resend code option
            HStack {
                if countdown > 0 {
                    Text("Resend code in \(countdown)s")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                } else {
                    Button("Resend Code") {
                        Task {
                            await sendVerificationCode()
                        }
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primaryBrand)
                }
            }
            
            // Verify Button
            Button(action: {
                HapticManager.shared.impact(.medium)
                Task {
                    await verifyCode()
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
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(verificationCode.count == 6 ? LinearGradient.primaryGradient : LinearGradient(colors: [Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
                )
                .foregroundColor(.white)
            }
            .disabled(verificationCode.count != 6 || isLoading)
            
            // Change phone number
            Button("← Change Phone Number") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    resetState()
                }
            }
            .font(.subheadline)
            .foregroundColor(.secondaryText)
        }
    }
    
    // MARK: - Social Sign In Section
    
    private var socialSignInSection: some View {
        VStack(spacing: 16) {
            // Divider
            HStack {
                Rectangle()
                    .fill(Color.divider)
                    .frame(height: 1)
                
                Text("or continue with")
                    .font(.caption)
                    .foregroundColor(.tertiaryText)
                
                Rectangle()
                    .fill(Color.divider)
                    .frame(height: 1)
            }
            
            // Social buttons
            HStack(spacing: 16) {
                // Apple Sign In
                Button(action: {
                    HapticManager.shared.impact(.medium)
                    Task {
                        await signInWithApple()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 18, weight: .medium))
                        Text("Apple")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.gray.opacity(0.1))
                    .foregroundColor(.primaryText)
                    .cornerRadius(12)
                }
                
                // Google Sign In
                Button(action: {
                    HapticManager.shared.impact(.medium)
                    Task {
                        await signInWithGoogle()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "g.circle.fill")
                            .font(.system(size: 18, weight: .medium))
                        Text("Google")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.gray.opacity(0.1))
                    .foregroundColor(.primaryText)
                    .cornerRadius(12)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatPhoneNumber(_ number: String) -> String {
        let cleaned = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        let limited = String(cleaned.prefix(10))
        
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
    
    private func resetState() {
        isCodeSent = false
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
        signUp = nil
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
    
    private func showErrorMessage(_ message: String) {
        HapticManager.shared.impact(.light)
        errorMessage = message
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showError = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            hideError()
        }
    }
    
    private func hideError() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showError = false
        }
    }
    
    // MARK: - Auth Methods
    
    private func sendVerificationCode() async {
        guard isPreviewMode || isPhoneNumberValid else { return }
        
        isLoading = true
        hideError()
        
        // Preview mode bypass
        if isPreviewMode {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await MainActor.run {
                withAnimation {
                    isCodeSent = true
                }
                startCountdown()
                isLoading = false
            }
            return
        }
        
        // Clean and format phone number
        let cleanPhone = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        guard cleanPhone.count == 10 else {
            showErrorMessage("Please enter a valid 10-digit phone number")
            isLoading = false
            return
        }
        
        let formattedPhone = "+1\(cleanPhone)"
        
        // Try to sign in first (existing user)
        do {
            signIn = try await SignIn.create(strategy: .identifier(formattedPhone))
            
            if signIn?.status == .needsFirstFactor {
                if let phoneNumberId = signIn?.supportedFirstFactors?.first(where: { $0.strategy == "phone_code" })?.phoneNumberId {
                    signIn = try await signIn!.prepareFirstFactor(strategy: .phoneCode(phoneNumberId: phoneNumberId))
                    
                    await MainActor.run {
                        withAnimation {
                            isCodeSent = true
                            isSigningUp = false
                        }
                        startCountdown()
                    }
                } else {
                    await attemptSignUp(formattedPhone: formattedPhone)
                }
            } else {
                await MainActor.run {
                    withAnimation {
                        isCodeSent = true
                        isSigningUp = false
                    }
                    startCountdown()
                }
            }
        } catch {
            // Phone number doesn't exist - prompt for sign up
            if username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty || !isPasswordValid {
                await MainActor.run {
                    withAnimation {
                        needsUsername = true
                    }
                }
                isLoading = false
                return
            }
            
            await attemptSignUp(formattedPhone: formattedPhone)
        }
        
        isLoading = false
    }
    
    private func attemptSignUp(formattedPhone: String) async {
        do {
            let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
            signUp = try await SignUp.create(strategy: .standard(
                password: password,
                username: trimmedUsername.isEmpty ? nil : trimmedUsername,
                phoneNumber: formattedPhone
            ))
            
            signUp = try await signUp!.prepareVerification(strategy: .phoneCode)
            
            await MainActor.run {
                withAnimation {
                    isCodeSent = true
                    isSigningUp = true
                }
                startCountdown()
            }
        } catch {
            await MainActor.run {
                showErrorMessage("Failed to send verification code: \(error.localizedDescription)")
            }
        }
    }
    
    private func verifyCode() async {
        guard verificationCode.count == 6 else { return }
        
        isLoading = true
        hideError()
        
        // Preview mode bypass
        if isPreviewMode {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await MainActor.run {
                setupPreviewUser()
                isLoading = false
            }
            return
        }
        
        do {
            if isSigningUp {
                guard let signUp = signUp else {
                    showErrorMessage("Sign-up session not found. Please try again.")
                    isLoading = false
                    return
                }
                
                let signUpAttempt = try await signUp.attemptVerification(strategy: .phoneCode(code: verificationCode))
                
                switch signUpAttempt.status {
                case .complete:
                    // Success - app state will update automatically
                    // Apply pending referral code if available (from deep link)
                    await applyPendingReferralCode()
                case .missingRequirements:
                    showErrorMessage("Additional information required. Please complete your profile.")
                default:
                    showErrorMessage("Sign-up incomplete. Please try again.")
                }
            } else {
                guard let signIn = signIn else {
                    showErrorMessage("Sign-in session not found. Please try again.")
                    isLoading = false
                    return
                }
                
                let signInAttempt = try await signIn.attemptFirstFactor(strategy: .phoneCode(code: verificationCode))
                
                switch signInAttempt.status {
                case .complete:
                    // Success - app state will update automatically
                    break
                default:
                    showErrorMessage("Sign-in incomplete. Please try again.")
                }
            }
        } catch {
            showErrorMessage("Invalid verification code. Please try again.")
        }
        
        isLoading = false
    }
    
    private func signInWithApple() async {
        if isPreviewMode {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await MainActor.run {
                setupPreviewUser()
            }
            return
        }
        
        do {
            let appleIdCredential = try await SignInWithAppleHelper.getAppleIdCredential()
            
            guard let idToken = appleIdCredential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else {
                showErrorMessage("Failed to get Apple ID token")
                return
            }
            
            _ = try await SignIn.authenticateWithIdToken(provider: .apple, idToken: idToken)
            
        } catch {
            showErrorMessage("Apple Sign In failed: \(error.localizedDescription)")
        }
    }
    
    private func signInWithGoogle() async {
        if isPreviewMode {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await MainActor.run {
                setupPreviewUser()
            }
            return
        }
        
        do {
            try await SignIn.authenticateWithRedirect(strategy: .oauth(provider: .google))
        } catch {
            showErrorMessage("Google Sign In failed: \(error.localizedDescription)")
        }
    }
    
    private func setupPreviewUser() {
        HapticManager.shared.impact(.success)
        appState.isAuthenticated = true
        
        let displayUsername = username.isEmpty ? "previewuser" : username
        
        appState.currentUser = User(
            id: UUID(),
            email: "preview@palytt.com",
            username: displayUsername,
            displayName: "Preview User"
        )
    }
    
    /// Apply pending referral code after successful signup (from deep link)
    private func applyPendingReferralCode() async {
        guard let pendingCode = UserDefaults.standard.string(forKey: "pendingReferralCode") else {
            return
        }
        
        print("📨 UnifiedAuthView: Applying pending referral code: \(pendingCode)")
        
        do {
            let result = try await BackendService.shared.applyReferralCode(pendingCode)
            UserDefaults.standard.removeObject(forKey: "pendingReferralCode")
            
            if result.success {
                print("✅ UnifiedAuthView: Referral code applied successfully: \(result.message)")
                HapticManager.shared.impact(.success)
            } else {
                print("⚠️ UnifiedAuthView: Referral code not applied: \(result.message)")
            }
        } catch {
            print("❌ UnifiedAuthView: Failed to apply referral code: \(error)")
            // Remove the pending code anyway to avoid repeated attempts
            UserDefaults.standard.removeObject(forKey: "pendingReferralCode")
        }
    }
}

// MARK: - Preview

#Preview("Unified Auth - Phone Entry") {
    UnifiedAuthView()
        .environmentObject(AppState.createForPreview())
}

