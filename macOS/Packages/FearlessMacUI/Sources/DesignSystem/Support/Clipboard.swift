import AppKit

/// Pasteboard writes. Secrets are marked concealed (clipboard managers that
/// follow nspasteboard.org skip them) and removed again after a delay if the
/// pasteboard still holds them.
@MainActor
public final class Clipboard {
    public static let shared = Clipboard(pasteboard: .general)

    /// Marker type from nspasteboard.org.
    public static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    public static let defaultClearDelay: TimeInterval = 60

    private let pasteboard: NSPasteboard
    private var clearTask: Task<Void, Never>?

    public init(pasteboard: NSPasteboard) {
        self.pasteboard = pasteboard
    }

    /// Copies ordinary text (addresses, hashes).
    public func copy(_ string: String) {
        clearTask?.cancel()
        clearTask = nil
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    /// Copies a secret: marked concealed, cleared after `clearAfter` seconds
    /// unless something else has been copied meanwhile.
    public func copyConcealed(_ string: String, clearAfter: TimeInterval = Clipboard.defaultClearDelay) {
        clearTask?.cancel()
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
        pasteboard.setData(Data(), forType: Clipboard.concealedType)
        let expected = pasteboard.changeCount
        clearTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(clearAfter))
            guard !Task.isCancelled else { return }
            self?.clearIfUnchanged(since: expected)
        }
    }

    /// Clears the pasteboard only if nothing was copied after `changeCount`.
    public func clearIfUnchanged(since changeCount: Int) {
        guard pasteboard.changeCount == changeCount else { return }
        pasteboard.clearContents()
    }

    /// Plain text on the pasteboard, trimmed; nil when there is none.
    public func string() -> String? {
        guard let text = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }
        return text
    }

    public var changeCount: Int { pasteboard.changeCount }

    public var isConcealed: Bool {
        pasteboard.types?.contains(Clipboard.concealedType) ?? false
    }
}
