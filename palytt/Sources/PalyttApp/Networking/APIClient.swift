//
//  APIClient.swift
//  Palytt
//
//  Copyright © 2025 Palytt Inc. All rights reserved.
//
//  This software is proprietary and confidential. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//

import Foundation

/// HTTP methods supported by the API client
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// Protocol for API client
protocol APIClientProtocol {
    func call<T: Encodable, R: Decodable>(
        procedure: String,
        input: T,
        method: HTTPMethod
    ) async throws -> R
    
    func call<R: Decodable>(
        procedure: String,
        method: HTTPMethod
    ) async throws -> R
}

/// Low-level HTTP client for making tRPC API calls
final class APIClient: APIClientProtocol {
    
    // MARK: - Properties
    
    private let session: URLSession
    private let baseURL: URL
    private let authProvider: AuthProviderProtocol
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder
    
    // MARK: - Initialization
    
    init(
        baseURL: URL,
        authProvider: AuthProviderProtocol = AuthProvider.shared,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.authProvider = authProvider
        self.session = session
        
        // Configure JSON encoder
        self.jsonEncoder = JSONEncoder()
        self.jsonEncoder.dateEncodingStrategy = .iso8601
        
        // Configure JSON decoder
        self.jsonDecoder = JSONDecoder()
        self.jsonDecoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - Public Methods
    
    /// Call tRPC procedure with input
    /// - Parameters:
    ///   - procedure: tRPC procedure name (e.g., "posts.getRecentPosts")
    ///   - input: Input parameters
    ///   - method: HTTP method (GET for queries, POST for mutations)
    /// - Returns: Decoded response
    /// - Throws: APIError if request fails
    func call<T: Encodable, R: Decodable>(
        procedure: String,
        input: T,
        method: HTTPMethod
    ) async throws -> R {
        // Build request
        let request = try await buildRequest(
            procedure: procedure,
            input: input,
            method: method
        )
        
        // Execute request
        return try await execute(request: request)
    }
    
    /// Call tRPC procedure without input
    /// - Parameters:
    ///   - procedure: tRPC procedure name
    ///   - method: HTTP method
    /// - Returns: Decoded response
    /// - Throws: APIError if request fails
    func call<R: Decodable>(
        procedure: String,
        method: HTTPMethod
    ) async throws -> R {
        // Use empty input
        let emptyInput: [String: String] = [:]
        return try await call(
            procedure: procedure,
            input: emptyInput,
            method: method
        )
    }
    
    // MARK: - Private Methods
    
    /// Build URL request for tRPC procedure
    private func buildRequest<T: Encodable>(
        procedure: String,
        input: T,
        method: HTTPMethod
    ) async throws -> URLRequest {
        // Build URL
        let procedureURL = baseURL
            .appendingPathComponent("trpc")
            .appendingPathComponent(procedure)
        
        var request = URLRequest(url: procedureURL)
        request.httpMethod = method.rawValue
        request.timeoutInterval = 30
        
        // Add authentication headers
        do {
            let headers = try await authProvider.getHeaders()
            headers.forEach { key, value in
                request.setValue(value, forHTTPHeaderField: key)
            }
        } catch {
            // Convert auth errors
            throw APIError.from(error)
        }
        
        // Encode input based on HTTP method
        if method == .get {
            // For GET requests, encode input as query parameter
            try encodeAsQueryParameter(input: input, into: &request)
        } else {
            // For POST/PUT/etc., encode as JSON body
            try encodeAsJSONBody(input: input, into: &request)
        }
        
        return request
    }
    
    /// Encode input as URL query parameter (for GET requests)
    private func encodeAsQueryParameter<T: Encodable>(
        input: T,
        into request: inout URLRequest
    ) throws {
        // Encode input to JSON string
        let inputData = try jsonEncoder.encode(input)
        guard let inputString = String(data: inputData, encoding: .utf8) else {
            throw APIError.encodingError(
                EncodingError.invalidValue(
                    input,
                    EncodingError.Context(
                        codingPath: [],
                        debugDescription: "Failed to convert input to string"
                    )
                )
            )
        }
        
        // Add as query parameter
        guard var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidData
        }
        
        components.queryItems = [URLQueryItem(name: "input", value: inputString)]
        request.url = components.url
    }
    
