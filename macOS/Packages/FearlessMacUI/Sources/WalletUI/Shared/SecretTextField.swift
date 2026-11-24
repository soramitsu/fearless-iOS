import AppKit
import DesignSystem
import SwiftUI
import WalletCore

/// What a field that takes a wallet secret holds. Both kinds edit in an
/// AppKit field editor that belongs to the field alone, with every text
/// service off: spelling and grammar checking, autocorrection, text
/// replacement, completion, smart quotes, dashes and insert/delete, link and
/// data detection, inline prediction, math completion, Writing Tools, Share,
/// Look Up and the selection's Services button. The window's shared field
/// editor, used by every other field, is never touched.
enum SecretTextEntry: Sendable {
    /// One English recovery word. Only Roman-script input sources can be
    /// selected while the field has focus. An input method's own Roman mode
    /// still receives the keys and decides how it processes them.
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

    /// Single-line mode turns typed or pasted line and paragraph separators
    /// into spaces. That is harmless between recovery words, but a path goes
    /// to derivation exactly as entered, so path fields keep them.
    var usesSingleLineMode: Bool {
        self == .recoveryWord
    }
}

/// Derivation paths that carry a password or invisible line breaks.
enum DerivationPath {
    /// True when `path` has a `///password` part, which the engine splits off
    /// at the first `///` for both Substrate and Ethereum paths.
    static func holdsPassword(_ path: String) -> Bool {
        path.contains("///")
    }

    /// True when `path` contains a line or paragraph separator. No field
    /// shows one, but derivation uses it.
    static func hasLineBreak(_ path: String) -> Bool {
        path.unicodeScalars.contains { CharacterSet.newlines.contains($0) }
    }
}

/// Byte-for-byte text comparison. Swift's `==` treats canonically
/// equivalent strings (é and e + ◌́) as equal, but derivation encodes a path
/// as UTF-8, so the two give different accounts.
enum ExactText {
    static func same(_ lhs: String, _ rhs: String) -> Bool {
        lhs.utf8.elementsEqual(rhs.utf8)
    }
}

/// Derivation options compared byte for byte (see `ExactText`).
struct ExactDerivationOptions: Equatable {
    let options: DerivationOptions

    init(_ options: DerivationOptions) {
        self.options = options
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.options.substrateCryptoType == rhs.options.substrateCryptoType
            && ExactText.same(lhs.options.substrateDerivationPath, rhs.options.substrateDerivationPath)
            && ExactText.same(lhs.options.evmDerivationPath, rhs.options.evmDerivationPath)
    }
}

/// What a live address preview was derived from: the validated words and
/// the derivation options, both compared byte for byte.
struct ImportPreviewKey: Equatable {
    let words: [String]
    let options: ExactDerivationOptions

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.words.elementsEqual(rhs.words, by: ExactText.same) && lhs.options == rhs.options
    }
}

/// The field editor of one secret field. Text services stay off. Copy and
/// Cut go through `Clipboard.copyConcealed` (concealed, this Mac only,
/// cleared after 60 seconds), the "delete to" commands skip the kill ring,
/// and the selection cannot be dragged out, shared, looked up or sent to
/// Services. Paste and drops insert plain text exactly as it is.
final class SecretFieldEditor: NSTextView {
    private(set) var entry: SecretTextEntry = .recoveryWord
    /// Where Copy and Cut put the selection.
    var clipboard: Clipboard = .shared
    /// Asked before a typed space is inserted; true means it was handled.
    var onSpace: (() -> Bool)?
    /// Offered plain text from Paste or a drop first; true means handled.
    var onPaste: ((String) -> Bool)?
    /// Told when the editor gains (true) or loses (false) keyboard focus.
    var onFocusChange: ((Bool) -> Void)?
    /// Told when an input method's composition becomes ordinary text
    /// without any text change (`unmarkText`).
    var onCompositionCommit: (() -> Void)?
    /// Told when a composition starts or ends.
    var onCompositionChange: (() -> Void)?
    /// Told at once when a composition starts.
    var onCompositionStart: (() -> Void)?

