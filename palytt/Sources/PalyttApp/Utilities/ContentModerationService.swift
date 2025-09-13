//
//  ContentModerationService.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import Foundation
import SwiftUI
import Combine

// MARK: - Content Moderation Service

@MainActor
class ContentModerationService: ObservableObject {
    static let shared = ContentModerationService()
    
    @Published var isEnabled = true
    @Published var moderationLevel = ModerationLevel.balanced
    @Published var reportedContent: [ContentReport] = []
    @Published var contentFlags: [ContentFlag] = []
    @Published var safetyScore: Double = 95.0
    
    private var cancellables = Set<AnyCancellable>()
    private var bannedWords: Set<String> = [
        "spam", "inappropriate", "offensive"
    ]
    
    private init() {
        loadModerationSettings()
        loadReportedContent()
    }
    
    // MARK: - Content Screening
    
    func screenContent(_ content: String, type: ContentType) -> ModerationResult {
        guard isEnabled else {
            return ModerationResult(isAllowed: true, confidence: 1.0, flags: [])
        }
        
        var flags: [ModerationFlag] = []
        var confidence: Double = 1.0
        
        // Check for banned words
        let lowercaseContent = content.lowercased()
        for word in bannedWords {
            if lowercaseContent.contains(word) {
                flags.append(.inappropriateLanguage)
                confidence -= 0.3
            }
        }
        
        // Check content length
        if content.count > 2000 {
            flags.append(.excessiveLength)
            confidence -= 0.1
        }
        
        // Check for spam patterns
        if isSpamLike(content) {
            flags.append(.spam)
            confidence -= 0.4
        }
        
        // Check for personal information
        if containsPersonalInfo(content) {
            flags.append(.personalInformation)
            confidence -= 0.2
        }
        
        let isAllowed = flags.isEmpty || confidence > getModerationThreshold()
        
        return ModerationResult(
            isAllowed: isAllowed,
            confidence: confidence,
            flags: flags
        )
    }
    
    func screenImage(_ imageData: Data) -> ModerationResult {
        // Simplified image moderation
        // In a real app, this would use ML models or cloud services
        return ModerationResult(isAllowed: true, confidence: 0.9, flags: [])
    }
    
    // MARK: - Content Reporting
    
    func reportContent(
        contentId: String,
        contentType: ContentType,
        reason: ReportReason,
        description: String = "",
        reporterId: String
    ) {
        let report = ContentReport(
            contentId: contentId,
            contentType: contentType,
            reason: reason,
            description: description,
            reporterId: reporterId
        )
        
        reportedContent.append(report)
        saveReportedContent()
        
        // Auto-flag if enough reports
        checkForAutoModeration(contentId: contentId)
        
        print("📊 Content reported: \(contentId) for \(reason.rawValue)")
    }
    
    private func checkForAutoModeration(contentId: String) {
        let reports = reportedContent.filter { $0.contentId == contentId }
        
        if reports.count >= getAutoModerationThreshold() {
            flagContent(contentId: contentId, reason: .multipleReports)
        }
    }
    
    // MARK: - Content Flagging
    
    func flagContent(contentId: String, reason: FlagReason) {
        let flag = ContentFlag(
            contentId: contentId,
            reason: reason,
            severity: getSeverityForReason(reason)
        )
        
        contentFlags.append(flag)
        updateSafetyScore()
        
        print("🚩 Content flagged: \(contentId) for \(reason.rawValue)")
    }
    
    func unflagContent(contentId: String) {
        contentFlags.removeAll { $0.contentId == contentId }
        updateSafetyScore()
        
        print("✅ Content unflagged: \(contentId)")
    }
    
    func isContentFlagged(_ contentId: String) -> Bool {
        return contentFlags.contains { $0.contentId == contentId }
    }
    
    // MARK: - User Safety
    
    func getUserSafetyScore(userId: String) -> Double {
        let userReports = reportedContent.filter { $0.reporterId == userId }
        let userFlags = contentFlags.filter { _ in true } // Would filter by user's content
        
        var score: Double = 100.0
        
        // Reduce score based on reports against user
        score -= Double(userReports.count) * 5.0
        
        // Reduce score based on flagged content
        for flag in userFlags {
            score -= flag.severity.scoreImpact
        }
        
        return max(0.0, min(100.0, score))
    }
    
    func blockUser(_ userId: String, reason: String) {
        // Implementation would block user in the system
        print("🚫 User blocked: \(userId) - \(reason)")
    }
    
    func reportUser(_ userId: String, reason: ReportReason, reporterId: String) {
        reportContent(
            contentId: userId,
            contentType: .user,
            reason: reason,
            reporterId: reporterId
        )
    }
    
    // MARK: - Settings
    
    func setModerationLevel(_ level: ModerationLevel) {
        moderationLevel = level
        saveModerationSettings()
    }
    
    func toggleModeration() {
        isEnabled.toggle()
        saveModerationSettings()
    }
    
