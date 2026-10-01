import SwiftUI
import UIKit

/// Help text mirrored from the web app's settings panel (`src/components/settings-panel.ts`
/// `TOOLTIPS`), shown via an info-circle button next to the matching setting's label.
private enum SettingsHelpText {
    static let sentencePause =
        "Extra duration after periods, question marks, and exclamation points."
    static let paragraphPause = "Extra delay when a new paragraph begins."
    static let letterSpacing = "Adjust the horizontal space between characters."
    static let pivotOffset =
        "Nudges the focus point left or right if you prefer eye-fixation off-center."
    static let speedRamp =
        "Slowly accelerates the speed at the start of a session so your brain can adjust."
    static let smartSpeed =
        "Varies the duration of each word based on its character length (longer words dwell longer)."
    static let peripheralContext =
        "Shows a ghost of the previous and next words to help stay oriented."
    static let orpGuides =
        "Small markers above and below the focus point to help lock your gaze."
    static let colorizeQuotes =
        "Apply a distinct color to words inside double quotes (dialogue)."
    static let colorizeParens =
        "Apply a distinct color to words inside parentheses or square brackets (asides)."
    static let dyslexiaMode =
        "Uses OpenDyslexic, a font designed to improve readability for neurodivergent readers."
    static let contextPauseOnClose =
        "Slight extra pause after closing ) or ] to help process the phrase."
    static let commaAsPause =
        "Treat commas with the same weighted pause as full sentence ends."
    static let fontWeight =
        "Heavier weight makes text easier to track. Many dyslexic readers prefer medium-to-bold weights."
}

/// An info-circle button that reveals a setting's help text in a popover, matching the
/// inline tooltip affordance used alongside help-equipped settings in the web app.
private struct InfoTip: View {
    let text: String
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "info.circle")
                .imageScale(.small)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("More information")
        .accessibilityHint(text)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            Text(text)
                .font(.footnote)
                .padding()
                .frame(minWidth: 220, maxWidth: 320, alignment: .leading)
                .presentationCompactAdaptation(.popover)
        }
    }
}

/// A row label with an optional trailing info-circle, used for settings that have
/// matching help text in the web app.
private struct SettingLabel: View {
    let title: String
    var tip: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
            if let tip {
                InfoTip(text: tip)
            }
        }
    }
}

struct SettingsView: View {
    @Binding var settings: ReaderSettings
    @Environment(\.colorScheme) private var colorScheme
    @State private var pendingSaveTask: Task<Void, Never>?
    @State private var saveGeneration: UInt = 0
    @State private var hasPendingChanges = false
    let onSave: (ReaderSettings) -> Void

