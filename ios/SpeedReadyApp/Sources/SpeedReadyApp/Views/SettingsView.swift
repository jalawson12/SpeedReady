import SwiftUI

struct SettingsView: View {
    @Binding var settings: ReaderSettings
    @Binding var isPresented: Bool
    let onSave: (ReaderSettings) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Reading pace") {
                    HStack {
                        Text("WPM")
                        Spacer()
                        Text("\(Int(settings.wpm))")
                    }
                    Slider(value: $settings.wpm, in: 100...1600, step: 25)
                }

                Section("Behavior") {
                    Toggle("Smart speed", isOn: $settings.smartSpeed)
                    Toggle("Context pause on close", isOn: $settings.contextPauseOnClose)
                    Toggle("Focus mode", isOn: $settings.focusMode)
                    Toggle("Dyslexia mode", isOn: $settings.dyslexiaMode)
                }

                Section("Display") {
                    Picker("Bionic focus", selection: $settings.bionicFocusPosition) {
                        ForEach(BionicFocusPosition.allCases, id: \ .self) { value in
                            Text(value.rawValue.capitalized).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)

                    Stepper("Font scale: \(String(format: "%.1f", settings.fontScale))x", value: $settings.fontScale, in: 0.8...1.6, step: 0.1)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(settings)
                        isPresented = false
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView(
        settings: .constant(ReaderSettings()),
        isPresented: .constant(true),
        onSave: { _ in }
    )
}
