//
//  ToDoView.swift
//  AutoDay
//
//  Created by Januda Lelwala on 2025-12-03.
//

import SwiftUI
import Combine

struct ToDoView: View {
    @StateObject private var calendarManager = CalendarManager()
    @ObservedObject private var taskManager = TaskManager.shared
    @State private var showingAddTask = false
    @State private var newTaskTitle = ""
    @State private var taskDueDate: Date = Date()
    @State private var taskDuration: TimeInterval = 3600
    @State private var hasScheduledTime = false
    @State private var showingCalendarPermission = false
    @State private var editingTask: TodoTask?
    @State private var showingEditSheet = false
    
    var body: some View {
        ZStack {
            NavigationStack {
                ZStack {
                if taskManager.tasks.isEmpty {
                    // Empty State
                    VStack(spacing: 20) {
                        Image(systemName: "checklist")
                            .font(.system(size: 70))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("No Tasks Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Add tasks to organize your day")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            showingAddTask = true
                        }) {
                            Label("Add Task", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                        }
                        .padding(.top, 10)
                    }
                    .padding()
                } else {
                    // Task List
                    List {
                        ForEach(taskManager.tasks) { todoTask in
                            TaskRow(task: todoTask)
                                .contextMenu {
                                    Button(action: {
                                        editingTask = todoTask
                                        showingEditSheet = true
                                    }) {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    
                                    Button(action: {
                                        duplicateTask(todoTask)
                                    }) {
                                        Label("Duplicate", systemImage: "doc.on.doc")
                                    }
                                    
                                    Button(role: .destructive, action: {
                                        deleteTask(todoTask)
                                    }) {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                        .onDelete(perform: deleteTasks)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("To Do")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        Task {
                            await taskManager.syncWithCalendar()
                        }
                    }) {
                        if taskManager.isSyncing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(taskManager.isSyncing)
                }
            }
            .onAppear {
                taskManager.setCalendarManager(calendarManager)
                
                // Debug: Print pending notifications and test
                Task {
                    await NotificationManager.shared.printPendingNotifications()
                }
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskSheet(
                    newTaskTitle: $newTaskTitle,
                    taskDueDate: $taskDueDate,
                    taskDuration: $taskDuration,
                    hasScheduledTime: $hasScheduledTime,
                    onAdd: addTask
                )
            }
            .sheet(item: $editingTask) { task in
                EditTaskSheet(
                    task: task,
                    calendarManager: calendarManager,
                    onDismiss: {
                        showingEditSheet = false
                        editingTask = nil
                    }
                )
            }
            .alert("Calendar Access Required", isPresented: $showingCalendarPermission) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please enable calendar access in Settings to sync tasks with Apple Calendar.")
            }
        }
        
        // Floating Add Button
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: {
                    showingAddTask = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.trailing, 16)
                .padding(.bottom, 20)
            }
        }
    }
    }
    
    private func addTask() {
        guard !newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let newTask = TodoTask(
            title: newTaskTitle,
            isCompleted: false,
            dueDate: hasScheduledTime ? taskDueDate : nil,
            duration: taskDuration,
            calendarEventId: nil
        )
        
        // Add task to manager
        taskManager.addTask(newTask)
        
        // Sync with Apple Calendar if scheduled
        if hasScheduledTime {
            Task {
                // Try calendar; even if denied, still schedule notification
                if !calendarManager.isAuthorized {
                    let granted = await calendarManager.requestAccess()
                    if granted {
                        if let eventId = await calendarManager.addTaskToCalendar(
                            title: newTaskTitle,
                            dueDate: taskDueDate,
                            duration: taskDuration
                        ) {
                            await MainActor.run { newTask.calendarEventId = eventId }
                        }
                    } else {
                        await MainActor.run { showingCalendarPermission = true }
                    }
                } else {
                    if let eventId = await calendarManager.addTaskToCalendar(
                        title: newTaskTitle,
                        dueDate: taskDueDate,
                        duration: taskDuration
                    ) {
                        await MainActor.run { newTask.calendarEventId = eventId }
                    }
                }

                // Always schedule notification even if calendar permission is denied
                await NotificationManager.shared.scheduleNotification(for: newTask)
            }
        }
        
        // Reset state
        newTaskTitle = ""
        taskDueDate = Date()
        taskDuration = 3600
        hasScheduledTime = false
        showingAddTask = false
    }
    
