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
    @State private var showingSampleDataAlert = false
    
    var body: some View {
        NavigationStack {
            VStack {
                WeekView(viewModel: viewModel)
            }
            .navigationTitle("일정 밀도")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        viewModel.moveToToday()
                    }) {
                        Text("오늘")
                            .fontWeight(.semibold)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        // 추천 버튼
                        Button(action: {
                            viewModel.showingRecommendations = true
                        }) {
                            Image(systemName: "lightbulb.fill")
                        }
                        
                        // 추가 버튼
                        Button(action: {
                            viewModel.showingAddEvent = true
                        }) {
                            Image(systemName: "plus")
                        }
                        
                        // 더보기 메뉴
                        Menu {
                            Button(action: {
                                showingSampleDataAlert = true
                            }) {
                                Label("샘플 데이터 추가", systemImage: "tray.and.arrow.down")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingAddEvent) {
                AddEventView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingRecommendations) {
                RecommendationView(viewModel: viewModel)
            }
            .alert("샘플 데이터 추가", isPresented: $showingSampleDataAlert) {
                Button("추가", role: .destructive) {
                    viewModel.addSampleEvents()
                }
                Button("취소", role: .cancel) { }
            } message: {
                Text("샘플 일정을 추가하시겠습니까?\n(수업, 운동, 스터디, 스터디 준비)")
            }
            .onAppear {
                viewModel.setModelContext(modelContext)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Event.self, inMemory: true)
}
