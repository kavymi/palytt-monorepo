//
//  EditProfileView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI
import Kingfisher
#if os(iOS)
import PhotosUI
#elseif os(macOS)
import AppKit
#endif

struct EditProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) var presentationMode
    
    #if os(iOS)
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showPhotoPicker = false
    #endif
    
    @State private var showDuplicateAlert = false
    @State private var duplicateMessage = ""
    
    var body: some View {
        Group {
            #if os(iOS)
            EditProfileMainContent(
                viewModel: viewModel,
                showDuplicateAlert: $showDuplicateAlert,
                duplicateMessage: duplicateMessage,
                selectedPhoto: $selectedPhoto,
                validateUsername: validateUsername,
                validateEmail: validateEmail,
                validatePhoneNumber: validatePhoneNumber,
                selectProfileImage: selectProfileImage
            )
            #else
            EditProfileMainContent(
                viewModel: viewModel,
                showDuplicateAlert: $showDuplicateAlert,
                duplicateMessage: duplicateMessage,
                validateUsername: validateUsername,
                validateEmail: validateEmail,
                validatePhoneNumber: validatePhoneNumber,
                selectProfileImage: selectProfileImage
            )
            #endif
        }
        .task {
            // Load user profile data first
            await viewModel.loadUserProfile()
        }
        .onAppear {
            // Initialize editable fields with current values after data is loaded
            initializeFormFields()
        }
        .onChange(of: viewModel.currentUser) { _, _ in
            // Update form fields when user data changes
            initializeFormFields()
        }
    }
    
    private var profileImageSection: some View {
        VStack(spacing: 16) {
            #if os(iOS)
            PhotosPicker(
                selection: $selectedPhoto,
                matching: .images,
                photoLibrary: .shared()
            ) {
                profileImageView
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    if let newItem = newItem {
                        if let data = try? await newItem.loadTransferable(type: Data.self) {
                            if let uiImage = UIImage(data: data) {
                                viewModel.profileImage = uiImage
                                HapticManager.shared.impact(.medium)
                            }
                        }
                    }
                }
            }
            #else
            Button(action: selectProfileImage) {
                profileImageView
            }
            .buttonStyle(PlainButtonStyle())
            #endif
        }
        .padding(.top, 8)
    }
    
    private var profileImageView: some View {
        // Main profile image
        Group {
            if let profileImage = viewModel.profileImage {
                #if os(iOS)
                Image(uiImage: profileImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                #else
                Image(nsImage: profileImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                #endif
            } else if let avatarURL = viewModel.avatarURL {
                KFImage(avatarURL)
                    .placeholder {
                        Circle()
                            .fill(LinearGradient.primaryGradient)
                            .frame(width: 120, height: 120)
                            .overlay(
                                Text(String(viewModel.username.prefix(2).uppercased()))
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(LinearGradient.primaryGradient)
                    .frame(width: 120, height: 120)
                    .overlay(
                        Text(String(viewModel.username.prefix(2).uppercased()))
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
            }
        }
        .frame(width: 120, height: 120)
    }
    
    private var basicInfoCard: some View {
        ProfileEditCard(title: "Username", icon: "person.fill") {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Enter username", text: $viewModel.username)
                    .textFieldStyle(CustomTextFieldStyle())
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .disableAutocorrection(true)
                    .onChange(of: viewModel.username) { _, newValue in
                        if !newValue.isEmpty {
                            Task {
                                await validateUsername(newValue)
                            }
                        }
                    }
            }
        }
    }
    
    private var emailCard: some View {
        ProfileEditCard(title: "Email", icon: "envelope.fill") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    TextField("Enter email address", text: $viewModel.newEmail)
                        .textFieldStyle(CustomTextFieldStyle())
                        #if os(iOS)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        #endif
                        .disableAutocorrection(true)
                        .onChange(of: viewModel.newEmail) { _, newValue in
                            if !newValue.isEmpty && newValue != viewModel.currentEmail {
                                Task {
                                    await validateEmail(newValue)
                                }
                            }
                        }
                    
                    if !viewModel.newEmail.isEmpty && viewModel.newEmail != viewModel.currentEmail {
                        Button("Update") {
                            HapticManager.shared.impact(.light)
                            viewModel.updateEmail()
                        }
                        .disabled(viewModel.isUpdatingEmail)
                        .buttonStyle(ActionButtonStyle(isSecondary: true))
                    }
                }
                
                if viewModel.isUpdatingEmail {
                    Text("Sending confirmation email...")
                        .font(.caption2)
                        .foregroundColor(.warmAccentText)
                }
            }
        }
    }
    
    private var phoneCard: some View {
        ProfileEditCard(title: "Phone", icon: "phone.fill") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    TextField("Enter phone number", text: $viewModel.phoneNumber)
                        .textFieldStyle(CustomTextFieldStyle())
                        #if os(iOS)
                        .keyboardType(.phonePad)
                        #endif
                        .onChange(of: viewModel.phoneNumber) { _, newValue in
                            if !newValue.isEmpty && newValue != viewModel.currentPhoneNumber {
                                Task {
                                    await validatePhoneNumber(newValue)
                                }
                            }
                        }
                    
                    if !viewModel.phoneNumber.isEmpty && viewModel.phoneNumber != viewModel.currentPhoneNumber {
                        Button("Update") {
                            HapticManager.shared.impact(.light)
                            viewModel.updatePhoneNumber()
                        }
                        .disabled(viewModel.isUpdatingPhoneNumber)
                        .buttonStyle(ActionButtonStyle(isSecondary: true))
                    }
                }
                
                if viewModel.isUpdatingPhoneNumber {
                    Text("Sending confirmation SMS...")
                        .font(.caption2)
                        .foregroundColor(.warmAccentText)
                }
            }
        }
    }
    
    private var bioCard: some View {
        ProfileEditCard(title: "About you", icon: "quote.bubble.fill") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Spacer()
                    
                    Text("\(viewModel.bioCharacterCount)/\(viewModel.bioCharacterLimit)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(viewModel.isBioValid ? .warmAccentText : .error)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(viewModel.isBioValid ? Color.warmAccentText.opacity(0.1) : Color.error.opacity(0.1))
                        )
                }
                
                TextField("Tell us about yourself...", text: $viewModel.bio, axis: .vertical)
                    .lineLimit(4...8)
                    .textFieldStyle(CustomTextFieldStyle(minHeight: 80))
            }
        }
    }
    
    private var emailVerificationSheet: some View {
        NavigationView {
            ZStack {
                Color.background.ignoresSafeArea()
                
                VStack(spacing: 32) {
                    VStack(spacing: 24) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient.primaryGradient)
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        
                        VStack(spacing: 12) {
                            Text("Verify Your Email")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primaryText)
                            
                            Text("We've sent a verification code to")
                                .font(.subheadline)
                                .foregroundColor(.secondaryText)
                            
                            Text(viewModel.newEmail)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primaryBrand)
                        }
                        .multilineTextAlignment(.center)
                    }
                    
                    VStack(spacing: 20) {
                        TextField("Verification Code", text: $viewModel.verificationCode)
                            .textFieldStyle(CustomTextFieldStyle())
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            #endif
                        
                        Button(action: {
                            HapticManager.shared.impact(.medium)
                            Task {
                                await viewModel.verifyEmailCode()
                            }
                        }) {
                            if viewModel.isUpdatingEmail {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Verify Email")
                                    .fontWeight(.semibold)
                            }
                        }
                        .disabled(viewModel.verificationCode.isEmpty || viewModel.isUpdatingEmail)
                        .buttonStyle(ActionButtonStyle())
                    }
                    
                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("Email Verification")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        HapticManager.shared.impact(.light)
                        viewModel.cancelEmailUpdate()
                    }
                    .foregroundColor(.primaryText)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticManager.shared.impact(.light)
                        viewModel.cancelEmailUpdate()
                    }
                    .foregroundColor(.primaryText)
                }
                #endif
            }
        }
    }
    
    private var phoneVerificationSheet: some View {
        NavigationView {
            ZStack {
                Color.background.ignoresSafeArea()
                
                VStack(spacing: 32) {
                    VStack(spacing: 24) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient.primaryGradient)
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "phone.fill")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        
                        VStack(spacing: 12) {
                            Text("Verify Your Phone")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primaryText)
                            
                            Text("We've sent a verification code to")
                                .font(.subheadline)
                                .foregroundColor(.secondaryText)
                            
                            Text(viewModel.phoneNumber)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primaryBrand)
                        }
                        .multilineTextAlignment(.center)
                    }
                    
                    VStack(spacing: 20) {
                        TextField("Verification Code", text: $viewModel.phoneVerificationCode)
                            .textFieldStyle(CustomTextFieldStyle())
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            #endif
                        
                        Button(action: {
                            HapticManager.shared.impact(.medium)
                            Task {
                                await viewModel.verifyPhoneCode()
                            }
                        }) {
                            if viewModel.isUpdatingPhoneNumber {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Verify Phone")
                                    .fontWeight(.semibold)
                            }
                        }
                        .disabled(viewModel.phoneVerificationCode.isEmpty || viewModel.isUpdatingPhoneNumber)
                        .buttonStyle(ActionButtonStyle())
                    }
                    
                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("Phone Verification")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        HapticManager.shared.impact(.light)
                        viewModel.cancelPhoneUpdate()
                    }
                    .foregroundColor(.primaryText)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticManager.shared.impact(.light)
                        viewModel.cancelPhoneUpdate()
                    }
                    .foregroundColor(.primaryText)
                }
                #endif
            }
        }
    }
    
    private func selectProfileImage() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK {
            if let url = panel.url,
               let nsImage = NSImage(contentsOf: url) {
                viewModel.profileImage = nsImage
                HapticManager.shared.impact(.medium)
            }
        }
        #endif
    }
    
    private func dismissView() {
        // Try multiple dismiss approaches for better compatibility
        DispatchQueue.main.async {
            if #available(iOS 15.0, macOS 12.0, *) {
                dismiss()
            } else {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    private func initializeFormFields() {
        guard let user = viewModel.currentUser else { return }
        
        // Initialize all form fields with current user data
        if viewModel.firstName.isEmpty {
            viewModel.firstName = user.firstName ?? ""
        }
        
        if viewModel.lastName.isEmpty {
            viewModel.lastName = user.lastName ?? ""
        }
        
        if viewModel.username.isEmpty {
            viewModel.username = user.username
        }
        
        if viewModel.bio.isEmpty {
            viewModel.bio = user.bio ?? ""
        }
        
        // Initialize email field
        if viewModel.newEmail.isEmpty {
            viewModel.newEmail = viewModel.currentEmail
        }
        
        // Initialize phone number field
        if viewModel.phoneNumber.isEmpty || viewModel.phoneNumber == "Not set" {
            viewModel.phoneNumber = viewModel.currentPhoneNumber == "Not set" ? "" : viewModel.currentPhoneNumber
        }
        
        // Initialize dietary preferences
        if viewModel.selectedDietaryPreferences.isEmpty {
            viewModel.selectedDietaryPreferences = Set(user.dietaryPreferences)
        }
        
        // Initialize profile image URL if available
        if viewModel.profileImageURL.isEmpty, let avatarURL = user.avatarURL {
            viewModel.profileImageURL = avatarURL.absoluteString
        }
    }
    
    // MARK: - Validation Functions
    
    private func validateUsername(_ username: String) async {
        do {
            let isAvailable = try await BackendService.shared.checkUsernameAvailability(username: username)
            if !isAvailable {
                await MainActor.run {
                    duplicateMessage = "Username '\(username)' is already taken. Please choose a different username."
                    showDuplicateAlert = true
                    viewModel.hasValidationErrors = true
                    HapticManager.shared.haptic(.error)
                }
            } else {
                await MainActor.run {
                    viewModel.hasValidationErrors = false
                }
            }
        } catch {
            print("❌ Username validation error: \(error)")
        }
    }
    
    private func validateEmail(_ email: String) async {
        do {
            let isAvailable = try await BackendService.shared.checkEmailAvailability(email: email)
            if !isAvailable {
                await MainActor.run {
                    duplicateMessage = "Email '\(email)' is already registered. Please use a different email address."
                    showDuplicateAlert = true
                    viewModel.hasValidationErrors = true
                    HapticManager.shared.haptic(.error)
                }
            } else {
                await MainActor.run {
                    viewModel.hasValidationErrors = false
                }
            }
        } catch {
            print("❌ Email validation error: \(error)")
        }
    }
    
    private func validatePhoneNumber(_ phoneNumber: String) async {
        do {
            let isAvailable = try await BackendService.shared.checkPhoneAvailability(phoneNumber: phoneNumber)
            if !isAvailable {
                await MainActor.run {
                    duplicateMessage = "Phone number '\(phoneNumber)' is already registered. Please use a different phone number."
                    showDuplicateAlert = true
                    viewModel.hasValidationErrors = true
                    HapticManager.shared.haptic(.error)
                }
            } else {
                await MainActor.run {
                    viewModel.hasValidationErrors = false
                }
            }
        } catch {
            print("❌ Phone validation error: \(error)")
        }
    }
    
    private var nameCard: some View {
        ProfileEditCard(title: "Full Name", icon: "person.text.rectangle.fill") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("First name", text: $viewModel.firstName)
                    .textFieldStyle(CustomTextFieldStyle())
                    #if os(iOS)
                    .textInputAutocapitalization(.words)
                    #endif
                
                TextField("Last name", text: $viewModel.lastName)
                    .textFieldStyle(CustomTextFieldStyle())
                    #if os(iOS)
                    .textInputAutocapitalization(.words)
                    #endif
            }
        }
    }
}

