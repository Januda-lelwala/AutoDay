//
//  TaskManager.swift
//  AutoDay
//
//  Created by Januda Lelwala on 2025-12-03.
//

import Foundation
import Combine
import SwiftUI

class TaskManager: ObservableObject {
    static let shared = TaskManager()
    
    @Published var tasks: [TodoTask] = [] {
        didSet {
            saveTasks()
        }
    }
    @Published var isSyncing = false
    @Published var isCloudSyncEnabled: Bool = true
    private var timer: Timer?
    private var calendarManager: CalendarManager?
    private let tasksKey = "savedTasks"
    private let iCloudSync = iCloudSyncManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadTasks()
        startCleanupTimer()
        setupCloudSyncObserver()
    }
    
    func setCalendarManager(_ manager: CalendarManager) {
        self.calendarManager = manager
    }
    
    func addTask(_ task: TodoTask) {
        tasks.append(task)
    }
    
    func deleteTask(_ task: TodoTask) {
        tasks.removeAll { $0.id == task.id }
    }
    
    func deleteTasks(at offsets: IndexSet) {
        tasks.remove(atOffsets: offsets)
    }
    
    func updateTask(_ task: TodoTask) {
        // Task is a class now, so changes are already reflected
        // Check if task should be removed immediately
        if task.isCompleted {
            checkAndRemoveCompletedTask(task)
        }
    }
    
    private func startCleanupTimer() {
        // Check every minute for tasks that should be removed
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.cleanupCompletedTasks()
        }
    }
    
    private func checkAndRemoveCompletedTask(_ task: TodoTask) {
        if task.dueDate == nil {
            // No due date - remove immediately with delay for animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.deleteTask(task)
            }
        } else if let dueDate = task.dueDate {
            let calendar = Calendar.current
            let now = Date()
            
            // If due date has passed, remove immediately with delay
            if calendar.startOfDay(for: dueDate) < calendar.startOfDay(for: now) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.deleteTask(task)
                }
            }
        }
    }
    
    private func cleanupCompletedTasks() {
        let calendar = Calendar.current
        let now = Date()
        
        // Remove completed tasks whose due date has passed
        tasks.removeAll { task in
            guard task.isCompleted else { return false }
            
            if let dueDate = task.dueDate {
                // Remove if due date has passed (not today)
                return calendar.startOfDay(for: dueDate) < calendar.startOfDay(for: now)
            }
            
            return false // Keep tasks without due dates that somehow weren't removed immediately
        }
    }
    
    func syncWithCalendar() async {
        guard let calendarManager = calendarManager else { return }
        
        await MainActor.run {
            isSyncing = true
        }
        
        let calendarTasks = await calendarManager.syncCalendarToTasks()
        
        await MainActor.run {
            // Find tasks from calendar that don't exist in our list
            for calendarTask in calendarTasks {
                // Check if task already exists (by calendar event ID)
                if !tasks.contains(where: { $0.calendarEventId == calendarTask.calendarEventId }) {
                    // Only add if it's not already in our list
                    tasks.append(calendarTask)
                }
            }
            
            isSyncing = false
        }
    }
    
    // MARK: - Cloud Sync Observer
    private func setupCloudSyncObserver() {
        // Listen for changes from other devices
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloudChange),
            name: .iCloudTasksDidChange,
            object: nil
        )
    }
    
    @objc private func handleCloudChange() {
        // Load tasks from iCloud and merge with local
        guard let cloudTasks = iCloudSync.loadTasks() else { return }
        
        DispatchQueue.main.async {
            // Merge cloud and local tasks
            let mergedTasks = self.iCloudSync.mergeTasks(localTasks: self.tasks, cloudTasks: cloudTasks)
            
            // Update without triggering didSet (to avoid infinite loop)
            self.tasks = mergedTasks
            
            // Save locally
            self.saveTasksLocally()
            
            // Reschedule notifications after sync
            Task {
                await NotificationManager.shared.rescheduleAllNotifications(for: self.tasks)
            }
            
            print("Tasks synced from iCloud")
        }
    }
    
    // MARK: - Local Persistence
    private func saveTasks() {
        // Save locally
        saveTasksLocally()
        
        // Save to iCloud if enabled
        if isCloudSyncEnabled {
            iCloudSync.saveTasks(tasks)
        }
    }
    
    private func saveTasksLocally() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(tasks)
            UserDefaults.standard.set(data, forKey: tasksKey)
        } catch {
            print("Failed to save tasks locally: \(error.localizedDescription)")
        }
    }
    
    private func loadTasks() {
        // First try to load from iCloud if enabled
        if isCloudSyncEnabled, let cloudTasks = iCloudSync.loadTasks() {
            // Load local tasks
            if let data = UserDefaults.standard.data(forKey: tasksKey) {
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let localTasks = try decoder.decode([TodoTask].self, from: data)
                    
                    // Merge cloud and local tasks
                    tasks = iCloudSync.mergeTasks(localTasks: localTasks, cloudTasks: cloudTasks)
                    
                    print("Tasks loaded and merged from iCloud and local storage")
                } catch {
                    // If local decode fails, just use cloud tasks
                    tasks = cloudTasks
                    print("Using cloud tasks only")
                }
            } else {
                // No local tasks, use cloud
                tasks = cloudTasks
                print("Tasks loaded from iCloud")
            }
        } else {
            // Load from local storage only
            guard let data = UserDefaults.standard.data(forKey: tasksKey) else {
                return
            }
            
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                tasks = try decoder.decode([TodoTask].self, from: data)
                print("Tasks loaded from local storage")
            } catch {
                print("Failed to load tasks: \(error.localizedDescription)")
            }
        }
        
        // Reschedule all notifications after loading tasks
        Task {
            await NotificationManager.shared.rescheduleAllNotifications(for: tasks)
        }
    }
    
    func toggleCloudSync(enabled: Bool) {
        isCloudSyncEnabled = enabled
        
        if enabled {
            // When enabling, sync current tasks to cloud
            iCloudSync.saveTasks(tasks)
        }
    }
    
    deinit {
        timer?.invalidate()
    }
}
