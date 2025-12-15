//
//  CloudflareAIService.swift
//  SkillSwapTnDam
//
//  AI Image Generation Service using Cloudflare Workers AI
//

import Foundation
import UIKit

/// Service for generating images using Cloudflare Workers AI
final class CloudflareAIService {
    static let shared = CloudflareAIService()
    
    // Cloudflare credentials
    private let accountId = "8eed97a724b5b02f81416c09406365a6"
    private let apiKey = "dmyguB_Cauq9KF-q1ZBfkCxcmsU0QZhgia5lLc3P"
    
    private var baseURL: String {
        "https://api.cloudflare.com/client/v4/accounts/\(accountId)/ai/run"
    }
    
    private init() {}
    
    /// Generate an image from a text prompt using Cloudflare Stable Diffusion
    /// - Parameter prompt: The text description of the image to generate
    /// - Returns: The generated image data
    func generateImage(prompt: String) async throws -> Data {
        let modelURL = "\(baseURL)/@cf/bytedance/stable-diffusion-xl-lightning"
        
        guard let url = URL(string: modelURL) else {
            throw CloudflareAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "prompt": prompt,
            "num_steps": 4
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("🎨 [Cloudflare AI] Generating image for prompt: \(prompt)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudflareAIError.invalidResponse
        }
        
        if httpResponse.statusCode == 429 {
            throw CloudflareAIError.quotaExceeded
        }
        
        // Check if response is JSON (error) or binary (image)
        if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
           contentType.contains("application/json") {
            // It's an error response
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ [Cloudflare AI] API error: \(httpResponse.statusCode) - \(errorText)")
            throw CloudflareAIError.apiError(statusCode: httpResponse.statusCode, message: errorText)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ [Cloudflare AI] API error: \(httpResponse.statusCode) - \(errorText)")
            throw CloudflareAIError.apiError(statusCode: httpResponse.statusCode, message: errorText)
        }
        
        print("✅ [Cloudflare AI] Image generated: \(data.count) bytes")
        
        // Cloudflare returns binary image data directly
        return data
    }
    
    /// Generate a marketing banner image for a promo
    func generatePromoBanner(title: String, description: String) async throws -> Data {
        let prompt = "Professional marketing banner for promotion: \(title). \(description). Modern design, vibrant colors, promotional offer style, high quality."
        return try await generateImage(prompt: prompt)
    }
    
    /// Generate an image for an annonce/announcement
    func generateAnnonceImage(title: String, description: String, category: String?) async throws -> Data {
        var prompt = "Modern illustration for service announcement: \(title). \(description)."
        if let category = category, !category.isEmpty {
            prompt += " Category: \(category)."
        }
        prompt += " Professional, clean, inviting design, high quality."
        return try await generateImage(prompt: prompt)
    }
}

enum CloudflareAIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case quotaExceeded
    case apiError(statusCode: Int, message: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .quotaExceeded:
            return "API quota exceeded. Please try again later."
        case .apiError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        }
    }
}
