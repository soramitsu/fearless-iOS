import AppKit
import DesignSystem
import Foundation
import Observation
import SwiftUI
import Testing
import WalletCore
@testable import WalletPreviewSupport
@testable import WalletUI

/// The text-service settings of one editor, for comparing before and after.
private struct EditorSettings: Equatable {
    let continuousSpellChecking: Bool
    let grammarChecking: Bool
    let spellingCorrection: Bool
    let textReplacement: Bool
    let textCompletion: Bool
    let quoteSubstitution: Bool
    let dashSubstitution: Bool
    let smartInsertDelete: Bool
    let inlinePrediction: NSTextInputTraitType
    let inputSources: [String]?

    @MainActor
    init(_ editor: NSTextView) {
        continuousSpellChecking = editor.isContinuousSpellCheckingEnabled
        grammarChecking = editor.isGrammarCheckingEnabled
        spellingCorrection = editor.isAutomaticSpellingCorrectionEnabled
        textReplacement = editor.isAutomaticTextReplacementEnabled
        textCompletion = editor.isAutomaticTextCompletionEnabled
        quoteSubstitution = editor.isAutomaticQuoteSubstitutionEnabled
        dashSubstitution = editor.isAutomaticDashSubstitutionEnabled
        smartInsertDelete = editor.smartInsertDeleteEnabled
        inlinePrediction = editor.inlinePredictionType
        inputSources = editor.allowedInputSourceLocales
    }
}

/// Derivation options SwiftUI observes, like `OnboardingModel.derivation`.
@MainActor
@Observable
private final class OptionsHolder {
    var options = DerivationOptions.standard
}

@MainActor
@Observable
private final class VisibilityHolder {
    var isVisible = false
}

/// Wallet services whose address preview for one Substrate path waits
/// until `release()`.
private final class GatedWallets: WalletServicing, @unchecked Sendable {
    private let base: any WalletServicing
    private let gatedPath: String
    private let lock = NSLock()
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var isOpen = false
    private var started = 0

    init(base: any WalletServicing, gatedPath: String) {
        self.base = base
        self.gatedPath = gatedPath
    }

    var startedCount: Int {
        lock.withLock { started }
    }

    func release() {
        let waiting: [CheckedContinuation<Void, Never>] = lock.withLock {
            isOpen = true
            defer { waiters = [] }
            return waiters
        }
        waiting.forEach { $0.resume() }
    }

    func previewAddresses(for source: WalletImportSource) async throws -> WalletAddressPreview {
        if case let .mnemonic(_, options) = source, options.substrateDerivationPath == gatedPath {
            await withCheckedContinuation { continuation in
                let resumeNow: Bool = lock.withLock {
                    started += 1
                    if isOpen { return true }
                    waiters.append(continuation)
                    return false
                }
                if resumeNow { continuation.resume() }
            }
        }
        return try await base.previewAddresses(for: source)
    }

    var mnemonicWordList: [String] { base.mnemonicWordList }
    func wallets() async throws -> [Wallet] { try await base.wallets() }
    func generateMnemonic(length: MnemonicLength) async throws -> [String] { try await base.generateMnemonic(length: length) }
    func validateMnemonic(_ words: [String]) async -> MnemonicValidation { await base.validateMnemonic(words) }
    func addWallet(name: String, source: WalletImportSource) async throws -> Wallet { try await base.addWallet(name: name, source: source) }
    func renameWallet(_ id: WalletID, to name: String) async throws { try await base.renameWallet(id, to: name) }
    func deleteWallet(_ id: WalletID) async throws { try await base.deleteWallet(id) }
    func markBackedUp(_ id: WalletID) async throws { try await base.markBackedUp(id) }
    func exportMnemonic(_ id: WalletID, approval: UserApproval) async throws -> MnemonicBackup {
        try await base.exportMnemonic(id, approval: approval)
    }
    func exportJSON(_ id: WalletID, ecosystem: Ecosystem, approval: UserApproval, exportPassword: String) async throws -> Data {
        try await base.exportJSON(id, ecosystem: ecosystem, approval: approval, exportPassword: exportPassword)
    }
    func address(of id: WalletID, on chainID: ChainID) async throws -> String { try await base.address(of: id, on: chainID) }
}

/// The derivation form under a parent that reads the options in its body,
/// as the import steps do, so a change re-renders the form.
private struct FormHost: View {
    @Bindable var holder: OptionsHolder

    var body: some View {
        DerivationOptionsForm(options: $holder.options, showsEVM: true)
            .onChange(of: ExactDerivationOptions(holder.options)) { _, _ in }
    }
}

/// A window that is never shown, for driving fields and hosted views.
@MainActor
private final class TestWindow {
    let window: NSWindow

    init(size: CGSize = CGSize(width: 720, height: 640)) {
        _ = NSApplication.shared
        window = NSWindow(
            contentRect: NSRect(origin: CGPoint(x: -20_000, y: -20_000), size: size),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
    }

    convenience init(_ views: NSView...) {
        self.init()
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        window.contentView = stack
    }

    convenience init(hosting view: some View) {
        self.init()
        window.contentView = NSHostingView(rootView: view)
    }

    func close() {
        window.makeFirstResponder(nil)
        window.contentView = nil
        window.close()
    }

    /// Lets SwiftUI update and queued main-thread work run.
    func pump() async {
        spin()
        try? await Task.sleep(for: .milliseconds(5))
    }

    private func spin() {
        window.contentView?.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
    }

    func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { return false }
            await pump()
        }
        return true
    }

    /// AppKit views SwiftUI adds for selectable text (`.textSelection(.enabled)`).
    var selectableTextViews: [NSView] {
        views(NSView.self).filter { String(describing: type(of: $0)).contains("TextInteraction") }
    }

    func views<T: NSView>(_ type: T.Type) -> [T] {
        guard let root = window.contentView else { return [] }
        return Self.descendants(of: root).compactMap { $0 as? T }
    }

    private static func descendants(of view: NSView) -> [NSView] {
        view.subviews.flatMap { [$0] + descendants(of: $0) }
    }
}

/// Types `text` one character at a time, as the keyboard would.
@MainActor
private func type(_ text: String, into editor: NSTextView) {
    for character in text {
        editor.insertText(String(character), replacementRange: editor.selectedRange())
    }
}