    private func getModerationThreshold() -> Double {
        switch moderationLevel {
        case .strict:
            return 0.9
        case .balanced:
            return 0.7
        case .lenient:
            return 0.5
        }
    }
    
    private func getAutoModerationThreshold() -> Int {
        switch moderationLevel {
        case .strict:
            return 2
        case .balanced:
            return 3
        case .lenient:
            return 5
        }
    }
    
    // MARK: - Helper Methods
    
    private func isSpamLike(_ content: String) -> Bool {
        // Check for repeated characters
        let repeatedPatterns = ["!!!", "???", "...", "www", "http"]
        for pattern in repeatedPatterns {
            if content.lowercased().contains(pattern) {
                return true
            }
        }
        
        // Check for excessive capitalization
        let uppercaseCount = content.filter { $0.isUppercase }.count
        if Double(uppercaseCount) / Double(content.count) > 0.5 {
            return true
        }
        
        return false
    }
    
    private func containsPersonalInfo(_ content: String) -> Bool {
        // Simplified check for phone numbers and emails
        let phonePattern = #"\d{3}-?\d{3}-?\d{4}"#
        let emailPattern = #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#
        
        return content.range(of: phonePattern, options: .regularExpression) != nil ||
               content.range(of: emailPattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
    
    private func getSeverityForReason(_ reason: FlagReason) -> FlagSeverity {
        switch reason {
        case .spam:
            return .low
        case .inappropriateContent:
            return .medium
        case .harassment:
            return .high
        case .violentContent:
            return .critical
        case .multipleReports:
            return .medium
        case .personalInformation:
            return .low
        }
    }
    
    private func updateSafetyScore() {
        let totalFlags = contentFlags.count
        let criticalFlags = contentFlags.filter { $0.severity == .critical }.count
        let highFlags = contentFlags.filter { $0.severity == .high }.count
        
        var score: Double = 100.0
        score -= Double(criticalFlags) * 20.0
        score -= Double(highFlags) * 10.0
        score -= Double(totalFlags) * 2.0
        
        safetyScore = max(0.0, min(100.0, score))
    }
    
    // MARK: - Persistence
    
    private func saveModerationSettings() {
        UserDefaults.standard.set(isEnabled, forKey: "moderation_enabled")
        UserDefaults.standard.set(moderationLevel.rawValue, forKey: "moderation_level")
    }
    
    private func loadModerationSettings() {
        isEnabled = UserDefaults.standard.bool(forKey: "moderation_enabled")
        
        if let levelString = UserDefaults.standard.string(forKey: "moderation_level"),
           let level = ModerationLevel(rawValue: levelString) {
            moderationLevel = level
        }
    }
    
    private func saveReportedContent() {
        do {
            let data = try JSONEncoder().encode(reportedContent)
            UserDefaults.standard.set(data, forKey: "reported_content")
        } catch {
            print("Failed to save reported content: \(error)")
        }
    }
    
    private func loadReportedContent() {
        guard let data = UserDefaults.standard.data(forKey: "reported_content") else { return }
        
        do {
            reportedContent = try JSONDecoder().decode([ContentReport].self, from: data)
        } catch {
            print("Failed to load reported content: \(error)")
        }
    }
}

// MARK: - Supporting Models

enum ContentType: String, Codable, CaseIterable {
    case post = "post"
    case comment = "comment"
    case message = "message"
    case profile = "profile"
    case user = "user"
}

enum ReportReason: String, Codable, CaseIterable {
    case falseInformation = "false_information"
    case harassment = "harassment"
    case hateSpeech = "hate_speech"
    case inappropriateContent = "inappropriate_content"
    case other = "other"
    case spam = "spam"
    case violentContent = "violent_content"
    
    var displayName: String {
        switch self {
        case .falseInformation: return "False Information"
        case .harassment: return "Harassment"
        case .hateSpeech: return "Hate Speech"
        case .inappropriateContent: return "Inappropriate Content"
        case .other: return "Other"
        case .spam: return "Spam"
        case .violentContent: return "Violent Content"
        }
    }
}

enum ModerationLevel: String, CaseIterable {
    case balanced = "balanced"
    case lenient = "lenient"
    case strict = "strict"
    
    var displayName: String {
        switch self {
        case .balanced: return "Balanced"
        case .lenient: return "Lenient"
        case .strict: return "Strict"
        }
    }
}

enum ModerationFlag {
    case inappropriateLanguage
    case spam
    case excessiveLength
    case personalInformation
    case suspiciousActivity
}

enum FlagReason: String, Codable {
    case spam = "spam"
    case inappropriateContent = "inappropriate_content"
    case harassment = "harassment"
    case violentContent = "violent_content"
    case multipleReports = "multiple_reports"
    case personalInformation = "personal_information"
}

enum FlagSeverity: String, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var scoreImpact: Double {
        switch self {
        case .low: return 2.0
        case .medium: return 5.0
        case .high: return 10.0
        case .critical: return 20.0
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .yellow
        case .medium: return .orange
        case .high: return .red
        case .critical: return .purple
        }
    }
}

struct ModerationResult {
    let isAllowed: Bool
    let confidence: Double
    let flags: [ModerationFlag]
    
