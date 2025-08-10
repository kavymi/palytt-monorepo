//
//  CreateListView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI
import PhotosUI
import Clerk

// MARK: - Create List View
struct CreateListView: View {
    let onListCreated: (SavedList) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @State private var listName = ""
    @State private var listDescription = ""
    @State private var isPrivate = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    coverImageSection
                    listDetailsSection
                }
            }
            .background(Color.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
        }
        .onChange(of: selectedPhoto) { _, newPhoto in
            Task {
                if let newPhoto = newPhoto {
                    selectedImageData = try? await newPhoto.loadTransferable(type: Data.self)
                }
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            Text("Create New List")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primaryText)
            
            Text("Organize your favorite posts into themed collections")
                .font(.subheadline)
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top)
    }
    
    // MARK: - Cover Image Section
    private var coverImageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cover Image")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primaryText)
            
            PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                coverImageContent
            }
            .buttonStyle(.plain)
            
            Text("Optional - Choose a cover image for your list")
                .font(.caption)
                .foregroundColor(.tertiaryText)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Cover Image Content
    private var coverImageContent: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient.primaryGradient.opacity(0.1))
                .frame(height: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primaryBrand.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [5]))
                )
            
            if let selectedImageData = selectedImageData,
               let uiImage = UIImage(data: selectedImageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.plus")
                        .font(.title2)
                        .foregroundColor(.primaryBrand)
                    
                    Text("Add Cover Photo")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primaryBrand)
                }
            }
        }
    }
    
    // MARK: - List Details Section
    private var listDetailsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            listNameField
            descriptionField
            privacySettingSection
        }
        .padding(.horizontal)
    }
    
    // MARK: - List Name Field
    private var listNameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("List Name")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primaryText)
            
            TextField("Enter list name", text: $listName)
                .textFieldStyle(CreateListTextFieldStyle())
        }
    }
    
    // MARK: - Description Field
    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primaryText)
            
            TextField("Tell us about this list (optional)", text: $listDescription, axis: .vertical)
                .textFieldStyle(CreateListTextFieldStyle(minHeight: 80))
                .lineLimit(3...6)
        }
    }
    
    // MARK: - Privacy Setting Section
    private var privacySettingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Privacy")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primaryText)
            
            VStack(spacing: 12) {
                PrivacyOptionView(
                    icon: "globe",
                    title: "Public",
                    description: "Anyone can see this list",
                    isSelected: !isPrivate
                ) {
                    isPrivate = false
                    HapticManager.shared.impact(.light)
                }
                
                PrivacyOptionView(
                    icon: "lock",
                    title: "Private",
                    description: "Only you can see this list",
                    isSelected: isPrivate
                ) {
                    isPrivate = true
                    HapticManager.shared.impact(.light)
                }
            }
        }
    }
    
    // MARK: - Toolbar Content
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") {
                dismiss()
            }
            .foregroundColor(.secondaryText)
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Create") {
                createList()
            }
            .foregroundColor(canCreateList ? .primaryBrand : .tertiaryText)
            .fontWeight(.semibold)
            .disabled(!canCreateList)
            .overlay(
                HStack {
                    if isCreating {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.primaryBrand)
                    }
                }
            )
        }
        #else
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                dismiss()
            }
            .foregroundColor(.secondaryText)
        }
        
        ToolbarItem(placement: .confirmationAction) {
            Button("Create") {
                createList()
            }
            .foregroundColor(canCreateList ? .primaryBrand : .tertiaryText)
            .fontWeight(.semibold)
            .disabled(!canCreateList)
        }
        #endif
    }
    
    private var canCreateList: Bool {
        !listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isCreating
    }
    
    private func createList() {
        guard canCreateList else { return }
        guard let currentUser = appState.currentUser else {
            errorMessage = "User not authenticated"
            return
        }
        
        isCreating = true
        
        Task {
            do {
                let trimmedName = listName.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedDescription = listDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                let finalDescription = trimmedDescription.isEmpty ? nil : trimmedDescription
                
                let response = try await BackendService.shared.createList(
                    name: trimmedName,
                    description: finalDescription,
                    isPrivate: isPrivate
                )
                
                await MainActor.run {
                    let newList = SavedList(
                        id: UUID().uuidString,
                        convexId: response.listId,
                        name: trimmedName,
                        description: finalDescription,
                        userId: currentUser.clerkId ?? "",
                        isPrivate: isPrivate
                    )
                    
                    HapticManager.shared.impact(.medium)
                    onListCreated(newList)
                    isCreating = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    print("❌ Failed to create list: \(error)")
                    errorMessage = "Failed to create list: \(error.localizedDescription)"
                    isCreating = false
                }
            }
        }
    }
}

// MARK: - Create List Text Field Style
struct CreateListTextFieldStyle: TextFieldStyle {
    let minHeight: CGFloat
    
    init(minHeight: CGFloat = 44) {
        self.minHeight = minHeight
    }
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: minHeight)
            .background(Color.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primaryBrand.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - Privacy Option View
struct PrivacyOptionView: View {
    let icon: String
    let title: String
    let description: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.primaryBrand : Color.primaryBrand.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isSelected ? .white : .primaryBrand)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.primaryBrand)
                }
            }
            .padding(16)
            .background(Color.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.primaryBrand : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CreateListView { _ in }
        .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    CreateListView { _ in }
        .preferredColorScheme(.dark)
} 