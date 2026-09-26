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
                    DocumentImportSheet { result in
                        switch result {
                        case .success(let document):
                            appState.addDocument(document)
                        case .failure(let error):
                            importErrorMessage = error.localizedDescription
                        }
                    }
                case .textInput:
                    TextImportSheet(text: $customText) { trimmed in
                        appState.addDocument(title: "Custom text", text: trimmed)
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
    @Binding var text: String

    let onLoad: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Paste or type text") {
                    TextEditor(text: $text)
                        .frame(minHeight: 220)
                }
            }
            .navigationTitle("New reading text")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        text = ""
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Load") {
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onLoad(trimmed)
                        text = ""
                        dismiss()
                    }
                }
            }
        }
    }
}
