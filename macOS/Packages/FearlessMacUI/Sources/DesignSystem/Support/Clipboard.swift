import AppKit

/// Pasteboard writes. Secrets are marked concealed (clipboard managers that
/// follow nspasteboard.org skip them), stay on this Mac (Universal Clipboard
/// would otherwise copy them to the user's iPhone and iPad, where malware on a
/// hacked device could read them), and are removed again after a delay, on lock
/// and on quit if the pasteboard still holds them.
@MainActor
public final class Clipboard {
    public static let shared: Clipboard = {
        let clipboard = Clipboard(pasteboard: .general)
        clipboard.clearConcealedOnQuit()
        return clipboard
    }()

    /// Marker type from nspasteboard.org.
    public static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    public static let defaultClearDelay: TimeInterval = 60

    private let pasteboard: NSPasteboard
    private var clearTask: Task<Void, Never>?
    /// The pasteboard's change count right after the last secret was written.
    private var concealedChangeCount: Int?

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
        _ = pasteboard.prepareForNewContents(with: .currentHostOnly)
        pasteboard.setString(string, forType: .string)
        pasteboard.setData(Data(), forType: Clipboard.concealedType)
        let expected = pasteboard.changeCount
        concealedChangeCount = expected
        clearTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(clearAfter))
            guard !Task.isCancelled else { return }
            self?.clearIfUnchanged(since: expected)
        }
    }

    /// Removes the last secret copied here if nothing replaced it (on lock and quit).
    public func clearConcealed() {
        clearTask?.cancel()
        clearTask = nil
        guard let expected = concealedChangeCount else { return }
        concealedChangeCount = nil
        clearIfUnchanged(since: expected)
    }

    private func clearConcealedOnQuit() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.clearConcealed() }
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
