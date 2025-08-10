//
//  CreatePostView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI
import PhotosUI
#if os(iOS)
import UIKit
import AVFoundation
#endif

struct CreatePostView: View {
    @StateObject private var viewModel = CreatePostViewModel()
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    @State private var showCamera = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Progress Indicator
                    HStack(spacing: 8) {
                        ForEach(0..<3) { index in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(index <= currentStep ? Color.primaryBrand : Color.gray.opacity(0.3))
                                .frame(height: 4)
                                .animation(.easeInOut, value: currentStep)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Content
                    TabView(selection: $currentStep) {
                        // Step 1: Media
                        MediaStepView(viewModel: viewModel)
                            .tag(0)
                        
                        // Step 2: Details
                        DetailsStepView(viewModel: viewModel)
                            .tag(1)
                        
                        // Step 3: Review
                        ReviewStepView(viewModel: viewModel)
                            .tag(2)
                    }
                    #if os(iOS)
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    #else
                    .tabViewStyle(.automatic)
                    #endif
                    
                    // Navigation Buttons
                    HStack(spacing: 16) {
                        if currentStep > 0 {
                            Button(action: { 
                                HapticManager.shared.impact(.light)
                                withAnimation {
                                    currentStep -= 1
                                }
                            }) {
                                Label("Back", systemImage: "chevron.left")
                                    .font(.headline)
                                    .foregroundColor(.primaryBrand)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.primaryBrand, lineWidth: 2)
                                    )
                            }
                        }
                        
                        Button(action: {
                            if currentStep < 2 {
                                HapticManager.shared.impact(.light)
                                withAnimation {
                                    currentStep += 1
                                }
                            } else {
                                HapticManager.shared.impact(.success)
                                Task {
                                    await viewModel.createPost(appState: appState)
                                }
                            }
                        }) {
                            HStack {
                                if viewModel.isLoading && currentStep == 2 {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                Text(currentStep < 2 ? "Next" : (viewModel.isLoading ? "Creating..." : "Share"))
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 24)
                            .background(viewModel.isLoading && currentStep == 2 ? Color.primaryBrand.opacity(0.7) : Color.primaryBrand)
                            .cornerRadius(16)
                        }
                        .disabled(
                            viewModel.isLoading ||
                            (currentStep == 0 && viewModel.selectedImages.isEmpty) ||
                            (currentStep == 1 && viewModel.caption.isEmpty) ||
                            (currentStep == 2 && !viewModel.canPost)
                        )
                    }
                    .padding()
                }
                
                // Success Animation Overlay
                if viewModel.isSuccess {
                    PostCreationSuccessOverlay()
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.3).combined(with: .opacity),
                            removal: .scale(scale: 1.1).combined(with: .opacity)
                        ))
                        .onAppear {
                            // Auto-dismiss after animation
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    dismiss()
                                }
                            }
                        }
                }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationTitle("New post")
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error occurred")
            }
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
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryBrand)
                }
                #endif
            }
        }
    }
}

// MARK: - Media Step View
struct MediaStepView: View {
    @ObservedObject var viewModel: CreatePostViewModel
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var showNativePicker = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Media Grid
            if viewModel.selectedImages.isEmpty {
                // Empty State
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 60))
                        .foregroundColor(.milkTea)
                    
                    Text("Add up to 6 photos")
                        .font(.headline)
                        .foregroundColor(.secondaryText)
                    
                    HStack(spacing: 16) {
                        Button(action: { showCamera = true }) {
                            Label("Camera", systemImage: "camera.fill")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.vertical, 16)
                                .padding(.horizontal, 24)
                                .background(Color.primaryBrand)
                                .cornerRadius(16)
                        }
                        
                        Button(action: { showNativePicker = true }) {
                            Label("Library", systemImage: "photo.fill")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.primaryBrand)
                                .padding(.vertical, 16)
                                .padding(.horizontal, 24)
                                .background(Color.primaryBrand.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.primaryBrand, lineWidth: 2)
                                )
                                .cornerRadius(16)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Selected Images
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ], spacing: 12) {
                        ForEach(viewModel.selectedImages, id: \.self) { image in
                            ZStack(alignment: .topTrailing) {
                                #if os(iOS)
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(3/4, contentMode: .fill)
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                #else
                                Image(nsImage: image)
                                    .resizable()
                                    .aspectRatio(3/4, contentMode: .fill)
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                #endif
                                
                                Button(action: {
                                    HapticManager.shared.impact(.light)
                                    viewModel.removeImage(image)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.white)
                                        .background(Circle().fill(Color.black.opacity(0.6)))
                                }
                                .padding(8)
                            }
                        }
                        
                        if viewModel.selectedImages.count < 6 {
                            Button(action: { showNativePicker = true }) {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(height: 100)
                                    .overlay(
                                        Image(systemName: "plus")
                                            .font(.title2)
                                            .foregroundColor(.primaryBrand)
                                    )
                            }
                        }
                    }
                    .padding()
                }
            }
            
            Spacer()
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(images: $viewModel.selectedImages)
        }
        .sheet(isPresented: $showCamera) {
            #if os(iOS)
            NativeCameraPicker(images: $viewModel.selectedImages)
            #else
            ImagePicker(images: $viewModel.selectedImages)
            #endif
        }
        .sheet(isPresented: $showNativePicker) {
            NativePhotoPicker(selectedImages: $viewModel.selectedImages)
        }
    }
}

