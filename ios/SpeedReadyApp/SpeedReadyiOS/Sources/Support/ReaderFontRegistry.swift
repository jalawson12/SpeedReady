import CoreText
import Foundation

enum ReaderFontRegistry {
    private static let bundledFonts = [
        "JetBrainsMono.ttf",
        "FiraMono-Regular.ttf",
        "SourceCodePro-Regular.ttf",
        "Inconsolata-Regular.ttf",
        "IBMPlexMono-Regular.ttf"
    ]

    private static var didRegister = false

    static func registerBundledFonts() {
        guard !didRegister else { return }
        defer { didRegister = true }

        for filename in bundledFonts {
            let resourceName = (filename as NSString).deletingPathExtension
            let resourceExtension = (filename as NSString).pathExtension
            guard let url = Bundle.main.url(forResource: resourceName, withExtension: resourceExtension, subdirectory: "Fonts") else {
                continue
            }

            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
