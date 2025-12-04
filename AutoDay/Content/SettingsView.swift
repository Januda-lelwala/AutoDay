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
                    Toggle("Auto-sync with Calendar", isOn: $autoSyncCalendar)
                } header: {
                    Text("General")
                } footer: {
                    Text("Notifications will remind you about upcoming tasks")
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
        }
    }
}

#Preview {
    SettingsView()
}
