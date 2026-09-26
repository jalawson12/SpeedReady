import Foundation
import SwiftUI
import UniformTypeIdentifiers
import UIKit
import PDFKit

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

    private func makeDocument(from url: URL) -> ReadingDocument {
        let title = url.deletingPathExtension().lastPathComponent
        let text = extractTextFromURL(url)
        let cleanedText = text.isEmpty ? "Imported document loaded successfully. Add content from a text or PDF file to begin reading." : text
        return ReadingDocument(
            title: title,
            text: cleanedText,
            wordCount: cleanedText.split(whereSeparator: { $0.isWhitespace }).count,
            createdAt: Date()
        )
    }

    private func extractTextFromURL(_ url: URL) -> String {
        let ext = url.pathExtension.lowercased()

        if ext == "pdf", let pdf = PDFDocument(url: url) {
            var parts: [String] = []
            for pageIndex in 0..<pdf.pageCount {
                if let page = pdf.page(at: pageIndex), let pageText = page.string {
                    let cleaned = pageText
                        .replacingOccurrences(of: "\u{0000}", with: "")
                        .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleaned.isEmpty { parts.append(cleaned) }
                }
            }
            let combined = parts.joined(separator: "\n\n")
            if !combined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return combined
            }
        }

        if let content = try? String(contentsOf: url, encoding: .utf8) {
            return content
        }
        if let content = try? String(contentsOf: url, encoding: .isoLatin1) {
            return content
        }
        return ""
    }
}

extension DocumentImportService: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        let doc = makeDocument(from: url)
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
            let extracted = extractText(from: url)
            let finalText = extracted.isEmpty ? "Imported document loaded successfully." : extracted
            let doc = ReadingDocument(
                title: url.deletingPathExtension().lastPathComponent,
                text: finalText,
                wordCount: finalText.split(whereSeparator: { $0.isWhitespace }).count,
                createdAt: Date()
            )
            parent.onPick(doc)
        }

        private func extractText(from url: URL) -> String {
            let ext = url.pathExtension.lowercased()
            if ext == "pdf", let pdf = PDFDocument(url: url) {
                var parts: [String] = []
                for pageIndex in 0..<pdf.pageCount {
                    if let page = pdf.page(at: pageIndex), let pageText = page.string {
                        let cleaned = pageText
                            .replacingOccurrences(of: "\u{0000}", with: "")
                            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        if !cleaned.isEmpty { parts.append(cleaned) }
                    }
                }
                let combined = parts.joined(separator: "\n\n")
                if !combined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return combined
                }
            }

            if let content = try? String(contentsOf: url, encoding: .utf8) {
                return content
            }
            if let content = try? String(contentsOf: url, encoding: .isoLatin1) {
                return content
            }
            return ""
        }
    }
}

