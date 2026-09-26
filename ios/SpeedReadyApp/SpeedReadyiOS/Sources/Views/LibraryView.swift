import SwiftUI

struct LibraryView: View {
    private enum ActiveSheet: String, Identifiable {
        case documentPicker
        case textInput

        var id: String { rawValue }
    }

    @ObservedObject var appState: SpeedReadyAppState
    @State private var activeSheet: ActiveSheet?
    @State private var customText = ""
    @State private var importErrorMessage: String?

    var body: some View {
        NavigationStack {
            List(appState.documents) { document in
                VStack(alignment: .leading, spacing: 4) {
                    Text(document.title)
                        .font(.headline)
                    Text("\(document.wordCount) words")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(document.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    appState.currentDocument = document
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Load Document", systemImage: "doc.badge.plus") {
                            activeSheet = .documentPicker
                        }

                        Button("Paste Text", systemImage: "doc.on.clipboard") {
                            activeSheet = .textInput
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .accessibilityLabel("Add reading material")
                    }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .documentPicker:
                    DocumentPickerView { result in
                        switch result {
                        case .success(let document):
                            appState.addDocument(document)
                        case .failure(let error):
                            importErrorMessage = error.localizedDescription
                        }
                        activeSheet = nil
                    }
                case .textInput:
                    NavigationStack {
                        Form {
                            Section("Paste or type text") {
                                TextEditor(text: $customText)
                                    .frame(minHeight: 220)
                            }
                        }
                        .navigationTitle("New reading text")
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Cancel") {
                                    dismissTextInput()
                                }
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Load") {
                                    let trimmed = customText.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard !trimmed.isEmpty else { return }
                                    appState.addDocument(title: "Custom text", text: trimmed)
                                    dismissTextInput()
                                }
                            }
                        }
                    }
                }
            }
            .onChange(of: activeSheet?.id) { _, nextValue in
                if nextValue != ActiveSheet.textInput.id {
                    customText = ""
                }
            }
            .alert("Import failed", isPresented: Binding(get: {
                importErrorMessage != nil
            }, set: { newValue in
                if !newValue { importErrorMessage = nil }
            })) {
                Button("OK", role: .cancel) { importErrorMessage = nil }
            } message: {
                Text(importErrorMessage ?? "Unknown error.")
            }
        }
    }

    private func dismissTextInput() {
        customText = ""
        activeSheet = nil
    }
}

#Preview {
    LibraryView(appState: SpeedReadyAppState())
}
