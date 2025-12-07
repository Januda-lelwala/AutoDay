//
//  HomeView.swift
//  AutoDay
//
//  Created by Januda Lelwala on 2025-12-03.
//

import SwiftUI

struct HomeView: View {
    @State private var userInput: String = ""
    @State private var isGenerating: Bool = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var generatedTasksCount = 0
    @State private var showingSuccess = false
    @StateObject private var calendarManager = CalendarManager()
    @ObservedObject private var taskManager = TaskManager.shared
    @FocusState private var isTextEditorFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 30) {
                    // Header Section
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 70))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .padding(.top, 20)
                        
                        Text("AutoDay")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                        
                        Text("AI-Powered Schedule Assistant")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 10)
                    
                    // Input Section
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Describe Your Day", systemImage: "text.bubble.fill")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        ZStack(alignment: .topLeading) {
                            if userInput.isEmpty {
                                Text("Tell me what you need to do today...\n\nExamples:\n• I need to finish a report, go to the gym, and meet John for coffee\n• Schedule time for studying, meal prep, and a team meeting at 3 PM")
                                    .foregroundColor(.gray.opacity(0.6))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 12)
                                    .allowsHitTesting(false)
                            }
                            
                            TextEditor(text: $userInput)
                                .frame(minHeight: 180)
                                .scrollContentBackground(.hidden)
                                .padding(4)
                                .focused($isTextEditorFocused)
                        }
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal)
                    
                    // Generate Button
                    Button(action: {
                        generateSchedule()
                    }) {
                        HStack {
                            if isGenerating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding(.trailing, 8)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            
                            Text(isGenerating ? "Generating..." : "Generate Schedule")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: userInput.isEmpty ? [.gray, .gray.opacity(0.8)] : [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(14)
                        .shadow(color: userInput.isEmpty ? .clear : .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(userInput.isEmpty || isGenerating)
                    .padding(.horizontal)
                    
                    // Quick Tips Section
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Quick Tips", systemImage: "lightbulb.fill")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            TipRow(icon: "clock.fill", text: "Include specific times if you have fixed appointments")
                            TipRow(icon: "flag.fill", text: "Mention priorities to help organize your day better")
                            TipRow(icon: "list.bullet", text: "List all tasks, and I'll create an optimal schedule")
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 20)
                }
                .padding(.vertical)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isTextEditorFocused = false
            }
            .navigationBarTitleDisplayMode(.inline)
            
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(action: { isTextEditorFocused = false }) {
                        Image(systemName: "keyboard.chevron.compact.down")
                    }
                }
            }
            .alert("Success!", isPresented: $showingSuccess) {
                Button("OK") {
                    userInput = ""
                }
            } message: {
                Text("Successfully created \(generatedTasksCount) task\(generatedTasksCount == 1 ? "" : "s")! Check the To Do tab.")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Unknown error occurred")
            }
            .onAppear {
                taskManager.setCalendarManager(calendarManager)
            }
        }
    }
    
    private func generateSchedule() {
        isGenerating = true
        errorMessage = nil
        
        Task {
            do {
                let openAIService = OpenAIService()
                let scheduledTasks = try await openAIService.generateSchedule(from: userInput)
                
                await MainActor.run {
                    // Convert OpenAI tasks to TodoTask objects
                    var createdCount = 0
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    
                    let timeFormatter = DateFormatter()
                    timeFormatter.dateFormat = "HH:mm"
                    
                    for scheduledTask in scheduledTasks {
                        var dueDate: Date? = nil
                        
                        // Parse date and time
                        if let dateString = scheduledTask.date, let date = dateFormatter.date(from: dateString) {
                            if let timeString = scheduledTask.time, let time = timeFormatter.date(from: timeString) {
                                // Combine date and time
                                let calendar = Calendar.current
                                let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
                                dueDate = calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                                       minute: timeComponents.minute ?? 0,
                                                       second: 0,
                                                       of: date)
                            } else {
                                // Just use the date at current time
                                dueDate = date
                            }
                        }
                        
                        let duration = TimeInterval(scheduledTask.duration * 60) // Convert minutes to seconds
                        
                        let newTask = TodoTask(
                            title: scheduledTask.title,
                            isCompleted: false,
                            dueDate: dueDate,
                            duration: duration,
                            calendarEventId: nil
                        )
                        
                        taskManager.addTask(newTask)
                        createdCount += 1
                        
                        // Add to calendar if it has a due date
                        if dueDate != nil {
                            Task {
                                if let eventId = await calendarManager.addTaskToCalendar(
                                    title: newTask.title,
                                    dueDate: newTask.dueDate,
                                    duration: duration
                                ) {
                                    await MainActor.run {
                                        newTask.calendarEventId = eventId
                                    }
                                }
                                // Schedule notification
                                await NotificationManager.shared.scheduleNotification(for: newTask)
                            }
                        }
                    }
                    
                    generatedTasksCount = createdCount
                    isGenerating = false
                    
                    if createdCount > 0 {
                        showingSuccess = true
                    } else {
                        errorMessage = "No tasks were created. Please try rephrasing your request."
                        showingError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

struct TipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    HomeView()
}
