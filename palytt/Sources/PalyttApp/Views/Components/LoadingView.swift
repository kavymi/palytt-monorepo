//
//  LoadingView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI

// MARK: - Branded Loading View
struct LoadingView: View {
    @State private var isAnimating = false
    let message: String
    
    init(_ message: String = "Loading...") {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Animated Logo
            Image("palytt-logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .scaleEffect(isAnimating ? 1.1 : 0.9)
                .opacity(isAnimating ? 0.7 : 1.0)
                .animation(
                    .easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true),
                    value: isAnimating
                )
            
            // Loading Text
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondaryText)
            
            // Loading Indicator
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .primaryBrand))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.background)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - App Launch Loading View
struct AppLaunchLoadingView: View {
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0.0
    @State private var textOpacity: Double = 0.0
    
    var body: some View {
        VStack {
            Spacer()
            Image("palytt-logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.background)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            
            withAnimation(.easeInOut(duration: 0.6).delay(0.3)) {
                textOpacity = 1.0
            }
        }
    }
}

// MARK: - Mini Loading State
struct MiniLoadingView: View {
    @State private var isRotating = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image("palytt-logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .rotationEffect(.degrees(isRotating ? 360 : 0))
                .animation(
                    .linear(duration: 2.0)
                    .repeatForever(autoreverses: false),
                    value: isRotating
                )
            
            Text("Loading...")
                .font(.caption)
                .foregroundColor(.secondaryText)
        }
        .onAppear {
            isRotating = true
        }
    }
}

/// Animated loading bar for post creation
struct PostCreationLoadingBar: View {
    @State private var progress: Double = 0.0
    @State private var animationPhase: Int = 0
    
    let messages = [
        "Preparing your post...",
        "Processing content...",
        "Uploading to server...",
        "Almost done..."
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            // Progress bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Creating Post")
                        .font(.headline)
                        .foregroundColor(.primaryText)
                    
                    Spacer()
                    
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                
                // Animated progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 8)
                        
                        // Progress fill
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [.milkTea, .milkTea.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * progress, height: 8)
                            .animation(.easeInOut(duration: 0.3), value: progress)
                    }
                }
                .frame(height: 8)
            }
            
            // Status message
            Text(messages[min(animationPhase, messages.count - 1)])
                .font(.body)
                .foregroundColor(.secondaryText)
                .animation(.easeInOut(duration: 0.3), value: animationPhase)
        }
        .padding(20)
        .background(Color.background)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        // Animate progress bar
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if progress < 1.0 {
                progress += 0.02 // Increment by 2% each time
                
                // Change message at certain progress points
                let newPhase = Int(progress * Double(messages.count))
                if newPhase != animationPhase && newPhase < messages.count {
                    animationPhase = newPhase
                }
            } else {
                timer.invalidate()
            }
        }
        
        // Ensure timer runs on main thread
        RunLoop.main.add(timer, forMode: .common)
    }
}

// MARK: - Post Creation Top Loading Bar
struct PostCreationTopLoadingBar: View {
    @State private var progress: Double = 0.0
    @State private var statusIndex = 0
    
    private let statuses = [
        "Preparing your post...",
        "Uploading images...",
        "Processing content...",
        "Almost ready...",
        "Publishing..."
    ]
    
    var body: some View {
        VStack(spacing: 8) {
            // Status Text
            Text(statuses[statusIndex])
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primaryText)
                .animation(.easeInOut(duration: 0.3), value: statusIndex)
            
            // Progress Bar
            HStack(spacing: 8) {
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .primaryBrand))
                    .frame(height: 4)
                    .cornerRadius(2)
                
                Text("\(Int(progress * 100))%")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondaryText)
                    .frame(width: 30, alignment: .trailing)
            }
        }
        .padding()
        .background(Color.cardBackground.opacity(0.95))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.primaryBrand.opacity(0.2)),
            alignment: .bottom
        )
        .onAppear {
            startProgressAnimation()
        }
    }
    
    private func startProgressAnimation() {
        // Animate progress and update status messages
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            withAnimation(.easeInOut(duration: 0.4)) {
                progress += 0.15
                
                // Update status based on progress
                let newStatusIndex = min(Int(progress * Double(statuses.count)), statuses.count - 1)
                if newStatusIndex != statusIndex {
                    statusIndex = newStatusIndex
                }
                
                // Stop when progress reaches 95% (to avoid completing before actual upload)
                if progress >= 0.95 {
                    progress = 0.95
                    timer.invalidate()
                }
            }
        }
    }
}

// MARK: - SwiftUI Previews
#Preview("Loading View") {
    LoadingView("Loading posts...")
}

#Preview("App Launch Loading") {
    AppLaunchLoadingView()
}

#Preview("Mini Loading") {
    VStack {
        MiniLoadingView()
        Spacer()
    }
    .padding()
}

#Preview("Post Creation Loading Bar") {
    PostCreationLoadingBar()
        .padding()
        .background(Color.gray.opacity(0.1))
}

#Preview("Post Creation Top Loading Bar") {
    PostCreationTopLoadingBar()
        .padding()
        .background(Color.background)
}

#Preview("All Loading States") {
    VStack(spacing: 20) {
        LoadingView("Loading...")
            .frame(height: 200)
        
        PostCreationLoadingBar()
        
        MiniLoadingView()
    }
    .padding()
} 