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
    /// 앱이 만들어 넘겨준다. 할 일 화면에서 데드라인을 정할 때도 이 뷰모델을 거쳐
    /// 무지개에 줄이 그어지므로, 무지개 탭을 한 번도 안 열어도 살아 있어야 한다.
    @Bindable var viewModel: ScheduleViewModel
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
    ContentView(viewModel: ScheduleViewModel())
        .modelContainer(for: Event.self, inMemory: true)
}
