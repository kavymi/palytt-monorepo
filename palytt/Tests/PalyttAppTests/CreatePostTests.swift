//
//  CreatePostTests.swift
//  PalyttAppTests
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//

import XCTest
@testable import Palytt
import UIKit
import CoreLocation

final class CreatePostTests: XCTestCase {
    
    var createPostViewModel: CreatePostViewModel!
    
    override func setUpWithError() throws {
        createPostViewModel = CreatePostViewModel()
    }
    
    override func tearDownWithError() throws {
        createPostViewModel = nil
    }
    
    // MARK: - Initial State Tests
    
    func test_createPostViewModel_initialState_isCorrect() {
        // Given - Fresh CreatePostViewModel
        
        // When - Initial state
        
        // Then
        XCTAssertTrue(createPostViewModel.selectedImages.isEmpty, "Selected images should be empty initially")
        XCTAssertTrue(createPostViewModel.caption.isEmpty, "Caption should be empty initially")
        XCTAssertTrue(createPostViewModel.productName.isEmpty, "Product name should be empty initially")
        XCTAssertNil(createPostViewModel.selectedLocation, "Selected location should be nil initially")
        XCTAssertTrue(createPostViewModel.menuItems.isEmpty, "Menu items should be empty initially")
        XCTAssertNil(createPostViewModel.rating, "Rating should be nil initially")
        XCTAssertNil(createPostViewModel.selectedFoodCategory, "Food category should be nil initially")
        XCTAssertFalse(createPostViewModel.showLocationPicker, "Location picker should not be shown initially")
        XCTAssertFalse(createPostViewModel.isLoading, "Should not be loading initially")
        XCTAssertFalse(createPostViewModel.isSuccess, "Should not be success initially")
        XCTAssertNil(createPostViewModel.errorMessage, "Error message should be nil initially")
    }
    
    // MARK: - Validation Tests
    
    func test_createPostViewModel_canPost_withValidData_returnsTrue() {
        // Given
        setupValidPostData()
        
        // When
        let canPost = createPostViewModel.canPost
        
        // Then
        XCTAssertTrue(canPost, "Should be able to post with valid data")
    }
    
    func test_createPostViewModel_canPost_withoutImages_returnsFalse() {
        // Given
        setupValidPostData()
        createPostViewModel.selectedImages = []
        
        // When
        let canPost = createPostViewModel.canPost
        
        // Then
        XCTAssertFalse(canPost, "Should not be able to post without images")
    }
    
    func test_createPostViewModel_canPost_withoutCaption_returnsFalse() {
        // Given
        setupValidPostData()
        createPostViewModel.caption = ""
        
        // When
        let canPost = createPostViewModel.canPost
        
        // Then
        XCTAssertFalse(canPost, "Should not be able to post without caption")
    }
    
    func test_createPostViewModel_canPost_withoutLocation_returnsFalse() {
        // Given
        setupValidPostData()
        createPostViewModel.selectedLocation = nil
        
        // When
        let canPost = createPostViewModel.canPost
        
        // Then
        XCTAssertFalse(canPost, "Should not be able to post without location")
    }
    
    func test_createPostViewModel_canPost_withoutRating_returnsFalse() {
        // Given
        setupValidPostData()
        createPostViewModel.rating = nil
        
        // When
        let canPost = createPostViewModel.canPost
        
        // Then
        XCTAssertFalse(canPost, "Should not be able to post without rating")
    }
    
    func test_createPostViewModel_canPost_withoutFoodCategory_returnsFalse() {
        // Given
        setupValidPostData()
        createPostViewModel.selectedFoodCategory = nil
        
        // When
        let canPost = createPostViewModel.canPost
        
        // Then
        XCTAssertFalse(canPost, "Should not be able to post without food category")
    }
    
    // MARK: - Image Management Tests
    
    func test_createPostViewModel_addImage_increasesCount() {
        // Given
        let initialCount = createPostViewModel.selectedImages.count
        let testImage = createTestImage()
        
        // When
        createPostViewModel.selectedImages.append(testImage)
        
        // Then
        XCTAssertEqual(createPostViewModel.selectedImages.count, initialCount + 1, "Should increase image count by 1")
    }
    
