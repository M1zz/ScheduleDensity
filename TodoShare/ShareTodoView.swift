//
//  ShareTodoView.swift
//  TodoShareExtension
//
//  공유 시트 위에 뜨는 작은 창. 목록 화면과 같은 규칙으로 그린다 —
//  작은 글씨 없이, 시간은 목록에서 쓰는 것과 똑같은 칩으로.
//

import SwiftUI

struct ShareTodoView: View {
    @Bindable var model: ShareTodoModel
    @FocusState private var titleFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("할 일", text: $model.title, axis: .vertical)
                        .font(.title3)
                        .lineLimit(1...3)
                        .focused($titleFocused)
                        .submitLabel(.done)

                    if let link = model.link {
                        Label(link, systemImage: "link")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                } footer: {
                    if model.link != nil {
                        Text("이 페이지에서 가져왔습니다. 이름은 고쳐 쓸 수 있습니다.")
                    }
                }

                if let errorMessage = model.errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("할 일로")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { model.cancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("추가") { model.save() }
                        .disabled(!model.canSave)
                }
            }
            .overlay {
                // 받은 내용을 읽는 사이에 빈 칸이 잠깐 보이는 걸 막는다.
                if model.isLoading {
                    ProgressView()
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.background)
                }
            }
        }
    }
}
