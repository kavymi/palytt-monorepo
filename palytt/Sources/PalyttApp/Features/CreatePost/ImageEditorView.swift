//
//  ImageEditorView.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
#if os(iOS)
import UIKit
#endif

// MARK: - Image Editor View

/// A view for editing images with crop, rotate, and filter capabilities
struct ImageEditorView: View {
    @Binding var image: UIImage
    @Environment(\.dismiss) private var dismiss
    
    @State private var editedImage: UIImage
    @State private var selectedFilter: ImageFilter = .none
    @State private var brightness: Double = 0
    @State private var contrast: Double = 1
    @State private var saturation: Double = 1
    @State private var warmth: Double = 0
    @State private var rotation: Double = 0
    @State private var showCropView = false
    @State private var isProcessing = false
    
    private let context = CIContext()
    
    init(image: Binding<UIImage>) {
        self._image = image
        self._editedImage = State(initialValue: image.wrappedValue)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Image Preview
                GeometryReader { geometry in
                    ZStack {
                        Color.black
                        
                        Image(uiImage: editedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .rotationEffect(.degrees(rotation))
                            .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                        
                        if isProcessing {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                        }
                    }
                }
                
                // Editor Controls
                VStack(spacing: 16) {
                    // Filter Presets
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(ImageFilter.allCases) { filter in
                                FilterPresetButton(
                                    filter: filter,
                                    originalImage: image,
                                    isSelected: selectedFilter == filter,
                                    onSelect: {
                                        selectedFilter = filter
                                        applyFilter()
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // Adjustment Sliders
                    VStack(spacing: 12) {
                        AdjustmentSlider(
                            icon: "sun.max.fill",
                            label: "Brightness",
                            value: $brightness,
                            range: -0.5...0.5,
                            onChange: applyAdjustments
                        )
                        
                        AdjustmentSlider(
                            icon: "circle.lefthalf.filled",
                            label: "Contrast",
                            value: $contrast,
                            range: 0.5...1.5,
                            onChange: applyAdjustments
                        )
                        
                        AdjustmentSlider(
                            icon: "drop.fill",
                            label: "Saturation",
                            value: $saturation,
                            range: 0...2,
                            onChange: applyAdjustments
                        )
                        
                        AdjustmentSlider(
                            icon: "thermometer.medium",
                            label: "Warmth",
                            value: $warmth,
                            range: -0.5...0.5,
                            onChange: applyAdjustments
                        )
                    }
                    .padding(.horizontal, 16)
                    
                    // Action Buttons
                    HStack(spacing: 20) {
                        // Rotate Left
                        EditorActionButton(
                            icon: "rotate.left",
                            label: "Rotate",
                            action: rotateLeft
                        )
                        
                        // Crop
                        EditorActionButton(
                            icon: "crop",
                            label: "Crop",
                            action: { showCropView = true }
                        )
                        
                        // Reset
                        EditorActionButton(
                            icon: "arrow.counterclockwise",
                            label: "Reset",
                            action: resetEdits
                        )
                    }
                    .padding(.vertical, 8)
                }
                .padding(.vertical, 16)
                .background(Color.cardBackground)
            }
            .background(Color.black)
            .navigationTitle("Edit Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        image = editedImage
                        HapticManager.shared.impact(.success)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryBrand)
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .sheet(isPresented: $showCropView) {
            CropView(image: $editedImage)
        }
    }
    
    // MARK: - Image Processing
    
    private func applyFilter() {
        isProcessing = true
        
        Task {
            let filtered = await ImageFilterService.shared.applyFilter(
                selectedFilter,
                to: image
            )
            
            await MainActor.run {
                editedImage = filtered
                applyAdjustments()
                isProcessing = false
            }
        }
    }
    
    private func applyAdjustments() {
        guard !isProcessing else { return }
        isProcessing = true
        
        Task {
            let adjusted = await ImageFilterService.shared.applyAdjustments(
                to: selectedFilter == .none ? image : editedImage,
                brightness: brightness,
                contrast: contrast,
                saturation: saturation,
                warmth: warmth
            )
            
            await MainActor.run {
                editedImage = adjusted
                isProcessing = false
            }
        }
    }
    
    private func rotateLeft() {
        withAnimation(.easeInOut(duration: 0.2)) {
            rotation -= 90
            if rotation <= -360 {
                rotation = 0
            }
        }
        
        // Apply rotation to actual image
        if let rotated = image.rotated(by: -90) {
            editedImage = rotated
            applyFilter()
        }
        
        HapticManager.shared.impact(.light)
    }
    
    private func resetEdits() {
        withAnimation {
            selectedFilter = .none
            brightness = 0
            contrast = 1
            saturation = 1
            warmth = 0
            rotation = 0
            editedImage = image
        }
        HapticManager.shared.impact(.medium)
    }
}

// MARK: - Image Filter Enum

enum ImageFilter: String, CaseIterable, Identifiable {
    case none = "Original"
    case warm = "Warm"
    case cool = "Cool"
    case vintage = "Vintage"
    case noir = "Noir"
    case vivid = "Vivid"
    case fade = "Fade"
    case chrome = "Chrome"
    
    var id: String { rawValue }
    
    var displayName: String { rawValue }
}

// MARK: - Image Filter Service

@MainActor
class ImageFilterService {
    static let shared = ImageFilterService()
    
    private let context = CIContext()
    
    private init() {}
    
    func applyFilter(_ filter: ImageFilter, to image: UIImage) async -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        
        var outputImage: CIImage = ciImage
        
        switch filter {
        case .none:
            return image
            
        case .warm:
            let temperatureFilter = CIFilter.temperatureAndTint()
            temperatureFilter.inputImage = ciImage
            temperatureFilter.neutral = CIVector(x: 6500, y: 0)
            temperatureFilter.targetNeutral = CIVector(x: 5000, y: 0)
            outputImage = temperatureFilter.outputImage ?? ciImage
            
        case .cool:
            let temperatureFilter = CIFilter.temperatureAndTint()
            temperatureFilter.inputImage = ciImage
            temperatureFilter.neutral = CIVector(x: 6500, y: 0)
            temperatureFilter.targetNeutral = CIVector(x: 8000, y: 0)
            outputImage = temperatureFilter.outputImage ?? ciImage
            
        case .vintage:
            let sepia = CIFilter.sepiaTone()
            sepia.inputImage = ciImage
            sepia.intensity = 0.4
            
            if let sepiaOutput = sepia.outputImage {
                let vignette = CIFilter.vignette()
                vignette.inputImage = sepiaOutput
                vignette.intensity = 1.0
                vignette.radius = 2.0
                outputImage = vignette.outputImage ?? sepiaOutput
            }
            
        case .noir:
            let noir = CIFilter.photoEffectNoir()
            noir.inputImage = ciImage
            outputImage = noir.outputImage ?? ciImage
            
        case .vivid:
            let vibrance = CIFilter.vibrance()
            vibrance.inputImage = ciImage
            vibrance.amount = 1.0
            outputImage = vibrance.outputImage ?? ciImage
            
        case .fade:
            let fade = CIFilter.photoEffectFade()
            fade.inputImage = ciImage
            outputImage = fade.outputImage ?? ciImage
            
        case .chrome:
            let chrome = CIFilter.photoEffectChrome()
            chrome.inputImage = ciImage
            outputImage = chrome.outputImage ?? ciImage
        }
        
        return renderImage(outputImage, originalImage: image)
    }
    
    func applyAdjustments(
        to image: UIImage,
        brightness: Double,
        contrast: Double,
        saturation: Double,
        warmth: Double
    ) async -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        
        var outputImage = ciImage
        
        // Apply color controls (brightness, contrast, saturation)
        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = outputImage
        colorControls.brightness = Float(brightness)
        colorControls.contrast = Float(contrast)
        colorControls.saturation = Float(saturation)
        
        if let colorOutput = colorControls.outputImage {
            outputImage = colorOutput
        }
        
        // Apply warmth (temperature)
        if warmth != 0 {
            let temperature = CIFilter.temperatureAndTint()
            temperature.inputImage = outputImage
            temperature.neutral = CIVector(x: 6500, y: 0)
            temperature.targetNeutral = CIVector(x: 6500 - warmth * 3000, y: 0)
            
            if let tempOutput = temperature.outputImage {
                outputImage = tempOutput
            }
        }
        
        return renderImage(outputImage, originalImage: image)
    }
    
    private func renderImage(_ ciImage: CIImage, originalImage: UIImage) -> UIImage {
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return originalImage
        }
        return UIImage(cgImage: cgImage, scale: originalImage.scale, orientation: originalImage.imageOrientation)
    }
}