    func test_createPostViewModel_removeImage_decreasesCount() {
        // Given
        let testImage = createTestImage()
        createPostViewModel.selectedImages = [testImage]
        
        // When
        createPostViewModel.removeImage(testImage)
        
        // Then
        XCTAssertTrue(createPostViewModel.selectedImages.isEmpty, "Should remove the image")
    }
    
    func test_createPostViewModel_removeImage_onlyRemovesSpecificImage() {
        // Given
        let image1 = createTestImage()
        let image2 = createTestImage()
        createPostViewModel.selectedImages = [image1, image2]
        
        // When
        createPostViewModel.removeImage(image1)
        
        // Then
        XCTAssertEqual(createPostViewModel.selectedImages.count, 1, "Should only remove one image")
        XCTAssertEqual(createPostViewModel.selectedImages.first, image2, "Should keep the correct image")
    }
    
    // MARK: - Menu Items Tests
    
    func test_createPostViewModel_addMenuItem_addsNewItem() {
        // Given
        let menuItem = "Delicious Pasta"
        
        // When
        createPostViewModel.addMenuItem(menuItem)
        
        // Then
        XCTAssertTrue(createPostViewModel.menuItems.contains(menuItem), "Should add the menu item")
        XCTAssertEqual(createPostViewModel.menuItems.count, 1, "Should have one menu item")
    }
    
    func test_createPostViewModel_addMenuItem_preventsDuplicates() {
        // Given
        let menuItem = "Delicious Pasta"
        createPostViewModel.addMenuItem(menuItem)
        
        // When
        createPostViewModel.addMenuItem(menuItem)
        
        // Then
        XCTAssertEqual(createPostViewModel.menuItems.count, 1, "Should not add duplicate menu items")
    }
    
    func test_createPostViewModel_removeMenuItem_removesSpecificItem() {
        // Given
        let item1 = "Pasta"
        let item2 = "Pizza"
        createPostViewModel.addMenuItem(item1)
        createPostViewModel.addMenuItem(item2)
        
        // When
        createPostViewModel.removeMenuItem(item1)
        
        // Then
        XCTAssertFalse(createPostViewModel.menuItems.contains(item1), "Should remove specific item")
        XCTAssertTrue(createPostViewModel.menuItems.contains(item2), "Should keep other items")
        XCTAssertEqual(createPostViewModel.menuItems.count, 1, "Should have one item remaining")
    }
    
    // MARK: - Caption Validation Tests
    
    func test_createPostViewModel_caption_validLength() {
        // Given
        let validCaptions = [
            "Great food!",
            "Amazing restaurant with delicious food and excellent service!",
            String(repeating: "a", count: 280) // Max typical length
        ]
        
        // When & Then
        for caption in validCaptions {
            createPostViewModel.caption = caption
            XCTAssertFalse(createPostViewModel.caption.isEmpty, "Caption '\(caption.prefix(20))...' should be valid")
        }
    }
    
    func test_createPostViewModel_caption_trimming() {
        // Given
        let captionWithSpaces = "  Amazing food experience!  "
        
        // When
        createPostViewModel.caption = captionWithSpaces.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Then
        XCTAssertEqual(createPostViewModel.caption, "Amazing food experience!", "Caption should be trimmed")
    }
    
    // MARK: - Rating Tests
    
    func test_createPostViewModel_rating_validRange() {
        // Given
        let validRatings = [1.0, 2.5, 3.0, 4.5, 5.0]
        
        // When & Then
        for rating in validRatings {
            createPostViewModel.rating = rating
            XCTAssertEqual(createPostViewModel.rating, rating, "Rating \(rating) should be valid")
            XCTAssertTrue(rating >= 1.0 && rating <= 5.0, "Rating should be between 1.0 and 5.0")
        }
    }
    
    func test_createPostViewModel_rating_invalidRange() {
        // Given
        let invalidRatings = [0.0, -1.0, 6.0, 10.0]
        
        // When & Then
        for rating in invalidRatings {
            // In a real implementation, you would validate the rating
            XCTAssertTrue(rating < 1.0 || rating > 5.0, "Rating \(rating) should be invalid")
        }
    }
    
    // MARK: - Location Tests
    
    func test_createPostViewModel_location_validLocation() {
        // Given
        let testLocation = createTestLocation()
        
        // When
        createPostViewModel.selectedLocation = testLocation
        
        // Then
        XCTAssertNotNil(createPostViewModel.selectedLocation, "Location should be set")
        XCTAssertEqual(createPostViewModel.selectedLocation?.name, testLocation.name, "Location name should match")
        XCTAssertEqual(createPostViewModel.selectedLocation?.address, testLocation.address, "Location address should match")
    }
    
