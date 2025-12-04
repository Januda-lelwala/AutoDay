//
//  AutoDayApp.swift
//  AutoDay
//
//  Created by Januda Lelwala on 2025-12-03.
//

import SwiftUI
import UserNotifications

@main
struct AutoDayApp: App {
    @StateObject private var notificationManager = NotificationManager.shared
    private let notificationDelegate = NotificationDelegate()
    
    init() {
        // Setup notification delegate
        UNUserNotificationCenter.current().delegate = notificationDelegate
        
        // Setup notification categories
        NotificationManager.shared.setupNotificationCategories()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Request notification permission on first launch
                    Task {
                        await notificationManager.requestAuthorization()
                    }
                }
        }
    }
}