// MARK: - Details Step View
struct DetailsStepView: View {
    @ObservedObject var viewModel: CreatePostViewModel
    #if os(iOS)
    @FocusState private var isCaptionFocused: Bool
    #endif
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // Rating (moved to top)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 16) {
                        ForEach(1...5, id: \.self) { star in
                            Button(action: {
                                HapticManager.shared.impact(.light)
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    if viewModel.rating == Double(star) {
                                        viewModel.rating = nil
                                    } else {
                                        viewModel.rating = Double(star)
                                    }
                                }
                            }) {
                                Image(systemName: star <= Int(viewModel.rating ?? 0) ? "star.fill" : "star")
                                    .font(.title)
                                    .foregroundColor(.warning)
                                    .scaleEffect(star == Int(viewModel.rating ?? 0) ? 1.2 : 1.0)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(16)
                }
                
                // Product Name Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("What's your pick?")
                        .font(.headline)
                        .foregroundColor(.primaryText)
                    
                    TextField("Enter product name", text: $viewModel.productName)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(16)
                }
                
                // Food Category Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Food Category")
                        .font(.headline)
                        .foregroundColor(.primaryText)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(FoodCategory.allCases, id: \.self) { category in
                            FoodCategorySelectionChip(
                                category: category,
                                isSelected: viewModel.selectedFoodCategory == category
                            ) {
                                viewModel.selectedFoodCategory = category
                                HapticManager.shared.impact(.light)
                            }
                        }
                    }
                    
                    if viewModel.selectedFoodCategory != nil {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            
                            Text("Category selected: \(viewModel.selectedFoodCategory?.displayName ?? "")")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                        .padding(.top, 4)
                    }
                }
                
                // Caption
                VStack(alignment: .leading, spacing: 8) {
                    Text("How's your drink?")
                        .font(.headline)
                        .foregroundColor(.primaryText)
                    
                    TextEditor(text: $viewModel.caption)
                        #if os(iOS)
                        .focused($isCaptionFocused)
                        #endif
                        .frame(minHeight: 120)
                        .padding(12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(16)
                        .scrollContentBackground(.hidden)
                        .overlay(alignment: .topLeading) {
                            if viewModel.caption.isEmpty {
                                Text("Share your thoughts...")
                                    .foregroundColor(.tertiaryText)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 20)
                                    .allowsHitTesting(false)
                            }
                        }
                }
                
                // Location
                Button(action: { viewModel.showLocationPicker = true }) {
                    HStack {
                        Image(systemName: "location.fill")
                            .font(.title3)
                            .foregroundColor(.primaryBrand)
                            .frame(width: 40, height: 40)
                            .background(Color.matchaGreen.opacity(0.2))
                            .cornerRadius(12)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Location")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                            Text(viewModel.selectedLocation?.displayName ?? "Add location")
                                .font(.subheadline)
                                .foregroundColor(.primaryText)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.tertiaryText)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(16)
                }
                .buttonStyle(.plain)
                
                Spacer(minLength: 100)
            }
            .padding()
        }
        .sheet(isPresented: $viewModel.showLocationPicker) {
            LocationPickerView(selectedLocation: $viewModel.selectedLocation)
        }
        #if os(iOS)
        .onTapGesture {
            isCaptionFocused = false
        }
        #endif
    }
}

