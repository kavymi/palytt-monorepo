//
//  NotificationPermissionPrompt.swift
//  Palytt
//
//  Contextual notification permission prompt for better UX
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//

import SwiftUI

/// Contextual scenarios for showing notification permission prompt
enum NotificationPromptContext {
    case firstPost          // After user creates their first post
    case firstFriendRequest // When receiving first friend request
    case firstLike          // When their post gets first like
    case afterOnboarding    // After completing onboarding
    case settings           // From settings screen
    
    var title: String {
        switch self {
        case .firstPost:
            return "Know When Friends React"
        case .firstFriendRequest:
            return "Don't Miss Friend Requests"
        case .firstLike:
            return "Your Post is Getting Love!"
        case .afterOnboarding:
            return "Stay Connected"
        case .settings:
            return "Enable Notifications"
        }
    }
    
    var message: String {
        switch self {
        case .firstPost:
            return "Turn on notifications to see when friends like and comment on your posts."
        case .firstFriendRequest:
            return "Enable notifications so you never miss a friend request or message."
        case .firstLike:
            return "Get notified when more people discover your content."
        case .afterOnboarding:
            return "Stay in the loop when friends post, message you, or interact with your content."
        case .settings:
            return "Allow notifications to stay updated on likes, comments, messages, and friend activity."
        }
    }
    
    var iconName: String {
        switch self {
        case .firstPost:
            return "heart.text.square"
        case .firstFriendRequest:
            return "person.2.fill"
        case .firstLike:
            return "star.fill"
        case .afterOnboarding:
            return "bell.badge.fill"
        case .settings:
            return "bell.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .firstPost, .firstLike:
            return .red
        case .firstFriendRequest:
            return .green
        case .afterOnboarding, .settings:
            return .primaryBrand
        }
    }
}

struct NotificationPermissionPrompt: View {
    let context: NotificationPromptContext
    let onAllow: () -> Void
    let onDismiss: () -> Void
    
    @StateObject private var notificationManager = NativeNotificationManager.shared
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
            
            VStack(spacing: 24) {
                // Animated icon
                ZStack {
                    Circle()
                        .fill(context.iconColor.opacity(0.15))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: context.iconName)
                        .font(.system(size: 36))
                        .foregroundColor(context.iconColor)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .animation(
                            Animation.easeInOut(duration: 1.0)
                                .repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                }
                .padding(.top, 24)
                
                // Title and message
                VStack(spacing: 12) {
                    Text(context.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primaryText)
                        .multilineTextAlignment(.center)
                    
                    Text(context.message)
                        .font(.body)
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                
                // Features list
                VStack(alignment: .leading, spacing: 12) {
                    NotificationFeatureRow(icon: "heart.fill", text: "Likes on your posts", color: .red)
                    NotificationFeatureRow(icon: "bubble.left.fill", text: "Comments and replies", color: .blue)
                    NotificationFeatureRow(icon: "person.badge.plus.fill", text: "Friend requests", color: .green)
                    NotificationFeatureRow(icon: "message.fill", text: "Direct messages", color: .purple)
                }
                .padding(.horizontal, 24)
                
                // Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        HapticManager.shared.impact(.medium)
                        Task {
                            let granted = await notificationManager.requestPermissions()
                            if granted {
                                onAllow()
                            }
                        }
                    }) {
                        Text("Allow Notifications")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.primaryBrand)
                            .cornerRadius(12)
                    }
                    
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        onDismiss()
                    }) {
                        Text("Maybe Later")
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .background(Color.appBackground)
        .cornerRadius(20, corners: [.topLeft, .topRight])
        .onAppear {
            isAnimating = true
        }
    }
}

struct NotificationFeatureRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primaryText)
            
            Spacer()
        }
    }
}

// MARK: - View Modifier for showing permission prompt
// Note: RoundedCorner shape is defined in MentionTextEditor.swift
struct NotificationPermissionModifier: ViewModifier {
    @Binding var isPresented: Bool
    let context: NotificationPromptContext
    let onAllow: () -> Void
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                NotificationPermissionPrompt(
                    context: context,
                    onAllow: {
                        isPresented = false
                        onAllow()
                    },
                    onDismiss: {
                        isPresented = false
                    }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
            }
    }
}

extension View {
    func notificationPermissionPrompt(
        isPresented: Binding<Bool>,
        context: NotificationPromptContext,
        onAllow: @escaping () -> Void = {}
    ) -> some View {
        modifier(NotificationPermissionModifier(
            isPresented: isPresented,
            context: context,
            onAllow: onAllow
        ))
    }
}

// MARK: - Manager for tracking when to show prompts
@MainActor
class NotificationPromptManager: ObservableObject {
    static let shared = NotificationPromptManager()
    
    @Published var shouldShowPrompt = false
    @Published var promptContext: NotificationPromptContext = .afterOnboarding
    
    private let defaults = UserDefaults.standard
    private let promptShownKey = "notification_prompt_shown_count"
    private let lastPromptDateKey = "notification_prompt_last_date"
    private let maxPromptCount = 3
    private let minDaysBetweenPrompts = 7
    
    private init() {}
    
    /// Check if we should show the permission prompt
    func shouldShowPermissionPrompt() -> Bool {
        // Don't show if already authorized
        guard !NativeNotificationManager.shared.isAuthorized else {
            return false
        }
        
        // Don't show if denied (user made their choice)
        if NativeNotificationManager.shared.authorizationStatus == .denied {
            return false
        }
        
        // Check if we've shown too many times
        let shownCount = defaults.integer(forKey: promptShownKey)
        if shownCount >= maxPromptCount {
            return false
        }
        
        // Check if enough time has passed since last prompt
        if let lastDate = defaults.object(forKey: lastPromptDateKey) as? Date {
            let daysSinceLastPrompt = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
            if daysSinceLastPrompt < minDaysBetweenPrompts {
                return false
            }
        }
        
        return true
    }
    
    /// Show the prompt if conditions are met
    func triggerPromptIfNeeded(context: NotificationPromptContext) {
        guard shouldShowPermissionPrompt() else { return }
        
        promptContext = context
        shouldShowPrompt = true
        
        // Record that we showed a prompt
        defaults.set(defaults.integer(forKey: promptShownKey) + 1, forKey: promptShownKey)
        defaults.set(Date(), forKey: lastPromptDateKey)
    }
    
    /// Reset prompt tracking (for testing)
    func resetPromptTracking() {
        defaults.removeObject(forKey: promptShownKey)
        defaults.removeObject(forKey: lastPromptDateKey)
    }
}

#Preview {
    NotificationPermissionPrompt(
        context: .firstLike,
        onAllow: {},
        onDismiss: {}
    )
}