    /// Menu and key-binding actions that would turn a text service back on,
    /// check the text against a dictionary, read it aloud, or hand it to
    /// Writing Tools, Share or Look Up. The editor takes each of them (so a
    /// nil-targeted action stops here instead of travelling further up the
    /// responder chain), does nothing, and disables their menu items.
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
        "ignoreSpelling:",
        "changeSpelling:",
        "checkTextInSelection:",
        "checkTextInDocument:",
        "orderFrontSubstitutionsPanel:",
        "orderFrontSharingServicePicker:",
        "quickLookPreviewItems:",
        "startSpeaking:",
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
        usesRolloverButtonForSelection = false
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

    // MARK: Typing and composition

    override func insertText(_ string: Any, replacementRange: NSRange) {
        let text = (string as? String) ?? (string as? NSAttributedString)?.string
        let hadMarkedText = hasMarkedText()
        if text == " ", !hadMarkedText, let onSpace, onSpace() { return }
        super.insertText(string, replacementRange: replacementRange)
        // An input method commits by inserting over its marked text.
        if hadMarkedText != hasMarkedText() { onCompositionChange?() }
    }

    /// True while a composition is being discarded; nothing is pushed then.
    private(set) var isCancellingComposition = false

    override func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        let hadMarkedText = hasMarkedText()
        super.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)
        if !hadMarkedText, hasMarkedText() { onCompositionStart?() }
        onCompositionChange?()
    }

    override func unmarkText() {
        let hadMarkedText = hasMarkedText()
        super.unmarkText()
        if hadMarkedText, !isCancellingComposition { onCompositionCommit?() }
        if hadMarkedText { onCompositionChange?() }
    }

    /// Discards text an input method is still composing, without handing
    /// it to the binding (before the owner replaces the field's text).
    func cancelComposition() {
        guard hasMarkedText() else { return }
        let marked = markedRange()
        isCancellingComposition = true
        defer { isCancellingComposition = false }
        unmarkText()
        inputContext?.discardMarkedText()
        guard marked.location != NSNotFound, NSMaxRange(marked) <= (string as NSString).length,
              shouldChangeText(in: marked, replacementString: "") else { return }
        replaceCharacters(in: marked, with: "")
        didChangeText()
    }

    /// Makes text an input method is still composing ordinary text, as typed.
    func commitComposition() {
        guard hasMarkedText() else { return }
        unmarkText()
        inputContext?.discardMarkedText()
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

    /// Paste and drops read plain text only and insert it exactly as it is.
    override func readSelection(from pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        guard let text = pboard.string(forType: .string) else { return false }
        if let onPaste, onPaste(text) { return true }
        let range = rangeForUserTextChange
        guard range.location != NSNotFound, shouldChangeText(in: range, replacementString: text) else { return false }
        replaceCharacters(in: range, with: text)
        setSelectedRange(NSRange(location: range.location + (text as NSString).length, length: 0))
        didChangeText()
        return true
    }

    override func dragSelection(with event: NSEvent, offset mouseOffset: NSSize, slideBack: Bool) -> Bool {
        false
    }

    override func validRequestor(forSendType sendType: NSPasteboard.PasteboardType?, returnType: NSPasteboard.PasteboardType?) -> Any? {
        nil
    }

    // MARK: Deletion without the kill ring

    // Control-K and the other "delete to" commands copy what they delete
    // into AppKit's kill ring, which Control-Y pastes in any other field.
    // Here they only delete.

    override func deleteToEndOfLine(_ sender: Any?) {
        deleteSelection(orFollowingBreak: true) { super.moveToEndOfLineAndModifySelection($0) }
    }

    override func deleteToEndOfParagraph(_ sender: Any?) {
        deleteSelection(orFollowingBreak: true) { super.moveToEndOfParagraphAndModifySelection($0) }
    }

    override func deleteToBeginningOfLine(_ sender: Any?) {
        deleteSelection { super.moveToBeginningOfLineAndModifySelection($0) }
    }

    override func deleteToBeginningOfParagraph(_ sender: Any?) {
        deleteSelection { super.moveToBeginningOfParagraphAndModifySelection($0) }
    }

    override func deleteToMark(_ sender: Any?) {
        deleteSelection { super.selectToMark($0) }
    }

    /// Edit ▸ Delete: removes the selection without adding it to the kill ring.
    override func delete(_ sender: Any?) {
        deleteSelection { _ in }
    }

    /// Deletes the selection, first extending an empty one. With
    /// `orFollowingBreak`, a caret right before a line or paragraph break
    /// deletes only that break (CR LF counts as one), as Control-K does
    /// elsewhere. `delete(_:)` would add the text to the kill
    /// ring, so the text is replaced instead.
    private func deleteSelection(orFollowingBreak: Bool = false, extending extend: (Any?) -> Void) {
        if selectedRange().length == 0 {
            if orFollowingBreak { selectFollowingLineBreak() }
            if selectedRange().length == 0 { extend(nil) }
        }
        let range = selectedRange()
        guard range.length > 0, shouldChangeText(in: range, replacementString: "") else { return }
        replaceCharacters(in: range, with: "")
        setSelectedRange(NSRange(location: range.location, length: 0))
        didChangeText()
    }

    private func selectFollowingLineBreak() {
        let text = string as NSString
        let location = selectedRange().location
        guard location < text.length else { return }
        if text.length - location >= 2, text.substring(with: NSRange(location: location, length: 2)) == "\r\n" {
            setSelectedRange(NSRange(location: location, length: 2))
            return
        }
        let next = text.rangeOfComposedCharacterSequence(at: location)
        if text.substring(with: next).unicodeScalars.allSatisfy({ CharacterSet.newlines.contains($0) }) {
            setSelectedRange(next)
        }
    }

    // MARK: Refused actions

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if let action = menuItem.action, Self.refusedActions.contains(NSStringFromSelector(action)) { return false }
        return super.validateMenuItem(menuItem)
    }

    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if let action = item.action, Self.refusedActions.contains(NSStringFromSelector(action)) { return false }
        return super.validateUserInterfaceItem(item)
    }

    override func toggleContinuousSpellChecking(_ sender: Any?) {}
    override func toggleGrammarChecking(_ sender: Any?) {}
    override func toggleAutomaticSpellingCorrection(_ sender: Any?) {}
    override func toggleAutomaticTextReplacement(_ sender: Any?) {}
    override func toggleAutomaticTextCompletion(_ sender: Any?) {}
    override func toggleAutomaticQuoteSubstitution(_ sender: Any?) {}
    override func toggleAutomaticDashSubstitution(_ sender: Any?) {}
    override func toggleSmartInsertDelete(_ sender: Any?) {}
    override func toggleAutomaticLinkDetection(_ sender: Any?) {}
    override func toggleAutomaticDataDetection(_ sender: Any?) {}
    override func checkSpelling(_ sender: Any?) {}
    override func showGuessPanel(_ sender: Any?) {}
    override func ignoreSpelling(_ sender: Any?) {}
    override func changeSpelling(_ sender: Any?) {}
    override func checkTextInSelection(_ sender: Any?) {}
    override func checkTextInDocument(_ sender: Any?) {}
    override func orderFrontSubstitutionsPanel(_ sender: Any?) {}
    override func orderFrontSharingServicePicker(_ sender: Any?) {}
    override func quickLookPreviewItems(_ sender: Any?) {}
    override func quickLook(with event: NSEvent) {}
    override func startSpeaking(_ sender: Any?) {}
    @available(macOS 15.2, *)
    override func showWritingTools(_ sender: Any?) {}

    // MARK: Menus

    /// Cut, Copy, Paste and Select All only: no Spelling, Substitutions,
    /// Services, Share, Look Up, AutoFill or Writing Tools entries.
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

