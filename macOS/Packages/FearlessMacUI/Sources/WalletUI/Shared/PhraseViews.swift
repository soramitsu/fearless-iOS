import AppKit
import DesignSystem
import SwiftUI

/// Keeps the window out of screenshots and screen sharing while a secret is
/// on screen.
struct CaptureProtection: NSViewRepresentable {
    let isActive: Bool

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.window?.sharingType = isActive ? .none : .readOnly
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: ()) {
        nsView.window?.sharingType = .readOnly
    }
}

/// The recovery phrase as a numbered grid. Hidden words are blurred and
/// kept from VoiceOver until the user reveals them.
struct PhraseGrid: View {
    let words: [String]
    let isRevealed: Bool

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 96), spacing: 8), count: words.count > 12 ? 4 : 3)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                HStack(spacing: 6) {
                    Text("\(index + 1)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 18, alignment: .trailing)
                    Text(isRevealed ? word : "••••••")
                        .font(.system(.body, design: .monospaced).weight(.medium))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(isRevealed ? "Word \(index + 1): \(word)" : "Word \(index + 1), hidden")
            }
        }
    }
}

/// The phrase with its Reveal and Copy controls and the warnings that go
/// with it. The phrase hides again when the window stops being the key
/// window. Saving to a file is deliberately not offered.
struct PhraseRevealPanel: View {
    let words: [String]
    @Binding var isRevealed: Bool

    @Environment(\.controlActiveState) private var controlActiveState
    @Environment(\.staticRendering) private var staticRendering
    @State private var isConfirmingCopy = false
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                PhraseGrid(words: words, isRevealed: isRevealed)
                    .blur(radius: isRevealed ? 0 : 5)
                    .accessibilityHidden(!isRevealed)
                if !isRevealed {
                    Button {
                        isRevealed = true
                    } label: {
                        Label("Reveal Phrase", systemImage: "eye")
                    }
                    .controlSize(.large)
                    .help("Show the words. Make sure nobody can see your screen.")
                }
            }
            HStack(spacing: 12) {
                if isRevealed {
                    Button {
                        isRevealed = false
                    } label: {
                        Label("Hide", systemImage: "eye.slash")
                    }
                }
                Button {
                    isConfirmingCopy = true
                } label: {
                    Label(copied ? "Copied" : "Copy…", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .help("Copy the phrase to the clipboard for 60 seconds")
                Spacer()
                Text("\(words.count) words")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .controlSize(.small)
        }
        .background(CaptureProtection(isActive: isRevealed && !staticRendering))
        .onChange(of: controlActiveState) { _, state in
            if state != .key, !staticRendering { isRevealed = false }
        }
        .confirmationDialog("Copy the recovery phrase?", isPresented: $isConfirmingCopy) {
            Button("Copy for 60 Seconds") {
                Clipboard.shared.copyConcealed(words.joined(separator: " "))
                copied = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    copied = false
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Other apps can read the clipboard. Fearless marks the phrase as a secret and clears it after 60 seconds, but writing the words on paper is safer.")
        }
    }
}

/// The backup check: pick the right word for a few positions.
struct PhraseVerifyPanel: View {
    let verification: PhraseVerification

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(verification.challenges) { challenge in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text("Word \(challenge.position + 1)")
                            .font(.headline)
                        if let correct = verification.isCorrect(challenge) {
                            Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(correct ? BrandColor.gain : BrandColor.failure)
                                .accessibilityLabel(correct ? "Correct" : "Not the right word")
                        }
                    }
                    HStack(spacing: 8) {
                        ForEach(challenge.options, id: \.self) { option in
                            let selected = challenge.selection == option
                            Button {
                                verification.select(option, for: challenge.position)
                            } label: {
                                Text(option)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(WordChoiceButtonStyle(
                                state: selected ? (verification.isCorrect(challenge) == false ? .wrong : .selected) : .normal
                            ))
                            .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Which word is number \(challenge.position + 1)?")
            }
            if verification.hasMistake {
                InlineMessage("One of the words is not right. Check your written copy and choose again.", kind: .error)
            }
        }
    }
}

/// A word to choose in the backup check. The chosen word is filled, so the
/// choice is visible without relying on colour alone (a wrong choice also
/// gets a mark beside the question).
struct WordChoiceButtonStyle: ButtonStyle {
    enum State {
        case normal, selected, wrong
    }

    let state: State

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 5)
            .padding(.horizontal, 6)
            .foregroundStyle(state == .normal ? AnyShapeStyle(.primary) : AnyShapeStyle(.white))
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(fill(pressed: configuration.isPressed))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.primary.opacity(state == .normal ? 0.18 : 0), lineWidth: 0.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func fill(pressed: Bool) -> Color {
        switch state {
        case .normal: return Color(nsColor: .controlColor).opacity(pressed ? 0.6 : 1)
        case .selected: return pressed ? BrandColor.accentFillPressed : BrandColor.accentFill
        case .wrong: return BrandColor.failure
        }
    }
}
