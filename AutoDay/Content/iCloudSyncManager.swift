//
//  iCloudSyncManager.swift
//  AutoDay
//
//  Created by Januda Lelwala on 2025-12-04.
//

import Foundation
import Combine

class iCloudSyncManager: ObservableObject {
    static let shared = iCloudSyncManager()
    
    private let ubiquitousStore = NSUbiquitousKeyValueStore.default
    private let tasksKey = "iCloudSyncedTasks"
    private var cancellables = Set<AnyCancellable>()
    
    @Published var isCloudAvailable: Bool = false
    @Published var lastSyncDate: Date?
    
    private init() {
        checkCloudAvailability()
        setupCloudObserver()
    }
    
    private func checkCloudAvailability() {
        // Check if iCloud is available
        if FileManager.default.ubiquityIdentityToken != nil {
            isCloudAvailable = true
        } else {
            isCloudAvailable = false
            print("iCloud is not available - user may not be signed in")
        }
    }
    
    private func setupCloudObserver() {
        // Observe changes from other devices
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cloudStoreDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: ubiquitousStore
        )
        
        // Synchronize with iCloud on startup
        ubiquitousStore.synchronize()
    }
    
    @objc private func cloudStoreDidChange(notification: Notification) {
        // Handle changes from other devices
        guard let userInfo = notification.userInfo,
              let changeReason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
            return
        }
        
        // Reason 0 = server change (from another device)
        // Reason 1 = initial sync
        // Reason 2 = quota violation
        if changeReason == NSUbiquitousKeyValueStoreServerChange ||
           changeReason == NSUbiquitousKeyValueStoreInitialSyncChange {
            
            // Notify TaskManager to pull updated tasks
            NotificationCenter.default.post(name: .iCloudTasksDidChange, object: nil)
        }
    }
    
    // MARK: - Sync Methods
    
    func saveTasks(_ tasks: [TodoTask]) {
        guard isCloudAvailable else {
            print("iCloud not available, skipping cloud sync")
            return
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(tasks)
            
            ubiquitousStore.set(data, forKey: tasksKey)
            ubiquitousStore.synchronize()
            
            lastSyncDate = Date()
            print("Tasks synced to iCloud successfully")
        } catch {
            print("Failed to sync tasks to iCloud: \(error.localizedDescription)")
        }
    }
    
    func loadTasks() -> [TodoTask]? {
        guard isCloudAvailable else {
            print("iCloud not available, skipping cloud load")
            return nil
        }
        
        guard let data = ubiquitousStore.data(forKey: tasksKey) else {
            print("No tasks found in iCloud")
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let tasks = try decoder.decode([TodoTask].self, from: data)
            
            lastSyncDate = Date()
            print("Tasks loaded from iCloud successfully")
            return tasks
        } catch {
            print("Failed to load tasks from iCloud: \(error.localizedDescription)")
            return nil
        }
    }
    
    func mergeTasks(localTasks: [TodoTask], cloudTasks: [TodoTask]) -> [TodoTask] {
        // Create a dictionary of cloud tasks by ID for quick lookup
        var taskDict: [UUID: TodoTask] = [:]
        
        // Start with cloud tasks
        for task in cloudTasks {
            taskDict[task.id] = task
        }
        
        // Add or update with local tasks (local takes precedence for conflicts)
        for task in localTasks {
            taskDict[task.id] = task
        }
        
        return Array(taskDict.values)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let iCloudTasksDidChange = Notification.Name("iCloudTasksDidChange")
}
