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
    // 맥을 안 쓰고 소개도 아직 안 봤으면, 설정 안에 새로 볼 것이 있다고 점을 찍는다
    // (→ MacCompanionView.swift). 소개를 한 번 열면 내린다.
    @AppStorage(MacCompanion.usesMacKey) private var usesMac = false
    @AppStorage(MacCompanion.seenKey) private var seenMacCompanion = false

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
                                .overlay(alignment: .topTrailing) {
                                    if !usesMac && !seenMacCompanion {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 8, height: 8)
                                            .offset(x: 3, y: -2)
                                    }
                                }
                        }
                        .accessibilityLabel(!usesMac && !seenMacCompanion
                                            ? Text("설정, 새로 볼 것 있음") : Text("설정"))
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