    private var palette: AppPalette {
        AppPalette(settings: settings, colorScheme: colorScheme)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                palette.background.ignoresSafeArea()

                Form {
                    Section("Theme") {
                        Picker("Appearance", selection: $settings.theme) {
                            Text("System").tag(AppTheme.system)
                            Text("Light").tag(AppTheme.light)
                            Text("Dark").tag(AppTheme.dark)
                        }
                        .pickerStyle(.segmented)
                    }
                    .listRowBackground(palette.surface)

                    Section("Reading pace") {
                        HStack {
                            Text("WPM")
                            Spacer()
                            Text("\(Int(settings.wpm))")
                        }
                        Slider(value: $settings.wpm, in: 100...1600, step: 25)

                        Toggle(isOn: $settings.smartSpeed) {
                            SettingLabel(title: "Smart speed", tip: SettingsHelpText.smartSpeed)
                        }
                        Toggle(isOn: $settings.speedRampEnabled) {
                            SettingLabel(title: "Speed ramp", tip: SettingsHelpText.speedRamp)
                        }
                        if settings.speedRampEnabled {
                            HStack {
                                Text("Ramp target")
                                Spacer()
                                Text("\(Int(settings.speedRampTarget))")
                            }
                            Slider(value: $settings.speedRampTarget, in: 100...1600, step: 25)
                        }
                    }
                    .listRowBackground(palette.surface)

                    Section("Typography") {
                        HStack {
                            Text("Font size")
                            Spacer()
                            Text("\(Int(settings.fontSize)) px")
                        }
                        Slider(value: $settings.fontSize, in: 16...256, step: 2)

                        HStack {
                            SettingLabel(title: "Letter spacing", tip: SettingsHelpText.letterSpacing)
                            Spacer()
                            Text(String(format: "%.2f em", settings.letterSpacing))
                        }
                        Slider(value: $settings.letterSpacing, in: 0...0.5, step: 0.01)

                        Picker(selection: $settings.fontWeight) {
                            Text("Light").tag(300)
                            Text("Regular").tag(400)
                            Text("Medium").tag(500)
                            Text("Semi").tag(600)
                            Text("Bold").tag(700)
                            Text("Extra").tag(800)
                        } label: {
                            SettingLabel(title: "Font weight", tip: SettingsHelpText.fontWeight)
                        }

                        Toggle(isOn: $settings.dyslexiaMode) {
                            SettingLabel(title: "Dyslexia mode", tip: SettingsHelpText.dyslexiaMode)
                        }
                    }
                    .listRowBackground(palette.surface)

                    Section("ORP & anchor") {
                        HStack {
                            SettingLabel(title: "Pivot offset", tip: SettingsHelpText.pivotOffset)
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

                        Toggle(isOn: $settings.showOrpGuides) {
                            SettingLabel(title: "ORP guide marks", tip: SettingsHelpText.orpGuides)
                        }
                        Toggle("Hide trailing punctuation", isOn: $settings.hidePunctuationInDisplay)
                    }
                    .listRowBackground(palette.surface)

                    Section("Timing") {
                        HStack {
                            SettingLabel(title: "Sentence pause", tip: SettingsHelpText.sentencePause)
                            Spacer()
                            Text(String(format: "%.1fx", settings.sentencePauseMultiplier))
                        }
                        Slider(value: $settings.sentencePauseMultiplier, in: 1...10, step: 0.5)

                        HStack {
                            SettingLabel(title: "Paragraph pause", tip: SettingsHelpText.paragraphPause)
                            Spacer()
                            Text(String(format: "%.1fx", settings.paragraphPauseMultiplier))
                        }
                        Slider(value: $settings.paragraphPauseMultiplier, in: 1...3, step: 0.1)

                        Toggle("Punctuation pauses", isOn: $settings.punctuationPause)
                        Toggle(isOn: $settings.commaAsPause) {
                            SettingLabel(title: "Comma as sentence pause", tip: SettingsHelpText.commaAsPause)
                        }
                        Toggle(isOn: $settings.contextPauseOnClose) {
                            SettingLabel(title: "Context pause on close", tip: SettingsHelpText.contextPauseOnClose)
                        }
                    }
                    .listRowBackground(palette.surface)

                    Section("Visual highlights") {
                        ColorPicker("Pivot highlight", selection: highlightColorBinding)
                        Toggle(isOn: $settings.colorizeQuotes) {
                            SettingLabel(title: "Colorize quotes", tip: SettingsHelpText.colorizeQuotes)
                        }
                        if settings.colorizeQuotes {
                            ColorPicker("Quote color", selection: quoteColorBinding)
                        }
                        Toggle(isOn: $settings.colorizeParens) {
                            SettingLabel(title: "Colorize parentheses", tip: SettingsHelpText.colorizeParens)
                        }
                        if settings.colorizeParens {
                            ColorPicker("Paren color", selection: parenColorBinding)
                        }
                    }
                    .listRowBackground(palette.surface)

                    Section("Pause view mode") {
                        Picker("Pause view", selection: $settings.pauseView) {
                            ForEach(PauseViewMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue.capitalized).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .listRowBackground(palette.surface)

                    Section("Reading features") {
                        Toggle("Focus mode", isOn: $settings.focusMode)
                        Toggle("Remove citations", isOn: $settings.removeCitations)
                        Toggle(isOn: $settings.peripheralContext) {
                            SettingLabel(title: "Peripheral context", tip: SettingsHelpText.peripheralContext)
                        }
                        if settings.peripheralContext {
                            Stepper("Peripheral density: \(settings.peripheralContextCount)", value: $settings.peripheralContextCount, in: 1...3)
                        }
                    }
                    .listRowBackground(palette.surface)
                }
                .navigationTitle("Settings")
                .scrollContentBackground(.hidden)
                .background(palette.background)
                .tint(palette.accent)
            }
            .onChange(of: settings) { _, newSettings in
                hasPendingChanges = true
                saveGeneration &+= 1
                let generation = saveGeneration
                pendingSaveTask?.cancel()
                pendingSaveTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(400))
                    guard !Task.isCancelled, generation == saveGeneration else { return }
                    onSave(newSettings)
                    hasPendingChanges = false
                }
            }
            .onDisappear {
                saveGeneration &+= 1
                pendingSaveTask?.cancel()
                pendingSaveTask = nil
                if hasPendingChanges {
                    onSave(settings)
                    hasPendingChanges = false
                }
            }
        }
    }

    private var highlightColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: settings.highlightColor) ?? Color(hex: "#605DF6") ?? .red },
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

extension Color {
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