@MainActor
private func expectEveryTextServiceOff(_ editor: SecretFieldEditor, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(editor.isFieldEditor, sourceLocation: sourceLocation)
    #expect(!editor.isRichText, sourceLocation: sourceLocation)
    #expect(!editor.importsGraphics, sourceLocation: sourceLocation)
    #expect(editor.enabledTextCheckingTypes == 0, sourceLocation: sourceLocation)
    #expect(!editor.isContinuousSpellCheckingEnabled, "continuous spelling", sourceLocation: sourceLocation)
    #expect(!editor.isGrammarCheckingEnabled, "grammar", sourceLocation: sourceLocation)
    #expect(!editor.isAutomaticSpellingCorrectionEnabled, "automatic correction", sourceLocation: sourceLocation)
    #expect(!editor.isAutomaticTextReplacementEnabled, "text replacement", sourceLocation: sourceLocation)
    #expect(!editor.isAutomaticTextCompletionEnabled, "completion", sourceLocation: sourceLocation)
    #expect(!editor.isAutomaticQuoteSubstitutionEnabled, "smart quotes", sourceLocation: sourceLocation)
    #expect(!editor.isAutomaticDashSubstitutionEnabled, "smart dashes", sourceLocation: sourceLocation)
    #expect(!editor.smartInsertDeleteEnabled, "smart insert/delete", sourceLocation: sourceLocation)
    #expect(!editor.isAutomaticLinkDetectionEnabled, sourceLocation: sourceLocation)
    #expect(!editor.isAutomaticDataDetectionEnabled, sourceLocation: sourceLocation)
    #expect(editor.inlinePredictionType == .no, "inline prediction", sourceLocation: sourceLocation)
    if #available(macOS 15.0, *) {
        #expect(editor.mathExpressionCompletionType == .no, "math completion", sourceLocation: sourceLocation)
        #expect(editor.writingToolsBehavior == .none, "Writing Tools", sourceLocation: sourceLocation)
    }
    #expect(!editor.allowsCharacterPickerTouchBarItem, sourceLocation: sourceLocation)
    #expect(!editor.usesRolloverButtonForSelection, "the selection's Services button", sourceLocation: sourceLocation)
}

// Serialized: hosted views share NSApp's windows, and Continue commits
// compositions in all of them.
@MainActor
@Suite("Secret text fields", .serialized)
struct SecretTextFieldTests {
    // MARK: AppKit field and editor