// MARK: - Review Step View
struct ReviewStepView: View {
    @ObservedObject var viewModel: CreatePostViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Title
                VStack(spacing: 8) {
                    Text("Review Post")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primaryText)
                    Text("Make sure everything looks good")
                        .font(.subheadline)
                        .foregroundColor(.warmAccentText)
                }
                .padding(.top, 32)
                
                // Preview Card
                VStack(spacing: 16) {
                    // Images Preview
                    if !viewModel.selectedImages.isEmpty {
                        TabView {
                            ForEach(viewModel.selectedImages, id: \.self) { image in
                                #if os(iOS)
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 300)
                                    .clipped()
                                #else
                                Image(nsImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 300)
                                    .clipped()
                                #endif
                            }
                        }
                        #if os(iOS)
                        .tabViewStyle(.page)
                        #else
                        .tabViewStyle(.automatic)
                        #endif
                        .frame(height: 300)
                        .cornerRadius(16)
                    }
                    
                    // Details
                    VStack(alignment: .leading, spacing: 12) {
                        // Caption
                        Text(viewModel.caption)
                            .font(.body)
                            .foregroundColor(.primaryText)
                        
                        // Location
                        if let location = viewModel.selectedLocation {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.secondaryText)
                                Text(location.displayName)
                                    .font(.caption)
                                    .foregroundColor(.secondaryText)
                            }
                        }
                        
                        // Rating
                        if let rating = viewModel.rating {
                            HStack(spacing: 4) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= Int(rating) ? "star.fill" : "star")
                                        .font(.caption)
                                        .foregroundColor(.warning)
                                }
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                }
                
                Spacer(minLength: 100)
            }
            .padding()
        }
    }
}

// MARK: - Media Selection Section
struct MediaSelectionSection: View {
    @ObservedObject var viewModel: CreatePostViewModel
    @State private var showImagePicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Photos")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Add Photo Button
                    Button(action: { showImagePicker = true }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: 100, height: 100)
                            
                            VStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.title2)
                                Text("Add")
                                    .font(.caption)
                            }
                            .foregroundColor(.primaryBrand)
                        }
                    }
                    
                    // Selected Images
                    ForEach(viewModel.selectedImages, id: \.self) { image in
                        ZStack(alignment: .topTrailing) {
                            #if os(iOS)
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            #else
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            #endif
                            
                            Button(action: {
                                viewModel.removeImage(image)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.black.opacity(0.5)))
                            }
                            .padding(4)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(images: $viewModel.selectedImages)
        }
    }
}

// MARK: - Caption Section
struct CaptionSection: View {
    @Binding var caption: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Caption")
                .font(.headline)
            
            TextEditor(text: $caption)
                .frame(minHeight: 100)
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .scrollContentBackground(.hidden)
        }
    }
}

// MARK: - Location Section
struct LocationSection: View {
    @ObservedObject var viewModel: CreatePostViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.primaryBrand)
                Text("Location")
                    .font(.headline)
            }
            
            HStack {
                if let location = viewModel.selectedLocation {
                    Text(location.formattedAddress)
                        .font(.subheadline)
                        .foregroundColor(.primaryText)
                    
                    Spacer()
                    
                    Button("Change") {
                        viewModel.showLocationPicker = true
                    }
                    .font(.caption)
                    .foregroundColor(.primaryBrand)
                } else {
                    Button("Add Location") {
                        viewModel.showLocationPicker = true
                    }
                    .foregroundColor(.primaryBrand)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

// MARK: - Menu Items Section
struct MenuItemsSection: View {
    @ObservedObject var viewModel: CreatePostViewModel
    @State private var newMenuItem = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "menucard.fill")
                    .foregroundColor(.primaryBrand)
                Text("Menu Items")
                    .font(.headline)
            }
            
            // Added Items
            if !viewModel.menuItems.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(viewModel.menuItems, id: \.self) { item in
                        HStack(spacing: 4) {
                            Text(item)
                                .font(.caption)
                            Button(action: { viewModel.removeMenuItem(item) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption2)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.matchaGreen.opacity(0.2))
                        .foregroundColor(.primaryText)
                        .cornerRadius(20)
                    }
                }
            }
            
            // Add Item Field
            HStack {
                TextField("Add menu item", text: $newMenuItem)
                    .textFieldStyle(.plain)
                
                Button(action: {
                    if !newMenuItem.isEmpty {
                        viewModel.addMenuItem(newMenuItem)
                        newMenuItem = ""
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.primaryBrand)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

// MARK: - Rating Section
struct RatingSection: View {
    @Binding var rating: Double?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.warning)
                Text("Rating")
                    .font(.headline)
            }
            
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { star in
                    Button(action: {
                        if rating == Double(star) {
                            rating = nil
                        } else {
                            rating = Double(star)
                        }
                    }) {
                        Image(systemName: star <= Int(rating ?? 0) ? "star.fill" : "star")
                            .font(.title2)
                            .foregroundColor(.warning)
                    }
                }
                
                Spacer()
                
                if rating != nil {
                    Button("Clear") {
                        rating = nil
                    }
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                }
            }
        }
    }
}

