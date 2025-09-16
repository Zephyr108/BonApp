//
//  SupabaseManager.swift
//  BonApp
//
//  Created by Marcin on 07/09/2025.
//

import Foundation
import Supabase

final class SupabaseManager {
    static let shared = SupabaseManager()
    let client: SupabaseClient

    private init() {
        let supabaseURL = URL(string: "https://pksuyabrwexreslizpxp.supabase.co")!
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBrc3V5YWJyd2V4cmVzbGl6cHhwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUwMTI5NjksImV4cCI6MjA3MDU4ODk2OX0.RFeuz5qS7tyOXh1ph3ltBIQDdUt8WFsuLlWO0m7NEB4"

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.waitsForConnectivity = true
        sessionConfig.timeoutIntervalForRequest = 30
        sessionConfig.timeoutIntervalForResource = 120
        sessionConfig.requestCachePolicy = .reloadIgnoringLocalCacheData

        _ = URLSession(configuration: sessionConfig) // kept to document tuned session; SDK uses its own session

        self.client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey
        )
    }
}