// MARK: - Filter Preset Button

struct FilterPresetButton: View {
    let filter: ImageFilter
    let originalImage: UIImage
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var previewImage: UIImage?
    
    var body: some View {
        Button(action: {
            onSelect()
            HapticManager.shared.impact(.light)
        }) {
            VStack(spacing: 6) {
                // Preview Image
                Group {
                    if let preview = previewImage {
                        Image(uiImage: preview)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(uiImage: originalImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.primaryBrand : Color.clear, lineWidth: 2)
                )
                
                // Label
                Text(filter.displayName)
                    .font(.caption2)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .primaryBrand : .secondaryText)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .task {
            // Generate preview thumbnail
            let thumbnail = originalImage.thumbnailImage(maxSize: 60)
            previewImage = await ImageFilterService.shared.applyFilter(filter, to: thumbnail)
        }
    }
}

// MARK: - Adjustment Slider

struct AdjustmentSlider: View {
    let icon: String
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let onChange: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.primaryBrand)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(label)
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    
                    Spacer()
                    
                    Text(String(format: "%.1f", value))
                        .font(.caption)
                        .foregroundColor(.tertiaryText)
                        .monospacedDigit()
                }
                
                Slider(value: $value, in: range)
                    .tint(.primaryBrand)
                    .onChange(of: value) { _, _ in
                        onChange()
                    }
            }
        }
    }
}

