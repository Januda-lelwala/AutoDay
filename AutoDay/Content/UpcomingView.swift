//
//  UpcomingView.swift
//  AutoDay
//
//  Created by Januda Lelwala on 2025-12-03.
//

import SwiftUI

struct UpcomingView: View {
    @ObservedObject private var taskManager = TaskManager.shared
    @StateObject private var calendarManager = CalendarManager()
    @State private var selectedDate = Date()
    @State private var currentWeekOffset = 0
    @State private var editingTask: TodoTask?
    @State private var showingEditSheet = false
    @Namespace private var scrollNamespace
    
    private let calendar = Calendar.current
    
    // Group tasks by date
    private var groupedTasks: [(date: Date, tasks: [TodoTask])] {
        let filteredTasks = taskManager.tasks.filter { $0.dueDate != nil }
        
        let grouped = Dictionary(grouping: filteredTasks) { task -> Date in
            guard let dueDate = task.dueDate else { return Date() }
            return calendar.startOfDay(for: dueDate)
        }
        
        return grouped.map { (date: $0.key, tasks: $0.value) }
            .sorted { $0.date < $1.date }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Week View Calendar
                WeekCalendarView(
                    selectedDate: $selectedDate,
                    currentWeekOffset: $currentWeekOffset,
                    tasks: taskManager.tasks,
                    onDateSelected: { date in
                        selectedDate = date
                    }
                )
                .padding(.horizontal)
                .padding(.top)
                
                Divider()
                    .padding(.vertical, 12)
                
                // All Tasks Timeline (Scrollable)
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 20) {
                            if groupedTasks.isEmpty {
                                // Empty State
                                VStack(spacing: 20) {
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.system(size: 60))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.blue.opacity(0.5), .purple.opacity(0.5)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                    
                                    Text("No Upcoming Tasks")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    
                                    Text("Schedule tasks in the To Do tab to see them here")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 60)
                            } else {
                                ForEach(groupedTasks, id: \.date) { group in
                                    DaySection(
                                        date: group.date,
                                        tasks: group.tasks,
                                        isSelected: calendar.isDate(group.date, inSameDayAs: selectedDate),
                                        onEdit: { task in
                                            editingTask = task
                                            showingEditSheet = true
                                        },
                                        onDelete: { task in
                                            deleteTask(task)
                                        },
                                        onDuplicate: { task in
                                            duplicateTask(task)
                                        }
                                    )
                                    .id(calendar.startOfDay(for: group.date))
                                }
                            }
                            
                            Spacer(minLength: 20)
                        }
                        .padding(.horizontal)
                        .padding(.vertical)
                    }
                    .onChange(of: selectedDate) { _, newDate in
                        withAnimation(.easeInOut(duration: 0.5)) {
                            proxy.scrollTo(calendar.startOfDay(for: newDate), anchor: .top)
                        }
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            proxy.scrollTo(calendar.startOfDay(for: selectedDate), anchor: .top)
                        }
                    }
                }
            }
            .navigationTitle("Upcoming")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
            }
            .sheet(isPresented: $showingEditSheet) {
                if let task = editingTask {
                    EditTaskSheet(
                        task: task,
                        calendarManager: calendarManager,
                        onDismiss: {
                            showingEditSheet = false
                            editingTask = nil
                        }
                    )
                }
            }
        }
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
                if let eventId = await calendarManager.addTaskToCalendar(
                    title: duplicatedTask.title,
                    dueDate: duplicatedTask.dueDate,
                    duration: duplicatedTask.duration
                ) {
                    await MainActor.run {
                        duplicatedTask.calendarEventId = eventId
                    }
                }
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
        
        taskManager.deleteTask(task)
    }
}

struct WeekCalendarView: View {
    @Binding var selectedDate: Date
    @Binding var currentWeekOffset: Int
    let tasks: [TodoTask]
    let onDateSelected: (Date) -> Void
    
    private let calendar = Calendar.current
    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    private var currentDisplayDate: Date {
        calendar.date(byAdding: .weekOfYear, value: currentWeekOffset, to: Date()) ?? Date()
    }
    
    private var weekDates: [Date] {
        let weekday = calendar.component(.weekday, from: currentDisplayDate)
        let startOfWeek = calendar.date(byAdding: .day, value: -(weekday - 1), to: currentDisplayDate)!
        
        return (0..<7).compactMap { day in
            calendar.date(byAdding: .day, value: day, to: startOfWeek)
        }
    }
    
