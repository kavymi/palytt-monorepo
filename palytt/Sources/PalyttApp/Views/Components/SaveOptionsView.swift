//
//  SaveOptionsView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI
import Clerk

struct SaveOptionsView: View {
    let post: Post
    @Binding var isSaved: Bool
    let onListSelected: ((SavedList?) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var userLists: [SavedList] = []
    @State private var showCreateList = false
    @State private var newListName = ""
    @State private var selectedLists: Set<String> = []
    
    init(post: Post, isSaved: Binding<Bool>, onListSelected: ((SavedList?) -> Void)? = nil) {
        self.post = post
        self._isSaved = isSaved
        self.onListSelected = onListSelected
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Create New List Button
                Button(action: { showCreateList = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.primaryBrand)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Create New List")
                                .font(.headline)
                                .foregroundColor(.primaryText)
                            Text("Organize your saved posts")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.matchaGreen.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding()
                
                Divider()
                
                // Existing Lists
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(userLists) { list in
                            ListSelectionRow(
                                list: list,
                                isSelected: selectedLists.contains(list.id),
                                onTap: {
                                    if selectedLists.contains(list.id) {
                                        selectedLists.remove(list.id)
                                    } else {
                                        selectedLists.insert(list.id)
                                    }
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Save to List")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryBrand)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveToLists()
                    }
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryBrand)
                    .disabled(selectedLists.isEmpty)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryBrand)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveToLists()
                    }
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryBrand)
                    .disabled(selectedLists.isEmpty)
                }
                #endif
            }
            .sheet(isPresented: $showCreateList) {
                CreateSaveListView(onListCreated: { list in
                    userLists.append(list)
                    selectedLists.insert(list.id)
                })
            }
        }
        .onAppear {
            loadUserLists()
        }
    }
    
    private func getCurrentUserId() -> String? {
        // For now, return a placeholder. In a real app, this would get the current user's ID
        // from your authentication system (e.g., Clerk, AppState, etc.)
        return "current-user-id"
    }
    
    private func loadUserLists() {
        Task {
            do {
                guard let currentUserId = Clerk.shared.user?.id else {
                    print("⚠️ SaveOptionsView: No current user ID available")
                    userLists = []
                    return
                }
                
                let backendLists = try await BackendService.shared.getUserLists(userId: currentUserId)
                
                // Convert BackendList to SavedList model
                await MainActor.run {
                    userLists = backendLists.map { backendList in
                        SavedList(
                            id: UUID().uuidString,
                            convexId: backendList._id,
                            name: backendList.name,
                            description: backendList.description,
                            coverImageURL: nil as URL?,
                            userId: "current-user", // Will be updated with proper user ID
                            postIds: [],
                            isPrivate: backendList.isPrivate,
                            createdAt: Date(timeIntervalSince1970: Double(backendList.createdAt) / 1000),
                            updatedAt: Date(timeIntervalSince1970: Double(backendList.updatedAt) / 1000)
                        )
                    }
                    print("✅ SaveOptionsView: Loaded \(userLists.count) user lists")
                }
                
            } catch {
                print("❌ SaveOptionsView: Failed to load user lists: \(error)")
                await MainActor.run {
                    userLists = []
                }
            }
        }
    }
    
    private func saveToLists() {
        // Save to selected lists
        isSaved = !selectedLists.isEmpty
        
        // Notify callback with the first selected list
        if let firstListId = selectedLists.first,
           let list = userLists.first(where: { $0.id == firstListId }) {
            onListSelected?(list)
        } else {
            onListSelected?(nil)
        }
        
        // Actually save the post to the selected lists via API
        if !post.convexId.isEmpty {
            let postConvexId = post.convexId
            Task {
                for listId in selectedLists {
                    if let list = userLists.first(where: { $0.id == listId }) {
                        do {
                            let success = try await BackendService.shared.addPostToList(
                                listId: list.convexId ?? "", 
                                postId: postConvexId
                            )
                            if success {
                                print("✅ SaveOptionsView: Successfully added post to list: \(list.name)")
                            }
                        } catch {
                            print("❌ SaveOptionsView: Failed to add post to list \(list.name): \(error)")
                        }
                    }
                }
            }
        }
        
        dismiss()
    }
}

// MARK: - List Selection Row
struct ListSelectionRow: View {
    let list: SavedList
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // List Icon
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient.primaryGradient.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(list.name.prefix(2).uppercased())
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.primaryBrand)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(list.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primaryText)
                    
                    HStack(spacing: 4) {
                        Text("\(list.postCount) posts")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                        
                        if list.isPrivate {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundColor(.secondaryText)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .primaryBrand : .tertiaryText)
            }
            .padding()
            .background(isSelected ? Color.primaryBrand.opacity(0.1) : Color.cardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Create List View
struct CreateSaveListView: View {
    let onListCreated: (SavedList) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var listName = ""
    @State private var listDescription = ""
    @State private var isPrivate = false
    
    private func getCurrentUserId() -> String? {
        // For now, return a placeholder. In a real app, this would get the current user's ID
        // from your authentication system (e.g., Clerk, AppState, etc.)
        return "current-user-id"
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("List Name", text: $listName)
                    TextField("Description (optional)", text: $listDescription)
                }
                
                Section {
                    Toggle("Private List", isOn: $isPrivate)
                } footer: {
                    Text("Private lists are only visible to you")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            }
            .navigationTitle("Create New List")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryBrand)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        let newList = SavedList(
                            name: listName,
                            description: listDescription.isEmpty ? nil : listDescription,
                            userId: getCurrentUserId() ?? "unknown-user",
                            isPrivate: isPrivate
                        )
                        onListCreated(newList)
                        dismiss()
                    }
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryBrand)
                    .disabled(listName.isEmpty)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryBrand)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let newList = SavedList(
                            name: listName,
                            description: listDescription.isEmpty ? nil : listDescription,
                            userId: getCurrentUserId() ?? "unknown-user",
                            isPrivate: isPrivate
                        )
                        onListCreated(newList)
                        dismiss()
                    }
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryBrand)
                    .disabled(listName.isEmpty)
                }
                #endif
            }
        }
    }
}

// MARK: - SwiftUI Previews
#Preview("Save Options - With Lists") {
    @Previewable @State var isSaved = false
    let mockLists = [
        SavedList(name: "Favorite Restaurants", description: "My go-to dining spots", userId: "user1", isPrivate: false),
        SavedList(name: "Coffee Shops", description: "Best coffee in the city", userId: "user1", isPrivate: false),
        SavedList(name: "Date Night", description: "Romantic dinner ideas", userId: "user1", isPrivate: true)
    ]
    
    SaveOptionsView(
        post: MockData.generatePreviewPosts()[0],
        isSaved: $isSaved
    )
    .onAppear {
        // Simulate loaded lists for preview
    }
}

#Preview("Save Options - Empty Lists") {
    @Previewable @State var isSaved = false
    
    SaveOptionsView(
        post: MockData.generatePreviewPosts()[1],
        isSaved: $isSaved
    )
}

#Preview("Create List View") {
    CreateSaveListView { list in
        print("Created list: \(list.name)")
    }
}

#Preview("List Selection Row - Selected") {
    let mockList = SavedList(
        name: "Favorite Restaurants",
        description: "My go-to dining spots",
        userId: "user1",
        isPrivate: false
    )
    
    return VStack(spacing: 12) {
        ListSelectionRow(list: mockList, isSelected: true) { }
        ListSelectionRow(list: mockList, isSelected: false) { }
    }
    .padding()
} 