// MARK: - Editor Action Button

struct EditorActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.primaryText)
                
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondaryText)
            }
            .frame(width: 60)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Simple Crop View

struct CropView: View {
    @Binding var image: UIImage
    @Environment(\.dismiss) private var dismiss
    
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color.black
                    
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale = min(max(scale * delta, 1), 4)
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                }
                        )
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                    
                    // Crop overlay
                    Rectangle()
                        .stroke(Color.white, lineWidth: 1)
                        .frame(
                            width: min(geometry.size.width - 40, geometry.size.height - 40),
                            height: min(geometry.size.width - 40, geometry.size.height - 40)
                        )
                }
            }
            .navigationTitle("Crop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        // Apply crop
                        HapticManager.shared.impact(.success)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryBrand)
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

// MARK: - UIImage Extensions

extension UIImage {
    func rotated(by degrees: CGFloat) -> UIImage? {
        let radians = degrees * .pi / 180
        var newSize = CGRect(origin: .zero, size: size)
            .applying(CGAffineTransform(rotationAngle: radians))
            .integral.size
        
        // Ensure size is positive
        newSize.width = abs(newSize.width)
        newSize.height = abs(newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
        context.rotate(by: radians)
        
        draw(in: CGRect(
            x: -size.width / 2,
            y: -size.height / 2,
            width: size.width,
            height: size.height
        ))
        
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return rotatedImage
    }
    
    func thumbnailImage(maxSize: CGFloat) -> UIImage {
        let aspectRatio = size.width / size.height
        var targetSize: CGSize
        
        if size.width > size.height {
            targetSize = CGSize(width: maxSize, height: maxSize / aspectRatio)
        } else {
            targetSize = CGSize(width: maxSize * aspectRatio, height: maxSize)
        }
        
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 0)
        draw(in: CGRect(origin: .zero, size: targetSize))
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return thumbnail ?? self
    }
}

// MARK: - Preview

#Preview {
    ImageEditorView(image: .constant(UIImage(systemName: "photo")!))
}

