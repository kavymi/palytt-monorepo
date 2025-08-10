//
//  CameraViewModel.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import Foundation
import AVFoundation
#if os(iOS)
import UIKit
#endif
import SwiftUI
import Combine

// Shared types that work on all platforms
enum UploadStatus {
    case uploading(Double)
    case success
    case failed
}

#if os(iOS)
@MainActor
class CameraViewModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    
    // MARK: - Published Properties
    @Published var capturedImage: UIImage?
    @Published var isShowingPreview = false
    @Published var isCameraAuthorized = false
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0
    @Published var uploadMessage: String = ""
    @Published var errorMessage: String?
    
    // Additional properties for enhanced camera features
    @Published var capturedImages: [UIImage] = []
    @Published var selectedLibraryImages: [UIImage] = []
    @Published var flashMode: FlashMode = .off
    @Published var timerDuration: Int = 0
    @Published var showFocusIndicator = false
    @Published var focusPoint: CGPoint = .zero
    @Published var isCapturing = false
    @Published var uploadStatuses: [Int: UploadStatus] = [:]
    @Published var showUploadSuccess = false
    @Published var showUploadProgress = false
    
    enum FlashMode {
        case off, on, auto
        var icon: String {
            switch self {
            case .off: return "bolt.slash.fill"
            case .on: return "bolt.fill"
            case .auto: return "bolt.badge.a.fill"
            }
        }
    }

    // Camera Session
    private var session: AVCaptureSession
    private var photoOutput: AVCapturePhotoOutput
    private var cameraInput: AVCaptureDeviceInput?
    private var backCamera: AVCaptureDevice?
    private var frontCamera: AVCaptureDevice?
    private var currentCamera: AVCaptureDevice?
    
    // Public access to capture session
    var captureSession: AVCaptureSession {
        return session
    }
    
    // Services
    private let backendService = BackendService.shared
    private let bunnyNetService = BunnyNetService.shared
    
    // MARK: - Initialization
    override init() {
        self.session = AVCaptureSession()
        self.photoOutput = AVCapturePhotoOutput()
        super.init()
        self.checkCameraAuthorization()
    }
    
    // MARK: - Camera Setup & Authorization
    private func setupCamera() {
        session.sessionPreset = .photo
        
        // Find cameras
        self.backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        self.frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        self.currentCamera = self.backCamera
        
        guard let camera = currentCamera,
              let input = try? AVCaptureDeviceInput(device: camera) else {
            self.errorMessage = "Failed to access camera"
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
            self.cameraInput = input
        }
        
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        
        DispatchQueue.global(qos: .userInitiated).start_session(session)
    }

    private func checkCameraAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.isCameraAuthorized = true
            self.setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.isCameraAuthorized = true
                        self?.setupCamera()
                    } else {
                        self?.errorMessage = "Camera access is required to take photos."
                    }
                }
            }
        case .denied, .restricted:
            self.errorMessage = "Camera access denied. Please enable it in Settings."
        @unknown default:
            self.errorMessage = "Unknown camera authorization status."
        }
    }

    // MARK: - Camera Actions
    func startSession() {
        if isCameraAuthorized && !session.isRunning {
             DispatchQueue.global(qos: .userInitiated).start_session(session)
        }
    }

    func stopSession() {
        if session.isRunning {
            session.stopRunning()
        }
    }
    
    func capturePhoto() {
        isCapturing = true
        let settings = AVCapturePhotoSettings()
        
        // Configure flash if needed
        if let device = currentCamera, device.hasFlash {
            switch flashMode {
            case .off:
                settings.flashMode = .off
            case .on:
                settings.flashMode = .on
            case .auto:
                settings.flashMode = .auto
            }
        }
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func retake() {
        capturedImage = nil
        isShowingPreview = false
        startSession()
    }
    
    func toggleFlash() {
        switch flashMode {
        case .off:
            flashMode = .on
        case .on:
            flashMode = .auto
        case .auto:
            flashMode = .off
        }
    }
    
    func toggleTimer() {
        timerDuration = timerDuration == 0 ? 3 : (timerDuration == 3 ? 10 : 0)
    }
    
    func setCameraMode(_ mode: CameraView.CameraMode) {
        // Implementation for camera mode switching
    }
    
    func focusAndExpose(at point: CGPoint) {
        focusPoint = point
        showFocusIndicator = true
        
        guard let device = currentCamera else { return }
        
        do {
            try device.lockForConfiguration()
            
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
            }
            
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Failed to configure focus and exposure: \(error)")
        }
    }
    
    func flipCamera() {
        guard let currentInput = cameraInput else { return }
        
        session.beginConfiguration()
        session.removeInput(currentInput)
        
        currentCamera = (currentCamera == backCamera) ? frontCamera : backCamera
        
        guard let camera = currentCamera,
              let newInput = try? AVCaptureDeviceInput(device: camera) else {
            session.commitConfiguration()
            return
        }
        
        if session.canAddInput(newInput) {
            session.addInput(newInput)
            cameraInput = newInput
        }
        
        session.commitConfiguration()
    }
    
    func removeImage(at index: Int) {
        guard index < capturedImages.count else { return }
        capturedImages.remove(at: index)
        uploadStatuses.removeValue(forKey: index)
        
        // Reindex upload statuses
        let newStatuses = uploadStatuses.compactMapValues { status in status }
        uploadStatuses = Dictionary(uniqueKeysWithValues: newStatuses.enumerated().map { ($0.offset, $0.element.value) })
    }
    
    func uploadImages() {
        guard !capturedImages.isEmpty else { return }
        
        isUploading = true
        showUploadProgress = true
        uploadProgress = 0.0
        
        let totalImages = capturedImages.count
        var completedUploads = 0
        
        for (index, image) in capturedImages.enumerated() {
            uploadStatuses[index] = .uploading(0.0)
            
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                uploadStatuses[index] = .failed
                completedUploads += 1
                updateOverallProgress(completed: completedUploads, total: totalImages)
                continue
            }
            
            let fileName = "\(UUID().uuidString).jpg"
            
            bunnyNetService.uploadImage(data: imageData, fileName: fileName) { [weak self] response in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    if response.success {
                        self.uploadStatuses[index] = .success
                    } else {
                        self.uploadStatuses[index] = .failed
                    }
                    
                    completedUploads += 1
                    self.updateOverallProgress(completed: completedUploads, total: totalImages)
                }
            }
        }
    }
    
    private func updateOverallProgress(completed: Int, total: Int) {
        uploadProgress = Double(completed) / Double(total)
        
        if completed == total {
            isUploading = false
            showUploadSuccess = uploadStatuses.values.allSatisfy { status in
                if case .success = status { return true }
                return false
            }
        }
    }
    
    // MARK: - Image Upload
    func usePhoto() {
        guard let image = capturedImage else { return }
        
        stopSession()
        isUploading = true
        uploadMessage = "Uploading..."
        uploadProgress = 0.0
        
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            let fileName = "\(UUID().uuidString).jpg"
            
            bunnyNetService.uploadImage(data: imageData, fileName: fileName) { [weak self] response in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    self.isUploading = false
                    if response.success, let url = response.url {
                        self.uploadMessage = "Upload successful!"
                        print("Uploaded image URL: \(url)")
                        Task {
                             await self.sendUploadedImagesToBackend([response])
                        }
                    } else {
                        self.uploadMessage = "Upload failed: \(response.error ?? "Unknown error")"
                    }
                }
            }
        }
    }
    
    private func sendUploadedImagesToBackend(_ uploadedImages: [BunnyNetService.UploadResponse]) async {
        let imageUrls = uploadedImages.compactMap { $0.url }
        guard !imageUrls.isEmpty else {
            uploadMessage = "No images to send to backend."
            return
        }
        
        do {
            try await backendService.sendImageUrls(imageUrls)
            uploadMessage = "Backend updated successfully!"
        } catch {
            uploadMessage = "Failed to send image URLs to backend: \(error.localizedDescription)"
        }
    }
    
    // MARK: - AVCapturePhotoCaptureDelegate
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        isCapturing = false
        
        if let error = error {
            self.errorMessage = "Error capturing photo: \(error.localizedDescription)"
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            self.errorMessage = "Could not get image data."
            return
        }
        
        if let image = UIImage(data: imageData) {
            self.capturedImage = image
            self.capturedImages.append(image)
            self.isShowingPreview = true
        }
    }
}

