import Foundation
import Testing
import WalletCore
@testable import WalletPreviewSupport
@testable import WalletUI

@MainActor
@Suite("Onboarding flow")
struct OnboardingTests {
    private func makeModel(
        _ scenario: PreviewScenario = .firstRun,
        mode: OnboardingModel.Mode = .firstRun
    ) -> (model: OnboardingModel, services: WalletServices, finished: Box<Wallet?>) {
        let services = PreviewWalletServices.make(scenario: scenario.instant())
        let finished = Box<Wallet?>(nil)
        let model = OnboardingModel(mode: mode, services: services) { finished.value = $0 }
        return (model, services, finished)
    }

    @Test func firstRunCreatePathReachesAStoredBackedUpWallet() async throws {
        let (model, services, finished) = makeModel()
        #expect(model.step == .welcome)
        #expect(!model.canGoBack)

        await model.choose(.create)
        #expect(model.step == .password)
        #expect(model.outline == [.password, .phraseReveal, .phraseVerify, .confirm])

        model.password = PreviewWalletServices.samplePassword
        model.passwordConfirmation = PreviewWalletServices.samplePassword
        await model.submitPassword()
        #expect(await services.vault.state() == .unlocked)
        #expect(model.step == .biometrics)

        await model.enableBiometrics()
        #expect(await services.vault.biometricsAvailability() == .enabled)
        #expect(model.password.isEmpty, "the password is dropped once Touch ID is set up")
        #expect(model.step == .phraseReveal)
        #expect(model.phrase.count == 12)
        #expect(!model.isPhraseRevealed)

        model.isPhraseRevealed = true
        model.beginVerification()
        #expect(model.step == .phraseVerify)
        #expect(!model.isPhraseRevealed, "the phrase hides when the check begins")
        let verification = try #require(model.verification)
        for challenge in verification.challenges {
            verification.select(model.phrase[challenge.position], for: challenge.position)
        }
        #expect(verification.isComplete)
        await model.completeVerification()
        #expect(model.step == .confirm)
        #expect(model.addressPreview?.substrate != nil)
        #expect(model.addressPreview?.evm != nil)

        model.walletName = "Daily"
        await model.finish()
        let wallet = try #require(finished.value)
        #expect(wallet.name == "Daily")
        let stored = try await services.wallets.wallets()
        #expect(stored.count == 1)
        #expect(stored.first?.origin == .created)
        #expect(stored.first?.isBackedUp == true, "the check passed, so the wallet is marked backed up")
        #expect(model.phrase.isEmpty, "secrets are wiped after the wallet is stored")
    }

    @Test func backUpLaterKeepsAReminder() async throws {
        let (model, services, finished) = makeModel(.emptyWalletList, mode: .firstWallet)
        await model.choose(.create)
        #expect(model.step == .phraseReveal, "no password step once the vault exists")
        await model.backUpLater()
        #expect(model.step == .confirm)
        await model.finish()
        let wallet = try #require(finished.value)
        #expect(wallet.origin == .created)
        #expect(!wallet.isBackedUp)
        let stored = try #require(try await services.wallets.wallets().first { $0.id == wallet.id })
        #expect(!stored.isBackedUp, "nothing marks the wallet backed up until the check passes")
    }

    @Test func weakOrMismatchedPasswordsCannotBeSubmitted() async {
        let (model, services, _) = makeModel()
        await model.choose(.create)

        model.password = "short"
        model.passwordConfirmation = "short"
        #expect(model.passwordStrength == .tooShort)
        #expect(!model.canSubmitPassword)

        model.password = "password123"
        model.passwordConfirmation = "password123"
        #expect(model.passwordStrength == .weak)
        #expect(!model.canSubmitPassword)

        model.password = "Tangerine-42"
        model.passwordConfirmation = "Tangerine-43"
        #expect(model.passwordStrength >= .fair)
        #expect(model.passwordMismatchMessage != nil)
        #expect(!model.canSubmitPassword)
        await model.submitPassword()
        #expect(await services.vault.state() == .uninitialized, "nothing is sent while the form is invalid")

        model.passwordConfirmation = "Tangerine-42"
        #expect(model.passwordMismatchMessage == nil)
        #expect(model.canSubmitPassword)
    }

