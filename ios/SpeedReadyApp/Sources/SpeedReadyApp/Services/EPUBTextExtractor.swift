import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
import ZIPFoundation

struct EPUBTextExtractor {
    enum ExtractionError: LocalizedError, Equatable {
        case invalidFormat
        case corruptedArchive
        case missingContainer
        case malformedContainerXML
        case missingPackageDocument
        case malformedPackageDocument
        case noReadableContent

        var errorDescription: String? {
            switch self {
            case .invalidFormat:
                return "This file is not a valid EPUB archive."
            case .corruptedArchive:
                return "The EPUB archive is corrupted and could not be read."
            case .missingContainer:
                return "The EPUB container metadata is missing."
            case .malformedContainerXML:
                return "The EPUB container metadata is malformed."
            case .missingPackageDocument:
                return "The EPUB package document (OPF) could not be found."
            case .malformedPackageDocument:
                return "The EPUB package document is malformed."
            case .noReadableContent:
                return "No readable XHTML/HTML content was found in this EPUB."
            }
        }
    }

    struct SpineItem: Equatable {
        let id: String
        let href: String
        let mediaType: String
    }

    static func extract(from url: URL) throws -> String {
        let root = try unzipEPUB(at: url)
        defer { try? FileManager.default.removeItem(at: root) }

        let containerURL = root.appendingPathComponent("META-INF/container.xml")
        guard FileManager.default.fileExists(atPath: containerURL.path) else {
            throw ExtractionError.missingContainer
        }

        let opfRelativePath = try parseContainerXML(data: Data(contentsOf: containerURL))
        guard let opfURL = resolvePath(opfRelativePath, relativeTo: root, within: root),
              FileManager.default.fileExists(atPath: opfURL.path)
        else {
            throw ExtractionError.missingPackageDocument
        }

        let spineItems = try parseOPF(data: Data(contentsOf: opfURL))
        guard !spineItems.isEmpty else {
            throw ExtractionError.noReadableContent
        }

        let packageFolder = opfURL.deletingLastPathComponent()
        var chapters: [String] = []

        for item in spineItems {
            guard let itemURL = resolvePath(item.href, relativeTo: packageFolder, within: root),
                  FileManager.default.fileExists(atPath: itemURL.path)
            else {
                continue
            }
            let chapterText = try extractTextFromMarkupFile(at: itemURL)
            if !chapterText.isEmpty {
                chapters.append(chapterText)
            }
        }

        let joined = chapters.joined(separator: "\n\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !joined.isEmpty else {
            throw ExtractionError.noReadableContent
        }

        return joined
    }

    private static func unzipEPUB(at sourceURL: URL) throws -> URL {
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        guard let archive = Archive(url: sourceURL, accessMode: .read) else {
            throw ExtractionError.invalidFormat
        }

        do {
            for entry in archive {
                let entryURL = destination.appendingPathComponent(entry.path)
                let parent = entryURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
                _ = try archive.extract(entry, to: entryURL)
            }
            return destination
        } catch {
            throw ExtractionError.corruptedArchive
        }
    }

    static func parseContainerXML(data: Data) throws -> String {
        let parserDelegate = ContainerParser()
        let parser = XMLParser(data: data)
        parser.delegate = parserDelegate

        guard parser.parse() else {
            throw ExtractionError.malformedContainerXML
        }

        guard let path = parserDelegate.rootFilePath?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty else {
            throw ExtractionError.missingPackageDocument
        }

        return path
    }

    static func parseOPF(data: Data) throws -> [SpineItem] {
        let parserDelegate = OPFParser()
        let parser = XMLParser(data: data)
        parser.delegate = parserDelegate

        guard parser.parse() else {
            throw ExtractionError.malformedPackageDocument
        }

        return parserDelegate.spineItems
    }

    static func resolvePath(_ path: String, relativeTo baseURL: URL, within rootURL: URL) -> URL? {
        let decodedPath = path.removingPercentEncoding ?? path
        let resolved = URL(fileURLWithPath: decodedPath, relativeTo: baseURL).standardizedFileURL
        let root = rootURL.standardizedFileURL.path
        guard resolved.path.hasPrefix(root) else {
            return nil
        }
        return resolved
    }

    private static func extractTextFromMarkupFile(at url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .utf16)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
        return cleanMarkup(text)
    }

    static func cleanMarkup(_ markup: String) -> String {
        guard !markup.isEmpty else { return "" }

        var text = markup
        text = text.replacingOccurrences(of: "\r\n", with: "\n")
        text = text.replacingOccurrences(of: "\r", with: "\n")
        text = text.replacingOccurrences(of: "<(script|style)[^>]*>.*?</\\1>", with: "", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "</(p|div|section|article|li|h[1-6]|tr|blockquote)>", with: "\n\n", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        text = decodeHTMLEntities(in: text)
        text = text.replacingOccurrences(of: "[\\t ]+", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "[ ]*\\n[ ]*", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeHTMLEntities(in text: String) -> String {
        var decoded = text
        let entities: [String: String] = [
            "&nbsp;": " ",
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&mdash;": "—",
            "&ndash;": "–"
        ]

        for (entity, replacement) in entities {
            decoded = decoded.replacingOccurrences(of: entity, with: replacement)
        }

        let pattern = "&#(x?[0-9A-Fa-f]+);"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(decoded.startIndex..<decoded.endIndex, in: decoded)
        let matches = regex?.matches(in: decoded, options: [], range: range) ?? []
        for match in matches.reversed() {
            guard let matchRange = Range(match.range, in: decoded),
                  let rawRange = Range(match.range(at: 1), in: decoded) else { continue }
            let raw = String(decoded[rawRange])
            let scalarValue: UInt32?
            if raw.hasPrefix("x") || raw.hasPrefix("X") {
                scalarValue = UInt32(raw.dropFirst(), radix: 16)
            } else {
                scalarValue = UInt32(raw, radix: 10)
            }
            guard let value = scalarValue, let scalar = UnicodeScalar(value) else { continue }
            decoded.replaceSubrange(matchRange, with: String(Character(scalar)))
        }

        return decoded
    }
}

private final class ContainerParser: NSObject, XMLParserDelegate {
    var rootFilePath: String?

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        let name = elementName.lowercased()
        if name == "rootfile" {
            rootFilePath = attributeDict["full-path"]
        }
    }
}

private final class OPFParser: NSObject, XMLParserDelegate {
    private struct ManifestEntry {
        let href: String
        let mediaType: String
    }

    private var manifest: [String: ManifestEntry] = [:]
    private var spineIdRefs: [String] = []
    private var inSpine = false

    var spineItems: [EPUBTextExtractor.SpineItem] {
        spineIdRefs.compactMap { idRef in
            guard let entry = manifest[idRef] else { return nil }
            return EPUBTextExtractor.SpineItem(id: idRef, href: entry.href, mediaType: entry.mediaType)
        }
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        let name = elementName.lowercased()
        if name == "item" {
            guard let id = attributeDict["id"],
                  let href = attributeDict["href"],
                  let mediaType = attributeDict["media-type"]
            else {
                return
            }
            guard mediaType.contains("html") || mediaType.contains("xhtml") else {
                return
            }
            manifest[id] = ManifestEntry(href: href, mediaType: mediaType)
        } else if name == "spine" {
            inSpine = true
        } else if inSpine, name == "itemref", let idRef = attributeDict["idref"] {
            if attributeDict["linear"]?.lowercased() == "no" {
                return
            }
            spineIdRefs.append(idRef)
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName.lowercased() == "spine" {
            inSpine = false
        }
    }
}