/// A one-line AppKit text field that edits in its own `SecretFieldEditor`.
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
        usesSingleLineMode = entry.usesSingleLineMode
        maximumNumberOfLines = 1
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

    private func apply(_ style: Style) {
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

    /// The text as the user sees it, including edits not yet ended.
    var currentText: String {
        isEditing ? secretEditor.string : stringValue
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

/// A secret field's place on its screen.
enum SecretFieldID: Hashable, Sendable {
    case word(Int)
    case substratePath
    case evmPath

    var isWord: Bool {
        if case .word = self { return true }
        return false
    }
}

/// The secret fields of one screen. Its owner moves keyboard focus between
/// them inside the key event that asked for it, so the next key already
/// lands in the new field; shows fields' bound text at once after a change;
/// and commits or discards compositions before reading or replacing what
/// the fields hold. Fields join through the environment.
@MainActor
@Observable
final class SecretFieldGroup {
    private final class Member {
        weak var field: SecretEntryTextField?
        var showBindingText: () -> Void

        init(_ field: SecretEntryTextField, showBindingText: @escaping () -> Void) {
            self.field = field
            self.showBindingText = showBindingText
        }
    }

    @ObservationIgnored private var members: [SecretFieldID: Member] = [:]
    /// A focus move to a field not made yet (a growing grid), done when it joins.
    @ObservationIgnored private var pendingFocus: (id: SecretFieldID, caretAtEnd: Bool)?
    /// Fields whose editor holds text an input method is still composing.
    private(set) var composing: Set<SecretFieldID> = []
    /// Called at once, inside the key event, when a field starts composing.
    @ObservationIgnored var onCompositionStart: (() -> Void)?

    /// A field started composing.
    func compositionStarted() {
        onCompositionStart?()
    }

    var isComposing: Bool {
        !composing.isEmpty
    }

    func add(_ field: SecretEntryTextField, id: SecretFieldID, showBindingText: @escaping () -> Void) {
        if let member = members[id], member.field === field {
            member.showBindingText = showBindingText
        } else {
            members[id] = Member(field, showBindingText: showBindingText)
        }
        if let pending = pendingFocus, pending.id == id, field.window != nil {
            pendingFocus = nil
            move(to: id, caretAtEnd: pending.caretAtEnd)
        }
    }

    func remove(_ field: SecretEntryTextField) {
        members = members.filter { $0.value.field != nil && $0.value.field !== field }
        updateComposing()
    }

    func field(_ id: SecretFieldID) -> SecretEntryTextField? {
        members[id]?.field
    }

    private func fields(where include: (SecretFieldID) -> Bool) -> [SecretEntryTextField] {
        members.filter { include($0.key) }.compactMap(\.value.field)
    }

    /// A field was put in its window: a focus move that waited for it is
    /// done now, with its caret request.
    func attached(_ field: SecretEntryTextField) {
        guard let pending = pendingFocus, members[pending.id]?.field === field, field.window != nil else { return }
        pendingFocus = nil
        move(to: pending.id, caretAtEnd: pending.caretAtEnd)
    }

    /// Recomputes which fields are composing, after the current event.
    func compositionChanged() {
        DispatchQueue.main.async { [weak self] in self?.updateComposing() }
    }

    private func updateComposing() {
        let now = Set(members.filter { $0.value.field?.secretEditor.hasMarkedText() == true }.keys)
        if now != composing { composing = now }
    }

    /// Commits text an input method is still composing in the group's
    /// fields, so it reaches the bindings. Other windows are left alone.
    func finishComposition(where include: (SecretFieldID) -> Bool = { _ in true }) {
        fields(where: include).forEach { $0.secretEditor.commitComposition() }
        updateComposing()
    }

    /// Discards unfinished compositions in the fields whose text the owner
    /// is about to replace; other fields keep theirs.
    func cancelComposition(where include: (SecretFieldID) -> Bool) {
        fields(where: include).forEach { $0.secretEditor.cancelComposition() }
        updateComposing()
    }

    /// Shows the bound text of the given fields now, before the next key.
    func showBindingText(where include: (SecretFieldID) -> Bool) {
        members.filter { include($0.key) && $0.value.field != nil }.forEach { $0.value.showBindingText() }
    }

    /// Gives the field `id` keyboard focus now, committing compositions in
    /// the other fields first, or takes focus away from the group when `id`
    /// is nil. A field that is not made yet (a growing grid) is laid out at
    /// once; if it still does not exist, it takes focus when it joins.
    /// `caretAtEnd` puts the caret after the field's text instead of
    /// selecting it.
    func move(to id: SecretFieldID?, caretAtEnd: Bool = false) {
        finishComposition()
        guard let id else {
            pendingFocus = nil
            resign()
            return
        }
        if field(id) == nil {
            members.values.compactMap(\.field).first?.window?.contentView?.layoutSubtreeIfNeeded()
        }
        guard let field = field(id), let window = field.window else {
            pendingFocus = (id, caretAtEnd)
            resign()
            return
        }
        pendingFocus = nil
        if !field.isEditing { window.makeFirstResponder(field) }
        if caretAtEnd, field.isEditing {
            let editor = field.secretEditor
            editor.setSelectedRange(NSRange(location: (editor.string as NSString).length, length: 0))
        }
    }

    private func resign() {
        if let editing = members.values.compactMap(\.field).first(where: \.isEditing) {
            editing.window?.makeFirstResponder(nil)
        }
    }
}

extension EnvironmentValues {
    /// The group the secret fields below join; nil for none.
    @Entry var secretFieldGroup: SecretFieldGroup?
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
    /// Whether the owner wants this field to have keyboard focus. The field
    /// takes focus when this becomes true and gives it up when it becomes
    /// false while the field is still editing.
    var isFocused = false
    /// The field's place in the environment's `SecretFieldGroup`.
    var groupID: SecretFieldID?
    var onFocusChange: ((Bool) -> Void)?
    /// Returns true when the owner handled the key.
    var onCommand: ((Command) -> Bool)?
    /// Offered pasted or dropped plain text first; true when handled.
    var onPaste: ((String) -> Bool)?
    /// The bound text when the view was made. SwiftUI compares a binding by
    /// where it points, not by its value, so without this a change made
    /// elsewhere (Reset, Clear) would not reach `updateNSView`.
    private let textSnapshot: String

    init(
        entry: SecretTextEntry,
        placeholder: String = "",
        text: Binding<String>,
        style: SecretEntryTextField.Style = .bezeled,
        accessibilityLabel: String,
        isFocused: Bool = false,
        groupID: SecretFieldID? = nil,
        onFocusChange: ((Bool) -> Void)? = nil,
        onCommand: ((Command) -> Bool)? = nil,
        onPaste: ((String) -> Bool)? = nil
    ) {
        self.entry = entry
        self.placeholder = placeholder
        _text = text
        self.style = style
        self.accessibilityLabel = accessibilityLabel
        self.isFocused = isFocused
        self.groupID = groupID
        self.onFocusChange = onFocusChange
        self.onCommand = onCommand
        self.onPaste = onPaste
        textSnapshot = text.wrappedValue
    }

    /// Nesting depth of focus changes made while SwiftUI updates the view;
    /// focus reports are not sent then, because the owner asked for them.
    @MainActor private static var reconciling = 0

    @MainActor
    static func finishComposition(in window: NSWindow) {
        (window.firstResponder as? SecretFieldEditor)?.commitComposition()
    }

    @MainActor
    private static func isComposing(in window: NSWindow) -> Bool {
        (window.firstResponder as? NSTextView)?.hasMarkedText() ?? false
    }

    @MainActor
    private static func reconcile(_ body: () -> Void) {
        reconciling += 1
        defer { reconciling -= 1 }
        body()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> SecretEntryTextField {
        let field = SecretEntryTextField(entry: entry, style: style)
        let coordinator = context.coordinator
        coordinator.field = field
        field.delegate = coordinator
        field.stringValue = text
        coordinator.lastSynced = text
        let editor = field.secretEditor
        editor.onSpace = { [weak coordinator] in coordinator?.perform(.space) ?? false }
        editor.onPaste = { [weak coordinator] text in coordinator?.pasted(text) ?? false }
        editor.onFocusChange = { [weak coordinator] focused in coordinator?.focusChanged(focused) }
        editor.onCompositionCommit = { [weak coordinator] in coordinator?.pushFieldText() }
        editor.onCompositionChange = { [weak coordinator] in coordinator?.group?.compositionChanged() }
        editor.onCompositionStart = { [weak coordinator] in coordinator?.group?.compositionStarted() }
        field.onWindowChange = { [weak coordinator, weak field] in
            coordinator?.claimFocusIfWanted()
            if let field { coordinator?.group?.attached(field) }
        }
        return field
    }

    func updateNSView(_ field: SecretEntryTextField, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        let group = context.environment.secretFieldGroup
        if coordinator.group !== group {
            coordinator.group?.remove(field)
            coordinator.group = group
        }
        if let group, let groupID {
            group.add(field, id: groupID) { [weak coordinator] in
                guard let coordinator else { return }
                coordinator.show(coordinator.parent.text)
            }
        }
        field.placeholderString = placeholder
        field.setAccessibilityLabel(accessibilityLabel)
        let composing = field.isEditing && field.secretEditor.hasMarkedText()
        if composing {
            // The user's own composition is left alone, but a change made
            // elsewhere meanwhile (Reset, Clear, Paste) wins over it.
            if !ExactText.same(text, coordinator.lastSynced) { coordinator.replaceComposition(with: text) }
        } else if !ExactText.same(field.currentText, text) {
            coordinator.show(text)
        }
        let wasFocused = coordinator.wantsFocus
        coordinator.wantsFocus = isFocused
        if isFocused, !wasFocused, !field.isEditing {
            if let window = field.window, !Self.isComposing(in: window) {
                Self.reconcile { _ = window.makeFirstResponder(field) }
            } else {
                coordinator.claimFocusIfWanted()
            }
        } else if !isFocused, wasFocused, field.isEditing, !field.secretEditor.hasMarkedText() {
            Self.reconcile { _ = field.window?.makeFirstResponder(nil) }
        }
    }

    static func dismantleNSView(_ field: SecretEntryTextField, coordinator: Coordinator) {
        coordinator.group?.remove(field)
        coordinator.group = nil
        coordinator.field = nil
        let editor = field.secretEditor
        editor.onSpace = nil
        editor.onPaste = nil
        editor.onFocusChange = nil
        editor.onCompositionCommit = nil
        editor.onCompositionChange = nil
        editor.onCompositionStart = nil
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
        weak var group: SecretFieldGroup?
        var wantsFocus = false
        /// The field text the binding was last given or took. Ending an edit
        /// does not push it again, so a word replaced by an accepted
        /// suggestion is not overwritten by the stale prefix still shown.
        var lastSynced = ""
        private var claimScheduled = false
        /// Set while the field shows text given by the binding, so nothing
        /// is pushed back.
        private var isShowingBindingText = false

        init(_ parent: SecretTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            group?.compositionChanged()
            guard let field, !field.secretEditor.hasMarkedText() else { return }
            pushFieldText()
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let field, !ExactText.same(field.currentText, lastSynced) else { return }
            pushFieldText()
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.insertTab(_:)): return perform(.tab)
            case #selector(NSResponder.insertBacktab(_:)): return perform(.backtab)
            case #selector(NSResponder.insertNewline(_:)): return perform(.submit)
            default: return false
            }
        }

        /// A key the owner may handle. A composition still in progress is
        /// committed first, so the owner sees the whole word.
        func perform(_ command: Command) -> Bool {
            guard let onCommand = parent.onCommand else { return false }
            field?.secretEditor.commitComposition()
            return onCommand(command)
        }

        /// Pasted text the owner took is shown as the binding now has it
        /// before the next key arrives.
        func pasted(_ text: String) -> Bool {
            guard parent.onPaste?(text) == true else { return false }
            show(parent.text)
            return true
        }

        /// Shows `text` from the binding in the field. A field still being
        /// composed is left alone; a change made elsewhere reaches it in
        /// `updateNSView`, which drops the composition only then.
        func show(_ text: String) {
            guard let field, !(field.isEditing && field.secretEditor.hasMarkedText()) else { return }
            guard !ExactText.same(field.currentText, text) || !ExactText.same(lastSynced, text) else { return }
            isShowingBindingText = true
            defer { isShowingBindingText = false }
            if field.isEditing { field.secretEditor.string = text }
            field.stringValue = text
            lastSynced = text
        }

        /// Drops an unfinished composition in favour of `text` from the binding.
        func replaceComposition(with text: String) {
            guard let field else { return }
            isShowingBindingText = true
            defer { isShowingBindingText = false }
            let editor = field.secretEditor
            editor.unmarkText()
            editor.inputContext?.discardMarkedText()
            editor.string = text
            field.stringValue = text
            lastSynced = text
        }

        /// Hands the field's text to the binding, byte for byte.
        func pushFieldText() {
            guard !isShowingBindingText, let field, !field.secretEditor.isCancellingComposition else { return }
            let value = field.currentText
            lastSynced = value
            if !ExactText.same(parent.text, value) { parent.text = value }
        }

        /// Reported at once, so the owner's idea of the focus never lags
        /// behind the keys that move it. Not reported while the field leaves
        /// its window or while SwiftUI applies a focus change it asked for.
        func focusChanged(_ focused: Bool) {
            guard SecretTextField.reconciling == 0, let field, field.window != nil, !field.isLeavingWindow else { return }
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
                SecretTextField.finishComposition(in: window)
                window.makeFirstResponder(field)
            }
        }
    }
}