extension DispatchQueue {
    func start_session(_ session: AVCaptureSession) {
        session.startRunning()
    }
}
#else
// Placeholder implementation for non-iOS platforms
@MainActor
class CameraViewModel: NSObject, ObservableObject {
    @Published var capturedImage: NSImage?
    @Published var isShowingPreview = false
    @Published var isCameraAuthorized = false
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0
    @Published var uploadMessage: String = ""
    @Published var errorMessage: String?
    
    var capturedImages: [NSImage] = []
    var selectedLibraryImages: [NSImage] = []
    var captureSession = AVCaptureSession()
    var flashMode: FlashMode = .off
    var timerDuration: Int = 0
    var showFocusIndicator = false
    var focusPoint: CGPoint = .zero
    var isCapturing = false
    var uploadStatuses: [Int: UploadStatus] = [:]
    var showUploadSuccess = false
    var showUploadProgress = false
    
    enum FlashMode {
        case off, on, auto
        var icon: String {
            switch self {
            case .off: return "bolt.slash.fill"
            case .on: return "bolt.fill"
            case .auto: return "bolt.badge.a.fill"
            }
        }
    }
    
    func requestCameraPermission() {
        errorMessage = "Camera not available on this platform"
    }
    
    func stopSession() { }
    func toggleFlash() { }
    func toggleTimer() { }
    func setCameraMode(_ mode: CameraView.CameraMode) { }
    func focusAndExpose(at point: CGPoint) { }
    func capturePhoto() { }
    func flipCamera() { }
    func removeImage(at index: Int) { }
    func uploadImages() { }
}


#endif 