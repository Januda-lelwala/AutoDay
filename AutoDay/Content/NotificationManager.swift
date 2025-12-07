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

class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    @AppStorage("enableNotifications") private var enableNotifications = true

    private let allowedStatuses: [UNAuthorizationStatus] = [.authorized, .provisional, .ephemeral]
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        setupNotificationCategories()
        checkAuthorizationStatus()
    }
    
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = self.allowedStatuses.contains(settings.authorizationStatus)
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
        print("[NOTIF] scheduleNotification called for task: \(task.title)")
        print("[NOTIF] enableNotifications: \(enableNotifications)")
        print("[NOTIF] dueDate: \(task.dueDate?.description ?? "nil")")
        
        guard enableNotifications, let dueDate = task.dueDate else {
            print("[NOTIF] Skipping - notifications disabled or no due date")
            return
        }
        
        // Always check current authorization status
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        print("[NOTIF] Authorization status: \(settings.authorizationStatus.rawValue)")
        print("[NOTIF] Alert setting: \(settings.alertSetting.rawValue)")
        
        if !allowedStatuses.contains(settings.authorizationStatus) {
            print("[NOTIF] ❌ Not authorized to send notifications")
            let granted = await requestAuthorization()
            if !granted {
                print("[NOTIF] ❌ Authorization request denied")
                return
            }
            print("[NOTIF] ✅ Authorization granted")
        }
        
        let now = Date()
        print("[NOTIF] Current time: \(now)")
        print("[NOTIF] Task due at: \(dueDate)")
        print("[NOTIF] Time until due: \(dueDate.timeIntervalSince(now)) seconds")
        
        // Schedule reminder notification (15 minutes before)
        let reminderDate = dueDate.addingTimeInterval(-15 * 60)
        if reminderDate > now {
            let reminderContent = UNMutableNotificationContent()
            reminderContent.title = "Task Starting Soon"
            reminderContent.body = "⏰ \(task.title) starts in 15 minutes"
            reminderContent.sound = .default
            reminderContent.badge = 1
            reminderContent.categoryIdentifier = "TASK_REMINDER"
            
            let reminderComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: reminderDate)
            let reminderTrigger = UNCalendarNotificationTrigger(dateMatching: reminderComponents, repeats: false)
            
            let reminderRequest = UNNotificationRequest(
                identifier: "\(task.id.uuidString)-reminder",
                content: reminderContent,
                trigger: reminderTrigger
            )
            
            do {
                try await UNUserNotificationCenter.current().add(reminderRequest)
                print("[NOTIF] ✅ Reminder scheduled for: \(reminderDate)")
                print("[NOTIF] Reminder ID: \(task.id.uuidString)-reminder")
            } catch {
                print("[NOTIF] ❌ Error scheduling reminder: \(error.localizedDescription)")
            }
        } else {
            print("[NOTIF] ⏭️ Skipping reminder (would be in past)")
        }
        
        // Schedule due time notification (at the exact due time)
        if dueDate > now {
            let dueContent = UNMutableNotificationContent()
            dueContent.title = "Task Due Now"
            dueContent.body = "🔔 \(task.title) is due now!"
            dueContent.sound = .default  // Changed from .defaultCritical
            dueContent.badge = 1
            dueContent.categoryIdentifier = "TASK_REMINDER"
            
            let dueComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: dueDate)
            print("[NOTIF] Due components: year=\(dueComponents.year ?? 0), month=\(dueComponents.month ?? 0), day=\(dueComponents.day ?? 0), hour=\(dueComponents.hour ?? 0), minute=\(dueComponents.minute ?? 0)")
            
            let dueTrigger = UNCalendarNotificationTrigger(dateMatching: dueComponents, repeats: false)
            print("[NOTIF] Next trigger date: \(dueTrigger.nextTriggerDate()?.description ?? "nil")")
            
            let dueRequest = UNNotificationRequest(
                identifier: task.id.uuidString,
                content: dueContent,
                trigger: dueTrigger
            )
            
            do {
                try await UNUserNotificationCenter.current().add(dueRequest)
                print("[NOTIF] ✅ Due time notification scheduled for: \(dueDate)")
                print("[NOTIF] Due notification ID: \(task.id.uuidString)")
                
                // Verify it was added
                let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
                let found = pending.contains(where: { $0.identifier == task.id.uuidString })
                print("[NOTIF] Verification - notification in pending list: \(found)")
            } catch {
                print("[NOTIF] ❌ Error scheduling due notification: \(error.localizedDescription)")
            }
        } else {
            print("[NOTIF] ⏭️ Skipping due notification (would be in past)")
        }
    }
    
    func cancelNotification(for task: TodoTask) {
        // Cancel both the reminder and due time notifications
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            "\(task.id.uuidString)-reminder",
            task.id.uuidString
        ])
    }
    
    func updateNotification(for task: TodoTask) async {
        // Cancel old notification
        cancelNotification(for: task)
        
        // Schedule new one
        await scheduleNotification(for: task)
    }
    
    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await UNUserNotificationCenter.current().pendingNotificationRequests()
    }
    
    func printPendingNotifications() async {
        let pending = await getPendingNotifications()
        print("=== Pending Notifications (\(pending.count)) ===")
        for request in pending {
            print("ID: \(request.identifier)")
            print("Title: \(request.content.title)")
            print("Body: \(request.content.body)")
            if let trigger = request.trigger as? UNCalendarNotificationTrigger,
               let nextTriggerDate = trigger.nextTriggerDate() {
                print("Scheduled for: \(nextTriggerDate)")
            }
            print("---")
        }
    }
    
    func rescheduleAllNotifications(for tasks: [TodoTask]) async {
        guard enableNotifications else {
            print("[NOTIF] Notifications disabled in settings")
            return
        }
        
        print("[NOTIF] ========== RESCHEDULING ALL NOTIFICATIONS ==========")
        
        // Cancel all existing notifications first
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("[NOTIF] Cleared all pending notifications")
        
        // Schedule notifications for all incomplete tasks with due dates
        var scheduledCount = 0
        for task in tasks where !task.isCompleted && task.dueDate != nil {
            print("[NOTIF] Processing task: \(task.title)")
            await scheduleNotification(for: task)
            scheduledCount += 1
        }
        
        print("[NOTIF] Rescheduled notifications for \(scheduledCount) tasks")
        print("[NOTIF] ================================================")
        
        // Print debug info
        await printPendingNotifications()
    }
    
    // Test notification - fires in 10 seconds
    func sendTestNotification() async {
        print("[TEST] Sending test notification in 10 seconds...")
        
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "If you see this, notifications are working! 🎉"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        let request = UNNotificationRequest(identifier: "test-notification", content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("[TEST] ✅ Test notification scheduled successfully")
        } catch {
            print("[TEST] ❌ Failed to schedule test notification: \(error)")
        }
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

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager {
    // Show notifications even when app is in foreground
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
            if let task = TaskManager.shared.tasks.first(where: { $0.id.uuidString == taskId }) {
                task.isCompleted = true
                TaskManager.shared.updateTask(task)
            }
            
        case "SNOOZE_ACTION":
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