    /// Encode input as JSON body (for POST/PUT/etc. requests)
    private func encodeAsJSONBody<T: Encodable>(
        input: T,
        into request: inout URLRequest
    ) throws {
        request.httpBody = try jsonEncoder.encode(input)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    
    /// Execute HTTP request and decode response
    private func execute<R: Decodable>(request: URLRequest) async throws -> R {
        do {
            let (data, response) = try await session.data(for: request)
            
            // Validate HTTP response
            try validateResponse(response, data: data)
            
            // Decode response
            return try decodeResponse(data: data)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.from(error)
        }
    }
    
    /// Validate HTTP response
    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        // Check status code
        switch httpResponse.statusCode {
        case 200...299:
            return // Success
            
        case 400...499, 500...599:
            // Try to extract error message from response
            let errorMessage = extractErrorMessage(from: data)
            throw APIError.from(
                statusCode: httpResponse.statusCode,
                message: errorMessage
            )
            
        default:
            throw APIError.invalidResponse
        }
    }
    
    /// Extract error message from response data
    private func extractErrorMessage(from data: Data) -> String? {
        // Try to decode as JSON and extract message
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // Common error message keys
            if let message = json["message"] as? String {
                return message
            }
            if let message = json["error"] as? String {
                return message
            }
            if let errors = json["errors"] as? [String] {
                return errors.joined(separator: ", ")
            }
        }
        
        // Try to decode as plain text
        if let message = String(data: data, encoding: .utf8), !message.isEmpty {
            return message
        }
        
        return nil
    }
    
    /// Decode response data to expected type
    private func decodeResponse<R: Decodable>(data: Data) throws -> R {
        do {
            // Try to decode tRPC response wrapper first
            if let wrapper = try? jsonDecoder.decode(TRPCResponse<R>.self, from: data) {
                if let result = wrapper.result.data {
                    return result
                } else if let error = wrapper.error {
                    throw APIError.serverError(statusCode: error.code, message: error.message)
                }
            }
            
            // Fall back to direct decoding
            return try jsonDecoder.decode(R.self, from: data)
        } catch let decodingError as DecodingError {
            throw APIError.decodingError(decodingError)
        } catch {
            throw APIError.from(error)
        }
    }
}

// MARK: - tRPC Response Types

/// tRPC response wrapper
private struct TRPCResponse<T: Decodable>: Decodable {
    let result: TRPCResult<T>
    let error: TRPCError?
}

/// tRPC result wrapper
private struct TRPCResult<T: Decodable>: Decodable {
    let data: T?
}

/// tRPC error
private struct TRPCError: Decodable {
    let message: String
    let code: Int
    let data: TRPCErrorData?
}

/// tRPC error data
private struct TRPCErrorData: Decodable {
    let code: String?
    let httpStatus: Int?
}

// MARK: - Testing Support

#if DEBUG
/// Mock API client for testing
final class MockAPIClient: APIClientProtocol {
    var shouldFail = false
    var mockError: APIError?
    var mockResponseData: Data?
    
    func call<T: Encodable, R: Decodable>(
        procedure: String,
        input: T,
        method: HTTPMethod
    ) async throws -> R {
        if shouldFail {
            throw mockError ?? APIError.unknown(NSError(domain: "MockAPIClient", code: -1))
        }
        
        if let data = mockResponseData {
            return try JSONDecoder().decode(R.self, from: data)
        }
        
        throw APIError.invalidData
    }
    
    func call<R: Decodable>(
        procedure: String,
        method: HTTPMethod
    ) async throws -> R {
        return try await call(
            procedure: procedure,
            input: [:] as [String: String],
            method: method
        )
    }
}
#endif