    @Test func backNavigationFollowsHistoryAndNeverRevisitsThePassword() async {
        let (model, _, _) = makeModel()
        await model.choose(.importSeed)
        #expect(model.step == .password)
        #expect(model.canGoBack)
        model.back()
        #expect(model.step == .welcome)
        #expect(model.path == nil)

        await model.choose(.watchOnly)
        model.password = PreviewWalletServices.samplePassword
        model.passwordConfirmation = PreviewWalletServices.samplePassword
        await model.submitPassword()
        #expect(model.step == .biometrics)
        await model.skipBiometrics()
        #expect(model.step == .watchOnly)
        model.back()
        #expect(model.step == .welcome, "back from the first wallet step returns to the choice, not to the password")
        await model.choose(.importJSON)
        #expect(model.step == .importJSON, "the vault exists, so the password step is skipped")
    }

    @Test func importingAPhraseStoresABackedUpWallet() async throws {
        let (model, services, finished) = makeModel(.emptyWalletList, mode: .firstWallet)
        await model.choose(.importPhrase)
        #expect(!model.canContinueImport)
        model.phraseEntry.setText(PreviewWalletServices.samplePhrase(.words24).joined(separator: " "), at: 0)
        await model.phraseEntry.revalidate()
        #expect(model.phraseEntry.wordCount == 24)
        #expect(model.canContinueImport)
        await model.continueImport()
        #expect(model.step == .confirm)
        await model.finish()
        let wallet = try #require(finished.value)
        let stored = try await services.wallets.wallets()
        #expect(stored.first { $0.id == wallet.id }?.isBackedUp == true, "an imported phrase is already backed up")
        #expect(stored.first { $0.id == wallet.id }?.origin == .mnemonic)
    }

    @Test func optionsSetWhileImportingNeverLeakIntoACreatedWallet() async throws {
        let (model, services, finished) = makeModel(.emptyWalletList, mode: .firstWallet)

        // Visit the import screen and change its Advanced options…
        await model.choose(.importPhrase)
        model.derivation = DerivationOptions(substrateCryptoType: .ed25519, substrateDerivationPath: "//other///pw", evmDerivationPath: "m/44'/60'/0'/0/9")
        // …then go back and create a wallet instead.
        model.back()
        #expect(model.step == .welcome)
        #expect(model.derivation == .standard, "leaving a flow resets its options")
        await model.choose(.create)
        #expect(model.derivation == .standard)
        await model.backUpLater()
        #expect(model.step == .confirm)
        await model.finish()

        let wallet = try #require(finished.value)
        #expect(wallet.origin == .created)
        let substrate = try #require(wallet.account(for: .substrate))
        #expect(substrate.cryptoType == .sr25519)
        #expect(substrate.derivationPath == nil)
        #expect(wallet.account(for: .evm)?.derivationPath == DerivationOptions.defaultEVMPath)
        let backup = try await services.wallets.exportMnemonic(wallet.id, approval: .password(PreviewWalletServices.samplePassword))
        #expect(backup.options == .standard, "a wallet created here always uses the standard derivation")
        #expect(!backup.needsDerivationDetails)
    }

    @Test func switchingImportKindsStartsFromStandardOptions() async throws {
        let (model, _, finished) = makeModel(.emptyWalletList, mode: .firstWallet)
        await model.choose(.importSeed)
        model.derivation.substrateCryptoType = .ecdsa
        model.back()
        await model.choose(.importPhrase)
        #expect(model.derivation == .standard, "options chosen for a seed do not follow into a phrase import")

        // Options set inside the phrase import are used for that import.
        model.derivation.substrateDerivationPath = "//staking"
        model.phraseEntry.setText(PreviewWalletServices.samplePhrase(.words12).joined(separator: " "), at: 0)
        await model.phraseEntry.revalidate()
        await model.continueImport()
        await model.finish()
        let wallet = try #require(finished.value)
        #expect(wallet.account(for: .substrate)?.derivationPath == "//staking")
    }

