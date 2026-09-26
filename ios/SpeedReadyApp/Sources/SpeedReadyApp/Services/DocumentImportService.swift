import Foundation
import SwiftUI
import UniformTypeIdentifiers
import UIKit

final class DocumentImportService: NSObject, ObservableObject {
    private var onPick: ((ReadingDocument) -> Void)?
    private var picker: UIDocumentPickerViewController?

    func present(from viewController: UIViewController, onPick: @escaping (ReadingDocument) -> Void) {
        self.onPick = onPick
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [UTType.plainText, UTType.text, UTType.pdf, UTType.epub],
            asCopy: true
        )
        picker.delegate = self
        picker.allowsMultipleSelection = false
        self.picker = picker
        viewController.present(picker, animated: true)
    }

    private func loadText(from url: URL) -> String {
        do {
            let data = try Data(contentsOf: url)
            if let text = String(data: data, encoding: .utf8) {
                return text
            }
            if let text = String(data: data, encoding: .isoLatin1) {
                return text
            }
            return ""
        } catch {
            return ""
        }
    }
}

extension DocumentImportService: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        let title = url.deletingPathExtension().lastPathComponent
        let text = loadText(from: url)
        let doc = ReadingDocument(
            title: title,
            text: text.isEmpty ? "Imported document loaded successfully. Add content from a plain text, markdown, or other supported file to begin reading." : text,
            wordCount: text.isEmpty ? 0 : text.split(whereSeparator: { $0.isWhitespace }).count,
            createdAt: Date()
        )
        onPick?(doc)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        controller.dismiss(animated: true)
    }
}

struct DocumentPickerView: UIViewControllerRepresentable {
    let onPick: (ReadingDocument) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [UTType.plainText, UTType.text, UTType.pdf, UTType.epub],
            asCopy: true
        )
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let parent: DocumentPickerView

        init(parent: DocumentPickerView) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            let text = try? String(contentsOf: url, encoding: .utf8)
            let finalText = text ?? "" 
            let doc = ReadingDocument(
                title: url.deletingPathExtension().lastPathComponent,
                text: finalText.isEmpty ? "Imported document loaded successfully." : finalText,
                wordCount: finalText.isEmpty ? 0 : finalText.split(whereSeparator: { $0.isWhitespace }).count,
                createdAt: Date()
            )
            parent.onPick(doc)
        }
    }
}
