//
//  BunnyNetService.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
import Foundation
import UIKit

class BunnyNetService {
    static let shared = BunnyNetService()
    private init() {}

    // Bunny CDN Configuration
    private let apiKey = "72e3bc95-0ac6-487e-9d4e2012b37b-f319-4098"
    private let storageZoneName = "palytt"
    private let region = "" // Empty for Frankfurt (DE), or "ny", "la", "uk", "sg", "se", "br", "jh"
    private let baseHostname = "storage.bunnycdn.com"
    private let cdnHostname = "palytt.b-cdn.net" // Fixed typo: was "payltt"

    struct UploadResponse {
        let success: Bool
        let url: String?
        let error: String?
        let fileName: String?
        let fileSize: Int?
    }
    
    enum ContentType: String {
        case jpeg = "image/jpeg"
        case png = "image/png"
        case webp = "image/webp"
        case mp4 = "video/mp4"
        case octetStream = "application/octet-stream"
        
        static func from(fileName: String) -> ContentType {
            let ext = (fileName as NSString).pathExtension.lowercased()
            switch ext {
            case "jpg", "jpeg": return .jpeg
            case "png": return .png
            case "webp": return .webp
            case "mp4": return .mp4
            default: return .octetStream
            }
        }
    }

    /// Upload a file to Bunny CDN
    /// - Parameters:
    ///   - data: The file data to upload
    ///   - fileName: The desired filename (will be made unique automatically)
    ///   - path: Optional subdirectory path (e.g., "images", "videos")
    ///   - completion: Completion handler with upload result
    func uploadFile(data: Data, fileName: String, path: String? = nil, completion: @escaping (UploadResponse) -> Void) {
        // Generate unique filename to avoid conflicts
        let timestamp = Int(Date().timeIntervalSince1970)
        let uuid = UUID().uuidString.prefix(8)
        let fileExtension = (fileName as NSString).pathExtension
        let baseName = (fileName as NSString).deletingPathExtension
        let uniqueFileName = "\(baseName)_\(timestamp)_\(uuid).\(fileExtension)"
        
        // Build the full path
        let fullPath: String
        if let path = path, !path.isEmpty {
            fullPath = "\(path)/\(uniqueFileName)"
        } else {
            fullPath = uniqueFileName
        }
        
        // Build the upload URL according to Bunny CDN API spec
        let hostname = region.isEmpty ? baseHostname : "\(region).\(baseHostname)"
        let urlString = "https://\(hostname)/\(storageZoneName)/\(fullPath)"
        
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async {
                completion(UploadResponse(success: false, url: nil, error: "Invalid URL: \(urlString)", fileName: nil, fileSize: nil))
            }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(apiKey, forHTTPHeaderField: "AccessKey")
        request.setValue(ContentType.from(fileName: fileName).rawValue, forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "accept")
        
        // Optional: Add checksum for data integrity (SHA256 HEX, uppercase)
        // let checksum = data.sha256.uppercased()
        // request.setValue(checksum, forHTTPHeaderField: "Checksum")

        print("🚀 Uploading to Bunny CDN: \(urlString)")
        print("📁 File size: \(data.count) bytes")

        let task = URLSession.shared.uploadTask(with: request, from: data) { responseData, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Upload failed: \(error.localizedDescription)")
                    completion(UploadResponse(
                        success: false, 
                        url: nil, 
                        error: "Network error: \(error.localizedDescription)",
                        fileName: nil,
                        fileSize: nil
                    ))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Invalid response from server")
                    completion(UploadResponse(
                        success: false, 
                        url: nil, 
                        error: "Invalid response from server",
                        fileName: nil,
                        fileSize: nil
                    ))
                    return
                }

                print("📊 Upload response: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 201 {
                    let fileUrl = "https://\(self.cdnHostname)/\(fullPath)"
                    print("✅ Upload successful: \(fileUrl)")
                    completion(UploadResponse(
                        success: true, 
                        url: fileUrl, 
                        error: nil,
                        fileName: uniqueFileName,
                        fileSize: data.count
                    ))
                } else {
                    var errorMessage = "Upload failed with status code: \(httpResponse.statusCode)"
                    
                    // Add detailed error information
                    switch httpResponse.statusCode {
                    case 400:
                        errorMessage += " (Bad Request - Invalid file format or data)"
                    case 401:
                        errorMessage += " (Unauthorized - Invalid AccessKey or authentication)"
                    case 403:
                        errorMessage += " (Forbidden - Access denied)"
                    case 404:
                        errorMessage += " (Not Found - Storage zone not found)"
                    case 413:
                        errorMessage += " (File too large - Exceeds size limit)"
                    case 500:
                        errorMessage += " (Server Error - Try again later)"
                    default:
                        break
                    }
                    
                    if let responseData = responseData, let message = String(data: responseData, encoding: .utf8) {
                        errorMessage += " - Response: \(message)"
                    }
                    
                    print("❌ Upload failed: \(errorMessage)")
                    completion(UploadResponse(
                        success: false, 
                        url: nil, 
                        error: errorMessage,
                        fileName: nil,
                        fileSize: nil
                    ))
                }
            }
        }
        task.resume()
    }
    
    /// Convenience method for uploading images
    func uploadImage(data: Data, fileName: String, completion: @escaping (UploadResponse) -> Void) {
        uploadFile(data: data, fileName: fileName, path: "images", completion: completion)
    }
    
    /// Convenience method for uploading videos
    func uploadVideo(data: Data, fileName: String, completion: @escaping (UploadResponse) -> Void) {
        uploadFile(data: data, fileName: fileName, path: "videos", completion: completion)
    }
    
    /// Upload multiple files concurrently
    func uploadFiles(_ files: [(fileName: String, data: Data, path: String?)], completion: @escaping ([UploadResponse]) -> Void) {
        let group = DispatchGroup()
        var responses: [UploadResponse] = Array(repeating: UploadResponse(success: false, url: nil, error: "Not processed", fileName: nil, fileSize: nil), count: files.count)

        for (index, file) in files.enumerated() {
            group.enter()
            uploadFile(data: file.data, fileName: file.fileName, path: file.path) { response in
                responses[index] = response
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion(responses)
        }
    }
    
    /// Upload multiple images concurrently
    func uploadImages(images: [(fileName: String, data: Data)], completion: @escaping ([UploadResponse]) -> Void) {
        let filesWithPath = images.map { (fileName: $0.fileName, data: $0.data, path: "images") }
        uploadFiles(filesWithPath, completion: completion)
    }
    
    /// Delete a file from Bunny CDN
    func deleteFile(fileName: String, path: String? = nil, completion: @escaping (Bool, String?) -> Void) {
        let fullPath: String
        if let path = path, !path.isEmpty {
            fullPath = "\(path)/\(fileName)"
        } else {
            fullPath = fileName
        }
        
        let hostname = region.isEmpty ? baseHostname : "\(region).\(baseHostname)"
        let urlString = "https://\(hostname)/\(storageZoneName)/\(fullPath)"
        
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async {
                completion(false, "Invalid URL: \(urlString)")
            }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(apiKey, forHTTPHeaderField: "AccessKey")

        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, "Network error: \(error.localizedDescription)")
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false, "Invalid response from server")
                    return
                }

                if httpResponse.statusCode == 200 || httpResponse.statusCode == 404 {
                    completion(true, nil)
                } else {
                    completion(false, "Delete failed with status code: \(httpResponse.statusCode)")
                }
            }
        }
        task.resume()
    }
} 