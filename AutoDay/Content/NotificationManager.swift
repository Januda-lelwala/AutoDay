//
//  NotificationManager.swift
//  AutoDay
//
//  Created by Januda Lelwala on 2025-12-04.
//

import Foundation
import UserNotifications
import SwiftUI
import Combine

class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    @AppStorage("enableNotifications") private var enableNotifications = true
    
    private override init() {
        super.init()
        checkAuthorizationStatus()
    }
    
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            await MainActor.run {
                isAuthorized = granted
            }
            return granted
        } catch {
            print("Error requesting notification authorization: \(error.localizedDescription)")
            return false
        }
    }
    
    func scheduleNotification(for task: TodoTask) async {
        guard enableNotifications, let dueDate = task.dueDate else { return }
        
        // Check authorization
        if !isAuthorized {
            let granted = await requestAuthorization()
            if !granted { return }
        }
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Task Reminder"
        content.body = task.title
        content.sound = .default
        content.badge = 1
        
        // Add actions
        content.categoryIdentifier = "TASK_REMINDER"
        
        // Calculate notification time (15 minutes before)
        let notificationDate = dueDate.addingTimeInterval(-15 * 60)
        
        // Only schedule if notification time is in the future
        guard notificationDate > Date() else { return }
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: notificationDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        // Create request
        let request = UNNotificationRequest(
            identifier: task.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        // Schedule notification
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("Notification scheduled for: \(notificationDate)")
        } catch {
            print("Error scheduling notification: \(error.localizedDescription)")
        }
    }
    
    func cancelNotification(for task: TodoTask) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [task.id.uuidString])
    }
    
    func updateNotification(for task: TodoTask) async {
        // Cancel old notification
        cancelNotification(for: task)
        
        // Schedule new one
        await scheduleNotification(for: task)
    }
    
    func setupNotificationCategories() {
        let completeAction = UNNotificationAction(
            identifier: "COMPLETE_ACTION",
            title: "Mark Complete",
            options: []
        )
        
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_ACTION",
            title: "Snooze 10 min",
            options: []
        )
        
        let category = UNNotificationCategory(
            identifier: "TASK_REMINDER",
            actions: [completeAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
}

// Notification Delegate
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    
    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification actions
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let taskId = response.notification.request.identifier
        
        switch response.actionIdentifier {
        case "COMPLETE_ACTION":
            // Find and complete the task
            if let task = TaskManager.shared.tasks.first(where: { $0.id.uuidString == taskId }) {
                task.isCompleted = true
                TaskManager.shared.updateTask(task)
            }
            
        case "SNOOZE_ACTION":
            // Reschedule for 10 minutes later
            if let task = TaskManager.shared.tasks.first(where: { $0.id.uuidString == taskId }) {
                Task {
                    await NotificationManager.shared.scheduleNotification(for: task)
                }
            }
            
        default:
            break
        }
        
        completionHandler()
    }
}
