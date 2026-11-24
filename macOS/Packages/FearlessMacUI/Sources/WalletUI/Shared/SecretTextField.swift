import AppKit
import DesignSystem
import SwiftUI

/// What a field that takes a wallet secret holds. Both kinds edit in an
/// AppKit field editor that belongs to the field alone, with every text
/// service off: spelling and grammar checking, autocorrection, text
/// replacement, completion, smart quotes, dashes and insert/delete, link and
/// data detection, inline prediction, math completion and Writing Tools.
/// The window's shared field editor, used by every other field, is never
/// touched.
enum SecretTextEntry: Sendable {
    /// One English recovery word. Only Roman input sources can be chosen
    /// while the field has focus, so no input method sees the words.
    case recoveryWord
    /// A derivation path, which may end in a `///password`. Every input
    /// source stays available, so a Unicode password can still be typed.
    /// With smart quotes off, BIP-32 apostrophes stay straight.
    case derivationPath

    /// Input sources the field allows while it has focus; nil allows all.
    var allowedInputSourceLocales: [String]? {
        switch self {
        case .recoveryWord: return [NSAllRomanInputSourcesLocaleIdentifier]
        case .derivationPath: return nil
        }
    }
}

/// Derivation paths that carry a password.
enum DerivationPath {
    /// True when `path` has a `///password` part, which the engine splits off
    /// at the first `///` for both Substrate and Ethereum paths.
    static func holdsPassword(_ path: String) -> Bool {
        path.contains("///")
    }
}

/// The field editor of one secret field. Text services stay off, Copy and
/// Cut go through `Clipboard.copyConcealed` (concealed, this Mac only,
/// cleared after 60 seconds), and the selection cannot be dragged out or
/// sent to Services. Paste works as usual.
final class SecretFieldEditor: NSTextView {
    private(set) var entry: SecretTextEntry = .recoveryWord
    /// Where Copy and Cut put the selection.
    var clipboard: Clipboard = .shared
    /// Asked before a typed space is inserted; true means it was handled.
    var onSpace: (() -> Bool)?
    /// Told when the editor gains (true) or loses (false) keyboard focus.
    var onFocusChange: ((Bool) -> Void)?

    /// Menu and key-binding actions that would turn a text service back on,
    /// check the text against a dictionary or hand it to Writing Tools.
    nonisolated static let refusedActions: Set<String> = [
        "toggleContinuousSpellChecking:",
        "toggleGrammarChecking:",
        "toggleAutomaticSpellingCorrection:",
        "toggleAutomaticTextReplacement:",
        "toggleAutomaticTextCompletion:",
        "toggleAutomaticQuoteSubstitution:",
        "toggleAutomaticDashSubstitution:",
        "toggleSmartInsertDelete:",
        "toggleAutomaticLinkDetection:",
        "toggleAutomaticDataDetection:",
        "checkSpelling:",
        "showGuessPanel:",
        "checkTextInSelection:",
        "checkTextInDocument:",
        "orderFrontSubstitutionsPanel:",
        "complete:",
        "showWritingTools:"
    ]

    convenience init(entry: SecretTextEntry) {
        self.init(frame: .zero)
        self.entry = entry
        isFieldEditor = true
        applySecretSettings()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    /// Turns every text service off. Applied again whenever editing starts,
    /// because the text field sets up its field editor at that point.
    func applySecretSettings() {
        isRichText = false
        importsGraphics = false
        enabledTextCheckingTypes = 0
        isContinuousSpellCheckingEnabled = false
        isGrammarCheckingEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticTextCompletionEnabled = false
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        smartInsertDeleteEnabled = false
        isAutomaticLinkDetectionEnabled = false
        isAutomaticDataDetectionEnabled = false
        inlinePredictionType = .no
        if #available(macOS 15.0, *) {
            mathExpressionCompletionType = .no
            writingToolsBehavior = .none
        }
        allowsCharacterPickerTouchBarItem = false
        usesFindBar = false
        usesFindPanel = false
        usesFontPanel = false
        usesRuler = false
        usesInspectorBar = false
        displaysLinkToolTips = false
        allowedInputSourceLocales = entry.allowedInputSourceLocales
    }

