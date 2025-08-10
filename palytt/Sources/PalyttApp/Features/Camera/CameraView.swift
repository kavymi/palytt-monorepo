//
//  CameraView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import SwiftUI
import AVFoundation
import PhotosUI
#if os(iOS)
import UIKit
#endif

struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showImagePicker = false
    @State private var showPhotoLibrary = false
    @State private var selectedMode: CameraMode = .photo
    
    enum CameraMode: String, CaseIterable {
        case photo = "Photo"
        case portrait = "Portrait"
        case video = "Video"
        
        var icon: String {
            switch self {
            case .photo: return "camera.fill"
            case .portrait: return "person.crop.circle.fill"
            case .video: return "video.fill"
            }
        }
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Controls
                topControls
                
                // Camera Preview
                cameraPreview
                
                // Bottom Controls
                bottomControls
                
                // Recent Photos Strip (if photos exist)
                if !viewModel.capturedImages.isEmpty {
                    recentPhotosStrip
                }
            }
        }
        #if os(iOS)
        .navigationBarHidden(true)
        #else
        .toolbar(.hidden)
        #endif
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.requestCameraPermission()
        }
        .onDisappear {
            viewModel.stopSession()
        }
        .alert("Upload Complete", isPresented: $viewModel.showUploadSuccess) {
            Button("OK") {
                viewModel.showUploadSuccess = false
            }
        } message: {
            Text("Images uploaded successfully!")
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error occurred")
        }
        .sheet(isPresented: $showPhotoLibrary) {
#if os(iOS)
            PhotoLibraryPicker(selectedImages: $viewModel.selectedLibraryImages)
#else
            PhotoLibraryPicker(selectedImages: .constant([]))
#endif
        }
        .sheet(isPresented: $viewModel.showUploadProgress) {
            UploadProgressView(viewModel: viewModel)
        }
    }
    
    // MARK: - Top Controls
    
    private var topControls: some View {
        HStack {
            // Close Button
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.black.opacity(0.3)))
            }
            
            Spacer()
            
            // Flash Control
            Button(action: viewModel.toggleFlash) {
                Image(systemName: viewModel.flashMode.icon)
                    .font(.title2)
                    .foregroundColor(viewModel.flashMode == .off ? .white : .yellow)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.black.opacity(0.3)))
            }
            
            // Timer Control
            Button(action: viewModel.toggleTimer) {
                Text(viewModel.timerDuration > 0 ? "\(viewModel.timerDuration)" : "")
                    .font(.caption)
                    .foregroundColor(.white)
                Image(systemName: "timer")
                    .font(.title2)
                    .foregroundColor(viewModel.timerDuration > 0 ? .yellow : .white)
            }
            .frame(width: 44, height: 44)
            .background(Circle().fill(Color.black.opacity(0.3)))
            
            // Settings
            Button(action: { /* Settings action */ }) {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.black.opacity(0.3)))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    // MARK: - Camera Preview
    
    private var cameraPreview: some View {
        GeometryReader { geometry in
            ZStack {
                // Camera Preview
                CameraPreviewView(session: viewModel.captureSession)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                
                // Camera Mode Selector
                VStack {
                    Spacer()
                    
                    // Mode Selector
                    HStack(spacing: 20) {
                        ForEach(CameraMode.allCases, id: \.self) { mode in
                            Button(action: {
                                withAnimation(.spring()) {
                                    selectedMode = mode
                                    viewModel.setCameraMode(mode)
                                }
                            }) {
                                Text(mode.rawValue)
                                    .font(.system(size: 16, weight: selectedMode == mode ? .bold : .medium))
                                    .foregroundColor(selectedMode == mode ? .yellow : .white)
                                    .scaleEffect(selectedMode == mode ? 1.1 : 1.0)
                            }
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.3))
                            .blur(radius: 10)
                    )
                    
                    Spacer().frame(height: 40)
                }
                
                // Focus and Exposure Controls
                if viewModel.showFocusIndicator {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.yellow, lineWidth: 2)
                        .frame(width: 80, height: 80)
                        .position(viewModel.focusPoint)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.focusPoint)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                viewModel.showFocusIndicator = false
                            }
                        }
                }
            }
            .onTapGesture { location in
                viewModel.focusAndExpose(at: location)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
    
    // MARK: - Bottom Controls
    
    private var bottomControls: some View {
        HStack(spacing: 30) {
            // Photo Library Button
            Button(action: { showPhotoLibrary = true }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 60)
                    
#if os(iOS)
                    if let lastImage = viewModel.capturedImages.last {
                        Image(uiImage: lastImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        Image(systemName: "photo.stack.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
#else
                    Image(systemName: "photo.stack.fill")
                        .font(.title2)
                        .foregroundColor(.white)
#endif
                }
            }
            
            Spacer()
            
            // Capture Button
            Button(action: viewModel.capturePhoto) {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 70, height: 70)
                        .scaleEffect(viewModel.isCapturing ? 0.8 : 1.0)
                        .animation(.easeInOut(duration: 0.1), value: viewModel.isCapturing)
                }
            }
            .disabled(viewModel.isCapturing)
            
            Spacer()
            
            // Camera Flip Button
            Button(action: viewModel.flipCamera) {
                Image(systemName: "camera.rotate.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Circle().fill(Color.black.opacity(0.3)))
            }
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 20)
    }
    
    // MARK: - Recent Photos Strip
    
    private var recentPhotosStrip: some View {
        VStack(spacing: 12) {
            // Upload Button
            if !viewModel.capturedImages.isEmpty {
                Button(action: viewModel.uploadImages) {
                    HStack {
                        Image(systemName: "icloud.and.arrow.up.fill")
                        Text("Upload \(viewModel.capturedImages.count) photo\(viewModel.capturedImages.count == 1 ? "" : "s")")
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.primaryBrand)
                    )
                }
                .disabled(viewModel.isUploading)
            }
            
            // Photos Strip
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(Array(viewModel.capturedImages.enumerated()), id: \.offset) { index, image in
                        ZStack(alignment: .topTrailing) {
#if os(iOS)
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
#else
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 80, height: 80)
#endif
                            
                            // Delete Button
                            Button(action: {
                                withAnimation(.spring()) {
                                    viewModel.removeImage(at: index)
                                }
                                HapticManager.shared.impact(.light)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.black.opacity(0.6)))
                            }
                            .padding(4)
                            
                            // Upload Status Indicator
                            if let uploadStatus = viewModel.uploadStatuses[index] {
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        uploadStatusIndicator(for: uploadStatus)
                                            .padding(6)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 10)
    }
    
    // MARK: - Upload Status Indicator
    
    @ViewBuilder
    private func uploadStatusIndicator(for status: UploadStatus) -> some View {
        switch status {
        case .uploading(let progress):
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    .frame(width: 20, height: 20)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.green, lineWidth: 2)
                    .frame(width: 20, height: 20)
                    .rotationEffect(.degrees(-90))
            }
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 20))
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
                .font(.system(size: 20))
        }
    }
}

