//
//  ContentView.swift
//  AutoDay
//
//  Created by Januda Lelwala on 2025-12-03.
//

import SwiftUI

struct ContentView: View {
    @State private var showingSettings = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            TabView {
                HomeView()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                
                ToDoView()
                    .tabItem {
                        Label("To Do", systemImage: "checklist")
                    }
                
                UpcomingView()
                    .tabItem {
                        Label("Upcoming", systemImage: "calendar")
                    }
            }
            
            // Settings Button
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                            .padding(12)
                            .background(Color(.systemBackground))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 8)
                }
                Spacer()
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

#Preview {
    ContentView()
}
