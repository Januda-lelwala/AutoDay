//
//  CalendarManager.swift
//  AutoDay
//
//  Created by Januda Lelwala on 2025-12-03.
//

import EventKit
import Foundation
import Combine

class CalendarManager: ObservableObject {
    private let eventStore = EKEventStore()
    @Published var isAuthorized = false
    
    init() {
        checkAuthorizationStatus()
    }
    
    func checkAuthorizationStatus() {
        if #available(iOS 17.0, *) {
            let status = EKEventStore.authorizationStatus(for: .event)
            isAuthorized = (status == .fullAccess || status == .writeOnly)
        } else {
            let status = EKEventStore.authorizationStatus(for: .event)
            isAuthorized = (status == .authorized)
        }
    }
    
    func requestAccess() async -> Bool {
        do {
            if #available(iOS 17.0, *) {
                let granted = try await eventStore.requestFullAccessToEvents()
                await MainActor.run {
                    isAuthorized = granted
                }
                return granted
            } else {
                let granted = try await eventStore.requestAccess(to: .event)
                await MainActor.run {
                    isAuthorized = granted
                }
                return granted
            }
        } catch {
            print("Error requesting calendar access: \(error.localizedDescription)")
            return false
        }
    }
    
    func fetchCalendarEvents(from startDate: Date, to endDate: Date) async -> [EKEvent] {
        if !isAuthorized {
            let granted = await requestAccess()
            if !granted { return [] }
        }
        
        let calendars = eventStore.calendars(for: .event)
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        let events = eventStore.events(matching: predicate)
        
        return events
    }
    
    func syncCalendarToTasks() async -> [TodoTask] {
        if !isAuthorized {
            let granted = await requestAccess()
            if !granted { 
                print("Calendar access not granted")
                return [] 
            }
        }
        
        // Fetch events from today to 90 days in the future
        let startDate = Calendar.current.startOfDay(for: Date())
        let endDate = Calendar.current.date(byAdding: .day, value: 90, to: startDate) ?? Date()
        
        print("Syncing calendar events from \(startDate) to \(endDate)")
        let events = await fetchCalendarEvents(from: startDate, to: endDate)
        print("Found \(events.count) calendar events")
        
        // Convert calendar events to tasks
        let tasks = events.map { event -> TodoTask in
            let duration = event.endDate.timeIntervalSince(event.startDate)
            let task = TodoTask(
                title: event.title ?? "Untitled",
                isCompleted: false,
                dueDate: event.startDate,
                duration: duration,
                calendarEventId: event.eventIdentifier
            )
            return task
        }
        
        return tasks
    }
    
    func addTaskToCalendar(title: String, dueDate: Date?, duration: TimeInterval = 3600) async -> String? {
        if !isAuthorized {
            let granted = await requestAccess()
            if !granted { return nil }
        }
        
        guard let dueDate = dueDate else { return nil }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = dueDate
        event.endDate = dueDate.addingTimeInterval(duration)
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        // Add reminder 15 minutes before
        let alarm = EKAlarm(relativeOffset: -15 * 60)
        event.addAlarm(alarm)
        
        do {
            try eventStore.save(event, span: .thisEvent)
            return event.eventIdentifier
        } catch {
            print("Error saving event: \(error.localizedDescription)")
            return nil
        }
    }
    
    func updateCalendarEvent(eventIdentifier: String, title: String, dueDate: Date?, duration: TimeInterval = 3600) async -> Bool {
        guard isAuthorized else { return false }
        guard let dueDate = dueDate else { return false }
        
        guard let event = eventStore.event(withIdentifier: eventIdentifier) else {
            return false
        }
        
        event.title = title
        event.startDate = dueDate
        event.endDate = dueDate.addingTimeInterval(duration)
        
        do {
            try eventStore.save(event, span: .thisEvent)
            return true
        } catch {
            print("Error updating event: \(error.localizedDescription)")
            return false
        }
    }
    
    func deleteCalendarEvent(eventIdentifier: String) async -> Bool {
        guard isAuthorized else { return false }
        
        guard let event = eventStore.event(withIdentifier: eventIdentifier) else {
            return false
        }
        
        do {
            try eventStore.remove(event, span: .thisEvent)
            return true
        } catch {
            print("Error deleting event: \(error.localizedDescription)")
            return false
        }
    }
}