// MARK: - Camera Preview View

#if os(iOS)
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.frame
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}
#else
struct CameraPreviewView: View {
    let session: AVCaptureSession
    
    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.gray.opacity(0.3))
            .overlay(
                VStack {
                    Image(systemName: "camera.fill")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("Camera Preview")
                        .foregroundColor(.gray)
                }
            )
    }
}
#endif

// MARK: - Photo Library Picker

#if os(iOS)
struct PhotoLibraryPicker: View {
    @Binding var selectedImages: [UIImage]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItems: [PhotosPickerItem] = []
    
    var body: some View {
        NavigationStack {
            PhotosPicker(
                selection: $selectedItems,
                maxSelectionCount: 10,
                matching: .images
            ) {
                VStack(spacing: 20) {
                    Image(systemName: "photo.stack.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.primaryBrand)
                    
                    Text("Select Photos")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Choose up to 10 photos from your library")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.background)
            }
            .navigationTitle("Photo Library")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.primaryBrand)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.primaryBrand)
                    .disabled(selectedItems.isEmpty)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.primaryBrand)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.primaryBrand)
                    .disabled(selectedItems.isEmpty)
                }
                #endif
            }
            .onChange(of: selectedItems) { _, newItems in
                Task {
                    var images: [UIImage] = []
                    for item in newItems {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            images.append(image)
                        }
                    }
                    await MainActor.run {
                        selectedImages = images
                    }
                }
            }
        }
    }
}
#else
struct PhotoLibraryPicker: View {
    @Binding var selectedImages: [NSImage]
    
