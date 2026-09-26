import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#else
typealias CGFloat = Double
#endif

#if canImport(PDFKit) && canImport(Vision)
import PDFKit
import Vision
#endif

struct PDFTextExtractor {
    enum ExtractionError: LocalizedError, Equatable {
        case unreadable
        case emptyDocument
        case noExtractableText
        case ocrFailed

        var errorDescription: String? {
            switch self {
            case .unreadable:
                return "The PDF could not be opened or read."
            case .emptyDocument:
                return "The PDF contains zero pages."
            case .noExtractableText:
                return "No readable text could be extracted from this PDF."
            case .ocrFailed:
                return "OCR processing failed for all pages."
            }
        }
    }

    struct Options: Equatable {
        var ocrLanguages: [String] = ["en-US"]
        var ocrRenderScale: CGFloat = 2.0
        var includePageMarkers: Bool = false
    }

    struct ExtractionResult {
        let text: String
        let metadata: PDFMetadata
        let statistics: ExtractionStatistics
    }

    struct PDFMetadata {
        let title: String
        let author: String?
        let subject: String?
        let creator: String?
        let creationDate: Date?
        let pageCount: Int
    }

    struct ExtractionStatistics {
        let totalPages: Int
        let pagesWithNativeText: Int
        let pagesWithOCRText: Int
        let skippedPages: Int
        let ocrConfidence: Double
        let extractedCharacterCount: Int
        let estimatedWordCount: Int
    }

    static func extract(from url: URL, options: Options = Options()) throws -> String {
#if canImport(PDFKit) && canImport(Vision)
        try extractWithMetadata(from: url, options: options).text
#else
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ExtractionError.unreadable
        }
        throw ExtractionError.noExtractableText
#endif
    }

    static func extractWithMetadata(from url: URL, options: Options = Options()) throws -> ExtractionResult {
#if canImport(PDFKit) && canImport(Vision)
        guard let pdf = PDFDocument(url: url) else {
            throw ExtractionError.unreadable
        }
        guard pdf.pageCount > 0 else {
            throw ExtractionError.emptyDocument
        }

        let metadata = extractMetadata(from: pdf, sourceURL: url)
        let nativeText = extractNativePageText(from: pdf)

        var pagesWithOCRText = 0
        var totalOCRConfidence: Double = 0
        var skippedPages = 0
        var combinedPages: [String] = []

        for pageIndex in 0..<pdf.pageCount {
            if let native = nativeText[pageIndex], !native.isEmpty {
                combinedPages.append(options.includePageMarkers ? "[Page \(pageIndex + 1)]\n\(native)" : native)
                continue
            }

            guard let page = pdf.page(at: pageIndex),
                  let image = renderedImage(for: page, scale: options.ocrRenderScale)
            else {
                skippedPages += 1
                continue
            }

            do {
                let ocr = try performOCR(on: image, languages: options.ocrLanguages)
                if !ocr.text.isEmpty {
                    let content = options.includePageMarkers ? "[Page \(pageIndex + 1)]\n\(ocr.text)" : ocr.text
                    combinedPages.append(content)
                    pagesWithOCRText += 1
                    totalOCRConfidence += ocr.confidence
                } else {
                    skippedPages += 1
                }
            } catch {
                skippedPages += 1
            }
        }

        let fullText = normalizeExtractedText(combinedPages.joined(separator: "\n\n")).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fullText.isEmpty else {
            throw pagesWithOCRText == 0 ? ExtractionError.noExtractableText : ExtractionError.ocrFailed
        }

        let avgOCRConfidence = pagesWithOCRText > 0 ? totalOCRConfidence / Double(pagesWithOCRText) : 0
        let stats = ExtractionStatistics(
            totalPages: pdf.pageCount,
            pagesWithNativeText: nativeText.compactMap { $0 }.count,
            pagesWithOCRText: pagesWithOCRText,
            skippedPages: skippedPages,
            ocrConfidence: avgOCRConfidence,
            extractedCharacterCount: fullText.count,
            estimatedWordCount: fullText.split(whereSeparator: \.isWhitespace).count
        )

        return ExtractionResult(text: fullText, metadata: metadata, statistics: stats)
#else
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ExtractionError.unreadable
        }
        throw ExtractionError.noExtractableText
