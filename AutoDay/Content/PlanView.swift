//
//  PlanView.swift
//  AutoDay
//
//  Created by Januda Lelwala on 2025-12-03.
//

import SwiftUI

struct PlanView: View {
    @State private var selectedDate = Date()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Date Picker
                    DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    
                    // Schedule Preview
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                            Text("Schedule for \(selectedDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.headline)
                        }
                        .padding(.horizontal)
                        
                        // Empty State
                        VStack(spacing: 16) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 50))
                                .foregroundColor(.secondary)
                            
                            Text("No schedule for this day")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("Go to Home to generate a schedule")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                }
                .padding(.vertical)
            }
            .navigationTitle("Plan")
        }
    }
}

#Preview {
    PlanView()
}