// FlowLayout is defined in UIComponents.swift

// MARK: - Image Picker
#if os(iOS)
struct ImagePicker: View {
    @Binding var images: [UIImage]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedImages: Set<String> = []
    @State private var availableImages: [UIImage] = []
    @State private var showSortOptions = false
    @State private var showFilterOptions = false
    @State private var searchText = ""
    @State private var currentTab: PhotoTab = .photos
    
    enum PhotoTab {
        case photos, collections
    }
    
    var filteredPhotoIndices: [Int] {
        let baseIndices: [Int]
        
        switch currentTab {
        case .photos:
            baseIndices = Array(0..<12) // Regular photos
        case .collections:
            baseIndices = Array(12..<24) // Collections (different set)
        }
        
        if searchText.isEmpty {
            return baseIndices
        } else {
            // Simple filter simulation - in real app, this would filter by metadata
            return baseIndices.filter { index in
                String(index).contains(searchText) || 
                (searchText.lowercased().contains("photo") && currentTab == .photos) ||
                (searchText.lowercased().contains("collection") && currentTab == .collections)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                searchBarView
                
                // Photo Grid
                photoGridView
                
                // Bottom Selection Info
                bottomSelectionInfoView
            }
            .background(Color.background)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showSortOptions) {
                SortOptionsSheet(
                    showSortOptions: $showSortOptions, 
                    selectedImages: $selectedImages
                )
            }
            .sheet(isPresented: $showFilterOptions) {
                FilterOptionsSheet(
                    showFilterOptions: $showFilterOptions,
                    selectedImages: $selectedImages,
                    filteredPhotoIndices: filteredPhotoIndices
                )
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    cancelButton
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    addButton
                }
                
                ToolbarItem(placement: .principal) {
                    tabSelectorView
                }
            }
        }
    }
    
    private var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondaryText)
                .font(.system(size: 16))
            
            TextField("Search your library...", text: $searchText)
                .foregroundColor(.primaryText)
                .font(.system(size: 16))
                .textFieldStyle(PlainTextFieldStyle())
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    HapticManager.shared.impact(.light)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondaryText)
                        .font(.system(size: 16))
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .padding()
    }
    
    private var photoGridView: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
                ForEach(filteredPhotoIndices, id: \.self) { index in
                    photoItemView(for: index)
                }
            }
        }
        .background(Color.background)
    }
    
    private func photoItemView(for index: Int) -> some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                VStack(spacing: 4) {
                    Image(systemName: currentTab == .photos ? "photo" : "rectangle.stack")
                        .foregroundColor(.secondaryText)
                        .font(.title)
                    
                    if currentTab == .collections {
                        Text("Collection \(index - 11)")
                            .font(.caption2)
                            .foregroundColor(.tertiaryText)
                    }
                }
            )
            .overlay(alignment: .topTrailing) {
                if selectedImages.contains("\(index)") {
                    Circle()
                        .fill(Color.primaryBrand)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "checkmark")
                                .foregroundColor(.white)
                                .font(.caption)
                                .fontWeight(.bold)
                        )
                        .padding(8)
                }
            }
            .onTapGesture {
                HapticManager.shared.impact(.light)
                if selectedImages.contains("\(index)") {
                    selectedImages.remove("\(index)")
                } else if selectedImages.count < 6 {
                    selectedImages.insert("\(index)")
                }
            }
    }
    
    private var bottomSelectionInfoView: some View {
        HStack {
            Button(action: {
                HapticManager.shared.impact(.light)
                showSortOptions = true
            }) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 18))
                    .foregroundColor(.primaryBrand)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Text("Select Photos")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                if !selectedImages.isEmpty {
                    Text("(\(selectedImages.count))")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryBrand)
                }
            }
            
            Spacer()
            
            Button(action: {
                HapticManager.shared.impact(.light)
                showFilterOptions = true
            }) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18))
                    .foregroundColor(.primaryBrand)
            }
        }
        .padding()
        .background(Color.background)
    }
    
    private var cancelButton: some View {
        Button("Cancel") {
            dismiss()
        }
        .foregroundColor(.primaryBrand)
        .font(.system(size: 16, weight: .semibold))
    }
    
    private var addButton: some View {
        Button("Add") {
            // Add selected mock images
            for _ in 0..<selectedImages.count {
                if let mockImage = createMockImage() {
                    images.append(mockImage)
                }
            }
            dismiss()
        }
        .foregroundColor(selectedImages.isEmpty ? .tertiaryText : .primaryBrand)
        .font(.system(size: 16, weight: .semibold))
        .disabled(selectedImages.isEmpty)
    }
    
    private var tabSelectorView: some View {
        HStack(spacing: 20) {
            Button("Photos") {
                currentTab = .photos
                HapticManager.shared.impact(.light)
            }
            .foregroundColor(currentTab == .photos ? .primaryText : .secondaryText)
            .font(.system(size: 16, weight: .semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(currentTab == .photos ? Color.cardBackground : Color.clear)
            .cornerRadius(20)
            
            Button("Collections") {
                currentTab = .collections
                HapticManager.shared.impact(.light)
            }
            .foregroundColor(currentTab == .collections ? .primaryText : .secondaryText)
            .font(.system(size: 16, weight: .semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(currentTab == .collections ? Color.cardBackground : Color.clear)
            .cornerRadius(20)
        }
    }
    
    private func createMockImage() -> UIImage? {
        let size = CGSize(width: 400, height: 400)
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(UIColor.systemGray4.cgColor)
        context?.fill(CGRect(origin: .zero, size: size))
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
#else
// Placeholder for macOS
struct ImagePicker: View {
    @Binding var images: [UIImage]
    
    var body: some View {
        Text("Image picker not available on macOS")
            .foregroundColor(.secondaryText)
            .padding()
    }
}

typealias UIImage = NSImage
#endif

// MARK: - Image Upload Service (Removed - Using BunnyNetService from Utilities instead)

// MARK: - Native Photo Picker
#if os(iOS)
import PhotosUI

struct NativePhotoPicker: UIViewControllerRepresentable {
    @Binding var selectedImages: [UIImage]
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 6
        configuration.preferredAssetRepresentationMode = .current
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: NativePhotoPicker
        
        init(_ parent: NativePhotoPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            
            guard !results.isEmpty else { return }
            
            for result in results {
                let itemProvider = result.itemProvider
                
                if itemProvider.canLoadObject(ofClass: UIImage.self) {
                    itemProvider.loadObject(ofClass: UIImage.self) { image, error in
                        DispatchQueue.main.async {
                            if let uiImage = image as? UIImage {
                                self.parent.selectedImages.append(uiImage)
                            }
                        }
                    }
                }
            }
        }
    }
}
#else
// Placeholder for macOS
struct NativePhotoPicker: View {
    @Binding var selectedImages: [UIImage]
    
    var body: some View {
        Text("Native photo picker not available on macOS")
            .foregroundColor(.secondaryText)
            .padding()
    }
}
#endif
// MARK: - View Model
@MainActor
class CreatePostViewModel: ObservableObject {
    @Published var selectedImages: [UIImage] = []
    @Published var caption = ""
    @Published var productName = ""
    @Published var selectedLocation: Location?
    @Published var menuItems: [String] = []
    @Published var rating: Double?
    @Published var selectedFoodCategory: FoodCategory?
    @Published var showLocationPicker = false
    @Published var showShopPicker = false
    @Published var isLoading = false
    @Published var isSuccess = false
    @Published var errorMessage: String?
    
    private let backendService = BackendService.shared
    private let bunnyNetService = BunnyNetService.shared
    
    var canPost: Bool {
        !selectedImages.isEmpty && !caption.isEmpty && selectedLocation != nil && rating != nil && selectedFoodCategory != nil
    }
    
    func removeImage(_ image: UIImage) {
        selectedImages.removeAll { $0 == image }
    }
    
    func addMenuItem(_ item: String) {
        if !menuItems.contains(item) {
            menuItems.append(item)
        }
    }
    
    func removeMenuItem(_ item: String) {
        menuItems.removeAll { $0 == item }
    }
    
    @MainActor
    func createPost(appState: AppState? = nil) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Validate inputs
            guard let location = selectedLocation else {
                throw NSError(domain: "CreatePost", code: 1, userInfo: [NSLocalizedDescriptionKey: "Please select a location"])
            }
            
            guard let rating = rating else {
                throw NSError(domain: "CreatePost", code: 2, userInfo: [NSLocalizedDescriptionKey: "Please provide a rating"])
            }
            
            // Upload images to BunnyCDN first
            let imageUrls = await uploadImages()
            
            guard !imageUrls.isEmpty else {
                throw NSError(domain: "CreatePost", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to upload images"])
            }
            
            // Remove duplicates from imageUrls before sending
            let uniqueImageUrls = Array(Set(imageUrls))
            
            // Get the authenticated user ID
            guard let currentUser = appState?.currentUser,
                  let clerkId = currentUser.clerkId else {
                throw NSError(domain: "CreatePost", code: 4, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            }
            
            // Create post using the correct function parameters
            let postId = try await backendService.createPostViaConvex(
                userId: clerkId,
                title: productName.isEmpty ? nil : productName,
                content: caption,
                imageUrl: uniqueImageUrls.first,
                imageUrls: uniqueImageUrls,
                location: location,
                tags: menuItems,
                isPublic: true,
                metadata: BackendService.ConvexPostMetadata(
                    category: selectedFoodCategory?.rawValue ?? "food",
                    rating: rating
                )
            )
            
            print("✅ CreatePost: Successfully created post with ID: \(postId)")
            
            // Play success sound for post creation
            // SoundManager.shared.playSuccessSound()
            
            // Update app state with new post if available
            if let appState = appState {
                Task { @MainActor in
                    // Refresh the home view to show the new post immediately
                    appState.homeViewModel.refreshPosts()
                    
                    // Notify HomeView and other views to refresh via NotificationCenter
                    NotificationCenter.default.post(name: NSNotification.Name("NewPostCreated"), object: nil)
                    
                    // Also refresh user's posts in profile/explore
                    if let currentUser = appState.currentUser,
                       let clerkId = currentUser.clerkId {
                        // Refresh user's posts in any view models that might be active
                        NotificationCenter.default.post(
                            name: NSNotification.Name("UserPostsUpdated"),
                            object: nil,
                            userInfo: ["userId": clerkId]
                        )
                    }
                }
            }
            
            isLoading = false
            
            // Show success animation
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isSuccess = true
            }
            
            // Success haptic feedback
            HapticManager.shared.impact(.success)
            
            // Clear form on success
            clearForm()
            
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    private func uploadImages() async -> [String] {
        var uploadedUrls: [String] = []
        
        await withTaskGroup(of: (Int, String?).self) { group in
            for (index, image) in selectedImages.enumerated() {
                group.addTask { [bunnyNetService] in
                    return await withCheckedContinuation { continuation in
                        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                            print("❌ Failed to convert image \(index) to data")
                            continuation.resume(returning: (index, nil))
                            return
                        }
                        
                        let fileName = "post_\(UUID().uuidString).jpg"
                        
                        bunnyNetService.uploadImage(data: imageData, fileName: fileName) { response in
                            if response.success, let url = response.url {
                                print("✅ Uploaded image \(index): \(url)")
                                continuation.resume(returning: (index, url))
                            } else {
                                print("❌ Failed to upload image \(index): \(response.error ?? "Unknown error")")
                                continuation.resume(returning: (index, nil))
                            }
                        }
                    }
                }
            }
            
            // Collect results in order
            var results: [(Int, String?)] = []
            for await result in group {
                results.append(result)
            }
            
            // Sort by index and extract URLs
            uploadedUrls = results
                .sorted { $0.0 < $1.0 }
                .compactMap { $0.1 }
        }
        
        return uploadedUrls
    }
    
    private func clearForm() {
        selectedImages = []
        caption = ""
        productName = ""
        selectedLocation = nil
        menuItems = []
        rating = nil
        selectedFoodCategory = nil
    }
}

// MARK: - Native Camera Picker (iOS)
#if os(iOS)
struct NativeCameraPicker: UIViewControllerRepresentable {
    @Binding var images: [UIImage]
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: NativeCameraPicker
        
        init(_ parent: NativeCameraPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.images.append(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
#endif

// MARK: - Sort Options Sheet
struct SortOptionsSheet: View {
    @Binding var showSortOptions: Bool
    @Binding var selectedImages: Set<String>
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    showSortOptions = false
                }
                .foregroundColor(.primaryBrand)
                .font(.system(size: 16, weight: .semibold))
                
                Spacer()
                
                Text("Sort Photos")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                Spacer()
                
                // Invisible button for balance
                Button("Cancel") {
                    showSortOptions = false
                }
                .opacity(0)
            }
            .padding()
            .background(Color.background)
            
            Divider()
            
            // Options
            VStack(spacing: 0) {
                Button(action: {
                    let sortedIds = selectedImages.compactMap { Int($0) }.sorted()
                    selectedImages.removeAll()
                    for id in sortedIds {
                        selectedImages.insert("\(id)")
                    }
                    HapticManager.shared.impact(.light)
                    showSortOptions = false
                }) {
                    HStack {
                        Image(systemName: "arrow.up")
                            .foregroundColor(.primaryText)
                            .frame(width: 24)
                        Text("Sort Oldest First")
                            .foregroundColor(.primaryText)
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                    }
                    .padding()
                    .background(Color.background)
                }
                
                Divider()
                
                Button(action: {
                    let sortedIds = selectedImages.compactMap { Int($0) }.sorted(by: >)
                    selectedImages.removeAll()
                    for id in sortedIds {
                        selectedImages.insert("\(id)")
                    }
                    HapticManager.shared.impact(.light)
                    showSortOptions = false
                }) {
                    HStack {
                        Image(systemName: "arrow.down")
                            .foregroundColor(.primaryText)
                            .frame(width: 24)
                        Text("Sort Newest First")
                            .foregroundColor(.primaryText)
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                    }
                    .padding()
                    .background(Color.background)
                }
            }
            
            Spacer()
        }
        .background(Color.background)
        .presentationDetents([.height(240)])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Filter Options Sheet
struct FilterOptionsSheet: View {
    @Binding var showFilterOptions: Bool
    @Binding var selectedImages: Set<String>
    let filteredPhotoIndices: [Int]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    showFilterOptions = false
                }
                .foregroundColor(.primaryBrand)
                .font(.system(size: 16, weight: .semibold))
                
                Spacer()
                
                Text("Filter Options")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryText)
                
                Spacer()
                
                // Invisible button for balance
                Button("Cancel") {
                    showFilterOptions = false
                }
                .opacity(0)
            }
            .padding()
            .background(Color.background)
            
            Divider()
            
            // Options
            VStack(spacing: 0) {
                Button(action: {
                    selectedImages.removeAll()
                    HapticManager.shared.impact(.light)
                    showFilterOptions = false
                }) {
                    HStack {
                        Image(systemName: "xmark.circle")
                            .foregroundColor(.primaryText)
                            .frame(width: 24)
                        Text("Clear All Selections")
                            .foregroundColor(.primaryText)
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                    }
                    .padding()
                    .background(Color.background)
                }
                
                Divider()
                
                Button(action: {
                    let allImages = Set(filteredPhotoIndices.map { "\($0)" })
                    selectedImages = allImages.subtracting(selectedImages)
                    HapticManager.shared.impact(.light)
                    showFilterOptions = false
                }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.primaryText)
                            .frame(width: 24)
                        Text("Invert Selection")
                            .foregroundColor(.primaryText)
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                    }
                    .padding()
                    .background(Color.background)
                }
            }
            
            Spacer()
        }
        .background(Color.background)
        .presentationDetents([.height(260)])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Food Category Selection Chip