#endif
    }

#if canImport(PDFKit) && canImport(Vision)
    private static func extractMetadata(from pdf: PDFDocument, sourceURL: URL) -> PDFMetadata {
        let attrs = pdf.documentAttributes ?? [:]
        let title = (attrs[PDFDocumentAttribute.titleAttribute] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackTitle = sourceURL.deletingPathExtension().lastPathComponent
        let normalizedTitle = (title?.isEmpty == false ? title : nil) ?? fallbackTitle

        return PDFMetadata(
            title: normalizedTitle,
            author: attrs[PDFDocumentAttribute.authorAttribute] as? String,
            subject: attrs[PDFDocumentAttribute.subjectAttribute] as? String,
            creator: attrs[PDFDocumentAttribute.creatorAttribute] as? String,
            creationDate: attrs[PDFDocumentAttribute.creationDateAttribute] as? Date,
            pageCount: pdf.pageCount
        )
    }

    private static func extractNativePageText(from pdf: PDFDocument) -> [String?] {
        (0..<pdf.pageCount).map { pageIndex in
            guard let page = pdf.page(at: pageIndex), let text = page.string else {
                return nil
            }
            let cleaned = normalizeExtractedText(text).trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.isEmpty ? nil : cleaned
        }
    }

    private static func renderedImage(for page: PDFPage, scale: CGFloat) -> CGImage? {
        let pageBounds = page.bounds(for: .mediaBox)
        guard pageBounds.width > 0, pageBounds.height > 0 else {
            return nil
        }

        let renderScale = max(1.0, min(scale, 3.0))
        let width = max(Int((pageBounds.width * renderScale).rounded(.up)), 1)
        let height = max(Int((pageBounds.height * renderScale).rounded(.up)), 1)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        let renderSize = CGSize(width: CGFloat(width), height: CGFloat(height))
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(origin: .zero, size: renderSize))

        context.saveGState()
        context.translateBy(x: 0, y: renderSize.height)
        context.scaleBy(x: renderScale, y: -renderScale)
        page.draw(with: .mediaBox, to: context)
        context.restoreGState()

        return context.makeImage()
    }

    private static func performOCR(on image: CGImage, languages: [String]) throws -> OCRPageResult {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = languages.isEmpty ? ["en-US"] : languages
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])

        var collectedText: [String] = []
        var totalConfidence: Float = 0
        var observationCount = 0

        let observations = request.results ?? []
        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            collectedText.append(candidate.string)
            totalConfidence += observation.confidence
            observationCount += 1
        }

        let confidence = observationCount > 0 ? Double(totalConfidence) / Double(observationCount) : 0
        return OCRPageResult(text: normalizeExtractedText(collectedText.joined(separator: "\n")), confidence: confidence)
    }
#endif

    static func normalizeExtractedText(_ text: String) -> String {
        guard !text.isEmpty else { return "" }

        var normalized = text
        normalized = normalized.replacingOccurrences(of: "\u{0000}", with: "")
        normalized = normalized.replacingOccurrences(of: "\r\n", with: "\n")
        normalized = normalized.replacingOccurrences(of: "\r", with: "\n")
        normalized = normalized.replacingOccurrences(of: "([A-Za-z])\\-\\n([A-Za-z])", with: "$1$2", options: .regularExpression)
        normalized = normalized.replacingOccurrences(of: "(?<!\\n)\\n(?!\\n)", with: " ", options: .regularExpression)
        normalized = normalized.replacingOccurrences(of: "[\\t ]+", with: " ", options: .regularExpression)
        normalized = normalized.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)

        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#if canImport(PDFKit) && canImport(Vision)
private struct OCRPageResult {
    let text: String
    let confidence: Double
}
#endif