    var body: some View {
        VStack {
            Image(systemName: "photo.stack.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("Photo Library")
                .font(.title2)
            Text("Not available on this platform")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
}
#endif

// MARK: - Upload Progress View

struct UploadProgressView: View {
    @ObservedObject var viewModel: CameraViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            UploadProgressContent(viewModel: viewModel)
                .navigationTitle("Upload Progress")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    UploadProgressToolbar(viewModel: viewModel, dismiss: dismiss)
                }
        }
    }
}

// MARK: - Upload Progress Content

struct UploadProgressContent: View {
    @ObservedObject var viewModel: CameraViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            UploadProgressIndicator(viewModel: viewModel)
            UploadProgressHeader()
            
            if !viewModel.uploadStatuses.isEmpty {
                UploadStatusList(viewModel: viewModel)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Upload Progress Indicator

struct UploadProgressIndicator: View {
    @ObservedObject var viewModel: CameraViewModel
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                .frame(width: 120, height: 120)
            
            Circle()
                .trim(from: 0, to: viewModel.uploadProgress)
                .stroke(Color.primaryBrand, lineWidth: 8)
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: viewModel.uploadProgress)
            
            VStack {
                Image(systemName: "icloud.and.arrow.up.fill")
                    .font(.title)
                    .foregroundColor(.primaryBrand)
                
                Text("\(Int(viewModel.uploadProgress * 100))%")
                    .font(.headline)
                    .fontWeight(.bold)
            }
        }
    }
}

// MARK: - Upload Progress Header

struct UploadProgressHeader: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Uploading Images")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Please wait while we upload your photos...")
                .font(.subheadline)
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Upload Status List

struct UploadStatusList: View {
    @ObservedObject var viewModel: CameraViewModel
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(viewModel.uploadStatuses.keys.sorted()), id: \.self) { index in
                    if let status = viewModel.uploadStatuses[index] {
                        UploadStatusRow(
                            index: index,
                            status: status,
                            capturedImages: viewModel.capturedImages
                        )
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Upload Status Row

struct UploadStatusRow: View {
    let index: Int
    let status: UploadStatus
    #if os(iOS)
    let capturedImages: [UIImage]
    #else
    let capturedImages: [NSImage]
    #endif
    
    var body: some View {
        HStack {
            UploadStatusRowImage(index: index, capturedImages: capturedImages)
            UploadStatusRowContent(index: index, status: status)
            Spacer()
            UploadStatusRowIndicator(status: status)
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Upload Status Row Components

struct UploadStatusRowImage: View {
    let index: Int
    #if os(iOS)
    let capturedImages: [UIImage]
    #else
    let capturedImages: [NSImage]
    #endif
    
    var body: some View {
        #if os(iOS)
        if index < capturedImages.count {
            Image(uiImage: capturedImages[index])
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 40)
        }
        #else
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.3))
            .frame(width: 40, height: 40)
        #endif
    }
}

struct UploadStatusRowContent: View {
    let index: Int
    let status: UploadStatus
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Image \(index + 1)")
                .font(.subheadline)
                .fontWeight(.medium)
            
            switch status {
            case .uploading(let progress):
                Text("Uploading... \(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            case .success:
                Text("Upload complete")
                    .font(.caption)
                    .foregroundColor(.green)
            case .failed:
                Text("Upload failed")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
}

struct UploadStatusRowIndicator: View {
    let status: UploadStatus
    
    var body: some View {
        switch status {
        case .uploading:
            ProgressView()
                .scaleEffect(0.8)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
        }
    }
}

// MARK: - Upload Progress Toolbar

struct UploadProgressToolbar: ToolbarContent {
    @ObservedObject var viewModel: CameraViewModel
    let dismiss: DismissAction
    
    var body: some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Done") {
                dismiss()
            }
            .disabled(viewModel.isUploading)
        }
        #else
        ToolbarItem(placement: .confirmationAction) {
            Button("Done") {
                dismiss()
            }
            .disabled(viewModel.isUploading)
        }
        #endif
    }
}

#Preview {
    CameraView()
        .environmentObject(MockAppState())
} 