    var requiresReview: Bool {
        return !isAllowed || confidence < 0.8
    }
}

struct ContentReport: Identifiable, Codable {
    let id = UUID()
    let contentId: String
    let contentType: ContentType
    let reason: ReportReason
    let description: String
    let reporterId: String
    let timestamp: Date
    
    init(contentId: String, contentType: ContentType, reason: ReportReason, description: String = "", reporterId: String) {
        self.contentId = contentId
        self.contentType = contentType
        self.reason = reason
        self.description = description
        self.reporterId = reporterId
        self.timestamp = Date()
    }
}

struct ContentFlag: Identifiable, Codable {
    let id = UUID()
    let contentId: String
    let reason: FlagReason
    let severity: FlagSeverity
    let timestamp: Date
    
    init(contentId: String, reason: FlagReason, severity: FlagSeverity) {
        self.contentId = contentId
        self.reason = reason
        self.severity = severity
        self.timestamp = Date()
    }
}

// MARK: - Content Reporting View

struct ContentReportView: View {
    let contentId: String
    let contentType: ContentType
    
    @StateObject private var moderationService = ContentModerationService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedReason: ReportReason = .spam
    @State private var description: String = ""
    @State private var isSubmitting = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Reason", selection: $selectedReason) {
                        ForEach(ReportReason.allCases, id: \.self) { reason in
                            Text(reason.displayName).tag(reason)
                        }
                    }
                } header: {
                    Text("Report Reason")
                }
                
                Section {
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                } header: {
                    Text("Additional Details")
                } footer: {
                    Text("Please provide specific details about why this content violates our community guidelines.")
                }
            }
            .navigationTitle("Report Content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        submitReport()
                    }
                    .disabled(isSubmitting)
                }
            }
        }
    }
    
    private func submitReport() {
        isSubmitting = true
        
        let report = ContentReport(
            contentId: contentId,
            contentType: contentType,
            reason: selectedReason,
            description: description,
            reporterId: "current_user_id" // Would get from auth service
        )
        
        moderationService.reportContent(report: report)
        
        // Show success feedback
        HapticManager.shared.impact(.medium)
        
        dismiss()
    }
}

// MARK: - Moderation Queue View (Admin)

struct ModerationQueueView: View {
    @StateObject private var moderationService = ContentModerationService.shared
    @State private var selectedFilter: ModerationSeverity? = nil
    
    var filteredQueue: [ModerationItem] {
        guard let filter = selectedFilter else {
            return moderationService.moderationQueue
        }
        return moderationService.moderationQueue.filter { $0.severity == filter }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // Filter controls
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FilterChip(
                            title: "All",
                            isSelected: selectedFilter == nil
                        ) {
                            selectedFilter = nil
                        }
                        
                        ForEach(ModerationSeverity.allCases.filter { $0 != .none }, id: \.self) { severity in
                            FilterChip(
                                title: severity.displayName,
                                isSelected: selectedFilter == severity,
                                color: severity.color
                            ) {
                                selectedFilter = severity
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom)
                
                // Queue list
                List {
                    ForEach(filteredQueue) { item in
                        ModerationItemRow(item: item) { action in
                            handleModerationAction(item: item, action: action)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Moderation Queue")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private func handleModerationAction(item: ModerationItem, action: ModerationAction) {
        switch action {
        case .approved:
            moderationService.approveContent(item.contentId)
        case .blocked:
            moderationService.blockContent(item.contentId)
        default:
            break
        }
        
        HapticManager.shared.impact(.light)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    init(title: String, isSelected: Bool, color: Color = .blue, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.color = color
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

struct ModerationItemRow: View {
    let item: ModerationItem
    let onAction: (ModerationAction) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text(item.contentType.rawValue.capitalized)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                
                Spacer()
                
                Text(item.severity.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(item.severity.color.opacity(0.1))
                    .foregroundColor(item.severity.color)
                    .cornerRadius(8)
            }
            
            // Content preview
            Text(item.content)
                .font(.subheadline)
                .foregroundColor(.primaryText)
                .lineLimit(3)
            
            // Author and violations
            HStack {
                Text("By @\(item.author)")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                
                Spacer()
                
                HStack(spacing: 4) {
                    ForEach(item.violations, id: \.rawValue) { violation in
                        Image(systemName: violation.icon)
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            // Actions
            HStack(spacing: 12) {
                Button("Approve") {
                    onAction(.approved)
                }
                .buttonStyle(.bordered)
                .foregroundColor(.green)
                
                Button("Block") {
                    onAction(.blocked)
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
                
                Spacer()
                
                Text(item.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.tertiaryText)
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
}

#Preview("Report Content") {
    ContentReportView(contentId: "123", contentType: .post)
}

#Preview("Moderation Queue") {
    ModerationQueueView()
} 