// MARK: - Custom Components

struct ProfileEditCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primaryBrand)
                    .frame(width: 20)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                Spacer()
            }
            
            content
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    let minHeight: CGFloat
    
    init(minHeight: CGFloat = 44) {
        self.minHeight = minHeight
    }
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(12)
            .frame(minHeight: minHeight)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.background)
                    .stroke(Color.divider, lineWidth: 1)
            )
            .font(.subheadline)
            .foregroundColor(.primaryText)
    }
}

struct ActionButtonStyle: ButtonStyle {
    let isSecondary: Bool
    
    init(isSecondary: Bool = false) {
        self.isSecondary = isSecondary
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(isSecondary ? .primaryBrand : .white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSecondary ? Color.clear : Color.primaryBrand)
                    .stroke(Color.primaryBrand, lineWidth: isSecondary ? 1.5 : 0)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Edit Profile Main Content (broken out for type-checking)
struct EditProfileMainContent: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Binding var showDuplicateAlert: Bool
    let duplicateMessage: String
    #if os(iOS)
    @Binding var selectedPhoto: PhotosPickerItem?
    #endif
    let validateUsername: (String) async -> Void
    let validateEmail: (String) async -> Void
    let validatePhoneNumber: (String) async -> Void
    let selectProfileImage: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        profileImageSection
                        basicInfoCard
                        nameCard
                        bioCard
                        emailCard
                        phoneCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Edit Profile")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                EditProfileToolbar(viewModel: viewModel, dismiss: dismiss)
            }
            .sheet(isPresented: $viewModel.showEmailVerification) {
                emailVerificationSheet
            }
            .sheet(isPresented: $viewModel.showPhoneVerification) {
                phoneVerificationSheet
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
            .alert("Duplicate Found", isPresented: $showDuplicateAlert) {
                Button("OK") { }
            } message: {
                Text(duplicateMessage)
            }
            .disabled(viewModel.isSaving)
            .overlay {
                if viewModel.isSaving {
                    LoadingOverlay()
                }
            }
            .onChange(of: viewModel.didSaveSuccessfully) { _, didSave in
                if didSave {
                    // Reset the flag and dismiss
                    viewModel.didSaveSuccessfully = false
                    dismiss()
                }
            }
        }
    }
    
    private var profileImageSection: some View {
        VStack(spacing: 12) {
            #if os(iOS)
            PhotosPicker(
                selection: $selectedPhoto,
                matching: .images,
                photoLibrary: .shared()
            ) {
                profileImageView
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    if let newItem = newItem {
                        if let data = try? await newItem.loadTransferable(type: Data.self) {
                            if let uiImage = UIImage(data: data) {
                                viewModel.profileImage = uiImage
                                HapticManager.shared.impact(.medium)
                            }
                        }
                    }
                }
            }
            #else
            Button(action: selectProfileImage) {
                profileImageView
            }
            .buttonStyle(PlainButtonStyle())
            #endif
            
            // Tap to change hint
            Text("Tap to change photo")
                .font(.caption)
                .foregroundColor(.secondaryText)
        }
        .padding(.top, 8)
    }
    
    private var profileImageView: some View {
        ZStack(alignment: .bottomTrailing) {
            // Main profile image
            Group {
                if let profileImage = viewModel.profileImage {
                    #if os(iOS)
                    Image(uiImage: profileImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                    #else
                    Image(nsImage: profileImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                    #endif
                } else if let avatarURL = viewModel.avatarURL {
                    KFImage(avatarURL)
                        .placeholder {
                            Circle()
                                .fill(LinearGradient.primaryGradient)
                                .frame(width: 120, height: 120)
                                .overlay(
                                    Text(String(viewModel.username.prefix(2).uppercased()))
                                        .font(.largeTitle)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                )
                        }
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(LinearGradient.primaryGradient)
                        .frame(width: 120, height: 120)
                        .overlay(
                            Text(String(viewModel.username.prefix(2).uppercased()))
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                }
            }
            .frame(width: 120, height: 120)
            .overlay(
                Circle()
                    .stroke(Color.primaryBrand.opacity(0.3), lineWidth: 3)
            )
            
            // Camera badge overlay
            ZStack {
                Circle()
                    .fill(Color.primaryBrand)
                    .frame(width: 36, height: 36)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                
                Image(systemName: "camera.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .offset(x: 4, y: 4)
        }
        .frame(width: 120, height: 120)
    }
    
    private var basicInfoCard: some View {
        ProfileEditCard(title: "Username", icon: "person.fill") {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Enter username", text: $viewModel.username)
                    .textFieldStyle(CustomTextFieldStyle())
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .disableAutocorrection(true)
                    .onChange(of: viewModel.username) { _, newValue in
                        if !newValue.isEmpty {
                            Task {
                                await validateUsername(newValue)
                            }
                        }
                    }
            }
        }
    }
    
    private var nameCard: some View {
        ProfileEditCard(title: "Full Name", icon: "person.text.rectangle.fill") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("First name", text: $viewModel.firstName)
                    .textFieldStyle(CustomTextFieldStyle())
                    #if os(iOS)
                    .textInputAutocapitalization(.words)
                    #endif
                
                TextField("Last name", text: $viewModel.lastName)
                    .textFieldStyle(CustomTextFieldStyle())
                    #if os(iOS)
                    .textInputAutocapitalization(.words)
                    #endif
            }
        }
    }
    
    private var emailCard: some View {
        ProfileEditCard(title: "Email", icon: "envelope.fill") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    TextField("Enter email address", text: $viewModel.newEmail)
                        .textFieldStyle(CustomTextFieldStyle())
                        #if os(iOS)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        #endif
                        .disableAutocorrection(true)
                        .onChange(of: viewModel.newEmail) { _, newValue in
                            if !newValue.isEmpty && newValue != viewModel.currentEmail {
                                Task {
                                    await validateEmail(newValue)
                                }
                            }
                        }
                    
                    if !viewModel.newEmail.isEmpty && viewModel.newEmail != viewModel.currentEmail {
                        Button("Update") {
                            HapticManager.shared.impact(.light)
                            viewModel.updateEmail()
                        }
                        .disabled(viewModel.isUpdatingEmail)
                        .buttonStyle(ActionButtonStyle(isSecondary: true))
                    }
                }
                
                if viewModel.isUpdatingEmail {
                    Text("Sending confirmation email...")
                        .font(.caption2)
                        .foregroundColor(.warmAccentText)
                }
            }
        }
    }
    
    private var phoneCard: some View {
        ProfileEditCard(title: "Phone", icon: "phone.fill") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    TextField("Enter phone number", text: $viewModel.phoneNumber)
                        .textFieldStyle(CustomTextFieldStyle())
                        #if os(iOS)
                        .keyboardType(.phonePad)
                        #endif
                        .onChange(of: viewModel.phoneNumber) { _, newValue in
                            if !newValue.isEmpty && newValue != viewModel.currentPhoneNumber {
                                Task {
                                    await validatePhoneNumber(newValue)
                                }
                            }
                        }
                    
                    if !viewModel.phoneNumber.isEmpty && viewModel.phoneNumber != viewModel.currentPhoneNumber {
                        Button("Update") {
                            HapticManager.shared.impact(.light)
                            viewModel.updatePhoneNumber()
                        }
                        .disabled(viewModel.isUpdatingPhoneNumber)
                        .buttonStyle(ActionButtonStyle(isSecondary: true))
                    }
                }
                
                if viewModel.isUpdatingPhoneNumber {
                    Text("Sending confirmation SMS...")
                        .font(.caption2)
                        .foregroundColor(.warmAccentText)
                }
            }
        }
    }
    
    private var bioCard: some View {
        ProfileEditCard(title: "About you", icon: "quote.bubble.fill") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Spacer()
                    
                    Text("\(viewModel.bioCharacterCount)/\(viewModel.bioCharacterLimit)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(viewModel.isBioValid ? .warmAccentText : .error)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(viewModel.isBioValid ? Color.warmAccentText.opacity(0.1) : Color.error.opacity(0.1))
                        )
                }
                
                TextField("Tell us about yourself...", text: $viewModel.bio, axis: .vertical)
                    .lineLimit(4...8)
                    .textFieldStyle(CustomTextFieldStyle(minHeight: 80))
            }
        }
    }
    
    private var emailVerificationSheet: some View {
        NavigationView {
            ZStack {
                Color.background.ignoresSafeArea()
                
                VStack(spacing: 32) {
                    VStack(spacing: 24) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient.primaryGradient)
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        
                        VStack(spacing: 12) {
                            Text("Verify Your Email")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primaryText)
                            
                            Text("We've sent a verification code to")
                                .font(.subheadline)
                                .foregroundColor(.secondaryText)
                            
                            Text(viewModel.newEmail)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primaryBrand)
                        }
                        .multilineTextAlignment(.center)
                    }
                    
                    VStack(spacing: 20) {
                        TextField("Verification Code", text: $viewModel.verificationCode)
                            .textFieldStyle(CustomTextFieldStyle())
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            #endif
                        
                        Button(action: {
                            HapticManager.shared.impact(.medium)
                            Task {
                                await viewModel.verifyEmailCode()
                            }
                        }) {
                            if viewModel.isUpdatingEmail {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Verify Email")
                                    .fontWeight(.semibold)
                            }
                        }
                        .disabled(viewModel.verificationCode.isEmpty || viewModel.isUpdatingEmail)
                        .buttonStyle(ActionButtonStyle())
                    }
                    
                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("Email Verification")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        HapticManager.shared.impact(.light)
                        viewModel.cancelEmailUpdate()
                    }
                    .foregroundColor(.primaryText)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticManager.shared.impact(.light)
                        viewModel.cancelEmailUpdate()
                    }
                    .foregroundColor(.primaryText)
                }
                #endif
            }
        }
    }
    
    private var phoneVerificationSheet: some View {
        NavigationView {
            ZStack {
                Color.background.ignoresSafeArea()
                
                VStack(spacing: 32) {
                    VStack(spacing: 24) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient.primaryGradient)
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "phone.fill")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        
                        VStack(spacing: 12) {
                            Text("Verify Your Phone")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primaryText)
                            
                            Text("We've sent a verification code to")
                                .font(.subheadline)
                                .foregroundColor(.secondaryText)
                            
                            Text(viewModel.phoneNumber)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primaryBrand)
                        }
                        .multilineTextAlignment(.center)
                    }
                    
                    VStack(spacing: 20) {
                        TextField("Verification Code", text: $viewModel.phoneVerificationCode)
                            .textFieldStyle(CustomTextFieldStyle())
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            #endif
                        
                        Button(action: {
                            HapticManager.shared.impact(.medium)
                            Task {
                                await viewModel.verifyPhoneCode()
                            }
                        }) {
                            if viewModel.isUpdatingPhoneNumber {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Verify Phone")
                                    .fontWeight(.semibold)
                            }
                        }
                        .disabled(viewModel.phoneVerificationCode.isEmpty || viewModel.isUpdatingPhoneNumber)
                        .buttonStyle(ActionButtonStyle())
                    }
                    
                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("Phone Verification")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        HapticManager.shared.impact(.light)
                        viewModel.cancelPhoneUpdate()
                    }
                    .foregroundColor(.primaryText)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticManager.shared.impact(.light)
                        viewModel.cancelPhoneUpdate()
                    }
                    .foregroundColor(.primaryText)
                }
                #endif
            }
        }
    }
}

