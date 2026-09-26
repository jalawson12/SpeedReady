import Foundation
import PDFKit
import Vision

struct PDFTextExtractor {
    enum ExtractionError: LocalizedError {
        case unreadable
        case imageOnly
        case ocrFailed

        var errorDescription: String? {
            switch self {
            case .unreadable:
                return "The PDF could not be opened or read."
            case .imageOnly:
                return "This PDF contains scanned pages. Attempting OCR extraction..."
            case .ocrFailed:
                return "OCR processing failed. Please try another PDF."
            }
        }
    }

    struct ExtractionResult {
        let text: String
        let metadata: PDFMetadata
        let statistics: ExtractionStatistics
    }

    struct PDFMetadata {
        let title: String?
        let author: String?
        let subject: String?
        let creator: String?
        let creationDate: Date?
        let pageCount: Int
    }

    struct ExtractionStatistics {
        let totalPages: Int
        let pagesWithText: Int
        let ocrPagesProcessed: Int
        let ocrConfidence: Double // 0.0 to 1.0
        let extractedCharacterCount: Int
        let estimatedWordCount: Int
        let extractionQuality: Quality

        enum Quality: String {
            case excellent = "Excellent (native text)"
            case good = "Good (mostly native text)"
            case fair = "Fair (mixed native + OCR)"
            case poor = "Poor (mostly OCR)"
            case veryPoor = "Very Poor (corrupted or encrypted)"
        }
    }

    static func extract(from url: URL) throws -> String {
        let result = try extractWithMetadata(from: url)
        return result.text
    }

    static func extractWithMetadata(from url: URL) throws -> ExtractionResult {
        guard let pdf = PDFDocument(url: url) else {
            throw ExtractionError.unreadable
        }

        // Extract metadata
        let metadata = extractMetadata(from: pdf)

        // Try native text extraction first
        var nativePages: [String?] = []
        var pagesWithText = 0
        var totalCharacters = 0

        for index in 0..<pdf.pageCount {
            guard let page = pdf.page(at: index) else {
                nativePages.append(nil)
                continue
            }

            if let text = page.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let cleaned = cleanText(text)
                nativePages.append(cleaned)
                pagesWithText += 1
                totalCharacters += cleaned.count
            } else {
                nativePages.append(nil)
            }
        }

        // If most pages have no text, attempt OCR
        let nativeTextRatio = Double(pagesWithText) / Double(pdf.pageCount)
        var ocrPages = 0
        var ocrConfidence: Double = 0

        if nativeTextRatio < 0.5 {
            // Attempt OCR on pages without text
            let ocrResult = try attemptOCR(on: pdf, skipPages: nativePages)
            ocrPages = ocrResult.processedPages
            ocrConfidence = ocrResult.averageConfidence

            // Merge OCR results
            for (index, ocrText) in ocrResult.extractedText.enumerated() {
                if nativePages[index] == nil {
                    nativePages[index] = ocrText
                    totalCharacters += ocrText.count
                }
            }
        }

        // Combine all text
        let allText = nativePages.compactMap { $0 }.joined(separator: "\n\n")
        guard !allText.isEmpty else {
            throw ExtractionError.imageOnly
        }

        // Calculate statistics
        let quality = determineQuality(
            nativeRatio: nativeTextRatio,
            ocrConfidence: ocrConfidence,
            ocrPages: ocrPages
        )
        let wordCount = allText.split(whereSeparator: { $0.isWhitespace }).count

        let statistics = ExtractionStatistics(
            totalPages: pdf.pageCount,
            pagesWithText: pagesWithText,
            ocrPagesProcessed: ocrPages,
            ocrConfidence: ocrConfidence,
            extractedCharacterCount: totalCharacters,
            estimatedWordCount: wordCount,
            extractionQuality: quality
        )