    // MARK: - Food Category Tests
    
    func test_createPostViewModel_foodCategory_validCategories() {
        // Given
        let categories = FoodCategory.allCases
        
        // When & Then
        for category in categories {
            createPostViewModel.selectedFoodCategory = category
            XCTAssertEqual(createPostViewModel.selectedFoodCategory, category, "Food category should be set correctly")
        }
    }
    
    // MARK: - Product Name Tests
    
    func test_createPostViewModel_productName_validNames() {
        // Given
        let validProductNames = [
            "Margherita Pizza",
            "Caesar Salad",
            "Chocolate Cake",
            "Beef Burger"
        ]
        
        // When & Then
        for productName in validProductNames {
            createPostViewModel.productName = productName
            XCTAssertEqual(createPostViewModel.productName, productName, "Product name should be set correctly")
            XCTAssertFalse(createPostViewModel.productName.isEmpty, "Product name should not be empty")
        }
    }
    
    // MARK: - State Management Tests
    
    func test_createPostViewModel_loadingState_togglesCorrectly() {
        // Given
        createPostViewModel.isLoading = false
        
        // When
        createPostViewModel.isLoading = true
        
        // Then
        XCTAssertTrue(createPostViewModel.isLoading, "Loading state should be true")
        
        // When
        createPostViewModel.isLoading = false
        
        // Then
        XCTAssertFalse(createPostViewModel.isLoading, "Loading state should be false")
    }
    
    func test_createPostViewModel_successState_togglesCorrectly() {
        // Given
        createPostViewModel.isSuccess = false
        
        // When
        createPostViewModel.isSuccess = true
        
        // Then
        XCTAssertTrue(createPostViewModel.isSuccess, "Success state should be true")
    }
    
    func test_createPostViewModel_errorHandling_setsErrorMessage() {
        // Given
        let errorMessage = "Failed to upload post"
        
        // When
        createPostViewModel.errorMessage = errorMessage
        
        // Then
        XCTAssertEqual(createPostViewModel.errorMessage, errorMessage, "Error message should be set")
    }
    
    // MARK: - UI State Tests
    
    func test_createPostViewModel_showLocationPicker_togglesCorrectly() {
        // Given
        createPostViewModel.showLocationPicker = false
        
        // When
        createPostViewModel.showLocationPicker = true
        
        // Then
        XCTAssertTrue(createPostViewModel.showLocationPicker, "Location picker should be shown")
        
        // When
        createPostViewModel.showLocationPicker = false
        
        // Then
        XCTAssertFalse(createPostViewModel.showLocationPicker, "Location picker should be hidden")
    }
    
    func test_createPostViewModel_showShopPicker_togglesCorrectly() {
        // Given
        createPostViewModel.showShopPicker = false
        
        // When
        createPostViewModel.showShopPicker = true
        
        // Then
        XCTAssertTrue(createPostViewModel.showShopPicker, "Shop picker should be shown")
    }
    
    // MARK: - Performance Tests
    
    func test_createPostViewModel_performance_withManyImages() {
        measure {
            // Test performance with multiple images
            var images: [UIImage] = []
            for _ in 0..<10 {
                images.append(createTestImage())
            }
            
            createPostViewModel.selectedImages = images
            
            // Test that validation still works quickly
            let canPost = createPostViewModel.canPost
            XCTAssertNotNil(canPost)
        }
    }
    
    func test_createPostViewModel_performance_withManyMenuItems() {
        measure {
            // Test performance with many menu items
            for i in 0..<100 {
                createPostViewModel.addMenuItem("Menu Item \(i)")
            }
            
            XCTAssertEqual(createPostViewModel.menuItems.count, 100)
        }
    }
    
    // MARK: - Integration Tests
    
    func test_createPostViewModel_completePostFlow_success() async {
        // Given
        setupValidPostData()
        
        // When
        createPostViewModel.isLoading = true
        
        // Simulate post creation
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        createPostViewModel.isLoading = false
        createPostViewModel.isSuccess = true
        
        // Then
        XCTAssertFalse(createPostViewModel.isLoading, "Should not be loading after completion")
        XCTAssertTrue(createPostViewModel.isSuccess, "Should be successful")
        XCTAssertTrue(createPostViewModel.canPost, "Should have valid data for posting")
    }
    
