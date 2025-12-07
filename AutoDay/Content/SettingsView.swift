//
//  SettingsView.swift
//  AutoDay
//
//  Created by Januda Lelwala on 2025-12-03.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("autoSyncCalendar") private var autoSyncCalendar = true
    @AppStorage("defaultTaskDuration") private var defaultTaskDuration = 3600.0
    @AppStorage("cleanupCompletedTasks") private var cleanupCompletedTasks = true
    @ObservedObject private var taskManager = TaskManager.shared
    @ObservedObject private var iCloudSync = iCloudSyncManager.shared
    @ObservedObject private var notificationManager = NotificationManager.shared
    @EnvironmentObject var calendarManager: CalendarManager
    @State private var pendingNotificationsCount = 0
    
    private let durationOptions: [(String, TimeInterval)] = [
        ("15 minutes", 900),
        ("30 minutes", 1800),
        ("45 minutes", 2700),
        ("1 hour", 3600),
        ("1.5 hours", 5400),
        ("2 hours", 7200),
        ("3 hours", 10800),
        ("4 hours", 14400)
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Enable Notifications", isOn: $enableNotifications)
                    
                    HStack {
                        Text("Status")
                        Spacer()
                        if notificationManager.isAuthorized {
                            Label("Authorized", systemImage: "bell.badge.check")
                                .foregroundColor(.green)
                                .font(.caption)
                        } else {
                            Label("Not Authorized", systemImage: "bell.slash")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                    
                    HStack {
                        Text("Pending Reminders")
                        Spacer()
                        Text("\(pendingNotificationsCount)")
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: {
                        Task {
                            await notificationManager.sendTestNotification()
                        }
                    }) {
                        HStack {
                            Image(systemName: "bell.badge.fill")
                                .foregroundColor(.blue)
                            Text("Send Test Notification")
                            Spacer()
                            Text("in 10s")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Receive notifications 15 minutes before and at the exact due time. Test notification appears in 10 seconds.")
                }
                
                Section {
                    Toggle("Auto-sync with Calendar", isOn: $autoSyncCalendar)
                    
                    HStack {
                        Text("Status")
                        Spacer()
                        if calendarManager.isAuthorized {
                            Label("Authorized", systemImage: "calendar.badge.checkmark")
                                .foregroundColor(.green)
                                .font(.caption)
                        } else {
                            Label("Not Authorized", systemImage: "calendar.badge.exclamationmark")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                    
                    if !calendarManager.isAuthorized {
                        Button(action: {
                            Task {
                                let granted = await calendarManager.requestAccess()
                                if granted {
                                    // Set the calendar manager for task syncing
                                    taskManager.setCalendarManager(calendarManager)
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: "calendar.badge.plus")
                                    .foregroundColor(.blue)
                                Text("Request Calendar Access")
                                Spacer()
                            }
                        }
                    } else if autoSyncCalendar {
                        Button(action: {
                            Task {
                                await taskManager.syncWithCalendar()
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundColor(.blue)
                                Text("Sync Calendar Now")
                                Spacer()
                            }
                        }
                    }
                } header: {
                    Text("Calendar")
                } footer: {
                    Text(calendarManager.isAuthorized ? "Automatically sync tasks with your calendar events. You can manually sync anytime." : "Grant calendar access to sync your events with tasks.")
                }
                
                Section {
                    Toggle("iCloud Sync", isOn: $taskManager.isCloudSyncEnabled)
                        .onChange(of: taskManager.isCloudSyncEnabled) { oldValue, newValue in
                            taskManager.toggleCloudSync(enabled: newValue)
                        }
                    
                    HStack {
                        Text("Status")
                        Spacer()
                        if iCloudSync.isCloudAvailable {
                            Label("Available", systemImage: "checkmark.icloud")
                                .foregroundColor(.green)
                                .font(.caption)
                        } else {
                            Label("Not Available", systemImage: "xmark.icloud")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                    
                    if let lastSync = iCloudSync.lastSyncDate {
                        HStack {
                            Text("Last Sync")
                            Spacer()
                            Text(lastSync, style: .relative)
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                } header: {
                    Text("iCloud Sync")
                } footer: {
                    Text("Sync your tasks across all your Apple devices using iCloud. Make sure you're signed in to iCloud.")
                }
                
                Section {
                    Picker("Default Task Duration", selection: $defaultTaskDuration) {
                        ForEach(durationOptions, id: \.1) { option in
                            Text(option.0).tag(option.1)
                        }
                    }
                } header: {
                    Text("Tasks")
                } footer: {
                    Text("Default duration for new scheduled tasks")
                }
                
                Section {
                    Toggle("Auto-remove Completed Tasks", isOn: $cleanupCompletedTasks)
                } header: {
                    Text("Cleanup")
                } footer: {
                    Text("Automatically remove completed tasks after their due date")
                }
                
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://apple.com")!) {
                        HStack {
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Link(destination: URL(string: "https://apple.com")!) {
                        HStack {
                            Text("Terms of Service")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.blue)
                        }
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .task {
                let notifications = await notificationManager.getPendingNotifications()
                pendingNotificationsCount = notifications.count
                
                // Set calendar manager for task syncing
                taskManager.setCalendarManager(calendarManager)
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(CalendarManager())
}