        return ExtractionResult(
            text: allText,
            metadata: metadata,
            statistics: statistics
        )
    }

    // MARK: - Private Helpers

    private static func extractMetadata(from pdf: PDFDocument) -> PDFMetadata {
        let dict = pdf.documentAttributes ?? [:]

        return PDFMetadata(
            title: dict[PDFDocumentAttribute.titleAttribute] as? String,
            author: dict[PDFDocumentAttribute.authorAttribute] as? String,
            subject: dict[PDFDocumentAttribute.subjectAttribute] as? String,
            creator: dict[PDFDocumentAttribute.creatorAttribute] as? String,
            creationDate: dict[PDFDocumentAttribute.creationDateAttribute] as? Date,
            pageCount: pdf.pageCount
        )
    }

    private static func cleanText(_ text: String) -> String {
        var result = text

        // Remove null characters
        result = result.replacingOccurrences(of: "\u{0000}", with: "")

        // Handle multi-column layout: collapse excessive whitespace
        result = result.replacingOccurrences(
            of: "[ \\t]{2,}",
            with: " ",
            options: .regularExpression
        )

        // Preserve paragraph breaks but normalize
        result = result.replacingOccurrences(
            of: "\\n{3,}",
            with: "\n\n",
            options: .regularExpression
        )

        // Remove trailing spaces on lines
        result = result.replacingOccurrences(
            of: "[ \\t]+\n",
            with: "\n",
            options: .regularExpression
        )

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func attemptOCR(on pdf: PDFDocument, skipPages: [String?]) throws -> OCRResult {
        var extractedText: [String] = Array(repeating: "", count: pdf.pageCount)
        var totalConfidence: Double = 0
        var processedCount = 0

        for index in 0..<pdf.pageCount {
            // Skip pages that already have native text
            if skipPages[index] != nil {
                continue
            }

            guard let page = pdf.page(at: index) else {
                continue
            }

            // Render page as thumbnail image for OCR
            if let thumbnail = page.thumbnail(of: CGSize(width: 1024, height: 1024)) {
                do {
                    let result = try performOCR(on: thumbnail)
                    extractedText[index] = result.text
                    totalConfidence += result.confidence
                    processedCount += 1
                } catch {
                    // Continue with next page on OCR failure
                    continue
                }
            }
        }

        let averageConfidence = processedCount > 0 ? totalConfidence / Double(processedCount) : 0

        return OCRResult(
            extractedText: extractedText,
            processedPages: processedCount,
            averageConfidence: averageConfidence
        )
    }

    private static func performOCR(on image: UIImage) throws -> OCRPageResult {
        guard let cgImage = image.cgImage else {
            throw ExtractionError.ocrFailed
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLanguages = ["en"] // Configurable for other languages
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        var recognizedText = ""
        var totalConfidence: Float = 0
        var recognitionCount = 0

        if let results = request.results as? [VNRecognizedTextObservation] {
            for observation in results {
                if let topCandidate = observation.topCandidates(1).first {
                    recognizedText += topCandidate.string + " "
                    totalConfidence += observation.confidence
                    recognitionCount += 1
                }
            }
        }

        let avgConfidence = recognitionCount > 0 ? Double(totalConfidence / Float(recognitionCount)) : 0
        return OCRPageResult(
            text: cleanText(recognizedText),
            confidence: avgConfidence
        )
    }

    private static func determineQuality(
        nativeRatio: Double,
        ocrConfidence: Double,
        ocrPages: Int
    ) -> ExtractionStatistics.Quality {
        if nativeRatio >= 0.9 {
            return .excellent
        } else if nativeRatio >= 0.7 {
            return .good
        } else if nativeRatio >= 0.5 {
            return ocrConfidence >= 0.85 ? .fair : .poor
        } else {
            return ocrConfidence >= 0.75 ? .poor : .veryPoor
        }
    }
}

// MARK: - Helper Structures

private struct OCRResult {
    let extractedText: [String]
    let processedPages: Int
    let averageConfidence: Double
}

private struct OCRPageResult {
    let text: String
    let confidence: Double
}
