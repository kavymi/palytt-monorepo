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
import Kingfisher

struct CreateListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var listName = ""
    @State private var listDescription = ""
    @State private var isPrivate = false
    @State private var selectedCoverImage: PhotosPickerItem?
    @State private var coverImageURL: URL?
    @State private var isLoading = false
    @State private var showImagePicker = false
    @FocusState private var isNameFieldFocused: Bool
    
    let onListCreated: (SavedList) -> Void
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Cover Image Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Cover Image")
                            .font(.headline)
                            .foregroundColor(.primaryText)
                        
                        Button(action: {
                            showImagePicker = true
                        }) {
                            if let coverImageURL = coverImageURL {
                                AsyncImage(url: coverImageURL) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .overlay(ProgressView())
                                }
                                .frame(height: 120)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.primaryBrand, lineWidth: 2)
                                )
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(height: 120)
                                    .frame(maxWidth: .infinity)
                                    .overlay(
                                        VStack(spacing: 8) {
                                            Image(systemName: "photo.badge.plus")
                                                .font(.title2)
                                                .foregroundColor(.primaryBrand)
                                            Text("Add Cover Image")
                                                .font(.subheadline)
                                                .foregroundColor(.primaryBrand)
                                        }
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.primaryBrand.opacity(0.3), lineWidth: 1, lineCap: .round, dash: [5])
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // List Details Section
                    VStack(alignment: .leading, spacing: 16) {
                        // List Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("List Name *")
                                .font(.headline)
                                .foregroundColor(.primaryText)
                            
                            TextField("Enter list name", text: $listName)
                                .focused($isNameFieldFocused)
                                .textFieldStyle(.roundedBorder)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isNameFieldFocused ? Color.primaryBrand : Color.clear, lineWidth: 2)
                                )
                        }
                        
                        // List Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.headline)
                                .foregroundColor(.primaryText)
                            
                            TextField("Add a description (optional)", text: $listDescription, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(3...6)
                        }
                        
                        // Privacy Setting
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Privacy")
                                .font(.headline)
                                .foregroundColor(.primaryText)
                            
                            Toggle(isOn: $isPrivate) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: isPrivate ? "lock.fill" : "globe")
                                            .foregroundColor(isPrivate ? .orange : .primaryBrand)
                                        Text(isPrivate ? "Private List" : "Public List")
                                            .fontWeight(.medium)
                                    }
                                    Text(isPrivate ? "Only you can see this list" : "Anyone can see this list")
                                        .font(.caption)
                                        .foregroundColor(.secondaryText)
                                }
                                Spacer()
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .primaryBrand))
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(Color.background)
            .navigationTitle("Create List")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
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
                    .foregroundColor(canCreateList ? .primaryBrand : .gray)
                    .fontWeight(.semibold)
                    .disabled(!canCreateList || isLoading)
                }
            }
            .photosPicker(isPresented: $showImagePicker, selection: $selectedCoverImage, matching: .images)
            .onChange(of: selectedCoverImage) { _, newItem in
                Task {
                    await loadSelectedImage(newItem)
                }
            }
            .onAppear {
                isNameFieldFocused = true
            }
        }
    }
    
    private var canCreateList: Bool {
        !listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }
    
    @MainActor
    private func loadSelectedImage(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                // TODO: Upload image to backend and get URL
                // For now, create a local URL placeholder
                coverImageURL = URL(string: "https://via.placeholder.com/400x200")
                print("📷 Image selected for list cover")
            }
        } catch {
            print("❌ Failed to load selected image: \(error)")
        }
    }
    
    private func createList() {
        guard canCreateList else { return }
        
        isLoading = true
        
        // Create new list
        let newList = SavedList(
            id: UUID().uuidString,
            name: listName.trimmingCharacters(in: .whitespacesAndNewlines),
            description: listDescription.isEmpty ? nil : listDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            isPrivate: isPrivate,
            postCount: 0,
            coverImageURL: coverImageURL,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onListCreated(newList)
            
            // Haptic feedback
            HapticManager.shared.impact(.light)
            
            isLoading = false
            dismiss()
        }
    }
}

// MARK: - Preview
#Preview {
    CreateListView { list in
        print("Created list: \(list.name)")
    }
} 