    private func duplicateTask(_ task: TodoTask) {
        let duplicatedTask = TodoTask(
            title: task.title + " (Copy)",
            isCompleted: false,
            dueDate: task.dueDate,
            duration: task.duration,
            calendarEventId: nil
        )
        
        // Add duplicated task to manager
        taskManager.addTask(duplicatedTask)
        
        // Sync with Apple Calendar if it has a schedule
        if task.dueDate != nil {
            Task {
                // Try calendar; still schedule notification even if permission denied
                if !calendarManager.isAuthorized {
                    let granted = await calendarManager.requestAccess()
                    if granted {
                        if let eventId = await calendarManager.addTaskToCalendar(
                            title: duplicatedTask.title,
                            dueDate: duplicatedTask.dueDate,
                            duration: duplicatedTask.duration
                        ) {
                            await MainActor.run { duplicatedTask.calendarEventId = eventId }
                        }
                    } else {
                        await MainActor.run { showingCalendarPermission = true }
                    }
                } else {
                    if let eventId = await calendarManager.addTaskToCalendar(
                        title: duplicatedTask.title,
                        dueDate: duplicatedTask.dueDate,
                        duration: duplicatedTask.duration
                    ) {
                        await MainActor.run { duplicatedTask.calendarEventId = eventId }
                    }
                }

                // Always schedule notification even if calendar permission is denied
                await NotificationManager.shared.scheduleNotification(for: duplicatedTask)
            }
        }
    }
    
    private func deleteTask(_ task: TodoTask) {
        // Remove from Apple Calendar if it exists
        if let eventId = task.calendarEventId {
            Task {
                await calendarManager.deleteCalendarEvent(eventIdentifier: eventId)
            }
        }
        
        // Cancel notification
        NotificationManager.shared.cancelNotification(for: task)
        
        taskManager.deleteTask(task)
    }
    
    private func deleteTasks(at offsets: IndexSet) {
        for index in offsets {
            let task = taskManager.tasks[index]
            
            // Remove from Apple Calendar if it exists
            if let eventId = task.calendarEventId {
                Task {
                    await calendarManager.deleteCalendarEvent(eventIdentifier: eventId)
                }
            }
            
            // Cancel notification
            NotificationManager.shared.cancelNotification(for: task)
        }
        
        taskManager.deleteTasks(at: offsets)
    }
}

class TodoTask: Identifiable, ObservableObject, Codable {
    let id: UUID
    @Published var title: String
    @Published var isCompleted: Bool = false
    @Published var dueDate: Date?
    @Published var duration: TimeInterval = 3600 // Default 1 hour in seconds
    @Published var calendarEventId: String?
    
    var endDate: Date? {
        guard let startDate = dueDate else { return nil }
        return startDate.addingTimeInterval(duration)
    }
    
    init(title: String, isCompleted: Bool = false, dueDate: Date? = nil, duration: TimeInterval = 3600, calendarEventId: String? = nil) {
        self.id = UUID()
        self.title = title
        self.isCompleted = isCompleted
        self.dueDate = dueDate
        self.duration = duration
        self.calendarEventId = calendarEventId
    }
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, title, isCompleted, dueDate, duration, calendarEventId
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        calendarEventId = try container.decodeIfPresent(String.self, forKey: .calendarEventId)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encodeIfPresent(dueDate, forKey: .dueDate)
        try container.encode(duration, forKey: .duration)
        try container.encodeIfPresent(calendarEventId, forKey: .calendarEventId)
    }
}

struct TaskRow: View {
    @ObservedObject var task: TodoTask
    
    var body: some View {
        HStack {
            Button(action: {
                task.isCompleted.toggle()
                TaskManager.shared.updateTask(task)
            }) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.isCompleted ? .green : .gray)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(task.title)
                        .strikethrough(task.isCompleted)
                        .foregroundColor(task.isCompleted ? .secondary : .primary)
                    
                    if task.calendarEventId != nil {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                if let dueDate = task.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(dueDate, style: .time)
                            .font(.caption)
                        if let endDate = task.endDate {
                            Text("-")
                                .font(.caption)
                            Text(endDate, style: .time)
                                .font(.caption)
                        }
                        Text("•")
                            .font(.caption)
                        Text(dueDate, style: .date)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
    }
}

struct AddTaskSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var newTaskTitle: String
    @Binding var taskDueDate: Date
    @Binding var taskDuration: TimeInterval
    @Binding var hasScheduledTime: Bool
    let onAdd: () -> Void
    
    private let durationOptions: [(String, TimeInterval)] = [
        ("15 min", 900),
        ("30 min", 1800),
        ("45 min", 2700),
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
                    TextField("Enter task name", text: $newTaskTitle)
                } header: {
                    Text("Task Title")
                }
                
