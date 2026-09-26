import Foundation
import ZipArchive

struct EPUBTextExtractor {
    enum ExtractionError: LocalizedError {
        case invalidFormat
        case noContent
        case corruptedArchive
        case xmlParseError

        var errorDescription: String? {
            switch self {
            case .invalidFormat:
                return "This does not appear to be a valid EPUB file."
            case .noContent:
                return "No readable content found in EPUB."
            case .corruptedArchive:
                return "The EPUB file is corrupted or cannot be extracted."
            case .xmlParseError:
                return "Failed to parse EPUB metadata or content."
            }
        }
    }

    static func extract(from url: URL) throws -> String {
        // Create temporary directory for extraction
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Extract ZIP contents
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ExtractionError.corruptedArchive
        }

        // Use Foundation's built-in ZIP support or manual ZIP extraction
        do {
            try extractZIP(from: url, to: tempDir)
        } catch {
            throw ExtractionError.corruptedArchive
        }

        // Find and parse container.xml to locate content.opf
        let containerPath = tempDir.appendingPathComponent("META-INF/container.xml")
        guard FileManager.default.fileExists(atPath: containerPath.path) else {
            throw ExtractionError.invalidFormat
        }

        let opfPath = try parseContainerXML(at: containerPath, basePath: tempDir)
        
        // Parse content.opf to find spine and manifest
        let contentItems = try parseOPF(at: opfPath)
        
        // Extract text from spine items in order
        var fullText = ""
        for item in contentItems {
            let itemPath = opfPath.deletingLastPathComponent().appendingPathComponent(item.href)
            if FileManager.default.fileExists(atPath: itemPath.path) {
                let itemText = try extractXHTML(from: itemPath)
                if !itemText.isEmpty {
                    fullText += itemText + "\n\n"
                }
            }
        }

        let cleaned = fullText
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleaned.isEmpty else {
            throw ExtractionError.noContent
        }
        
        return cleaned
    }

    // MARK: - Private Helpers

    private static func extractZIP(from url: URL, to destination: URL) throws {
        // Manual ZIP extraction using Foundation's Data and standard zip handling
        let data = try Data(contentsOf: url)
        
        // For a production app, use SSZipArchive or similar.
        // For now, we'll attempt basic ZIP extraction using shell or third-party.
        // This is a simplified version that assumes unzip availability.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", url.path, "-d", destination.path]
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw EPUBTextExtractor.ExtractionError.corruptedArchive
        }
    }

    private static func parseContainerXML(at url: URL, basePath: URL) throws -> URL {
        let data = try Data(contentsOf: url)
        let parser = ContainerXMLParser()
        
        guard XMLParser(data: data).delegate as? ContainerXMLParser != nil else {
            throw ExtractionError.xmlParseError
        }
        
        // For simplicity, assume standard EPUB structure
        // Typically content.opf is at {basePath}/OEBPS/content.opf
        let opfPath = basePath.appendingPathComponent("OEBPS/content.opf")
        if FileManager.default.fileExists(atPath: opfPath.path) {
            return opfPath
        }
        
        // Fallback: search for content.opf recursively
        if let found = try findFile(named: "content.opf", in: basePath) {
            return found
        }
        
        throw ExtractionError.invalidFormat
    }

    private static func parseOPF(at url: URL) throws -> [ContentItem] {
        let data = try Data(contentsOf: url)
        let parser = OPFParser()
        
        guard let xmlParser = XMLParser(data: data) else {
            throw ExtractionError.xmlParseError
        }
        
        xmlParser.delegate = parser
        guard xmlParser.parse() else {
            throw ExtractionError.xmlParseError
        }
        
        return parser.spine
    }

    private static func extractXHTML(from url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        guard let html = String(data: data, encoding: .utf8) else {
            return ""
        }
        
        // Strip HTML tags and decode entities
        return stripHTML(html)
    }

    private static func stripHTML(_ html: String) -> String {
        var result = html
        
        // Remove script and style tags
        result = result.replacingOccurrences(
            of: "<(script|style)[^>]*>.*?</\\1>",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        
        // Remove all HTML tags
        result = result.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
        
        // Decode common HTML entities
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&apos;", with: "'")
        
        // Normalize whitespace
        result = result.replacingOccurrences(
            of: "[ \\t]+",
            with: " ",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "\\n{3,}",
            with: "\n\n",
            options: .regularExpression
        )
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func findFile(named name: String, in directory: URL) throws -> URL? {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: nil) else {
            return nil
        }
        
        for case let url as URL in enumerator {
            if url.lastPathComponent == name {
                return url
            }
        }
        
        return nil
    }
}

// MARK: - XML Parsing Helpers

class ContainerXMLParser: NSObject, XMLParserDelegate {
    var opfPath: String?
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "rootfile" {
            opfPath = attributeDict["full-path"]
        }
    }
}

struct ContentItem {
    let id: String
    let href: String
    let mediaType: String
}

class OPFParser: NSObject, XMLParserDelegate {
    var manifest: [String: ContentItem] = [:]
    var spine: [ContentItem] = []
    var currentElementName: String = ""
    var inSpine = false
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElementName = elementName
        
        if elementName == "item" {
            let id = attributeDict["id"] ?? ""
            let href = attributeDict["href"] ?? ""
            let mediaType = attributeDict["media-type"] ?? ""
            let item = ContentItem(id: id, href: href, mediaType: mediaType)
            manifest[id] = item
        } else if elementName == "spine" {
            inSpine = true
        } else if elementName == "itemref", inSpine {
            if let idref = attributeDict["idref"], let item = manifest[idref] {
                spine.append(item)
            }
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "spine" {
            inSpine = false
        }
    }
}
