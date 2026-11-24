import AppKit
import DesignSystem
import Foundation
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
}

@MainActor
@Suite("Secret text fields")
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
            #expect(!editor.responds(to: NSSelectorFromString(name)), "\(name) must not reach the editor")
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
        let shown = TestWindow(hosting: ImportSeedStep(model: model, compact: false, isVisible: true))
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
}
