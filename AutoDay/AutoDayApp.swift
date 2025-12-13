//
//  AutoDayApp.swift
//  AutoDay
//
//  Created by Januda Lelwala on 2025-12-03.
//

import SwiftUI
import UserNotifications

@main
struct AutoDayApp: App {
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var calendarManager = CalendarManager()
    @State private var isLoading = true
    
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(calendarManager)
                    .opacity(isLoading ? 0 : 1)
                
                if isLoading {
                    LoadingScreen()
                        .transition(.opacity)
                }
            }
            .onAppear {
                // Request permissions on first launch
                Task {
                    // Request notification permission
                    _ = await notificationManager.requestAuthorization()
                    
                    // Request calendar permission
                    _ = await calendarManager.requestAccess()
                    
                    // Reschedule all notifications for loaded tasks
                    await notificationManager.rescheduleAllNotifications(for: TaskManager.shared.tasks)
                    
                    // Minimum loading time for smooth experience
                    try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                    
                    withAnimation(.easeInOut(duration: 0.5)) {
                        isLoading = false
                    }
                }
            }
        }
    }
}

struct LoadingScreen: View {
    @State private var isAnimating = false
    @State private var pulseAnimation = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.4, blue: 0.9),
                    Color(red: 0.5, green: 0.3, blue: 0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Animated calendar icon
                ZStack {
                    // Pulsing circle background
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 140, height: 140)
                        .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                        .opacity(pulseAnimation ? 0 : 0.5)
                    
                    // Main icon
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                }
                
                VStack(spacing: 12) {
                    Text("AutoDay")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("AI-Powered Schedule Assistant")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    
                    // Loading indicator
                    HStack(spacing: 8) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(.white)
                                .frame(width: 8, height: 8)
                                .scaleEffect(isAnimating ? 1.0 : 0.5)
                                .opacity(isAnimating ? 1.0 : 0.3)
                                .animation(
                                    .easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(Double(index) * 0.2),
                                    value: isAnimating
                                )
                        }
                    }
                    .padding(.top, 20)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
            
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                pulseAnimation = true
            }
        }
    }
}