                Section {
                    Toggle("Schedule for specific time", isOn: $hasScheduledTime)
                    
                    if hasScheduledTime {
                        DatePicker(
                            "Start Time",
                            selection: $taskDueDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        
                        Picker("Duration", selection: $taskDuration) {
                            ForEach(durationOptions, id: \.1) { option in
                                Text(option.0).tag(option.1)
                            }
                        }
                        
                        if let endDate = taskDueDate.addingTimeInterval(taskDuration) as Date? {
                            HStack {
                                Text("End Time")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(endDate, style: .time)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                } header: {
                    Text("Timing")
                } footer: {
                    if hasScheduledTime {
                        Text("You'll be reminded at the start time")
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Add New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        newTaskTitle = ""
                        hasScheduledTime = false
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        onAdd()
                    }
                    .fontWeight(.semibold)
                    .disabled(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.large])
    }
}

struct EditTaskSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var task: TodoTask
    let calendarManager: CalendarManager
    let onDismiss: () -> Void
    
    @State private var editedTitle: String
    @State private var editedDueDate: Date
    @State private var editedDuration: TimeInterval
    @State private var hasScheduledTime: Bool
    
    private let durationOptions: [(String, TimeInterval)] = [
        ("15 min", 900),
        ("30 min", 1800),
        ("45 min", 2700),
        ("1 hour", 3600),
        ("1.5 hours", 5400),
        ("2 hours", 7200),
        ("3 hours", 10800),
        ("4 hours", 14400)
    ]
    
    init(task: TodoTask, calendarManager: CalendarManager, onDismiss: @escaping () -> Void) {
        self.task = task
        self.calendarManager = calendarManager
        self.onDismiss = onDismiss
        _editedTitle = State(initialValue: task.title)
        _editedDueDate = State(initialValue: task.dueDate ?? Date())
        _editedDuration = State(initialValue: task.duration)
        _hasScheduledTime = State(initialValue: task.dueDate != nil)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Task Title")) {
                    TextField("Enter task name", text: $editedTitle)
                        .font(.body)
                }
                
                Section(header: Text("Timing")) {
                    Toggle("Schedule for specific time", isOn: $hasScheduledTime)
                    
                    if hasScheduledTime {
                        DatePicker(
                            "Start Time",
                            selection: $editedDueDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        
                        Picker("Duration", selection: $editedDuration) {
                            ForEach(durationOptions, id: \.1) { option in
                                Text(option.0).tag(option.1)
                            }
                        }
                        
                        if let endDate = editedDueDate.addingTimeInterval(editedDuration) as Date? {
                            HStack {
                                Text("End Time")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(endDate, style: .time)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                if hasScheduledTime {
                    Section {
                        Text("You'll be reminded at the start time")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                    .disabled(editedTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.large])
    }
    
    private func saveChanges() {
        let oldEventId = task.calendarEventId
        
        // Update task properties
        task.title = editedTitle
        task.dueDate = hasScheduledTime ? editedDueDate : nil
        task.duration = editedDuration
        
        // Handle calendar sync and notifications
        Task {
            // If there was an old event and we're removing the schedule, delete it
            if let eventId = oldEventId, !hasScheduledTime {
                _ = await calendarManager.deleteCalendarEvent(eventIdentifier: eventId)
                await MainActor.run {
                    task.calendarEventId = nil
                }
                // Cancel notification
                NotificationManager.shared.cancelNotification(for: task)
            }
            // If there's an existing event and we're updating it
            else if let eventId = oldEventId, hasScheduledTime {
                let success = await calendarManager.updateCalendarEvent(
                    eventIdentifier: eventId,
                    title: editedTitle,
                    dueDate: editedDueDate,
                    duration: editedDuration
                )
                if !success {
                    // If update failed, try creating new event
                    _ = await calendarManager.deleteCalendarEvent(eventIdentifier: eventId)
                    if let newEventId = await calendarManager.addTaskToCalendar(
                        title: editedTitle,
                        dueDate: editedDueDate,
                        duration: editedDuration
                    ) {
                        await MainActor.run {
                            task.calendarEventId = newEventId
                        }
                    }
                }
                // Update notification
                await NotificationManager.shared.updateNotification(for: task)
            }
            // If there's no event but we're adding a schedule
            else if oldEventId == nil && hasScheduledTime {
                if let newEventId = await calendarManager.addTaskToCalendar(
                    title: editedTitle,
                    dueDate: editedDueDate,
                    duration: editedDuration
                ) {
                    await MainActor.run {
                        task.calendarEventId = newEventId
                    }
                }
                // Schedule notification
                await NotificationManager.shared.scheduleNotification(for: task)
            }
        }
        
        onDismiss()
    }
}

#Preview {
    ToDoView()
}