    // MARK: Focus

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became {
            applySecretSettings()
            onFocusChange?(true)
        }
        return became
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned { onFocusChange?(false) }
        return resigned
    }

    // MARK: Typing

    override func insertText(_ string: Any, replacementRange: NSRange) {
        let text = (string as? String) ?? (string as? NSAttributedString)?.string
        if text == " ", !hasMarkedText(), let onSpace, onSpace() { return }
        super.insertText(string, replacementRange: replacementRange)
    }

    /// No dictionary completion list (Escape and F5 would otherwise show one).
    override func complete(_ sender: Any?) {}

    override func completions(forPartialWordRange charRange: NSRange, indexOfSelectedItem index: UnsafeMutablePointer<Int>) -> [String]? {
        nil
    }

    // MARK: Pasteboard

    override func copy(_ sender: Any?) {
        let range = selectedRange()
        guard range.length > 0, NSMaxRange(range) <= (string as NSString).length else { return }
        clipboard.copyConcealed((string as NSString).substring(with: range))
    }

    override func cut(_ sender: Any?) {
        let range = selectedRange()
        guard range.length > 0 else { return }
        copy(sender)
        if shouldChangeText(in: range, replacementString: "") {
            replaceCharacters(in: range, with: "")
            didChangeText()
        }
    }

    override func dragSelection(with event: NSEvent, offset mouseOffset: NSSize, slideBack: Bool) -> Bool {
        false
    }

    override func validRequestor(forSendType sendType: NSPasteboard.PasteboardType?, returnType: NSPasteboard.PasteboardType?) -> Any? {
        nil
    }

    // MARK: Menus

    nonisolated override func responds(to aSelector: Selector!) -> Bool {
        if let aSelector, Self.refusedActions.contains(NSStringFromSelector(aSelector)) { return false }
        return super.responds(to: aSelector)
    }

    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if let action = item.action, Self.refusedActions.contains(NSStringFromSelector(action)) { return false }
        return super.validateUserInterfaceItem(item)
    }

    /// Cut, Copy, Paste and Select All only: no Spelling, Substitutions,
    /// Services, AutoFill or Writing Tools entries.
    override func menu(for event: NSEvent) -> NSMenu? {
        Self.editingMenu()
    }

    static func editingMenu() -> NSMenu {
        let menu = NSMenu(title: "Edit")
        menu.allowsContextMenuPlugIns = false
        if #available(macOS 15.2, *) { menu.automaticallyInsertsWritingToolsItems = false }
        menu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "")
        return menu
    }
}

/// A single-line AppKit text field that edits in its own `SecretFieldEditor`.
final class SecretEntryTextField: NSTextField {
    enum Style {
        /// No border or background; the surrounding view draws them.
        case plain
        /// The standard bezeled text field.
        case bezeled
    }

    override class var cellClass: AnyClass? {
        get { SecretEntryTextFieldCell.self }
        set {}
    }

    let entry: SecretTextEntry
    let secretEditor: SecretFieldEditor
    /// Told when the field is put in a window.
    var onWindowChange: (() -> Void)?

    init(entry: SecretTextEntry, style: Style = .bezeled) {
        self.entry = entry
        secretEditor = SecretFieldEditor(entry: entry)
        super.init(frame: .zero)
        isEditable = true
        isSelectable = true
        usesSingleLineMode = true
        lineBreakMode = .byClipping
        cell?.isScrollable = true
        cell?.wraps = false
        font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        isAutomaticTextCompletionEnabled = false
        allowsCharacterPickerTouchBarItem = false
        if #available(macOS 15.2, *) { allowsWritingTools = false }
        if #available(macOS 15.4, *) { allowsWritingToolsAffordance = false }
        contentType = nil
        (cell as? NSTextFieldCell)?.allowedInputSourceLocales = entry.allowedInputSourceLocales
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        apply(style)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func apply(_ style: Style) {
        switch style {
        case .plain:
            isBezeled = false
            isBordered = false
            drawsBackground = false
            focusRingType = .none
        case .bezeled:
            isBezeled = true
            bezelStyle = .squareBezel
            drawsBackground = true
            focusRingType = .default
        }
    }

    /// True while the field's own editor is editing it.
    var isEditing: Bool {
        currentEditor() === secretEditor
    }

    /// True from the moment the field starts leaving its window.
    private(set) var isLeavingWindow = false

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        isLeavingWindow = newWindow == nil
        super.viewWillMove(toWindow: newWindow)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            isLeavingWindow = false
            onWindowChange?()
        }
    }
}

/// Hands its text field the field's own editor instead of the window's
/// shared one. It keeps no state of its own, because AppKit copies cells.
final class SecretEntryTextFieldCell: NSTextFieldCell {
    override func fieldEditor(for controlView: NSView) -> NSTextView? {
        (controlView as? SecretEntryTextField)?.secretEditor ?? super.fieldEditor(for: controlView)
    }

