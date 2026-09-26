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
    @State private var customTitle = ""
    @State private var importErrorMessage: String?
    @State private var editingDocument: ReadingDocument?
    @State private var editedTitle = ""

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
                    appState.setCurrentDocument(document)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("Rename") {
                        editingDocument = document
                        editedTitle = document.title
                    }
                    .tint(.blue)
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
                    }
                    .accessibilityLabel("Add reading material")
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .documentPicker:
                    DocumentImportSheet { result in
                        switch result {
                        case .success(let document):
                            appState.importDocument(document)
                        case .failure(let error):
                            importErrorMessage = error.localizedDescription
                        }
                    }
                case .textInput:
                    TextImportSheet(title: $customTitle, text: $customText) { title, trimmed in
                        appState.addDocument(title: title, text: trimmed)
                    }
                }
            }
            .onChange(of: activeSheet?.id) { _, nextValue in
                if nextValue != ActiveSheet.textInput.id {
                    customText = ""
                    customTitle = ""
                }
            }
            .alert("Edit title", isPresented: Binding(get: {
                editingDocument != nil
            }, set: { newValue in
                if !newValue {
                    editingDocument = nil
                    editedTitle = ""
                }
            })) {
                TextField("Title", text: $editedTitle)
                Button("Cancel", role: .cancel) {
                    editingDocument = nil
                    editedTitle = ""
                }
                Button("Save") {
                    guard let document = editingDocument else { return }
                    appState.renameDocument(id: document.id, title: editedTitle)
                    editingDocument = nil
                    editedTitle = ""
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

private struct DocumentImportSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onPick: (Result<ReadingDocument, DocumentImportError>) -> Void

    var body: some View {
        DocumentPickerView { result in
            onPick(result)
            dismiss()
        }
    }
}

private struct TextImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var title: String
    @Binding var text: String

    let onLoad: (String, String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Enter title", text: $title)
                }

                Section("Paste or type text") {
                    TextEditor(text: $text)
                        .frame(minHeight: 220)
                }
            }
            .navigationTitle("New reading text")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        title = ""
                        text = ""
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Load") {
                        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedTitle.isEmpty, !trimmed.isEmpty else { return }
                        onLoad(trimmedTitle, trimmed)
                        title = ""
                        text = ""
                        dismiss()
                    }
                }
            }
        }
    }
}
