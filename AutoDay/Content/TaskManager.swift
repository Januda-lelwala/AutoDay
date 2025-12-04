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
    
    @Published var tasks: [TodoTask] = []
    @Published var isSyncing = false
    private var timer: Timer?
    private var calendarManager: CalendarManager?
    
    private init() {
        startCleanupTimer()
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
    
    deinit {
        timer?.invalidate()
    }
}