struct FoodCategorySelectionChip: View {
    let category: FoodCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(category.icon)
                    .font(.title3)
                
                Text(category.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.primaryBrand : Color.gray.opacity(0.1))
            )
            .foregroundColor(isSelected ? .white : .primaryText)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Post Creation Success Overlay
struct PostCreationSuccessOverlay: View {
    @State private var checkmarkScale: CGFloat = 0.0
    @State private var checkmarkOpacity: Double = 0.0
    @State private var circleScale: CGFloat = 0.0
    @State private var circleOpacity: Double = 0.0
    @State private var titleOffset: CGFloat = 50
    @State private var titleOpacity: Double = 0.0
    @State private var subtitleOffset: CGFloat = 50
    @State private var subtitleOpacity: Double = 0.0
    @State private var confettiTrigger = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var backgroundOpacity: Double = 0.0
    
    var body: some View {
        ZStack {
            // Background blur overlay
            Color.black.opacity(0.4)
                .opacity(backgroundOpacity)
                .ignoresSafeArea()
                .onTapGesture { } // Prevent interaction
            
            VStack(spacing: 24) {
                Spacer()
                
                // Main success animation container
                ZStack {
                    // Outer pulse ring
                    Circle()
                        .stroke(Color.primaryBrand.opacity(0.3), lineWidth: 3)
                        .frame(width: 140, height: 140)
                        .scaleEffect(pulseScale)
                        .opacity(circleOpacity)
                    
                    // Middle ring
                    Circle()
                        .stroke(Color.primaryBrand.opacity(0.5), lineWidth: 2)
                        .frame(width: 120, height: 120)
                        .scaleEffect(circleScale)
                        .opacity(circleOpacity)
                    
                    // Main circle background
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.primaryBrand, .primaryBrand.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .scaleEffect(circleScale)
                        .opacity(circleOpacity)
                        .shadow(color: .primaryBrand.opacity(0.4), radius: 20, x: 0, y: 10)
                    
                    // Checkmark
                    Image(systemName: "checkmark")
                        .font(.system(size: 45, weight: .bold))
                        .foregroundColor(.white)
                        .scaleEffect(checkmarkScale)
                        .opacity(checkmarkOpacity)
                }
                
                // Success text
                VStack(spacing: 12) {
                    Text("Post Created!")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primaryText)
                        .offset(y: titleOffset)
                        .opacity(titleOpacity)
                    
                    Text("Your post has been shared with the community")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.center)
                        .offset(y: subtitleOffset)
                        .opacity(subtitleOpacity)
                }
                .padding(.horizontal, 40)
                
                Spacer()
            }
            
