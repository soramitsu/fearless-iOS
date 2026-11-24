import SwiftUI

/// A shortened address with a copy button. The tooltip and VoiceOver carry
/// the whole address; VoiceOver reads it in groups of four characters.
public struct AddressChip: View {
    private let address: String
    private let head: Int
    private let tail: Int
    private let showsCopyButton: Bool

    public init(_ address: String, head: Int = 8, tail: Int = 6, showsCopyButton: Bool = true) {
        self.address = address
        self.head = head
        self.tail = tail
        self.showsCopyButton = showsCopyButton
    }

    public var body: some View {
        HStack(spacing: 4) {
            Text(AddressFormat.truncated(address, head: head, tail: tail))
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .help(address)
                .accessibilityLabel(Text(AddressFormat.grouped(address)).speechSpellsOutCharacters())
            if showsCopyButton {
                CopyButton(value: address, label: "Copy Address")
            }
        }
    }
}

/// A small borderless button that copies a value and confirms with a check mark.
public struct CopyButton: View {
    private let value: String
    private let label: String
    private let concealed: Bool
    private let clipboard: Clipboard?

    @State private var copied = false

    /// `clipboard` is for tests; nil copies to the shared clipboard.
    public init(value: String, label: String = "Copy", concealed: Bool = false, clipboard: Clipboard? = nil) {
        self.value = value
        self.label = label
        self.concealed = concealed
        self.clipboard = clipboard
    }

    public var body: some View {
        Button {
            let target = clipboard ?? .shared
            if concealed {
                target.copyConcealed(value)
            } else {
                target.copy(value)
            }
            copied = true
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                copied = false
            }
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .font(.caption)
                .foregroundStyle(copied ? BrandColor.final : Color.secondary)
                .frame(width: 16, height: 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(copied ? "Copied" : label)
        .accessibilityLabel(copied ? "Copied" : label)
    }
}

/// A whole address in monospaced, selectable text that wraps in groups of
/// four so it can be compared character by character.
public struct FullAddressText: View {
    private let address: String

    public init(_ address: String) {
        self.address = address
    }

    public var body: some View {
        Text(AddressFormat.grouped(address))
            .font(.system(.callout, design: .monospaced))
            .textSelection(.enabled)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(Text(AddressFormat.grouped(address)).speechSpellsOutCharacters())
    }
}
