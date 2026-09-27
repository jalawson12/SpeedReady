import Foundation
import SwiftUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

enum DocumentImportError: LocalizedError, Equatable {
    case unsupportedType
    case unreadableText
    case emptyDocument
    case unavailableOnCurrentPlatform
    case pdf(PDFTextExtractor.ExtractionError)
    case epub(EPUBTextExtractor.ExtractionError)

    var errorDescription: String? {
        switch self {
        case .unsupportedType:
            return "That file type is not supported. Choose TXT, MD, PDF, or EPUB."
        case .unreadableText:
            return "The selected text file could not be decoded."
        case .emptyDocument:
            return "The selected document does not contain readable text."
        case .unavailableOnCurrentPlatform:
            return "Document import is unavailable on this platform."
        case .pdf(let error):
            return error.localizedDescription
        case .epub(let error):
            return error.localizedDescription
        }
    }
}

struct DocumentImportPipeline {
    private static let markdownType = UTType(filenameExtension: "md")

    static var supportedContentTypes: [UTType] {
        [UTType.plainText, UTType.text, markdownType, UTType.pdf, UTType.epub].compactMap { $0 }
    }

    static func importDocument(from url: URL) throws -> ReadingDocument {
        let title = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension.lowercased()
        let text: String

        switch ext {
        case "txt", "md", "markdown":
            text = try extractText(from: url)
        case "pdf":
            do {
                text = try PDFTextExtractor.extract(from: url)
            } catch let error as PDFTextExtractor.ExtractionError {
                throw DocumentImportError.pdf(error)
            }
        case "epub":
            do {
                text = try EPUBTextExtractor.extract(from: url)
            } catch let error as EPUBTextExtractor.ExtractionError {
                throw DocumentImportError.epub(error)
            }
        default:
            throw DocumentImportError.unsupportedType
        }

        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            throw DocumentImportError.emptyDocument
        }

        return ReadingDocument(
            title: title,
            text: cleaned,
            wordCount: cleaned.split(whereSeparator: \.isWhitespace).count,
            createdAt: Date()
        )
    }

    private static func extractText(from url: URL) throws -> String {
        if let content = try? String(contentsOf: url, encoding: .utf8) {
            return content
        }
        if let content = try? String(contentsOf: url, encoding: .utf16) {
            return content
        }
        if let content = try? String(contentsOf: url, encoding: .isoLatin1) {
            return content
        }
        throw DocumentImportError.unreadableText
    }
}

final class DocumentImportService: NSObject, ObservableObject {}

#if canImport(UIKit)
struct DocumentPickerView: UIViewControllerRepresentable {
    let onPick: (Result<ReadingDocument, DocumentImportError>) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: DocumentImportPipeline.supportedContentTypes,
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
            Task.detached(priority: .userInitiated) { [parent] in
                let didAccessSecurityScopedResource = url.startAccessingSecurityScopedResource()
                defer {
                    if didAccessSecurityScopedResource {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                let result: Result<ReadingDocument, DocumentImportError>
                do {
                    let document = try DocumentImportPipeline.importDocument(from: url)
                    result = .success(document)
                } catch let error as DocumentImportError {
                    result = .failure(error)
                } catch {
                    result = .failure(.emptyDocument)
                }

                await MainActor.run {
                    parent.onPick(result)
                }
            }
        }
    }
}
#else
struct DocumentPickerView: View {
    let onPick: (Result<ReadingDocument, DocumentImportError>) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Color.clear
            .onAppear {
                onPick(.failure(.unavailableOnCurrentPlatform))
                dismiss()
            }
    }
}
#endif
