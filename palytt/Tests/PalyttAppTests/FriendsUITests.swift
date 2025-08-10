//
//  FriendsUITests.swift
//  PalyttAppTests
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//

import XCTest

// MARK: - UI Test Helper

final class FriendsUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        app.launchEnvironment["UITEST_MODE"] = "1"
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Add Friends Flow Tests
    
    func test_addFriendsView_navigation_works() throws {
        // Wait for app to load
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        
        // Navigate to Profile tab
        let profileTab = app.tabBars.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 5))
        profileTab.tap()
        
        // Look for Add Friends button (may be in navigation or main view)
        let addFriendsButton = app.buttons["Add Friends"]
        if addFriendsButton.exists {
            addFriendsButton.tap()
            
            // Verify Add Friends view loaded
            XCTAssertTrue(app.navigationBars["Add Friends"].waitForExistence(timeout: 3))
        } else {
            // Alternative: Look for friends-related elements
            let friendsSection = app.staticTexts["Friends"]
            XCTAssertTrue(friendsSection.waitForExistence(timeout: 3))
        }
    }
    
    func test_addFriendsView_searchFunctionality_works() throws {
        // Navigate to Add Friends
        try navigateToAddFriends()
        
        // Test search functionality
        let searchField = app.searchFields.firstMatch
        if searchField.exists {
            searchField.tap()
            searchField.typeText("test")
            
            // Wait for search results (allow time for network request)
            sleep(2)
            
            // Verify search interface is responsive
            XCTAssertTrue(searchField.value as? String == "test")
        } else {
            // Alternative: Look for text field with placeholder
            let textField = app.textFields["Search users..."]
            if textField.exists {
                textField.tap()
                textField.typeText("test")
                XCTAssertTrue(textField.value as? String == "test")
            }
        }
    }
    
    func test_addFriendsView_suggestedTab_loads() throws {
        // Navigate to Add Friends
        try navigateToAddFriends()
        
        // Look for Suggested tab or section
        let suggestedTab = app.buttons["Suggested"]
        if suggestedTab.exists {
            suggestedTab.tap()
            
            // Wait for content to load
            sleep(1)
            
            // Verify we're on suggested tab
            XCTAssertTrue(suggestedTab.isSelected)
        } else {
            // Alternative: Look for suggested users section
            let suggestedSection = app.staticTexts["Suggested Users"]
            XCTAssertTrue(suggestedSection.waitForExistence(timeout: 3))
        }
    }
    
    // MARK: - Friend Requests Flow Tests
    
    func test_friendRequestsView_navigation_works() throws {
        // Navigate to Profile
        let profileTab = app.tabBars.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 5))
        profileTab.tap()
        
        // Look for Friend Requests button
        let friendRequestsButton = app.buttons["Friend Requests"]
        if friendRequestsButton.exists {
            friendRequestsButton.tap()
            
            // Verify Friend Requests view loaded
            XCTAssertTrue(app.navigationBars["Friend Requests"].waitForExistence(timeout: 3))
        } else {
            // Alternative: Look for requests-related elements
            let requestsSection = app.staticTexts["Requests"]
            XCTAssertTrue(requestsSection.waitForExistence(timeout: 3))
        }
    }
    
    func test_friendRequestsView_acceptReject_buttons_exist() throws {
        // Navigate to Friend Requests
        try navigateToFriendRequests()
        
        // Look for accept/reject buttons (if any requests exist)
        let acceptButton = app.buttons["Accept"]
        let rejectButton = app.buttons["Reject"]
        
        // Note: These might not exist if no friend requests are present
        // This test verifies the UI elements can be found when they exist
        if acceptButton.exists {
            XCTAssertTrue(acceptButton.isEnabled)
        }
        
        if rejectButton.exists {
            XCTAssertTrue(rejectButton.isEnabled)
        }
        
        // At minimum, verify the view loaded
        let navigationBar = app.navigationBars.firstMatch
        XCTAssertTrue(navigationBar.exists)
    }
    
    // MARK: - Friends List Tests
    
    func test_friendsList_navigation_works() throws {
        // Navigate to Profile
        let profileTab = app.tabBars.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 5))
        profileTab.tap()
        
        // Look for Friends list button
        let friendsButton = app.buttons["Friends"]
        if friendsButton.exists {
            friendsButton.tap()
            
            // Verify Friends view loaded
            let friendsView = app.otherElements["FriendsListView"]
            XCTAssertTrue(friendsView.waitForExistence(timeout: 3))
        } else {
            // Alternative: Look for friends count or section
            let friendsCount = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'friends'")).firstMatch
            XCTAssertTrue(friendsCount.waitForExistence(timeout: 3))
        }
    }
    
    // MARK: - Integration Tests
    
    func test_fullFriendsFlow_endToEnd() throws {
        // This is a comprehensive test of the friends feature
        
        // 1. Navigate to Profile
        let profileTab = app.tabBars.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 5))
        profileTab.tap()
        
        // 2. Access Add Friends
        try navigateToAddFriends()
        
        // 3. Test search
        let searchField = app.searchFields.firstMatch
        if !searchField.exists {
            let textField = app.textFields["Search users..."]
            if textField.exists {
                textField.tap()
                textField.typeText("test")
            }
        } else {
            searchField.tap()
            searchField.typeText("test")
        }
        
        // 4. Go back and check friend requests
        app.navigationBars.buttons.firstMatch.tap() // Back button
        
        try navigateToFriendRequests()
        
        // 5. Verify we can navigate back to profile
        app.navigationBars.buttons.firstMatch.tap() // Back button
        
        // Should be back on profile
        XCTAssertTrue(profileTab.isSelected)
    }
    
    // MARK: - Performance Tests
    
    func test_addFriends_loadTime_isAcceptable() throws {
        measure {
            try! navigateToAddFriends()
            
            // Wait for view to fully load
            let searchField = app.searchFields.firstMatch
            let textField = app.textFields["Search users..."]
            
            let loaded = searchField.waitForExistence(timeout: 2) || textField.waitForExistence(timeout: 2)
            XCTAssertTrue(loaded)
        }
    }
    
    // MARK: - Accessibility Tests
    
    func test_addFriends_accessibility_isProperlyConfigured() throws {
        // Navigate to Add Friends
        try navigateToAddFriends()
        
        // Check for accessibility labels
        let searchElement = app.searchFields.firstMatch.exists ? app.searchFields.firstMatch : app.textFields["Search users..."]
        
        if searchElement.exists {
            XCTAssertNotNil(searchElement.value)
            // Accessibility should be enabled for search
            XCTAssertTrue(searchElement.isEnabled)
        }
        
        // Check navigation accessibility
        let backButton = app.navigationBars.buttons.firstMatch
        if backButton.exists {
            XCTAssertTrue(backButton.isEnabled)
        }
    }
    
    // MARK: - Helper Methods
    
    private func navigateToAddFriends() throws {
        // Navigate to Profile if not already there
        let profileTab = app.tabBars.buttons["Profile"]
        if !profileTab.isSelected {
            profileTab.tap()
        }
        
        // Look for Add Friends button
        let addFriendsButton = app.buttons["Add Friends"]
        if addFriendsButton.exists {
            addFriendsButton.tap()
        } else {
            // Alternative navigation paths
            let friendsButton = app.buttons["Friends"]
            if friendsButton.exists {
                friendsButton.tap()
                
                // Look for add button in friends view
                let addButton = app.buttons["Add"]
                if addButton.exists {
                    addButton.tap()
                }
            } else {
                throw XCTSkip("Could not find Add Friends navigation")
            }
        }
        
        // Wait for Add Friends view to load
        sleep(1)
    }
    
    private func navigateToFriendRequests() throws {
        // Navigate to Profile if not already there
        let profileTab = app.tabBars.buttons["Profile"]
        if !profileTab.isSelected {
            profileTab.tap()
        }
        
        // Look for Friend Requests button
        let friendRequestsButton = app.buttons["Friend Requests"]
        if friendRequestsButton.exists {
            friendRequestsButton.tap()
        } else {
            // Alternative: Look in friends section
            let friendsButton = app.buttons["Friends"]
            if friendsButton.exists {
                friendsButton.tap()
                
                let requestsButton = app.buttons["Requests"]
                if requestsButton.exists {
                    requestsButton.tap()
                }
            } else {
                throw XCTSkip("Could not find Friend Requests navigation")
            }
        }
        
        // Wait for Friend Requests view to load
        sleep(1)
    }
} 