    private func hasTasksOn(date: Date) -> Bool {
        let dayStart = calendar.startOfDay(for: date)
        return tasks.contains { task in
            guard let dueDate = task.dueDate else { return false }
            return calendar.isDate(dueDate, inSameDayAs: dayStart)
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Month and Year with Navigation
            HStack {
                Button(action: {
                    withAnimation {
                        currentWeekOffset -= 1
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.blue)
                        .frame(width: 44, height: 44)
                }
                
                Spacer()
                
                Text(currentDisplayDate, format: .dateTime.month(.wide).year())
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        currentWeekOffset += 1
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundColor(.blue)
                        .frame(width: 44, height: 44)
                }
            }
            
            // Week Days
            HStack(spacing: 0) {
                ForEach(weekDates, id: \.self) { date in
                    VStack(spacing: 8) {
                        Text(calendar.component(.day, from: date), format: .number)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(calendar.isDate(date, inSameDayAs: selectedDate) ? .white : .primary)
                        
                        Text(daysOfWeek[calendar.component(.weekday, from: date) - 1])
                            .font(.caption)
                            .foregroundColor(calendar.isDate(date, inSameDayAs: selectedDate) ? .white.opacity(0.8) : .secondary)
                        
                        // Task indicator dot
                        Circle()
                            .fill(hasTasksOn(date: date) ? Color.blue : Color.clear)
                            .frame(width: 6, height: 6)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(calendar.isDate(date, inSameDayAs: selectedDate) ? 
                                  AnyShapeStyle(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)) :
                                  calendar.isDateInToday(date) ?
                                  AnyShapeStyle(Color.blue.opacity(0.2)) :
                                  AnyShapeStyle(Color.clear))
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            onDateSelected(date)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct DaySection: View {
    let date: Date
    let tasks: [TodoTask]
    var isSelected: Bool = false
    let onEdit: (TodoTask) -> Void
    let onDelete: (TodoTask) -> Void
    let onDuplicate: (TodoTask) -> Void
    
    private var sortedTasks: [TodoTask] {
        tasks.sorted { task1, task2 in
            guard let date1 = task1.dueDate, let date2 = task2.dueDate else { return false }
            return date1 < date2
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Date Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(date, format: .dateTime.weekday(.wide))
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(date, format: .dateTime.month().day())
                        .font(.subheadline)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
                
                Spacer()
                
                Text("\(tasks.count) task\(tasks.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isSelected ? Color.white.opacity(0.2) : Color(.systemGray5))
                    .cornerRadius(8)
            }
            .padding(.bottom, 4)
            
            // Timeline
            VStack(spacing: 0) {
                ForEach(Array(sortedTasks.enumerated()), id: \.element.id) { index, task in
                    TimelineTaskRow(
                        task: task,
                        isLast: index == sortedTasks.count - 1
                    )
                    .contextMenu {
                        Button(action: {
                            onEdit(task)
                        }) {
                            Label("Edit", systemImage: "pencil")
                        }
                        
                        Button(action: {
                            onDuplicate(task)
                        }) {
                            Label("Duplicate", systemImage: "doc.on.doc")
                        }
                        
                        Button(role: .destructive, action: {
                            onDelete(task)
                        }) {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            isSelected ?
            LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing) :
            LinearGradient(colors: [Color(.systemGray6), Color(.systemGray6)], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(16)
        .shadow(color: isSelected ? .blue.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
    }
}

struct TimelineTaskRow: View {
    @ObservedObject var task: TodoTask
    var isLast: Bool = false
    
    var body: some View {
        Button(action: {
            task.isCompleted.toggle()
            TaskManager.shared.updateTask(task)
        }) {
            HStack(alignment: .top, spacing: 12) {
            // Time
            if let dueDate = task.dueDate {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(dueDate, style: .time)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.blue)
                    if let endDate = task.endDate {
                        Text(endDate, style: .time)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 60)
            }                // Timeline dot and line
                VStack(spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(task.isCompleted ? Color.green : Color.blue)
                            .frame(width: 12, height: 12)
                        
                        if task.isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    
                    if !isLast {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 2, height: 40)
                    }
                }
                
                // Task Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .strikethrough(task.isCompleted)
                    
                    if task.isCompleted {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text("Completed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, isLast ? 4 : 8)
                
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    UpcomingView()
}
