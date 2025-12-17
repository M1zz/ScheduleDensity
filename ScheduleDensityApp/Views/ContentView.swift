//
//  ContentView.swift
//  ScheduleDensityApp
//
//  Created by Claude on 2025-03-01.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ScheduleViewModel()
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            TimelineDensityView(viewModel: viewModel)
                .navigationTitle("일정 밀도")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingSettings = true
                        }) {
                            Image(systemName: "gearshape")
                        }
                    }
                }
                .sheet(isPresented: $viewModel.showingAddEvent) {
                    AddEventView(viewModel: viewModel, eventToEdit: viewModel.eventToEdit)
                }
                .sheet(isPresented: $showingSettings) {
                    SettingsView(viewModel: viewModel)
                }
                .task {
                    // task를 사용하여 뷰가 나타날 때 modelContext 설정
                    viewModel.setModelContext(modelContext)
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Event.self, inMemory: true)
}
