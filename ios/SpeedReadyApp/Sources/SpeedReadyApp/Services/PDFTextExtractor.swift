import Foundation
import PDFKit

struct PDFTextExtractor {
    enum ExtractionError: LocalizedError {
        case unreadable
        case imageOnly

        var errorDescription: String? {
            switch self {
            case .unreadable:
                return "The PDF could not be opened or read."
            case .imageOnly:
                return "This PDF contains scanned pages without a text layer. OCR support is required to read it."
            }
        }
    }

    static func extract(from url: URL) throws -> String {
        guard let pdf = PDFDocument(url: url) else {
            throw ExtractionError.unreadable
        }

        let pages = (0..<pdf.pageCount).compactMap { index -> String? in
            guard let page = pdf.page(at: index), let text = page.string else { return nil }
            let cleaned = text
                .replacingOccurrences(of: "\u{0000}", with: "")
                .replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
                .replacingOccurrences(of: "\\n{3,}", with: "\\n\\n", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.isEmpty ? nil : cleaned
        }

        let result = pages.joined(separator: "\n\n")
        guard !result.isEmpty else { throw ExtractionError.imageOnly }
        return result
    }
}
