import SwiftUI

struct LibraryView: View {
    @ObservedObject var appState: SpeedReadyAppState
    @State private var showingDocumentPicker = false
    @State private var showingTextInput = false
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
                            showingDocumentPicker = true
                        }

                        Button("Paste Text", systemImage: "doc.on.clipboard") {
                            showingTextInput = true
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .accessibilityLabel("Add reading material")
                    }
                }
            }
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPickerView { result in
                    switch result {
                    case .success(let document):
                        appState.setCurrentDocument(document)
                    case .failure(let error):
                        importErrorMessage = error.localizedDescription
                    }
                    showingDocumentPicker = false
                }
            }
            .sheet(isPresented: $showingTextInput) {
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
                                showingTextInput = false
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Load") {
                                let trimmed = customText.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty else { return }
                                appState.addDocument(title: "Custom text", text: trimmed)
                                customText = ""
                                showingTextInput = false
                            }
                        }
                    }
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
}

#Preview {
    LibraryView(appState: SpeedReadyAppState())
}
