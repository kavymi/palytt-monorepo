//
//  Bundle+Resources.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import Foundation

extension Bundle {
    /// The bundle containing the PalyttApp module resources
    static let palyttModule = Bundle.main
    
    /// Load an image from the module bundle
    static func imageFromModule(named name: String) -> String {
        // For SwiftUI Image views, we just need the name
        // The bundle is handled automatically when using Image(name, bundle: .main)
        return name
    }
} 