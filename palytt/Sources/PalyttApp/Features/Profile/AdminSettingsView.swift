//
//  AdminSettingsView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI
import Combine

struct AdminSettingsView: View {
    @StateObject private var apiConfig = APIConfigurationManager.shared
    @StateObject private var backendService = BackendService.shared
    @ObservedObject var profileViewModel: ProfileViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingConfirmation = false
    @State private var selectedEnvironment: APIEnvironment = .local
    @State private var showingDebugInfo = false
    
    var currentUser: User? {
        return appState.currentUser
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    VStack(spacing: 12) {
                        Circle()
                            .fill(Color.error)
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "shield.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                            )
                        
                        Text("Admin Settings")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primaryText)
                        
                        Text("Manage API environments and debug tools")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    VStack(spacing: 20) {
                        // Current API Environment Status
                        Section(header: Text("API Environment")) {
                            HStack {
                                Image(systemName: apiConfig.currentEnvironment.statusIcon)
                                    .foregroundColor(apiConfig.currentEnvironment.statusIcon == "laptopcomputer" ? .orange : .green)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(apiConfig.currentEnvironment.displayName)
                                        .font(.headline)
                                    Text(apiConfig.currentTRPCURL)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("Convex: \(apiConfig.currentConvexURL)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Circle()
                                    .fill(apiConfig.isHealthy ? Color.green : Color.red)
                                    .frame(width: 12, height: 12)
                            }
                            .padding(.vertical, 4)
                            
                            // Debug Information
                            VStack(alignment: .leading, spacing: 8) {
                                Text("🔧 Debug Info:")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                
                                Text("Current Build: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                #if DEBUG
                                Text("Build Type: DEBUG")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                #else
                                Text("Build Type: RELEASE")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                #endif
                                
                                if let lastCheck = apiConfig.lastHealthCheck {
                                    Text("Last Health Check: \(DateFormatter.localizedString(from: lastCheck, dateStyle: .none, timeStyle: .medium))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let error = apiConfig.healthCheckError {
                                    Text("Error: \(error)")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        // Environment Switching
                        if profileViewModel.currentUser?.isAdmin == true {
                            Section(header: Text("Switch Environment (Admin Only)")) {
                                ForEach(APIEnvironment.allCases, id: \.self) { environment in
                                    Button(action: {
                                        apiConfig.switchEnvironment(to: environment, userRole: profileViewModel.currentUser?.role ?? .user)
                                    }) {
                                        HStack {
                                            Image(systemName: environment.statusIcon)
                                            Text(environment.displayName)
                                            
                                            Spacer()
                                            
                                            if environment == apiConfig.currentEnvironment {
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(.green)
                                            }
                                        }
                                    }
                                    .disabled(environment == apiConfig.currentEnvironment)
                                }
                            }
                        }
                        
                        // Test Buttons
                        Section(header: Text("API Testing")) {
                            Button("Perform Health Check") {
                                Task {
                                    await apiConfig.performHealthCheck()
                                }
                            }
                            
                            Button("Test Backend Connection") {
                                Task {
                                    do {
                                        let isHealthy = try await backendService.healthCheck()
                                        print("✅ Backend connection test: \(isHealthy ? "SUCCESS" : "FAILED")")
                                    } catch {
                                        print("❌ Backend connection test failed: \(error)")
                                    }
                                }
                            }
                            
                            Button("Reset to Build Default") {
                                apiConfig.resetToDefault()
                            }
                            .foregroundColor(.orange)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 100)
                }
            }
            .background(Color.background)
            .scrollContentBackground(.hidden)
            .navigationTitle("")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        HapticManager.shared.impact(.light)
                        dismiss()
                    }
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryBrand)
                }
                #else
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        HapticManager.shared.impact(.light)
                        dismiss()
                    }
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryBrand)
                }
                #endif
            }
        }
        .background(Color.background)
        .alert("Switch API Environment", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Switch", role: .destructive) {
                switchEnvironment()
            }
        } message: {
            Text("Are you sure you want to switch to \(selectedEnvironment.displayName)? This will change all API calls to use \(selectedEnvironment.baseURL)")
        }
        .sheet(isPresented: $showingDebugInfo) {
            DebugInfoView(debugInfo: apiConfig.debugInfo)
        }
    }
    
    private func switchEnvironment() {
        guard let userRole = currentUser?.role else {
            print("⚠️ No user role available")
            return
        }
        
        HapticManager.shared.impact(.heavy)
        apiConfig.switchEnvironment(to: selectedEnvironment, userRole: userRole)
    }
}

// MARK: - API Status Row
struct APIStatusRow: View {
    let environment: APIEnvironment
    let isHealthy: Bool
    let lastHealthCheck: Date?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(Color.primaryBrand.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: environment.statusIcon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primaryBrand)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(environment.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                    
                    Text(environment.baseURL)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isHealthy ? Color.success : Color.error)
                            .frame(width: 8, height: 8)
                        
                        Text(isHealthy ? "Healthy" : "Unhealthy")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(isHealthy ? .success : .error)
                    }
                    
                    if let lastCheck = lastHealthCheck {
                        Text("Last: \(DateFormatter.localizedString(from: lastCheck, dateStyle: .none, timeStyle: .short))")
                            .font(.caption2)
                            .foregroundColor(.warmAccentText)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Environment Row
struct EnvironmentRow: View {
    let environment: APIEnvironment
    let isSelected: Bool
    let isHealthy: Bool?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(.light)
            onTap()
        }) {
            HStack(spacing: 12) {
                Circle()
                    .fill(isSelected ? Color.primaryBrand.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: environment.statusIcon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(isSelected ? .primaryBrand : .secondaryText)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(environment.displayName)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .medium)
                        .foregroundColor(.primaryText)
                    
                    Text(environment.baseURL)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if isSelected {
                    Circle()
                        .fill(Color.primaryBrand)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        )
                } else {
                    Circle()
                        .stroke(Color.secondaryText.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isSelected)
        .opacity(isSelected ? 0.8 : 1.0)
    }
}

// MARK: - Debug Info View
struct DebugInfoView: View {
    let debugInfo: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(debugInfo)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.primaryText)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding()
            }
            .background(Color.background)
            .navigationTitle("Debug Information")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryBrand)
                }
                #else
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryBrand)
                }
                #endif
            }
        }
        .background(Color.background)
    }
}

// MARK: - Admin Section View
struct AdminSectionView<Content: View>: View {
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
                    .foregroundColor(.primaryText)
            }
            .padding(.horizontal, 4)
            
            VStack(spacing: 8) {
                content
            }
            .padding(16)
            .background(Color.cardBackground)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
    }
}

// MARK: - Admin Action Row
struct AdminActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(.light)
            action()
        }) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.primaryBrand.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primaryBrand)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primaryText)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.warmAccentText)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Previews
#Preview("Admin Settings - Local") {
    AdminSettingsView(profileViewModel: ProfileViewModel())
        .environmentObject(MockAppState())
}

#Preview("Admin Settings - Production") {
    AdminSettingsView(profileViewModel: ProfileViewModel())
        .environmentObject({
            let mockAppState = MockAppState()
            // Set mock user as admin
            mockAppState.currentUser = User(
                email: "admin@palytt.com",
                username: "admin",
                displayName: "Admin User",
                role: .admin
            )
            return mockAppState
        }())
} 