    override func setUpFieldEditorAttributes(_ textObj: NSText) -> NSText {
        let editor = super.setUpFieldEditorAttributes(textObj)
        (editor as? SecretFieldEditor)?.applySecretSettings()
        return editor
    }
}

/// A SwiftUI field for a wallet secret, backed by `SecretEntryTextField`.
struct SecretTextField: NSViewRepresentable {
    /// Keys the owner may handle before the field does.
    enum Command: Sendable {
        case space, tab, backtab, submit
    }

    let entry: SecretTextEntry
    var placeholder = ""
    @Binding var text: String
    /// Fixed when the field is made.
    var style: SecretEntryTextField.Style = .bezeled
    var accessibilityLabel: String
    var accessibilityHelp: String?
    /// Whether the owner wants this field to have keyboard focus. The field
    /// takes focus when this becomes true and gives it up when it becomes
    /// false while the field is still editing.
    var isFocused = false
    var onFocusChange: ((Bool) -> Void)?
    /// Returns true when the owner handled the key.
    var onCommand: ((Command) -> Bool)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> SecretEntryTextField {
        let field = SecretEntryTextField(entry: entry, style: style)
        let coordinator = context.coordinator
        coordinator.field = field
        field.delegate = coordinator
        field.stringValue = text
        field.secretEditor.onSpace = { [weak coordinator] in coordinator?.perform(.space) ?? false }
        field.secretEditor.onFocusChange = { [weak coordinator] focused in coordinator?.focusChanged(focused) }
        field.onWindowChange = { [weak coordinator] in coordinator?.claimFocusIfWanted() }
        return field
    }

    func updateNSView(_ field: SecretEntryTextField, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        field.placeholderString = placeholder
        field.setAccessibilityLabel(accessibilityLabel)
        field.setAccessibilityHelp(accessibilityHelp)
        // Never replace text while an input method is composing it.
        if !(field.isEditing && field.secretEditor.hasMarkedText()), field.stringValue != text {
            field.stringValue = text
        }
        let wasFocused = coordinator.wantsFocus
        coordinator.wantsFocus = isFocused
        if isFocused, !wasFocused {
            if let window = field.window {
                if !field.isEditing { window.makeFirstResponder(field) }
            } else {
                coordinator.claimFocusIfWanted()
            }
        } else if !isFocused, wasFocused, field.isEditing {
            field.window?.makeFirstResponder(nil)
        }
    }

    static func dismantleNSView(_ field: SecretEntryTextField, coordinator: Coordinator) {
        coordinator.field = nil
        field.secretEditor.onSpace = nil
        field.secretEditor.onFocusChange = nil
        field.onWindowChange = nil
        field.delegate = nil
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: SecretEntryTextField, context: Context) -> CGSize? {
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? 160
        return CGSize(width: width, height: nsView.intrinsicContentSize.height)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SecretTextField
        weak var field: SecretEntryTextField?
        var wantsFocus = false
        private var claimScheduled = false

        init(_ parent: SecretTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? SecretEntryTextField, !field.secretEditor.hasMarkedText() else { return }
            push(field.stringValue)
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let field = notification.object as? SecretEntryTextField else { return }
            push(field.stringValue)
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.insertTab(_:)): return perform(.tab)
            case #selector(NSResponder.insertBacktab(_:)): return perform(.backtab)
            case #selector(NSResponder.insertNewline(_:)): return perform(.submit)
            default: return false
            }
        }

        func perform(_ command: Command) -> Bool {
            parent.onCommand?(command) ?? false
        }

        /// Reported at once, so the owner's idea of the focus never lags
        /// behind the keys that move it. Nothing is reported while the field
        /// leaves its window, which happens inside SwiftUI view updates.
        func focusChanged(_ focused: Bool) {
            guard let field, field.window != nil, !field.isLeavingWindow else { return }
            parent.onFocusChange?(focused)
        }

        /// Takes focus on the next turn of the run loop if the owner still
        /// wants it and the field is in a window and not editing yet.
        func claimFocusIfWanted() {
            guard wantsFocus, !claimScheduled else { return }
            claimScheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.claimScheduled = false
                guard self.wantsFocus, let field = self.field, let window = field.window, !field.isEditing else { return }
                window.makeFirstResponder(field)
            }
        }

        private func push(_ value: String) {
            if parent.text != value { parent.text = value }
        }
    }
}
