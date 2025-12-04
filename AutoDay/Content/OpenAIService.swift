//
//  OpenAIService.swift
//  AutoDay
//
//  Created by Januda Lelwala on 2025-12-03.
//

import Foundation

struct ScheduledTask: Codable {
    let title: String
    let date: String?
    let time: String?
    let duration: Int
    let priority: String?
}

struct OpenAIResponse: Codable {
    let tasks: [ScheduledTask]
}

class OpenAIService {
    // TODO: Replace with your actual Cloudflare Worker URL (without /generate-schedule)
    // Example: "https://autoday-scheduler.your-account.workers.dev"
    private let endpoint = "https://autoday-proxy.4kcxwwb4gg.workers.dev/"
    
    init() {
        // Using Cloudflare Worker as proxy
    }
    
    func generateSchedule(from userInput: String) async throws -> [ScheduledTask] {
        let requestBody: [String: Any] = [
            "userInput": userInput,
            "currentDate": getCurrentDate(),
            "currentTime": getCurrentTime()
        ]
        
        guard let url = URL(string: endpoint) else {
            throw NSError(domain: "OpenAIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "OpenAIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "OpenAIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Worker Error: \(errorMessage)"])
        }
        
        // Parse response directly from Cloudflare Worker
        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        return openAIResponse.tasks
    }
    
    private func getCurrentDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    private func getCurrentTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }
}
