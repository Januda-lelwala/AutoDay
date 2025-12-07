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
    @StateObject private var calendarManager = CalendarManager()
    
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(calendarManager)
                .onAppear {
                    // Request permissions on first launch
                    Task {
                        // Request notification permission
                        _ = await notificationManager.requestAuthorization()
                        
                        // Request calendar permission
                        _ = await calendarManager.requestAccess()
                        
                        // Reschedule all notifications for loaded tasks
                        await notificationManager.rescheduleAllNotifications(for: TaskManager.shared.tasks)
                    }
                }
        }
    }
}