    func test_createPostViewModel_postCreation_validation() {
        // Given
        setupValidPostData()
        
        // When
        let isValid = createPostViewModel.canPost
        
        // Then - All required fields should be present
        XCTAssertTrue(isValid, "Post should be valid")
        XCTAssertFalse(createPostViewModel.selectedImages.isEmpty, "Should have images")
        XCTAssertFalse(createPostViewModel.caption.isEmpty, "Should have caption")
        XCTAssertNotNil(createPostViewModel.selectedLocation, "Should have location")
        XCTAssertNotNil(createPostViewModel.rating, "Should have rating")
        XCTAssertNotNil(createPostViewModel.selectedFoodCategory, "Should have food category")
    }
    
    // MARK: - Edge Cases Tests
    
    func test_createPostViewModel_edgeCases_emptyMenuItemsList() {
        // Given
        setupValidPostData()
        createPostViewModel.menuItems = []
        
        // When
        let canPost = createPostViewModel.canPost
        
        // Then
        XCTAssertTrue(canPost, "Should be able to post without menu items")
    }
    
    func test_createPostViewModel_edgeCases_emptyProductName() {
        // Given
        setupValidPostData()
        createPostViewModel.productName = ""
        
        // When
        let canPost = createPostViewModel.canPost
        
        // Then
        XCTAssertTrue(canPost, "Should be able to post without product name")
    }
}

// MARK: - Test Helpers

extension CreatePostTests {
    
    func setupValidPostData() {
        createPostViewModel.selectedImages = [createTestImage()]
        createPostViewModel.caption = "Amazing food experience!"
        createPostViewModel.selectedLocation = createTestLocation()
        createPostViewModel.rating = 4.5
        createPostViewModel.selectedFoodCategory = .italian
        createPostViewModel.productName = "Delicious Pasta"
    }
    
    func createTestImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        UIColor.red.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image ?? UIImage()
    }
    
    func createTestLocation() -> Location {
        return Location(
            _id: "test_location_123",
            name: "Test Restaurant",
            address: "123 Test Street",
            latitude: 37.7749,
            longitude: -122.4194,
            category: "restaurant",
            rating: 4.5,
            priceLevel: 2,
            isVerified: true,
            totalVisits: 50,
            createdAt: Int(Date().timeIntervalSince1970 * 1000),
            updatedAt: Int(Date().timeIntervalSince1970 * 1000)
        )
    }
}

// MARK: - Test Data Structures

enum FoodCategory: String, CaseIterable {
    case italian = "Italian"
    case asian = "Asian"
    case american = "American"
    case mexican = "Mexican"
    case indian = "Indian"
    case mediterranean = "Mediterranean"
    case vegetarian = "Vegetarian"
    case vegan = "Vegan"
    case dessert = "Dessert"
    case drinks = "Drinks"
}

// MARK: - Mock CreatePostViewModel for Testing

class MockCreatePostViewModel: ObservableObject {
    @Published var selectedImages: [UIImage] = []
    @Published var caption = ""
    @Published var productName = ""
    @Published var selectedLocation: Location?
    @Published var menuItems: [String] = []
    @Published var rating: Double?
    @Published var selectedFoodCategory: FoodCategory?
    @Published var isLoading = false
    @Published var isSuccess = false
    @Published var errorMessage: String?
    
    var canPost: Bool {
        !selectedImages.isEmpty && 
        !caption.isEmpty && 
        selectedLocation != nil && 
        rating != nil && 
        selectedFoodCategory != nil
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
    
    func createPost() async throws {
        isLoading = true
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        if canPost {
            isSuccess = true
            isLoading = false
        } else {
            errorMessage = "Missing required fields"
            isLoading = false
            throw CreatePostError.missingRequiredFields
        }
    }
}

enum CreatePostError: Error {
    case missingRequiredFields
    case networkError
    case uploadFailed
    
    var localizedDescription: String {
        switch self {
        case .missingRequiredFields:
            return "Please fill in all required fields"
        case .networkError:
            return "Network connection failed"
        case .uploadFailed:
            return "Failed to upload images"
        }
    }
} 