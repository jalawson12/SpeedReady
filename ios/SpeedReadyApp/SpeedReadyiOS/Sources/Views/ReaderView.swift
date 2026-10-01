    private var progressView: some View {
        VStack(alignment: .leading, spacing: 8) {
            ReaderScrubber(
                progress: Binding(
                    get: { displayedProgressFraction },
                    set: { fraction in
                        beginScrubbing()
                        scrubProgress = fraction
                        engine.seek(toWordIndex: scrubbedWordIndex(for: fraction))
                    }
                ),
                fillColor: palette.accent,
                onEditingChanged: { isEditing in
                    if isEditing {
                        beginScrubbing()
                    } else {
                        endScrubbing()
                    }
                }
            )
            .accessibilityLabel("Reading progress")
            .accessibilityValue("\(displayedWordIndex) of \(engine.state.totalWords) words")
            .accessibilityAdjustableAction { direction in
                let step = max(1, engine.state.totalWords / 100)
                let baseIndex = displayedWordIndex
                switch direction {
                case .increment:
                    engine.seek(toWordIndex: baseIndex + step)
                case .decrement:
                    engine.seek(toWordIndex: baseIndex - step)
                @unknown default:
                    break
                }
            }

            HStack {
                Text("\(displayedWordIndex)/\(engine.state.totalWords) words")
                    .font(.caption)
                    .foregroundStyle(palette.mutedText)
                    .accessibilityHidden(true)
                Spacer()
                Text(timeLeftText)
                    .font(.caption)
                    .foregroundStyle(palette.mutedText)
                    .accessibilityLabel(timeLeftAccessibilityText)
            }
            .paddingHorizontal(isLandscapeControlLayout ? 8 : 0)
        }
        .opacity(settings.focusMode ? 0.7 : 1)
    }