    @Test func recoveryWordFieldEditsInItsOwnEditorWithServicesOffAndRomanInputOnly() throws {
        let field = SecretEntryTextField(entry: .recoveryWord, style: .plain)
        let host = TestWindow(field)
        defer { host.close() }

        #expect(host.window.makeFirstResponder(field))
        let editor = try #require(field.currentEditor() as? SecretFieldEditor)
        #expect(editor === field.secretEditor)
        #expect(host.window.firstResponder === editor)
        expectEveryTextServiceOff(editor)
        #expect(editor.allowedInputSourceLocales == [NSAllRomanInputSourcesLocaleIdentifier])
        #expect(editor.inputContext?.allowedInputSourceLocales == [NSAllRomanInputSourcesLocaleIdentifier], "the live input context is Roman-only")
        #expect((field.cell as? NSTextFieldCell)?.allowedInputSourceLocales == [NSAllRomanInputSourcesLocaleIdentifier])
        #expect(!field.isAutomaticTextCompletionEnabled)
        #expect(field.contentType == nil)
        if #available(macOS 15.2, *) {
            #expect(!field.allowsWritingTools)
        }
    }

    @Test func derivationPathFieldKeepsEveryInputSourceAndTheExactText() throws {
        let field = SecretEntryTextField(entry: .derivationPath)
        let host = TestWindow(field)
        defer { host.close() }

        #expect(host.window.makeFirstResponder(field))
        let editor = try #require(field.currentEditor() as? SecretFieldEditor)
        expectEveryTextServiceOff(editor)
        #expect(editor.allowedInputSourceLocales == nil, "a Unicode password must stay typeable")
        #expect(editor.inputContext != nil)
        #expect(editor.inputContext?.allowedInputSourceLocales == nil)
        #expect((field.cell as? NSTextFieldCell)?.allowedInputSourceLocales == nil)

        let path = "m/44'/60'/0'/0/0///パスワード \"pass\" -- ok"
        type(path, into: editor)
        #expect(field.stringValue == path, "apostrophes, quotes, dashes and Unicode reach derivation as typed")
    }

    @Test func secretFieldsLeaveTheWindowsSharedEditorAlone() throws {
        let secret = SecretEntryTextField(entry: .recoveryWord)
        let plain = NSTextField(string: "")
        let host = TestWindow(secret, plain)
        defer { host.close() }

        #expect(host.window.makeFirstResponder(plain))
        let shared = try #require(plain.currentEditor() as? NSTextView)
        let before = EditorSettings(shared)

        #expect(host.window.makeFirstResponder(secret))
        #expect(secret.currentEditor() !== shared)
        #expect(host.window.makeFirstResponder(plain))
        #expect(plain.currentEditor() === shared)
        #expect(!(shared is SecretFieldEditor))
        #expect(EditorSettings(shared) == before, "the shared editor keeps the settings it had")
        #expect(shared.allowedInputSourceLocales == nil)
    }

    @Test func eachSecretFieldHasItsOwnEditor() {
        let first = SecretEntryTextField(entry: .recoveryWord)
        let second = SecretEntryTextField(entry: .recoveryWord)
        #expect(first.secretEditor !== second.secretEditor)
    }

    @Test func copyAndCutAreConcealedAndPasteStillWorks() throws {
        let field = SecretEntryTextField(entry: .derivationPath)
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("fearless.tests.secret-field.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        field.secretEditor.clipboard = Clipboard(pasteboard: pasteboard)
        let host = TestWindow(field)
        defer { host.close() }
        #expect(host.window.makeFirstResponder(field))
        let editor = try #require(field.currentEditor() as? SecretFieldEditor)

        type("//hard///pässwörd", into: editor)
        editor.selectAll(nil)
        editor.copy(nil)
        #expect(pasteboard.string(forType: .string) == "//hard///pässwörd")
        #expect(pasteboard.types?.contains(Clipboard.concealedType) == true, "the copy is marked concealed")

        pasteboard.clearContents()
        editor.setSelectedRange(NSRange(location: 6, length: 11))
        editor.cut(nil)
        #expect(pasteboard.string(forType: .string) == "///pässwörd")
        #expect(pasteboard.types?.contains(Clipboard.concealedType) == true)
        #expect(field.stringValue == "//hard")

        // Paste reads the pasteboard as usual.
        #expect(editor.readSelection(from: pasteboard))
        #expect(field.stringValue == "//hard///pässwörd")
    }

    @Test func emptySelectionCopiesNothing() throws {
        let field = SecretEntryTextField(entry: .recoveryWord)
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("fearless.tests.secret-field.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.setString("unrelated", forType: .string)
        field.secretEditor.clipboard = Clipboard(pasteboard: pasteboard)
        let host = TestWindow(field)
        defer { host.close() }
        #expect(host.window.makeFirstResponder(field))
        let editor = try #require(field.currentEditor() as? SecretFieldEditor)
        type("abandon", into: editor)
        editor.copy(nil)
        editor.cut(nil)
        #expect(pasteboard.string(forType: .string) == "unrelated")
        #expect(field.stringValue == "abandon")
    }

    @Test func textServiceActionsServicesAndDragsAreRefused() {
        let editor = SecretFieldEditor(entry: .derivationPath)
        for name in SecretFieldEditor.refusedActions {
            let item = NSMenuItem(title: name, action: NSSelectorFromString(name), keyEquivalent: "")
            #expect(!editor.validateMenuItem(item), "\(name) is disabled in menus")
            #expect(!editor.validateUserInterfaceItem(item))
        }
        #expect(editor.responds(to: #selector(NSText.paste(_:))))
        #expect(editor.responds(to: #selector(NSText.copy(_:))))
        #expect(editor.validRequestor(forSendType: .string, returnType: nil) == nil, "the selection is never handed to Services")
        #expect(editor.validRequestor(forSendType: nil, returnType: .string) == nil)
        var index = 0
        #expect(editor.completions(forPartialWordRange: NSRange(location: 0, length: 0), indexOfSelectedItem: &index) == nil)

        let item = NSMenuItem(title: "Check Spelling While Typing", action: #selector(NSTextView.toggleContinuousSpellChecking(_:)), keyEquivalent: "")
        #expect(!editor.validateUserInterfaceItem(item))

        let menu = SecretFieldEditor.editingMenu()
        #expect(menu.items.compactMap(\.action) == [
            #selector(NSText.cut(_:)), #selector(NSText.copy(_:)), #selector(NSText.paste(_:)), #selector(NSText.selectAll(_:))
        ], "the context menu offers no Spelling, Substitutions, Services or Writing Tools")
        #expect(!menu.allowsContextMenuPlugIns)
    }

    @Test func aTypedSpaceIsOfferedToTheOwnerFirst() throws {
        let field = SecretEntryTextField(entry: .recoveryWord)
        let host = TestWindow(field)
        defer { host.close() }
        #expect(host.window.makeFirstResponder(field))
        let editor = try #require(field.currentEditor() as? SecretFieldEditor)
        var spaces = 0
        editor.onSpace = {
            spaces += 1
            return true
        }
        type("ab c", into: editor)
        #expect(spaces == 1)
        #expect(field.stringValue == "abc")

        editor.onSpace = { false }
        type(" ", into: editor)
        #expect(field.stringValue == "abc ")
    }

    @Test func passwordPathsAreDetectedAtTheEnginesSplit() {
        #expect(DerivationPath.holdsPassword("//polkadot///secret"))
        #expect(DerivationPath.holdsPassword("m/44'/60'/0'/0/0///秘密"))
        #expect(DerivationPath.holdsPassword("///"))
        #expect(!DerivationPath.holdsPassword("//polkadot//0/1"))
        #expect(!DerivationPath.holdsPassword(DerivationOptions.defaultEVMPath))
        #expect(!DerivationPath.holdsPassword(""))
    }

    // MARK: Recovery-word grid

    private func onboarding(_ path: OnboardingModel.Path) async -> OnboardingModel {
        let services = PreviewWalletServices.make(scenario: PreviewScenario.emptyWalletList.instant())
        let model = OnboardingModel(mode: .firstWallet, services: services) { _ in }
        await model.choose(path)
        return model
    }

    @Test func phraseGridUsesRecoveryWordFieldsAndAcceptsAWholePastedPhrase() async throws {
        let model = await onboarding(.importPhrase)
        let entry = model.phraseEntry
        let host = TestWindow(hosting: ImportPhraseStep(model: model, compact: false))
        defer { host.close() }

        #expect(await host.waitUntil { host.views(SecretEntryTextField.self).count == 12 })
        let fields = host.views(SecretEntryTextField.self)
        #expect(fields.allSatisfy { $0.entry == .recoveryWord }, "the collapsed Advanced section adds no path fields")
        #expect(fields.allSatisfy { $0.currentEditor() == nil || $0.currentEditor() is SecretFieldEditor })
        #expect(host.views(NSTextField.self).allSatisfy { $0 is SecretEntryTextField || !$0.isEditable }, "no other editor takes the words")

        #expect(await host.waitUntil { fields[0].isEditing }, "the first word has focus when the step opens")
        #expect(entry.focusedIndex == 0)

        let phrase = PreviewWalletServices.samplePhrase(.words12)
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("fearless.tests.phrase-grid.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.setString(phrase.joined(separator: " "), forType: .string)
        #expect(fields[0].secretEditor.readSelection(from: pasteboard), "Paste reads the clipboard")

        #expect(entry.words == phrase, "the pasted phrase fills every field")
        #expect(await host.waitUntil { fields[11].isEditing }, "focus moves to the last word")
        #expect(await host.waitUntil { fields.map(\.stringValue) == phrase })
        await entry.revalidate()
        #expect(entry.isValid)
    }

    @Test func phraseGridKeepsTheWordListSuggestionsAndKeys() async throws {
        let model = await onboarding(.importPhrase)
        let entry = model.phraseEntry
        let host = TestWindow(hosting: ImportPhraseStep(model: model, compact: false))
        defer { host.close() }
        #expect(await host.waitUntil { host.views(SecretEntryTextField.self).count == 12 })
        let fields = host.views(SecretEntryTextField.self)
        #expect(await host.waitUntil { fields[0].isEditing })

        // Typing a prefix offers list words; Tab takes the first and moves on.
        type("aba", into: fields[0].secretEditor)
        #expect(entry.words[0] == "aba")
        #expect(entry.suggestions(at: 0).first == "abandon")
        fields[0].secretEditor.doCommand(by: #selector(NSResponder.insertTab(_:)))
        #expect(entry.words[0] == "abandon")
        #expect(await host.waitUntil { fields[1].isEditing })
        #expect(entry.focusedIndex == 1, "the model follows the field that has focus")

        // Space accepts the first suggestion too.
        type("abil", into: fields[1].secretEditor)
        type(" ", into: fields[1].secretEditor)
        #expect(entry.words[1] == "ability")
        #expect(await host.waitUntil { fields[2].isEditing })

        // A complete word and Return move to the next field.
        type("able", into: fields[2].secretEditor)
        fields[2].secretEditor.doCommand(by: #selector(NSResponder.insertNewline(_:)))
        #expect(entry.words[2] == "able")
        #expect(await host.waitUntil { fields[3].isEditing })

        // Shift-Tab goes back; clicking another field moves the focus with it.
        fields[3].secretEditor.doCommand(by: #selector(NSResponder.insertBacktab(_:)))
        #expect(await host.waitUntil { fields[2].isEditing && entry.focusedIndex == 2 })
        #expect(host.window.makeFirstResponder(fields[7]))
        #expect(await host.waitUntil { entry.focusedIndex == 7 })
        #expect(!fields[2].isEditing)
    }

    // MARK: Derivation paths

    @Test func derivationFormPassesTheExactPathsToTheOptions() async throws {
        let options = Box(DerivationOptions.standard)
        let form = DerivationOptionsForm(
            options: Binding(get: { options.value }, set: { options.value = $0 }),
            showsEVM: true
        )
        let host = TestWindow(hosting: form)
        defer { host.close() }
        #expect(await host.waitUntil { host.views(SecretEntryTextField.self).count == 2 })
        let fields = host.views(SecretEntryTextField.self)
        #expect(fields.allSatisfy { $0.entry == .derivationPath })
        #expect(host.views(NSTextField.self).allSatisfy { $0 is SecretEntryTextField || !$0.isEditable })

        let substrate = try #require(fields.first { $0.stringValue.isEmpty })
        let evm = try #require(fields.first { $0.stringValue == DerivationOptions.defaultEVMPath })

        #expect(host.window.makeFirstResponder(substrate))
        type("//polkadot///pä", into: substrate.secretEditor)
        // An input method composing kana: nothing reaches the options until it commits.
        substrate.secretEditor.setMarkedText("ぱす", selectedRange: NSRange(location: 2, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        #expect(options.value.substrateDerivationPath == "//polkadot///pä")
        substrate.secretEditor.insertText("パス", replacementRange: NSRange(location: NSNotFound, length: 0))
        #expect(options.value.substrateDerivationPath == "//polkadot///päパス")

        #expect(host.window.makeFirstResponder(evm))
        evm.secretEditor.selectAll(nil)
        type("m/44'/60'/0'/0/1///密码 \"x\"", into: evm.secretEditor)
        #expect(options.value.evmDerivationPath == "m/44'/60'/0'/0/1///密码 \"x\"", "BIP-32 apostrophes stay straight")
        #expect(options.value.substrateDerivationPath == "//polkadot///päパス")
    }

    @Test func revealedPasswordPathsCannotBeSelectedAndCopyConcealed() {
        typealias View = DerivationDetailsView
        #expect(View.presentation(of: "//polkadot///secret", isRevealed: false) == .init(shown: "••••••", isSelectable: false, copiesConcealed: false))
        #expect(View.presentation(of: "//polkadot///secret", isRevealed: true) == .init(shown: "//polkadot///secret", isSelectable: false, copiesConcealed: true))
        #expect(View.presentation(of: "m/44'/60'/0'/0/0///秘密", isRevealed: true) == .init(shown: "m/44'/60'/0'/0/0///秘密", isSelectable: false, copiesConcealed: true))
        #expect(View.presentation(of: "//polkadot", isRevealed: true) == .init(shown: "//polkadot", isSelectable: true, copiesConcealed: false))
        #expect(View.presentation(of: DerivationOptions.defaultEVMPath, isRevealed: true).isSelectable)
    }

    // MARK: Raw seed

    @Test func selectableTextIsDetectable() async {
        // The read-only checks below look for the view SwiftUI adds for
        // selectable text; make sure it is still there to be found.
        let host = TestWindow(hosting: VStack {
            Text("0xabcdef").textSelection(.enabled)
            Text("0x012345").textSelection(.disabled)
        })
        defer { host.close() }
        #expect(await host.waitUntil { host.selectableTextViews.count == 1 })
    }

    @Test(arguments: [Ecosystem.substrate, Ecosystem.evm])
    func revealedSeedIsReadOnlyTextBesideTheSecureField(_ ecosystem: Ecosystem) async throws {
        let model = await onboarding(.importSeed)
        model.seedEcosystem = ecosystem
        let seed = "0x" + String(repeating: "ab", count: 32)
        model.seedHex = seed

        let hidden = TestWindow(hosting: ImportSeedStep(model: model, compact: false))
        defer { hidden.close() }
        let shown = TestWindow(hosting: ImportSeedStep(model: model, compact: false, isVisible: .constant(true)))
        defer { shown.close() }
        #expect(await shown.waitUntil { !shown.views(NSSecureTextField.self).isEmpty && !hidden.views(NSSecureTextField.self).isEmpty })
        await shown.pump()

        let secure = shown.views(NSSecureTextField.self)
        #expect(secure.count == 1)
        #expect(secure.first?.stringValue == seed, "the secure field stays the only editor while the seed is shown")
        let others = shown.views(NSTextField.self).filter { !($0 is NSSecureTextField) }
        #expect(!others.contains { $0.stringValue == seed }, "no other AppKit field holds the seed")
        #expect(others.allSatisfy { $0 is SecretEntryTextField || !$0.isEditable }, "showing the seed adds no editable field")
        #expect(shown.selectableTextViews.isEmpty, "the shown seed cannot be selected")
        #expect(shown.views(NSTextView.self).allSatisfy { $0.string != seed })

        let shownHeight = try #require(shown.window.contentView).fittingSize.height
        let hiddenHeight = try #require(hidden.window.contentView).fittingSize.height
        #expect(shownHeight > hiddenHeight, "the seed is on screen as text while shown")
    }

    @Test func revealedPasswordPathRowsCannotBeSelected() async throws {
        let withPassword = DerivationOptions(substrateDerivationPath: "//polkadot///secret", evmDerivationPath: "m/44'/60'/0'/0/0///秘密")
        let plain = DerivationOptions(substrateDerivationPath: "//polkadot")

        let secret = TestWindow(hosting: DerivationDetailsView(options: withPassword, isRevealed: true))
        defer { secret.close() }
        let ordinary = TestWindow(hosting: DerivationDetailsView(options: plain, isRevealed: true))
        defer { ordinary.close() }
        let hidden = TestWindow(hosting: DerivationDetailsView(options: withPassword, isRevealed: false))
        defer { hidden.close() }

        // Key type, Polkadot path and Ethereum path are all selectable when no password is in them.
        #expect(await ordinary.waitUntil { ordinary.selectableTextViews.count == 3 })
        await secret.pump()
        await hidden.pump()
        #expect(secret.selectableTextViews.count == 1, "only the key type stays selectable; neither password path is")
        #expect(hidden.selectableTextViews.isEmpty)
    }

    // MARK: Review round 1

    @Test func refusedActionsDoNothingEvenWhenCalledDirectly() {
        let editor = SecretFieldEditor(entry: .derivationPath)
        for name in SecretFieldEditor.refusedActions.sorted() {
            let selector = NSSelectorFromString(name)
            guard SecretFieldEditor.instancesRespond(to: selector) else { continue }
            _ = editor.perform(selector, with: nil)
            #expect(editor.tryToPerform(selector, with: nil), "\(name) stops at the editor, which does nothing")
        }
        expectEveryTextServiceOff(editor)
    }

    @Test func dragsOfTheSelectionAreRefused() throws {
        let field = SecretEntryTextField(entry: .derivationPath)
        let host = TestWindow(field)
        defer { host.close() }
        #expect(host.window.makeFirstResponder(field))
        type("//hard///secret", into: field.secretEditor)
        field.secretEditor.selectAll(nil)
        let event = try #require(NSEvent.mouseEvent(
            with: .leftMouseDragged, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: host.window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
        ))
        #expect(!field.secretEditor.dragSelection(with: event, offset: .zero, slideBack: true))
    }

    @Test func deleteToCommandsLeaveTheKillRingAlone() throws {
        let killed = NSTextView(frame: NSRect(x: 0, y: 0, width: 200, height: 20))
        let yanked = NSTextView(frame: NSRect(x: 0, y: 0, width: 200, height: 20))
        let field = SecretEntryTextField(entry: .derivationPath)
        let host = TestWindow(killed, yanked, field)
        defer { host.close() }

        killed.string = "ordinary"
        killed.setSelectedRange(NSRange(location: 0, length: 0))
        killed.deleteToEndOfParagraph(nil)
        yanked.yank(nil)
        #expect(yanked.string == "ordinary", "control: the kill ring works here")

        #expect(host.window.makeFirstResponder(field))
        let editor = field.secretEditor
        type("//hard///secret", into: editor)
        editor.setSelectedRange(NSRange(location: 0, length: 0))
        editor.doCommand(by: #selector(NSResponder.deleteToEndOfParagraph(_:)))
        #expect(field.currentText.isEmpty, "Control-K still deletes")
        type("//a///b", into: editor)
        editor.doCommand(by: #selector(NSResponder.deleteToBeginningOfLine(_:)))
        #expect(field.currentText.isEmpty)
        type("//c///d", into: editor)
        editor.setSelectedRange(NSRange(location: 3, length: 0))
        editor.doCommand(by: #selector(NSResponder.deleteToEndOfLine(_:)))
        #expect(field.currentText == "//c")
        editor.doCommand(by: #selector(NSResponder.deleteToBeginningOfParagraph(_:)))
        #expect(field.currentText.isEmpty)
        type("//e///f", into: editor)
        editor.setSelectedRange(NSRange(location: 3, length: 4))
        editor.delete(nil)
        #expect(field.currentText == "//e", "Edit ▸ Delete still deletes the selection")

        yanked.string = ""
        yanked.yank(nil)
        #expect(yanked.string == "ordinary", "Control-Y elsewhere never gets the secret: got \(yanked.string)")
    }

    @Test func wordFieldsUseSingleLineModeAndPathFieldsKeepSeparators() {
        #expect(SecretEntryTextField(entry: .recoveryWord).usesSingleLineMode)
        #expect(!SecretEntryTextField(entry: .derivationPath).usesSingleLineMode)
        #expect(SecretEntryTextField(entry: .derivationPath).maximumNumberOfLines == 1)
    }

    @Test func exactOptionsTellCanonicallyEquivalentPathsApart() {
        let composed = DerivationOptions(substrateDerivationPath: "//\u{E9}")
        let decomposed = DerivationOptions(substrateDerivationPath: "//e\u{301}")
        #expect(composed == decomposed, "control: Swift calls them equal")
        #expect(ExactDerivationOptions(composed) != ExactDerivationOptions(decomposed))
        #expect(ExactDerivationOptions(composed) == ExactDerivationOptions(DerivationOptions(substrateDerivationPath: "//\u{E9}")))
        #expect(ExactDerivationOptions(DerivationOptions(evmDerivationPath: "m/44'/60'/0'/0/0///e\u{301}"))
            != ExactDerivationOptions(DerivationOptions(evmDerivationPath: "m/44'/60'/0'/0/0///\u{E9}")))
        #expect(DerivationPath.hasLineBreak("//a///p\u{2028}w"))
        #expect(DerivationPath.hasLineBreak("//a\n"))
        #expect(!DerivationPath.hasLineBreak("//a///p w"))
    }

    private func hostedForm(_ holder: OptionsHolder) async -> (TestWindow, substrate: SecretEntryTextField, evm: SecretEntryTextField)? {
        let host = TestWindow(hosting: FormHost(holder: holder))
        guard await host.waitUntil({ host.views(SecretEntryTextField.self).count == 2 }) else { return nil }
        let fields = host.views(SecretEntryTextField.self)
        guard let substrate = fields.first(where: { $0.stringValue.isEmpty }),
              let evm = fields.first(where: { $0.stringValue == DerivationOptions.defaultEVMPath }) else { return nil }
        return (host, substrate, evm)
    }

    @Test func pathsKeepCanonicallyEquivalentBytes() async throws {
        let holder = OptionsHolder()
        let (host, substrate, _) = try #require(await hostedForm(holder))
        defer { host.close() }
        #expect(host.window.makeFirstResponder(substrate))
        let editor = substrate.secretEditor

        type("//\u{E9}", into: editor)
        #expect(Array(holder.options.substrateDerivationPath.utf8) == [47, 47, 0xC3, 0xA9])
        editor.selectAll(nil)
        editor.insertText("//e\u{301}", replacementRange: editor.selectedRange())
        #expect(Array(holder.options.substrateDerivationPath.utf8) == [47, 47, 0x65, 0xCC, 0x81], "the new bytes reach the options")
        await host.pump()
        #expect(Array(substrate.currentText.utf8) == [47, 47, 0x65, 0xCC, 0x81], "a refresh keeps them")
    }

    @Test func pastedPathKeepsLineSeparatorsExactly() async throws {
        let holder = OptionsHolder()
        let (host, substrate, evm) = try #require(await hostedForm(holder))
        defer { host.close() }
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("fearless.tests.path-paste.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }

        #expect(host.window.makeFirstResponder(substrate))
        pasteboard.clearContents()
        pasteboard.setString("//a///p\u{2028}w\n", forType: .string)
        #expect(substrate.secretEditor.readSelection(from: pasteboard))
        #expect(Array(holder.options.substrateDerivationPath.unicodeScalars) == Array("//a///p\u{2028}w\n".unicodeScalars))

        #expect(host.window.makeFirstResponder(evm))
        evm.secretEditor.selectAll(nil)
        pasteboard.clearContents()
        pasteboard.setString("m/44'/60'/0'/0/0///\u{2029}x", forType: .string)
        #expect(evm.secretEditor.readSelection(from: pasteboard))
        #expect(Array(holder.options.evmDerivationPath.unicodeScalars) == Array("m/44'/60'/0'/0/0///\u{2029}x".unicodeScalars))
    }

    @Test func aCommittedCompositionReachesTheOptionsWithoutAnotherKey() async throws {
        let holder = OptionsHolder()
        let (host, substrate, _) = try #require(await hostedForm(holder))
        defer { host.close() }
        #expect(host.window.makeFirstResponder(substrate))
        let editor = substrate.secretEditor
        let noReplacement = NSRange(location: NSNotFound, length: 0)

        type("//a///", into: editor)
        editor.setMarkedText("ぱす", selectedRange: NSRange(location: 2, length: 0), replacementRange: noReplacement)
        #expect(holder.options.substrateDerivationPath == "//a///", "nothing is pushed while composing")
        holder.options.substrateCryptoType = .ed25519
        await host.pump()
        #expect(editor.hasMarkedText() && editor.string == "//a///ぱす", "a refresh leaves the composition alone")

        editor.unmarkText()
        #expect(holder.options.substrateDerivationPath == "//a///ぱす", "committing without a text change still updates the options")
        await host.pump()
        #expect(substrate.currentText == "//a///ぱす", "a refresh does not restore the old path")

        // Continue finishes a composition still in progress before it reads the options.
        editor.setMarkedText("か", selectedRange: NSRange(location: 1, length: 0), replacementRange: noReplacement)
        SecretTextField.finishComposition(in: host.window)   // what the field group's Continue does for its own fields
        #expect(!editor.hasMarkedText())
        #expect(holder.options.substrateDerivationPath == "//a///ぱすか")
    }

    // MARK: Review round 1, recovery-word grid

    private func hostedGrid() async -> (OnboardingModel, TestWindow, [SecretEntryTextField])? {
        let model = await onboarding(.importPhrase)
        let host = TestWindow(hosting: ImportPhraseStep(model: model, compact: false))
        guard await host.waitUntil({ host.views(SecretEntryTextField.self).count == 12 }) else { return nil }
        let fields = host.views(SecretEntryTextField.self)
        guard await host.waitUntil({ fields[0].isEditing }) else { return nil }
        return (model, host, fields)
    }

    @Test func theNextKeyAfterTabOrSpaceLandsInTheNextWord() async throws {
        let (model, host, fields) = try #require(await hostedGrid())
        defer { host.close() }
        let entry = model.phraseEntry

        type("aba", into: fields[0].secretEditor)
        fields[0].secretEditor.doCommand(by: #selector(NSResponder.insertTab(_:)))
        let second = try #require(host.window.firstResponder as? SecretFieldEditor)
        #expect(second === fields[1].secretEditor, "focus moved before the key returned")
        type("abil", into: second)
        type(" ", into: second)
        let third = try #require(host.window.firstResponder as? SecretFieldEditor)
        #expect(third === fields[2].secretEditor)
        type("l", into: third)

        #expect(entry.words[0] == "abandon")
        #expect(entry.words[1] == "ability")
        #expect(entry.words[2] == "l")
        await host.pump()
        await host.pump()
        #expect(entry.words[0] == "abandon" && entry.words[1] == "ability", "no stale prefix is pushed back")
        #expect(fields[0].stringValue == "abandon")
        #expect(entry.focusedIndex == 2)
    }

    @Test func gridBoundariesKeepTheirKeys() async throws {
        let (model, host, fields) = try #require(await hostedGrid())
        defer { host.close() }
        let entry = model.phraseEntry

        // Shift-Tab in the first word and Tab in the last are left to AppKit,
        // which moves to the previous or next key view instead of trapping focus.
        fields[0].secretEditor.doCommand(by: #selector(NSResponder.insertBacktab(_:)))
        #expect(entry.words.allSatisfy { $0.isEmpty })
        #expect(!fields[0].isEditing, "Shift-Tab leaves the first word")

        let phrase = PreviewWalletServices.samplePhrase(.words12)
        entry.setText(phrase.joined(separator: " "), at: 0)
        #expect(await host.waitUntil { fields[11].isEditing })
        await entry.revalidate()
        #expect(model.canContinueImport)
        fields[11].secretEditor.doCommand(by: #selector(NSResponder.insertTab(_:)))
        #expect(entry.words == phrase)
        #expect(!fields[11].isEditing, "Tab leaves the last word")

        // Return in the last word of a valid phrase continues.
        #expect(host.window.makeFirstResponder(fields[11]))
        fields[11].secretEditor.doCommand(by: #selector(NSResponder.insertNewline(_:)))
        #expect(await host.waitUntil { model.step == .confirm })
    }

    @Test func aPhrasePastedIntoAWordReplacesItAndFillsTheGrid() async throws {
        let (model, host, fields) = try #require(await hostedGrid())
        defer { host.close() }
        let entry = model.phraseEntry
        #expect(host.window.makeFirstResponder(fields[3]))
        type("aban", into: fields[3].secretEditor)
        #expect(entry.words[3] == "aban")

        let phrase = PreviewWalletServices.samplePhrase(.words12)
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("fearless.tests.phrase-lines.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.setString(phrase.joined(separator: "\n") + "\n", forType: .string)
        #expect(fields[3].secretEditor.readSelection(from: pasteboard))
        #expect(entry.words == phrase, "one word per line, pasted at the caret of a typed word")
        #expect(await host.waitUntil { fields.map(\.stringValue) == phrase })

        // A single word still pastes at the caret.
        #expect(host.window.makeFirstResponder(fields[5]))
        fields[5].secretEditor.selectAll(nil)
        pasteboard.clearContents()
        pasteboard.setString("abandon", forType: .string)
        #expect(fields[5].secretEditor.readSelection(from: pasteboard))
        #expect(entry.words[5] == "abandon")
    }

    @Test func anUnknownWordIsInItsAccessibilityLabel() async throws {
        let (model, host, fields) = try #require(await hostedGrid())
        defer { host.close() }
        model.phraseEntry.setText("fearles", at: 3)
        model.phraseEntry.focusedIndex = 0
        #expect(await host.waitUntil { fields[3].accessibilityLabel() == "Word 4, not in the word list" })
        #expect(fields[2].accessibilityLabel() == "Word 3")
    }

    // MARK: Review round 1, seed and settings

    @Test(arguments: [false, true])
    func hexPasteReachesTheSecureField(shown: Bool) async throws {
        let model = await onboarding(.importSeed)
        let host = TestWindow(hosting: ImportSeedStep(model: model, compact: false, isVisible: .constant(shown)))
        defer { host.close() }
        #expect(await host.waitUntil { host.views(NSSecureTextField.self).count == 1 })
        let secure = try #require(host.views(NSSecureTextField.self).first)
        #expect(host.window.makeFirstResponder(secure))
        let editor = try #require(secure.currentEditor() as? NSTextView)

        let hex = "0x" + String(repeating: "0f", count: 32)
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("fearless.tests.hex.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.setString(hex, forType: .string)
        #expect(editor.readSelection(from: pasteboard))
        #expect(await host.waitUntil { model.seedHex == hex })
        #expect(model.isSeedValid)
        #expect(host.views(NSSecureTextField.self).count == 1)
        #expect(!host.views(NSTextField.self).contains { !($0 is NSSecureTextField) && $0.stringValue == hex })
    }

    @Test func thePasswordPathCopyButtonCopiesConcealed() async throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("fearless.tests.path-copy.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        let path = "//polkadot///秘密"
        let host = TestWindow(hosting: DerivationDetailsView(
            options: DerivationOptions(substrateDerivationPath: path),
            isRevealed: true,
            clipboard: Clipboard(pasteboard: pasteboard)
        ))
        defer { host.close() }
        #expect(await host.waitUntil { !host.views(NSButton.self).isEmpty })
        let buttons = host.views(NSButton.self)
        #expect(buttons.count == 1, "only the password path has a copy button")
        buttons.first?.performClick(nil)
        #expect(await host.waitUntil { pasteboard.string(forType: .string) == path })
        #expect(pasteboard.types?.contains(Clipboard.concealedType) == true)
    }

    // MARK: Review round 2

    @Test func aLatePreviewNeverReplacesTheConfirmation() async throws {
        let base = PreviewWalletServices.make(scenario: PreviewScenario.emptyWalletList.instant())
        let gated = GatedWallets(base: base.wallets, gatedPath: "//late")
        let services = WalletServices(
            vault: base.vault, wallets: gated, catalog: base.catalog, nodes: base.nodes,
            balances: base.balances, prices: base.prices, transfers: base.transfers, activity: base.activity
        )
        let model = OnboardingModel(mode: .firstWallet, services: services) { _ in }
        await model.choose(.importPhrase)
        model.phraseEntry.setText(PreviewWalletServices.samplePhrase(.words12).joined(separator: " "), at: 0)
        await model.phraseEntry.revalidate()

        model.derivation.substrateDerivationPath = "//late"
        let late = Task { await model.refreshPreview() }
        #expect(await waitUntil(timeout: .seconds(5)) { gated.startedCount == 1 })
        model.derivation.substrateDerivationPath = "//final"
        await model.continueImport()
        #expect(model.step == .confirm)
        let confirmed = try #require(model.addressPreview)

        gated.release()
        await late.value
        #expect(model.addressPreview == confirmed, "the late preview for //late is dropped")

        // Without a race, a refresh still lands.
        let fresh = OnboardingModel(mode: .firstWallet, services: services) { _ in }
        await fresh.choose(.importPhrase)
        fresh.phraseEntry.setText(PreviewWalletServices.samplePhrase(.words12).joined(separator: " "), at: 0)
        await fresh.phraseEntry.revalidate()
        fresh.derivation.substrateDerivationPath = "//final"
        await fresh.refreshPreview()
        #expect(fresh.addressPreview == confirmed)
    }

    @Test func resetWinsOverAComposition() async throws {
        let holder = OptionsHolder()
        let (host, _, evm) = try #require(await hostedForm(holder))
        defer { host.close() }
        #expect(host.window.makeFirstResponder(evm))
        let editor = evm.secretEditor
        editor.setSelectedRange(NSRange(location: (editor.string as NSString).length, length: 0))
        type("///pw", into: editor)
        #expect(holder.options.evmDerivationPath == DerivationOptions.defaultEVMPath + "///pw")
        await host.pump()
        editor.setMarkedText("ぱ", selectedRange: NSRange(location: 1, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        await host.pump()
        #expect(editor.hasMarkedText())

        holder.options.evmDerivationPath = DerivationOptions.defaultEVMPath   // the Reset button
        #expect(await host.waitUntil { evm.currentText == DerivationOptions.defaultEVMPath })
        #expect(!editor.hasMarkedText())
        await host.pump()
        #expect(holder.options.evmDerivationPath == DerivationOptions.defaultEVMPath, "the old password is not pushed back")
    }

    @Test func clearAndPasteWinOverAComposition() async throws {
        let (model, host, fields) = try #require(await hostedGrid())
        defer { host.close() }
        let entry = model.phraseEntry
        type("ab", into: fields[0].secretEditor)
        fields[0].secretEditor.setMarkedText("´", selectedRange: NSRange(location: 1, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        entry.clear()   // the Clear button
        #expect(await host.waitUntil { fields[0].currentText.isEmpty })
        #expect(!fields[0].secretEditor.hasMarkedText())
        #expect(entry.words.allSatisfy { $0.isEmpty })
    }

    @Test func aNavigationKeyCommitsTheCompositionBeforeSuggestions() async throws {
        let (model, host, fields) = try #require(await hostedGrid())
        defer { host.close() }
        let entry = model.phraseEntry
        let editor = fields[0].secretEditor
        type("ab", into: editor)
        editor.setMarkedText("a", selectedRange: NSRange(location: 1, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        #expect(entry.words[0] == "ab")
        editor.doCommand(by: #selector(NSResponder.insertTab(_:)))
        #expect(entry.words[0] == "abandon", "the committed word aba picks the suggestion")
        #expect(host.window.firstResponder === fields[1].secretEditor)
        #expect(!editor.hasMarkedText())
    }

    @Test func typingRightAfterAPasteLandsWhereTheGridShowsIt() async throws {
        let (model, host, fields) = try #require(await hostedGrid())
        defer { host.close() }
        let entry = model.phraseEntry
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("fearless.tests.paste-type.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }

        #expect(host.window.makeFirstResponder(fields[3]))
        type("aban", into: fields[3].secretEditor)
        pasteboard.clearContents()
        pasteboard.setString("abandon ability", forType: .string)
        #expect(fields[3].secretEditor.readSelection(from: pasteboard))
        #expect(fields[3].stringValue == "abandon", "the source field shows its new word at once")
        let next = try #require(host.window.firstResponder as? SecretFieldEditor)
        #expect(next === fields[5].secretEditor, "focus moved past the pasted words")
        type("x", into: next)
        #expect(entry.words[3] == "abandon" && entry.words[4] == "ability" && entry.words[5] == "x")

        // In the last field the pasted word stays in place and typing extends it.
        #expect(host.window.makeFirstResponder(fields[11]))
        pasteboard.clearContents()
        pasteboard.setString("able about", forType: .string)
        #expect(fields[11].secretEditor.readSelection(from: pasteboard))
        #expect(fields[11].currentText == "able")
        type("x", into: fields[11].secretEditor)
        #expect(entry.words[11] == "ablex")
    }

    @Test func aGroupCommitsOnlyItsOwnCompositions() throws {
        let group = SecretFieldGroup()
        let own = SecretEntryTextField(entry: .derivationPath)
        let other = SecretEntryTextField(entry: .derivationPath)
        let ownHost = TestWindow(own)
        defer { ownHost.close() }
        let otherHost = TestWindow(other)
        defer { otherHost.close() }
        group.add(own, focusID: nil)
        let noReplacement = NSRange(location: NSNotFound, length: 0)
        for (host, field) in [(ownHost, own), (otherHost, other)] {
            #expect(host.window.makeFirstResponder(field))
            field.secretEditor.setMarkedText("か", selectedRange: NSRange(location: 1, length: 0), replacementRange: noReplacement)
        }
        group.finishComposition()
        #expect(!own.secretEditor.hasMarkedText())
        #expect(other.secretEditor.hasMarkedText(), "another window's composition is left alone")
    }

    @Test func returnInTheSeedStepCommitsThePathCompositionFirst() async throws {
        let model = await onboarding(.importSeed)
        model.seedHex = String(repeating: "ab", count: 32)
        let host = TestWindow(hosting: ImportSeedStep(model: model, compact: false))
        defer { host.close() }
        #expect(await host.waitUntil { host.views(SecretEntryTextField.self).count == 1 })
        let path = try #require(host.views(SecretEntryTextField.self).first)
        #expect(host.window.makeFirstResponder(path))
        type("//a///", into: path.secretEditor)
        path.secretEditor.setMarkedText("ぱ", selectedRange: NSRange(location: 1, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        #expect(model.derivation.substrateDerivationPath == "//a///")

        let returnKey = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: host.window.windowNumber,
            context: nil, characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36
        ))
        #expect(host.window.performKeyEquivalent(with: returnKey), "Return is Continue's shortcut")
        #expect(await host.waitUntil { model.step == .confirm })
        #expect(model.derivation.substrateDerivationPath == "//a///ぱ", "the composition was committed before the options were read")
    }

    @Test func controlKAtALineBreakDeletesTheBreak() throws {
        let killed = NSTextView(frame: NSRect(x: 0, y: 0, width: 200, height: 20))
        let yanked = NSTextView(frame: NSRect(x: 0, y: 0, width: 200, height: 20))
        let field = SecretEntryTextField(entry: .derivationPath)
        let host = TestWindow(killed, yanked, field)
        defer { host.close() }
        killed.string = "ordinary"
        killed.setSelectedRange(NSRange(location: 0, length: 0))
        killed.deleteToEndOfParagraph(nil)

        #expect(host.window.makeFirstResponder(field))
        let editor = field.secretEditor
        for (text, expected) in [("ab\ncd", "abcd"), ("ab\r\ncd", "abcd"), ("ab\u{2028}cd", "abcd")] {
            editor.string = text
            editor.setSelectedRange(NSRange(location: 2, length: 0))
            editor.doCommand(by: #selector(NSResponder.deleteToEndOfParagraph(_:)))
            editor.doCommand(by: #selector(NSResponder.deleteToEndOfLine(_:)))
            #expect(Array(field.currentText.unicodeScalars) == Array("ab".unicodeScalars) || field.currentText == expected)
        }
        editor.string = "ab\ncd"
        editor.setSelectedRange(NSRange(location: 2, length: 0))
        editor.doCommand(by: #selector(NSResponder.deleteToEndOfParagraph(_:)))
        #expect(field.currentText == "abcd", "the break goes first")
        editor.doCommand(by: #selector(NSResponder.deleteToEndOfParagraph(_:)))
        #expect(field.currentText == "ab", "then the rest of the paragraph")
        editor.string = "ab\ncd"
        editor.setSelectedRange(NSRange(location: 3, length: 0))
        editor.doCommand(by: #selector(NSResponder.deleteToBeginningOfLine(_:)))
        #expect(field.currentText == "ab\ncd", "at the start of a line nothing before the break is deleted")

        yanked.yank(nil)
        #expect(yanked.string == "ordinary")
    }

    @Test func hexPasteSurvivesTheEyeButton() async throws {
        let model = await onboarding(.importSeed)
        let visible = VisibilityHolder()
        let host = TestWindow(hosting: ImportSeedStep(
            model: model, compact: false,
            isVisible: Binding(get: { visible.isVisible }, set: { visible.isVisible = $0 })
        ))
        defer { host.close() }
        #expect(await host.waitUntil { host.views(NSSecureTextField.self).count == 1 })
        let secure = try #require(host.views(NSSecureTextField.self).first)
        #expect(host.window.makeFirstResponder(secure))
        let editor = try #require(secure.currentEditor() as? NSTextView)
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("fearless.tests.hex-eye.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }

        let first = "0x" + String(repeating: "0f", count: 16)
        pasteboard.clearContents()
        pasteboard.setString(first, forType: .string)
        #expect(editor.readSelection(from: pasteboard))
        #expect(await host.waitUntil { model.seedHex == first })

        visible.isVisible = true
        await host.pump()
        #expect(host.views(NSSecureTextField.self).first === secure, "showing the seed keeps the same editor")
        #expect(secure.currentEditor() === editor)
        let second = String(repeating: "f0", count: 16)
        pasteboard.clearContents()
        pasteboard.setString(second, forType: .string)
        #expect(editor.readSelection(from: pasteboard))
        #expect(await host.waitUntil { model.seedHex == first + second })
        #expect(model.isSeedValid)

        visible.isVisible = false
        await host.pump()
        #expect(host.views(NSSecureTextField.self).first === secure)
        #expect(model.seedHex == first + second)
    }
}
