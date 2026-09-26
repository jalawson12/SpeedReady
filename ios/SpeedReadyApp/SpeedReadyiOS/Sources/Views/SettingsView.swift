import SwiftUI
import UIKit

struct SettingsView: View {
    @Binding var settings: ReaderSettings
    let onSave: (ReaderSettings) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Theme") {
                    Picker("Appearance", selection: $settings.theme) {
                        Text("System").tag(AppTheme.system)
                        Text("Light").tag(AppTheme.light)
                        Text("Dark").tag(AppTheme.dark)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Reading pace") {
                    HStack {
                        Text("WPM")
                        Spacer()
                        Text("\(Int(settings.wpm))")
                    }
                    Slider(value: $settings.wpm, in: 100...1600, step: 25)

                    Toggle("Smart speed", isOn: $settings.smartSpeed)
                    Toggle("Speed ramp", isOn: $settings.speedRampEnabled)
                    if settings.speedRampEnabled {
                        HStack {
                            Text("Ramp target")
                            Spacer()
                            Text("\(Int(settings.speedRampTarget))")
                        }
                        Slider(value: $settings.speedRampTarget, in: 100...1600, step: 25)
                    }
                }

                Section("Typography") {
                    HStack {
                        Text("Font size")
                        Spacer()
                        Text("\(Int(settings.fontSize)) px")
                    }
                    Slider(value: $settings.fontSize, in: 16...256, step: 2)

                    HStack {
                        Text("Letter spacing")
                        Spacer()
                        Text(String(format: "%.2f em", settings.letterSpacing))
                    }
                    Slider(value: $settings.letterSpacing, in: 0...0.5, step: 0.01)

                    Picker("Font weight", selection: $settings.fontWeight) {
                        Text("Light").tag(300)
                        Text("Regular").tag(400)
                        Text("Medium").tag(500)
                        Text("Semi").tag(600)
                        Text("Bold").tag(700)
                        Text("Extra").tag(800)
                    }

                    Toggle("Dyslexia mode", isOn: $settings.dyslexiaMode)
                }

                Section("ORP & anchor") {
                    HStack {
                        Text("Pivot offset")
                        Spacer()
                        Text("\(Int(settings.pivotOffset))%")
                    }
                    Slider(value: $settings.pivotOffset, in: -30...30, step: 1)

                    Picker("Bionic anchor position", selection: $settings.bionicFocusPosition) {
                        ForEach(BionicFocusPosition.allCases, id: \.self) { value in
                            Text(value.rawValue.capitalized).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("ORP guide marks", isOn: $settings.showOrpGuides)
                    Toggle("Hide trailing punctuation", isOn: $settings.hidePunctuationInDisplay)
                }

                Section("Timing") {
                    HStack {
                        Text("Sentence pause")
                        Spacer()
                        Text(String(format: "%.1fx", settings.sentencePauseMultiplier))
                    }
                    Slider(value: $settings.sentencePauseMultiplier, in: 1...10, step: 0.5)

                    HStack {
                        Text("Paragraph pause")
                        Spacer()
                        Text(String(format: "%.1fx", settings.paragraphPauseMultiplier))
                    }
                    Slider(value: $settings.paragraphPauseMultiplier, in: 1...3, step: 0.1)

                    Toggle("Punctuation pauses", isOn: $settings.punctuationPause)
                    Toggle("Comma as sentence pause", isOn: $settings.commaAsPause)
                    Toggle("Context pause on close", isOn: $settings.contextPauseOnClose)
                }

                Section("Visual highlights") {
                    ColorPicker("Pivot highlight", selection: highlightColorBinding)
                    Toggle("Colorize quotes", isOn: $settings.colorizeQuotes)
                    if settings.colorizeQuotes {
                        ColorPicker("Quote color", selection: quoteColorBinding)
                    }
                    Toggle("Colorize parentheses", isOn: $settings.colorizeParens)
                    if settings.colorizeParens {
                        ColorPicker("Paren color", selection: parenColorBinding)
                    }
                }

                Section("Pause view mode") {
                    Picker("Pause view", selection: $settings.pauseView) {
                        ForEach(PauseViewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue.capitalized).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Reading features") {
                    Toggle("Focus mode", isOn: $settings.focusMode)
                    Toggle("Remove citations", isOn: $settings.removeCitations)
                    Toggle("Peripheral context", isOn: $settings.peripheralContext)
                    if settings.peripheralContext {
                        Stepper("Peripheral density: \(settings.peripheralContextCount)", value: $settings.peripheralContextCount, in: 1...3)
                    }
                }
            }
            .navigationTitle("Settings")
            .onChange(of: settings) { _, newSettings in
                onSave(newSettings)
            }
        }
    }

    private var highlightColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: settings.highlightColor) ?? .red },
            set: { settings.highlightColor = $0.toHex() ?? settings.highlightColor }
        )
    }

    private var quoteColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: settings.quoteHighlightColor) ?? .blue },
            set: { settings.quoteHighlightColor = $0.toHex() ?? settings.quoteHighlightColor }
        )
    }

    private var parenColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: settings.parenHighlightColor) ?? .indigo },
            set: { settings.parenHighlightColor = $0.toHex() ?? settings.parenHighlightColor }
        )
    }
}

private extension Color {
    init?(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard sanitized.count == 6 || sanitized.count == 8,
              let value = UInt64(sanitized, radix: 16)
        else { return nil }

        let red, green, blue, alpha: UInt64
        if sanitized.count == 8 {
            red = (value >> 24) & 0xFF
            green = (value >> 16) & 0xFF
            blue = (value >> 8) & 0xFF
            alpha = value & 0xFF
        } else {
            red = (value >> 16) & 0xFF
            green = (value >> 8) & 0xFF
            blue = value & 0xFF
            alpha = 0xFF
        }

        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: Double(alpha) / 255
        )
    }

    func toHex() -> String? {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        return String(
            format: "#%02X%02X%02X%02X",
            Int(red * 255),
            Int(green * 255),
            Int(blue * 255),
            Int(alpha * 255)
        )
    }
}

#Preview {
    SettingsView(
        settings: .constant(ReaderSettings()),
        onSave: { _ in }
    )
}
