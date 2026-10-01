import SwiftUI

struct LibraryView: View {
    private enum ActiveSheet: String, Identifiable {
        case documentPicker
        case textInput

        var id: String { rawValue }
    }

    let appState: SpeedReadyAppState
    let settings: ReaderSettings
    @Environment(\.colorScheme) private var colorScheme
    @State private var activeSheet: ActiveSheet?
    @State private var customText = ""
    @State private var customTitle = ""
    @State private var importErrorMessage: String?
    @State private var editingDocument: ReadingDocument?
    @State private var editedTitle = ""
    @State private var documentPendingDeletion: ReadingDocument?

    private var palette: AppPalette {
        AppPalette(settings: settings, colorScheme: colorScheme)
    }

    var body: some View {
        NavigationStack {
            List(appState.documents) { document in
                Button {
                    appState.setCurrentDocument(document)
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(document.title)
                                .font(.headline)
                                .foregroundStyle(palette.text)
                            Text("\(document.wordCount) words")
                                .font(.subheadline)
                                .foregroundStyle(palette.mutedText)
                            Text(document.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(palette.mutedText.opacity(0.8))
                        }

                        Spacer()

                        if appState.currentDocument?.id == document.id {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(palette.accent)
                                .accessibilityLabel("Currently selected")
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint("Selects this document as the current reading item")
                .padding(.vertical, 8)
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button("Rename") {
                        editingDocument = document
                        editedTitle = document.title
                    }
                    .tint(palette.accent)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("Delete", role: .destructive) {
                        documentPendingDeletion = document
                    }
                    .tint(.red)
                }
            }
            .listStyle(.insetGrouped)
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
                            .foregroundStyle(palette.accent)
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
                .disabled(editedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
            .confirmationDialog(
                "Delete document?",
                isPresented: Binding(get: {
                    documentPendingDeletion != nil
                }, set: { newValue in
                    if !newValue { documentPendingDeletion = nil }
                }),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    guard let document = documentPendingDeletion else { return }
                    appState.deleteDocument(id: document.id)
                    documentPendingDeletion = nil
                }
                Button("Cancel", role: .cancel) {
                    documentPendingDeletion = nil
                }
            } message: {
                if let document = documentPendingDeletion {
                    Text("Delete “\(document.title)” from your library? This cannot be undone.")
                }
            }
        }
    }

}

#Preview {
    LibraryView(appState: SpeedReadyAppState(), settings: ReaderSettings())
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
                        onLoad(trimmedTitle, trimmedText)
                        title = ""
                        text = ""
                        dismiss()
                    }
                    .disabled(!canLoad)
                }
            }
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canLoad: Bool {
        !trimmedTitle.isEmpty && !trimmedText.isEmpty
    }
}