    @Test func invalidSourcesStayOnTheirStepWithAMessage() async {
        let (model, _, _) = makeModel(.emptyWalletList, mode: .firstWallet)
        await model.choose(.watchOnly)
        model.watchSubstrateAddress = "not-an-address"
        #expect(model.canContinueImport)
        await model.continueImport()
        #expect(model.step == .watchOnly)
        #expect(model.errorMessage != nil)

        model.back()
        await model.choose(.importSeed)
        model.seedHex = "1234"
        #expect(!model.isSeedValid)
        #expect(!model.canContinueImport)
        model.seedHex = "0x" + String(repeating: "ab", count: 32)
        #expect(model.isSeedValid)
        await model.continueImport()
        #expect(model.step == .confirm)
    }

    @Test func duplicateWalletIsReportedOnTheLastStep() async {
        let (model, _, finished) = makeModel(.standard, mode: .addWallet)
        await model.choose(.watchOnly)
        model.watchSubstrateAddress = PreviewSampleData.alice.polkadot
        await model.continueImport()
        #expect(model.step == .confirm)
        await model.finish()
        #expect(finished.value == nil)
        #expect(model.errorMessage == WalletError.duplicateWallet(existing: PreviewSampleData.mainWalletID).errorDescription)
        #expect(model.step == .confirm)
    }

