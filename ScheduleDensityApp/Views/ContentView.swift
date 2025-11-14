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
    @State private var showingAddSampleAlert = false
    @State private var showingDeleteAllAlert = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            TimelineDensityView(viewModel: viewModel)
                .navigationTitle("일정 밀도")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 12) {
                            // 설정 버튼
                            Button(action: {
                                showingSettings = true
                            }) {
                                Image(systemName: "gearshape")
                            }

                            // 더보기 메뉴
                            Menu {
                                Button(action: {
                                    viewModel.showingAddEvent = true
                                }) {
                                    Label("일정 추가", systemImage: "plus")
                                }

                                Button(action: {
                                    showingAddSampleAlert = true
                                }) {
                                    Label("샘플 데이터 추가", systemImage: "tray.and.arrow.down")
                                }

                                Button(role: .destructive, action: {
                                    showingDeleteAllAlert = true
                                }) {
                                    Label("모든 일정 삭제", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                    }
                }
                .sheet(isPresented: $viewModel.showingAddEvent) {
                    AddEventView(viewModel: viewModel, eventToEdit: viewModel.eventToEdit)
                }
                .sheet(isPresented: $showingSettings) {
                    SettingsView(viewModel: viewModel)
                }
                .alert("샘플 데이터 추가", isPresented: $showingAddSampleAlert) {
                    Button("추가") {
                        viewModel.addSampleEvents()
                    }
                    Button("취소", role: .cancel) { }
                } message: {
                    Text("5개의 샘플 일정을 추가하시겠습니까?\n(프로젝트 A, B, 출장, 교육 프로그램, 컨퍼런스)")
                }
                .alert("모든 일정 삭제", isPresented: $showingDeleteAllAlert) {
                    Button("삭제", role: .destructive) {
                        viewModel.deleteAllEvents()
                    }
                    Button("취소", role: .cancel) { }
                } message: {
                    Text("모든 일정을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.")
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
