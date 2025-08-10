//
//  NotificationSettingsView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @StateObject private var notificationSettings = NotificationSettings.shared
    @StateObject private var soundManager = SoundManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingQuietHoursHelp = false
    @State private var showingPermissionAlert = false
    @State private var showingResetConfirmation = false
    @State private var systemPermissionStatus: UNAuthorizationStatus = .notDetermined
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Section
                    headerSection
                    
                    // System Permission Status
                    systemPermissionSection
                    
                    // Master Toggle
                    masterToggleSection
                    
                    // Quick Actions
                    quickActionsSection
                    
                    // Social Notifications
                    socialNotificationsSection
                    
                    // Content Notifications
                    contentNotificationsSection
                    
                    // Messages Notifications
                    messagesNotificationsSection
                    
                    // System Notifications
                    systemNotificationsSection
                    
                    // Audio & Haptic Settings
                    audioHapticSection
                    
                    // Timing & Schedule
                    timingSection
                    
                    // Privacy & Display
                    privacyDisplaySection
                    
                    // Management Actions
                    managementSection
                    
                    Spacer(minLength: 50)
                }
                .padding(.horizontal)
            }
            .background(Color.appBackground)
            .scrollContentBackground(.hidden)
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        SoundManager.shared.playWithHaptic(.buttonTap, hapticType: .light)
                        dismiss()
                    }
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryBrand)
                }
            }
            .onAppear {
                checkSystemPermissions()
            }
            .alert("System Notifications", isPresented: $showingPermissionAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Open Settings") {
                    openSystemSettings()
                }
            } message: {
                Text("To receive notifications, please enable them in your device Settings app.")
            }
            .alert("Reset Settings", isPresented: $showingResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    notificationSettings.resetToDefaults()
                    SoundManager.shared.playWithHaptic(.success, hapticType: .success)
                }
            } message: {
                Text("This will reset all notification settings to their default values. This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(LinearGradient.primaryGradient)
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "bell.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                )
            
            Text("Notification Settings")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.appPrimaryText)
            
            Text("Customize when and how you receive notifications")
                .font(.subheadline)
                .foregroundColor(.appSecondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }
    
    // MARK: - System Permission Section
    private var systemPermissionSection: some View {
        NotificationSectionView(title: "System Settings", icon: "gear") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Device Notifications")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.appPrimaryText)
                    
                    Text(systemPermissionStatusText)
                        .font(.caption)
                        .foregroundColor(systemPermissionColor)
                }
                
                Spacer()
                
                if systemPermissionStatus != .authorized {
                    Button("Enable") {
                        if systemPermissionStatus == .denied {
                            showingPermissionAlert = true
                        } else {
                            requestNotificationPermission()
                        }
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.primaryBrand)
                    .cornerRadius(8)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.success)
                        .font(.title3)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Master Toggle Section
    private var masterToggleSection: some View {
        NotificationSectionView(title: "Master Control", icon: "power") {
            VStack(spacing: 12) {
                NotificationToggleRow(
                    title: "All Notifications",
                    description: "Enable or disable all app notifications",
                    isOn: $notificationSettings.allNotificationsEnabled,
                    isMainToggle: true
                )
                
                if !notificationSettings.allNotificationsEnabled {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.warning)
                        Text("All notifications are currently disabled")
                            .font(.caption)
                            .foregroundColor(.appSecondaryText)
                        Spacer()
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
    
    // MARK: - Quick Actions Section
    private var quickActionsSection: some View {
        NotificationSectionView(title: "Quick Actions", icon: "clock.fill") {
            VStack(spacing: 8) {
                if let pauseUntil = notificationSettings.pauseNotificationsUntil,
                   pauseUntil > Date() {
                    // Currently paused
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notifications Paused")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.appPrimaryText)
                            
                            Text("Until \(pauseUntil, style: .time)")
                                .font(.caption)
                                .foregroundColor(.appSecondaryText)
                        }
                        
                        Spacer()
                        
                        Button("Resume") {
                            notificationSettings.resumeNotifications()
                            SoundManager.shared.playWithHaptic(.success, hapticType: .success)
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.success)
                        .cornerRadius(8)
                    }
                    .padding(.vertical, 8)
                } else {
                    // Pause options
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        QuickActionButton(
                            title: "30 minutes",
                            icon: "moon.fill",
                            action: { 
                                notificationSettings.pauseNotifications(for: 30 * 60)
                                SoundManager.shared.playWithHaptic(.modalPresent, hapticType: .medium)
                            }
                        )
                        
                        QuickActionButton(
                            title: "1 hour",
                            icon: "moon.fill",
                            action: { 
                                notificationSettings.pauseNotifications(for: 60 * 60)
                                SoundManager.shared.playWithHaptic(.modalPresent, hapticType: .medium)
                            }
                        )
                        
                        QuickActionButton(
                            title: "Until morning",
                            icon: "sunrise.fill",
                            action: { 
                                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                                let morning = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: tomorrow) ?? Date()
                                notificationSettings.pauseNotificationsUntil = morning
                                SoundManager.shared.playWithHaptic(.modalPresent, hapticType: .medium)
                            }
                        )
                        
                        QuickActionButton(
                            title: "Quiet Hours",
                            icon: "moon.zzz.fill",
                            action: { 
                                notificationSettings.quietHoursEnabled.toggle()
                                SoundManager.shared.playWithHaptic(.toggle, hapticType: .light)
                            }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Social Notifications Section
    private var socialNotificationsSection: some View {
        NotificationSectionView(title: "Social Activity", icon: "person.2.fill") {
            VStack(spacing: 8) {
                NotificationToggleRow(
                    title: "Comments",
                    description: "When someone comments on your posts",
                    isOn: $notificationSettings.commentsEnabled,
                    icon: "bubble.left.fill"
                )
                
                NotificationToggleRow(
                    title: "Likes & Hearts",
                    description: "When someone likes your posts or comments",
                    isOn: $notificationSettings.likesEnabled,
                    icon: "heart.fill"
                )
                
                NotificationToggleRow(
                    title: "Mentions",
                    description: "When someone mentions you in a comment",
                    isOn: $notificationSettings.mentionsEnabled,
                    icon: "at"
                )
                
                NotificationToggleRow(
                    title: "New Followers",
                    description: "When someone follows you",
                    isOn: $notificationSettings.followsEnabled,
                    icon: "person.badge.plus.fill"
                )
                
                NotificationToggleRow(
                    title: "Friend Requests",
                    description: "When someone sends you a friend request",
                    isOn: $notificationSettings.friendRequestsEnabled,
                    icon: "person.2.badge.plus.fill"
                )
            }
        }
    }
    
    // MARK: - Content Notifications Section
    private var contentNotificationsSection: some View {
        NotificationSectionView(title: "Content & Discovery", icon: "doc.text.fill") {
            VStack(spacing: 8) {
                NotificationToggleRow(
                    title: "Friend Posts",
                    description: "When your friends create new posts",
                    isOn: $notificationSettings.newPostsFromFriendsEnabled,
                    icon: "person.3.sequence.fill"
                )
                
                NotificationToggleRow(
                    title: "Trending Posts",
                    description: "When posts are trending in your area",
                    isOn: $notificationSettings.trendingPostsEnabled,
                    icon: "flame.fill"
                )
                
                NotificationToggleRow(
                    title: "Nearby Posts",
                    description: "When there are new posts near your location",
                    isOn: $notificationSettings.nearbyPostsEnabled,
                    icon: "location.fill"
                )
            }
        }
    }
    
    // MARK: - Messages Notifications Section
    private var messagesNotificationsSection: some View {
        NotificationSectionView(title: "Messages", icon: "message.fill") {
            VStack(spacing: 8) {
                NotificationToggleRow(
                    title: "Direct Messages",
                    description: "When you receive direct messages",
                    isOn: $notificationSettings.messagesEnabled,
                    icon: "message.fill"
                )
                
                NotificationToggleRow(
                    title: "Group Messages",
                    description: "When you receive group messages",
                    isOn: $notificationSettings.groupMessagesEnabled,
                    icon: "message.badge.filled.fill"
                )
            }
        }
    }
    
    // MARK: - System Notifications Section
    private var systemNotificationsSection: some View {
        NotificationSectionView(title: "System & Updates", icon: "app.badge.fill") {
            VStack(spacing: 8) {
                NotificationToggleRow(
                    title: "App Updates",
                    description: "Feature announcements and app updates",
                    isOn: $notificationSettings.systemUpdatesEnabled,
                    icon: "app.badge.fill"
                )
                
                NotificationToggleRow(
                    title: "Security Alerts",
                    description: "Important security notifications",
                    isOn: $notificationSettings.securityAlertsEnabled,
                    icon: "shield.fill",
                    cannotDisable: true
                )
                
                NotificationToggleRow(
                    title: "Achievements",
                    description: "When you unlock new achievements",
                    isOn: $notificationSettings.achievementsEnabled,
                    icon: "star.fill"
                )
            }
        }
    }
    
    // MARK: - Audio & Haptic Section
    private var audioHapticSection: some View {
        NotificationSectionView(title: "Audio & Haptics", icon: "speaker.wave.2.fill") {
            VStack(spacing: 12) {
                NotificationToggleRow(
                    title: "Notification Sounds",
                    description: "Play sounds for notifications",
                    isOn: $notificationSettings.notificationSoundsEnabled,
                    icon: "speaker.wave.2.fill"
                )
                
                NotificationToggleRow(
                    title: "App Sounds",
                    description: "Play sounds for app interactions",
                    isOn: $notificationSettings.soundsEnabled,
                    icon: "speaker.fill"
                )
                
                NotificationToggleRow(
                    title: "Haptic Feedback",
                    description: "Vibration feedback for interactions",
                    isOn: $notificationSettings.hapticsEnabled,
                    icon: "iphone.radiowaves.left.and.right"
                )
                
                if notificationSettings.soundsEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Volume")
                                .font(.subheadline)
                                .foregroundColor(.appPrimaryText)
                            
                            Spacer()
                            
                            Text("\(Int(soundManager.soundVolume * 100))%")
                                .font(.caption)
                                .foregroundColor(.appSecondaryText)
                        }
                        
                        Slider(value: $soundManager.soundVolume, in: 0...1)
                            .tint(.primaryBrand)
                            .onChange(of: soundManager.soundVolume) { oldValue, newValue in
                                // Play test sound at new volume
                                SoundManager.shared.playTestSound()
                            }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
    
    // MARK: - Timing Section
    private var timingSection: some View {
        NotificationSectionView(title: "Schedule & Timing", icon: "clock.fill") {
            VStack(spacing: 12) {
                NotificationToggleRow(
                    title: "Quiet Hours",
                    description: "Reduce notifications during specified hours",
                    isOn: $notificationSettings.quietHoursEnabled,
                    icon: "moon.zzz.fill"
                )
                
                if notificationSettings.quietHoursEnabled {
                    VStack(spacing: 12) {
                        HStack {
                            Text("From")
                                .font(.subheadline)
                                .foregroundColor(.appPrimaryText)
                            
                            Spacer()
                            
                            DatePicker(
                                "",
                                selection: $notificationSettings.quietHoursStart,
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                        }
                        
                        HStack {
                            Text("Until")
                                .font(.subheadline)
                                .foregroundColor(.appPrimaryText)
                            
                            Spacer()
                            
                            DatePicker(
                                "",
                                selection: $notificationSettings.quietHoursEnd,
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                        }
                        
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.primaryBrand)
                                .font(.caption)
                            
                            Text("Only security alerts will be shown during quiet hours")
                                .font(.caption)
                                .foregroundColor(.appSecondaryText)
                            
                            Spacer()
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
    
    // MARK: - Privacy & Display Section
    private var privacyDisplaySection: some View {
        NotificationSectionView(title: "Privacy & Display", icon: "eye.fill") {
            VStack(spacing: 8) {
                NotificationToggleRow(
                    title: "Lock Screen Preview",
                    description: "Show notification content on lock screen",
                    isOn: $notificationSettings.showPreviewInLockScreen,
                    icon: "lock.fill"
                )
                
                NotificationToggleRow(
                    title: "Notification Center Preview",
                    description: "Show notification content in notification center",
                    isOn: $notificationSettings.showPreviewInNotificationCenter,
                    icon: "list.bullet"
                )
                
                NotificationToggleRow(
                    title: "Group Similar",
                    description: "Group similar notifications together",
                    isOn: $notificationSettings.groupSimilarNotifications,
                    icon: "square.stack.fill"
                )
            }
        }
    }
    
    // MARK: - Management Section
    private var managementSection: some View {
        NotificationSectionView(title: "Management", icon: "gear") {
            VStack(spacing: 8) {
                Button(action: {
                    openSystemSettings()
                }) {
                    HStack {
                        Circle()
                            .fill(Color.primaryBrand.opacity(0.2))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "gear")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primaryBrand)
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("System Settings")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.appPrimaryText)
                            
                            Text("Open device notification settings")
                                .font(.caption)
                                .foregroundColor(.appSecondaryText)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.appSecondaryText)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    showingResetConfirmation = true
                }) {
                    HStack {
                        Circle()
                            .fill(Color.error.opacity(0.2))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.error)
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Reset Settings")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.error)
                            
                            Text("Reset all settings to defaults")
                                .font(.caption)
                                .foregroundColor(.appSecondaryText)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // MARK: - Helper Properties
    private var systemPermissionStatusText: String {
        switch systemPermissionStatus {
        case .authorized:
            return "Enabled"
        case .denied:
            return "Disabled"
        case .notDetermined:
            return "Not Set"
        case .provisional:
            return "Provisional"
        case .ephemeral:
            return "Temporary"
        @unknown default:
            return "Unknown"
        }
    }
    
    private var systemPermissionColor: Color {
        switch systemPermissionStatus {
        case .authorized:
            return .success
        case .denied:
            return .error
        default:
            return .warning
        }
    }
    
    // MARK: - Helper Methods
    private func checkSystemPermissions() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                systemPermissionStatus = settings.authorizationStatus
            }
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                checkSystemPermissions()
                if granted {
                    SoundManager.shared.playSuccessSound()
                }
            }
        }
    }
    
    private func openSystemSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// MARK: - Supporting Views

struct NotificationSectionView<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primaryBrand)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.appPrimaryText)
            }
            .padding(.horizontal, 4)
            
            VStack(spacing: 8) {
                content
            }
            .padding(16)
            .background(Color.appCardBackground)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
    }
}

struct NotificationToggleRow: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    let icon: String?
    let isMainToggle: Bool
    let cannotDisable: Bool
    
    init(
        title: String,
        description: String,
        isOn: Binding<Bool>,
        icon: String? = nil,
        isMainToggle: Bool = false,
        cannotDisable: Bool = false
    ) {
        self.title = title
        self.description = description
        self._isOn = isOn
        self.icon = icon
        self.isMainToggle = isMainToggle
        self.cannotDisable = cannotDisable
    }
    
    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Circle()
                    .fill(Color.primaryBrand.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primaryBrand)
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isMainToggle ? .semibold : .medium)
                    .foregroundColor(.appPrimaryText)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.appSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.primaryBrand)
                .disabled(cannotDisable)
                .onChange(of: isOn) { oldValue, newValue in
                    SoundManager.shared.playWithHaptic(.toggle, hapticType: .light)
                }
        }
        .padding(.vertical, 8)
        .opacity(cannotDisable ? 0.7 : 1.0)
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.primaryBrand)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.appPrimaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(Color.appCardBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primaryBrand.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Previews
#Preview("Notification Settings") {
    NotificationSettingsView()
        .environmentObject(ThemeManager())
}

#Preview("Notification Settings - Dark") {
    NotificationSettingsView()
        .environmentObject(ThemeManager())
        .preferredColorScheme(.dark)
} 