    @Test func jsonFilesAreCheckedBeforeTheyAreAccepted() throws {
        let (model, _, _) = makeModel(.emptyWalletList, mode: .firstWallet)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("fearless-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let notJSON = folder.appendingPathComponent("notes.json")
        try Data("hello".utf8).write(to: notJSON)
        model.loadJSON(from: notJSON)
        #expect(model.jsonFileName == nil)
        #expect(model.errorMessage == "That file is not a JSON backup.")

        let keystore = folder.appendingPathComponent("backup.json")
        try Data(#"{"address":"\#(PreviewSampleData.bob.polkadot)","encoded":"preview"}"#.utf8).write(to: keystore)
        model.loadJSON(from: keystore)
        #expect(model.jsonFileName == "backup.json")
        #expect(model.errorMessage == nil)
    }
}

/// A mutable value shared with a callback.
@MainActor
final class Box<Value> {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}

@MainActor
@Suite("Phrase verification")
struct PhraseVerificationTests {
    private let words12 = PreviewWalletServices.samplePhrase(.words12)
    private let words24 = PreviewWalletServices.samplePhrase(.words24)

    @Test func asksThreePositionsForTwelveWordsAndFourForLongerPhrases() {
        var generator = SystemRandomNumberGenerator()
        let short = PhraseVerification(words: words12, wordList: PreviewWalletServices.wordList, using: &generator)
        let long = PhraseVerification(words: words24, wordList: PreviewWalletServices.wordList, using: &generator)
        #expect(short.challenges.count == 3)
        #expect(long.challenges.count == 4)
        #expect(Set(long.challenges.map(\.position)).count == 4)
    }

    @Test func everyChallengeOffersTheAnswerAmongSixDistinctWords() {
        let verification = PhraseVerification(words: words12, wordList: PreviewWalletServices.wordList)
        for challenge in verification.challenges {
            #expect(challenge.options.count == 6)
            #expect(Set(challenge.options).count == 6)
            #expect(challenge.options.contains(words12[challenge.position]))
        }
    }

    @Test func completesOnlyWhenEveryAnswerIsRight() throws {
        let verification = PhraseVerification(words: words12, wordList: PreviewWalletServices.wordList)
        #expect(!verification.isComplete)
        let first = try #require(verification.challenges.first)
        let wrong = try #require(first.options.first { $0 != words12[first.position] })
        verification.select(wrong, for: first.position)
        #expect(verification.hasMistake)
        #expect(verification.isCorrect(try #require(verification.challenges.first)) == false)

        for challenge in verification.challenges {
            verification.select(words12[challenge.position], for: challenge.position)
        }
        #expect(!verification.hasMistake)
        #expect(verification.isComplete)
        #expect(verification.answeredCount == 3)
    }
}

@MainActor
@Suite("Phrase entry")
struct PhraseEntryTests {
    private func makeEntry(count: Int = 12) -> PhraseEntryModel {
        let wallets = PreviewWalletServices.make(scenario: PreviewScenario.standard.instant()).wallets
        return PhraseEntryModel(wordList: wallets.mnemonicWordList, wordCount: count) { await wallets.validateMnemonic($0) }
    }

    @Test func pastingAWholePhraseFillsEveryField() async {
        let entry = makeEntry()
        let phrase = PreviewWalletServices.samplePhrase(.words12)
        entry.setText("  " + phrase.joined(separator: "  ").uppercased() + "\n", at: 5)
        #expect(entry.words == phrase, "a full phrase replaces the grid from the first field, whatever field it was pasted into")
        await entry.revalidate()
        #expect(entry.validation == .valid)
        #expect(entry.isValid)
    }

    @Test func pastingALongerPhraseResizesTheGrid() {
        let entry = makeEntry()
        let phrase = PreviewWalletServices.samplePhrase(.words24)
        entry.setText(phrase.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"), at: 0)
        #expect(entry.wordCount == 24)
        #expect(entry.words == phrase, "numbering and punctuation are dropped")
    }

    @Test func pastingAFewWordsSpreadsThemFromTheField() {
        let entry = makeEntry()
        entry.setText("zoo zone, zero", at: 9)
        #expect(entry.words[9] == "zoo")
        #expect(entry.words[10] == "zone")
        #expect(entry.words[11] == "zero")
        #expect(entry.words[8].isEmpty)
        entry.setText("abandon ability able", at: 10)
        #expect(entry.words[10] == "abandon")
        #expect(entry.words[11] == "ability", "words past the last field are dropped")
    }

    @Test func unknownWordsAreFlaggedButNotWhileStillBeingTyped() async {
        let entry = makeEntry()
        entry.focusedIndex = 0
        entry.setText("aban", at: 0)
        #expect(!entry.isUnknown(0), "a prefix of a list word is not flagged in the focused field")
        #expect(entry.suggestions(at: 0).first == "abandon")
        entry.focusedIndex = 1
        #expect(entry.isUnknown(0), "once focus leaves, a non-word is flagged")
        entry.setText("qqqq", at: 1)
        #expect(entry.isUnknown(1), "no list word starts with this, so it is flagged at once")
        #expect(entry.suggestions(at: 1).isEmpty)
        #expect(entry.problem == "Words 1, 2 are not in the recovery word list.")
    }

    @Test func suggestionsCompleteTheWordAndMoveOn() {
        let entry = makeEntry()
        entry.setText("ozo", at: 0)
        #expect(entry.suggestions(at: 0) == ["ozone"])
        entry.acceptSuggestion("ozone", at: 0)
        #expect(entry.words[0] == "ozone")
        #expect(entry.focusedIndex == 1)
        #expect(entry.suggestions(at: 0).isEmpty, "a complete, unambiguous word needs no suggestion")
    }

    @Test func aWrongOrderFailsTheChecksum() async {
        let entry = makeEntry()
        var phrase = PreviewWalletServices.samplePhrase(.words12)
        phrase.swapAt(0, 1)
        entry.setText(phrase.joined(separator: " "), at: 0)
        await entry.revalidate()
        #expect(entry.validation == .invalidChecksum)
        #expect(!entry.isValid)
        #expect(entry.problem?.contains("do not form a valid phrase") == true)
    }

    @Test func changingLengthKeepsWhatFits() {
        let entry = makeEntry()
        entry.setText("zoo zone zero", at: 0)
        entry.setWordCount(24)
        #expect(entry.words.count == 24)
        #expect(entry.words[2] == "zero")
        entry.setWordCount(13)
        #expect(entry.wordCount == 24, "only BIP-39 lengths are accepted")
        entry.clear()
        #expect(entry.filledCount == 0)
    }
}