// MARK: - Edit Profile Toolbar (broken out for simplicity)
struct EditProfileToolbar: ToolbarContent {
    @ObservedObject var viewModel: ProfileViewModel
    let dismiss: DismissAction
    
    var body: some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") {
                HapticManager.shared.impact(.light)
                dismiss()
            }
            .foregroundColor(.primaryBrand)
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Save") {
                HapticManager.shared.impact(.medium)
                Task {
                    await viewModel.saveProfile()
                }
            }
            .foregroundColor(.primaryBrand)
            .disabled(!viewModel.canSaveProfile)
        }
        #else
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                HapticManager.shared.impact(.light)
                dismiss()
            }
            .foregroundColor(.primaryBrand)
        }
        
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
                HapticManager.shared.impact(.medium)
                Task {
                    await viewModel.saveProfile()
                }
            }
            .foregroundColor(.primaryBrand)
            .disabled(!viewModel.canSaveProfile)
        }
        #endif
    }
}

// MARK: - Loading Overlay (broken out for simplicity)
struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .primaryBrand))
                    .scaleEffect(1.2)
                
                Text("Saving Profile...")
                    .font(.subheadline)
                    .foregroundColor(.primaryText)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.cardBackground)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
            )
        }
    }
}

#Preview {
    EditProfileView(viewModel: ProfileViewModel())
}

 