            // Confetti animation
            if confettiTrigger {
                ConfettiView()
            }
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        // Background fade in
        withAnimation(.easeOut(duration: 0.2)) {
            backgroundOpacity = 1.0
        }
        
        // Step 1: Circle and pulse animation (0.0s)
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            circleScale = 1.0
            circleOpacity = 1.0
        }
        
        // Step 2: Pulse ring animation (0.1s delay)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                pulseScale = 1.2
            }
            
            // Continuous pulse
            Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 1.5)) {
                    pulseScale = pulseScale == 1.0 ? 1.2 : 1.0
                }
            }
        }
        
        // Step 3: Checkmark animation (0.3s delay)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                checkmarkScale = 1.0
                checkmarkOpacity = 1.0
            }
            
            // Checkmark bounce effect
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                    checkmarkScale = 1.1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        checkmarkScale = 1.0
                    }
                }
            }
        }
        
        // Step 4: Title animation (0.6s delay)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                titleOffset = 0
                titleOpacity = 1.0
            }
        }
        
        // Step 5: Subtitle animation (0.8s delay)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                subtitleOffset = 0
                subtitleOpacity = 1.0
            }
        }
        
        // Step 6: Confetti animation (1.0s delay)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            confettiTrigger = true
        }
    }
}

// MARK: - Confetti Animation View
struct ConfettiView: View {
    @State private var confettiPieces: [ConfettiPiece] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(confettiPieces, id: \.id) { piece in
                    ConfettiPieceView(piece: piece)
                }
            }
            .onAppear {
                generateConfetti(in: geometry.size)
            }
        }
    }
    
    private func generateConfetti(in size: CGSize) {
        let colors: [Color] = [.primaryBrand, .milkTea, .warning, .matchaGreen, .pink, .orange]
        
        for _ in 0..<30 {
            let piece = ConfettiPiece(
                id: UUID(),
                color: colors.randomElement() ?? .primaryBrand,
                x: Double.random(in: 0...size.width),
                y: -20,
                rotation: Double.random(in: 0...360),
                scale: Double.random(in: 0.5...1.0)
            )
            confettiPieces.append(piece)
        }
        
        // Animate confetti falling
        for (index, _) in confettiPieces.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0...0.5)) {
                withAnimation(.linear(duration: Double.random(in: 2...4))) {
                    confettiPieces[index].y = size.height + 50
                    confettiPieces[index].rotation += Double.random(in: 360...720)
                }
            }
        }
    }
}

// MARK: - Confetti Piece Model and View
struct ConfettiPiece {
    let id: UUID
    let color: Color
    var x: Double
    var y: Double
    var rotation: Double
    var scale: Double
}

struct ConfettiPieceView: View {
    let piece: ConfettiPiece
    
    var body: some View {
        Rectangle()
            .fill(piece.color)
            .frame(width: 8, height: 8)
            .scaleEffect(piece.scale)
            .rotationEffect(.degrees(piece.rotation))
            .position(x: piece.x, y: piece.y)
    }
}

#Preview {
    CreatePostView()
        .environmentObject(MockAppState())
} 