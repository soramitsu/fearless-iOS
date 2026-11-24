import IrohaCrypto
import SoraFoundation
import LocalAuthentication
import RobinHood
import SoraKeystore
import SSFModels
import TonSwift
import XCTest
@testable import fearless

private let recoveryTonPhrase = "cluster notice abandon frost gospel boring element situate click mix vague replace imitate garment useful crater resource dose tenant theme foam ancient phrase slight"

final class ProtectedKeychainRecoveryCheckTests: XCTestCase {
    private func check(_ fixture: ProtectedFixture, enabled: Bool = true, defaults: UserDefaults = CovHAssetListFixture.defaults()) -> ProtectedKeychainRecoveryCheck {
        ProtectedKeychainRecoveryCheck(
            inventory: fixture.legacy,
            keystore: fixture.legacy,
            evidence: fixture.evidence,
            userDefaults: defaults,
            isEnabled: { enabled }
        )
    }

    func testOfferedOnlyWhileTheFlagIsOnForAnOlderPhraseWalletAndOnlyOnce() throws {
        let fixture = try ProtectedFixture(imported: false)
        XCTAssertFalse(check(fixture, enabled: false).shouldOffer(fixture.wallet), "Flag off: nothing new is shown")

        let defaults = CovHAssetListFixture.defaults()
        let enabled = check(fixture, defaults: defaults)
        XCTAssertTrue(enabled.shouldOffer(fixture.wallet))
        enabled.markOffered(fixture.wallet.metaId)
        XCTAssertFalse(enabled.shouldOffer(fixture.wallet), "Once per wallet")
        XCTAssertTrue(check(fixture, defaults: defaults).wasOffered(fixture.wallet.metaId), "Remembered across launches")
    }

    func testNeverOfferedForWalletsThatAlreadyHaveEvidenceOrCannotBeCoveredByOnePhrase() throws {
        let imported = try ProtectedFixture()
        XCTAssertFalse(check(imported).shouldOffer(imported.wallet), "Imported in this build: evidence already exists")

        let chainAccount = try ProtectedFixture(imported: false)
        try chainAccount.legacy.addKey(
            Data([1]),
            with: fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(chainAccount.wallet.metaId, accountId: Data(repeating: 3, count: 32))
        )
        XCTAssertFalse(check(chainAccount).shouldOffer(chainAccount.wallet), "An account imported on its own")

        let seedBridge = try ProtectedFixture(imported: false)
        try seedBridge.legacy.addKey(
            Data(UniversalWalletSeedBridge.contract.utf8),
            with: fearless.KeystoreTagV2.universalWalletSecretSourceTagForMetaId(seedBridge.wallet.metaId)
        )
        XCTAssertFalse(check(seedBridge).shouldOffer(seedBridge.wallet), "A raw-seed wallet has no phrase")
    }

    func testMatchingPhraseRecordsEvidenceForEveryItemSoTheWalletCanMove() throws {
        let fixture = try ProtectedFixture(imported: false)
        XCTAssertEqual(fixture.migrator().migrateOffMain(fixture.wallet), .deferred(.recoveryUnverified))

        let typed = "  " + ProtectedFixture.phrase.uppercased().replacingOccurrences(of: " ", with: "\n  ") + " "
        XCTAssertEqual(check(fixture).verify(phrase: typed, wallet: fixture.wallet), .verified)

        XCTAssertTrue(fixture.originals.keys.allSatisfy { fixture.evidence.covers(tag: $0, walletId: fixture.wallet.metaId) })
        XCTAssertEqual(fixture.migrator().migrateOffMain(fixture.wallet), .committed)
        fixture.assertEveryOriginalReadable()
    }

    func testWrongPhraseChangesNothing() throws {
        let fixture = try ProtectedFixture(imported: false)
        let before = fixture.legacy.items
        let other = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

        XCTAssertEqual(check(fixture).verify(phrase: other, wallet: fixture.wallet), .mismatch)
        XCTAssertEqual(check(fixture).verify(phrase: "not a phrase", wallet: fixture.wallet), .mismatch)
        XCTAssertEqual(check(fixture).verify(phrase: "", wallet: fixture.wallet), .mismatch)

        XCTAssertTrue(fixture.originals.keys.allSatisfy { !fixture.evidence.covers(tag: $0, walletId: fixture.wallet.metaId) })
        XCTAssertEqual(fixture.legacy.items, before)
        XCTAssertTrue(fixture.protected.items.isEmpty)
    }

    func testCustomPathWalletStaysAsItIs() throws {
        let fixture = try ProtectedFixture(passwordPath: true, imported: false)

        XCTAssertEqual(check(fixture).verify(phrase: ProtectedFixture.phrase, wallet: fixture.wallet), .customPath,
                       "Restoring would also need the path and password, which this check does not ask for")

        XCTAssertTrue(fixture.originals.keys.allSatisfy { !fixture.evidence.covers(tag: $0, walletId: fixture.wallet.metaId) })
    }

    func testNativeTonWalletIsCheckedAgainstItsStoredKey() throws {
        let fixture = try ProtectedFixture(imported: false)
        let pair = try TonSwift.Mnemonic.mnemonicToPrivateKey(mnemonicArray: recoveryTonPhrase.components(separatedBy: " "))
        let account = try LegacyTonAccount(
            serializedAddress: JSONEncoder().encode(WalletV4R2(publicKey: pair.publicKey.data).address()),
            publicKey: pair.publicKey.data,
            contractVersion: "v4R2"
        )
        let metaId = UUID().uuidString
        try fixture.legacy.addKey(pair.privateKey.data, with: fearless.KeystoreTagV2.tonSecretKeyTagForMetaId(metaId))
        try fixture.legacy.addKey(Data(recoveryTonPhrase.utf8), with: fearless.KeystoreTagV2.entropyTagForMetaId(metaId))
        let wallet = MetaAccountModel(
            metaId: metaId, name: "TON", substrateAccountId: nil, substrateCryptoType: 0, substratePublicKey: nil,
            ethereumAddress: nil, ethereumPublicKey: nil, chainAccounts: [], assetKeysOrder: nil,
            canExportEthereumMnemonic: false, unusedChainIds: nil, selectedCurrency: .defaultCurrency(),
            networkManagmentFilter: nil, assetsVisibility: [], hasBackup: true, favouriteChainIds: [],
            legacyTonAccount: account
        )
        let check = check(fixture)

        XCTAssertTrue(check.shouldOffer(wallet))
        XCTAssertEqual(check.verify(phrase: ProtectedFixture.phrase, wallet: wallet), .mismatch)
        XCTAssertEqual(check.verify(phrase: recoveryTonPhrase, wallet: wallet), .verified)
        XCTAssertTrue(fixture.evidence.covers(tag: fearless.KeystoreTagV2.tonSecretKeyTagForMetaId(metaId), walletId: metaId))
    }

    @MainActor
    func testPhraseFieldOffersNoPasteCopySuggestionsOrAutocorrect() {
        let field = RecoveryPhraseTextView(frame: .zero, textContainer: nil)
        XCTAssertEqual(field.autocorrectionType, .no)
        XCTAssertEqual(field.spellCheckingType, .no)
        XCTAssertEqual(field.autocapitalizationType, .none)
        XCTAssertEqual(field.smartInsertDeleteType, .no)
        XCTAssertEqual(field.keyboardType, .asciiCapable)
        if #available(iOS 17.0, *) {
            XCTAssertEqual(field.inlinePredictionType, .no)
        }
        XCTAssertNil(field.pasteConfiguration)
        XCTAssertFalse(field.canPerformAction(#selector(UIResponderStandardEditActions.paste(_:)), withSender: nil))
        XCTAssertFalse(field.canPerformAction(#selector(UIResponderStandardEditActions.copy(_:)), withSender: nil))
        XCTAssertFalse(field.canPerformAction(#selector(UIResponderStandardEditActions.cut(_:)), withSender: nil))
    }

    @MainActor
    func testMismatchOnScreenKeepsTheWalletAndClosingRunsNothing() throws {
        let fixture = try ProtectedFixture(imported: false)
        var verified = 0
        let controller = ProtectedKeychainRecoveryCheckViewController(
            wallet: fixture.wallet, check: check(fixture), locale: Locale(identifier: "en")
        ) { verified += 1 }
        controller.loadViewIfNeeded()
        XCTAssertFalse(controller.phraseView.text.contains(" "), "The stored phrase is never shown")

        controller.show(.mismatch)

        XCTAssertFalse((controller.statusLabel.text ?? "").isEmpty)
        XCTAssertEqual(verified, 0)
        XCTAssertTrue(fixture.originals.keys.allSatisfy { !fixture.evidence.covers(tag: $0, walletId: fixture.wallet.metaId) })
    }

    // MARK: Codex review 3

    private func assertNoEvidence(_ fixture: ProtectedFixture, file: StaticString = #filePath, line: UInt = #line) {
        let tags = (try? fixture.legacy.applicationTags()) ?? []
        XCTAssertTrue(
            tags.allSatisfy { !fixture.evidence.covers(tag: $0, walletId: fixture.wallet.metaId) },
            "No item gained evidence", file: file, line: line
        )
    }

    private func replace(_ suffix: String, in fixture: ProtectedFixture, with data: Data) throws {
        try fixture.legacy.updateKey(data, with: fixture.wallet.metaId + suffix)
    }

    /// Finding 1: an Ethereum key from another backup, on a wallet row that kept only the address.
    func testEthereumKeyTheWordsDoNotWriteIsNeverCredited() throws {
        let fixture = try ProtectedFixture(imported: false)
        let foreign = try SECKeyFactory().createRandomKeypair().privateKey().rawData()
        try replace("-ethereumSecretKey", in: fixture, with: foreign)
        try replace("-ethereumSeed", in: fixture, with: foreign)
        let addressOnly = fixture.wallet.replacingEthereumPublicKeyWithNil()

        XCTAssertEqual(check(fixture).verify(phrase: ProtectedFixture.phrase, wallet: addressOnly), .unavailable)
        assertNoEvidence(fixture)
        XCTAssertEqual(fixture.migrator().migrateOffMain(addressOnly), .deferred(.recoveryUnverified))
    }

    /// Finding 2: 4.0.x kept a child account's seed under the wallet's own `-substrateSeed` tag.
    func testChildSeedUnderTheRootTagIsNeverCredited() throws {
        let fixture = try ProtectedFixture(imported: false)
        try replace("-substrateSeed", in: fixture, with: Data(repeating: 7, count: 32))

        XCTAssertEqual(check(fixture).verify(phrase: ProtectedFixture.phrase, wallet: fixture.wallet), .unavailable)
        assertNoEvidence(fixture)
    }

    /// Finding 2: an account imported on its own after the offer is never credited.
    func testAccountImportedAfterTheOfferIsNeverCredited() throws {
        let fixture = try ProtectedFixture(imported: false)
        let check = check(fixture)
        XCTAssertTrue(check.shouldOffer(fixture.wallet))
        let child = fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(fixture.wallet.metaId, accountId: Data(repeating: 3, count: 32))
        try fixture.legacy.addKey(Data([1]), with: child)

        XCTAssertEqual(check.verify(phrase: ProtectedFixture.phrase, wallet: fixture.wallet), .unavailable)
        assertNoEvidence(fixture)
    }

    /// Finding 2: evidence is bound to the bytes it compared; an item rewritten later is not covered.
    func testItemChangedAfterTheCheckDoesNotMove() throws {
        let fixture = try ProtectedFixture(imported: false)
        XCTAssertEqual(check(fixture).verify(phrase: ProtectedFixture.phrase, wallet: fixture.wallet), .verified)
        let original = try fixture.legacy.fetchKey(for: fixture.wallet.metaId + "-substrateSeed")
        try replace("-substrateSeed", in: fixture, with: Data(repeating: 9, count: 32))

        XCTAssertEqual(fixture.migrator().migrateOffMain(fixture.wallet), .deferred(.recoveryUnverified))
        XCTAssertTrue(fixture.protected.items.isEmpty)

        // The same bytes again: covered again. A write this build makes from a typed phrase
        // replaces the binding.
        try replace("-substrateSeed", in: fixture, with: original)
        XCTAssertTrue(fixture.evidence.stillMatches(fixture.originals, walletId: fixture.wallet.metaId))
        fixture.evidence.record(walletId: fixture.wallet.metaId, tags: [fixture.wallet.metaId + "-substrateSeed"])
        XCTAssertTrue(fixture.evidence.stillMatches(
            [fixture.wallet.metaId + "-substrateSeed": Data([1])], walletId: fixture.wallet.metaId
        ))
    }

    /// Finding 4: closed while deriving, or vetoed meanwhile: nothing is recorded.
    func testCancelledOrVetoedCheckRecordsNothing() throws {
        let fixture = try ProtectedFixture(imported: false)
        XCTAssertEqual(
            check(fixture).verify(phrase: ProtectedFixture.phrase, wallet: fixture.wallet, isCancelled: { true }),
            .unavailable
        )
        assertNoEvidence(fixture)

        var answers = [true, false]
        let vetoed = ProtectedKeychainRecoveryCheck(
            inventory: fixture.legacy, keystore: fixture.legacy, evidence: fixture.evidence,
            userDefaults: CovHAssetListFixture.defaults(),
            isEnabled: { answers.isEmpty ? false : answers.removeFirst() }
        )
        XCTAssertEqual(vetoed.verify(phrase: ProtectedFixture.phrase, wallet: fixture.wallet), .unavailable)
        assertNoEvidence(fixture)
    }

    // MARK: Codex review 4

    /// Closing the screen after the keys were compared but before the result reaches the screen:
    /// nothing is recorded (recording happens on the main thread, after the close check).
    @MainActor
    func testClosingAfterTheComparisonRecordsNothing() throws {
        let fixture = try ProtectedFixture(imported: false)
        let queue = DispatchQueue(label: "recovery-check-proved")
        var verified = 0
        let controller = ProtectedKeychainRecoveryCheckViewController(
            wallet: fixture.wallet, check: check(fixture), locale: Locale(identifier: "en"), workQueue: queue
        ) { verified += 1 }
        controller.loadViewIfNeeded()
        controller.phraseView.text = ProtectedFixture.phrase

        controller.didTapCheck()
        queue.sync {}
        assertNoEvidence(fixture)
        controller.didTapClose()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))

        XCTAssertEqual(verified, 0)
        assertNoEvidence(fixture)
    }

    /// A proof records only while the wallet holds exactly the items it compared.
    func testProofOfChangedItemsRecordsNothing() throws {
        let fixture = try ProtectedFixture(imported: false)
        let check = check(fixture)
        let (outcome, proof) = check.prove(phrase: ProtectedFixture.phrase, wallet: fixture.wallet)
        XCTAssertEqual(outcome, .verified)
        assertNoEvidence(fixture)
        let child = fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(fixture.wallet.metaId, accountId: Data(repeating: 4, count: 32))
        try fixture.legacy.addKey(Data([1]), with: child)

        XCTAssertEqual(check.record(try XCTUnwrap(proof)), .unavailable)
        assertNoEvidence(fixture)

        try fixture.legacy.deleteKey(for: child)
        try replace("-substrateSeed", in: fixture, with: Data(repeating: 6, count: 32))
        XCTAssertEqual(check.record(try XCTUnwrap(proof)), .unavailable)
        assertNoEvidence(fixture)
    }

    /// Wallets the 2.x single-to-multiasset migration moved keep the BIP32 seed under -ethereumSeed.
    func testHistoricalEthereumSeedIsAccepted() throws {
        let fixture = try ProtectedFixture(imported: false)
        let entropy = try IRMnemonicCreator().mnemonic(fromList: ProtectedFixture.phrase).entropy()
        let seed = try EthereumAccountImportWrapper().importEntropy(
            entropy, derivationPath: DerivationPathConstants.defaultEthereum
        ).seed
        try replace("-ethereumSeed", in: fixture, with: seed)

        XCTAssertEqual(check(fixture).verify(phrase: ProtectedFixture.phrase, wallet: fixture.wallet), .verified)
    }

    /// A stored Substrate path (custom path or wallet password) is visible from attributes: no offer.
    func testCustomSubstratePathIsNotOffered() throws {
        let fixture = try ProtectedFixture(passwordPath: true, imported: false)
        XCTAssertFalse(check(fixture).shouldOffer(fixture.wallet))
    }

    /// The offer is claimed as it is shown: once, and not after the flag goes off.
    func testOfferIsClaimedOnceAndNotAfterTheFlagGoesOff() throws {
        let fixture = try ProtectedFixture(imported: false)
        var enabled = true
        let check = ProtectedKeychainRecoveryCheck(
            inventory: fixture.legacy, keystore: fixture.legacy, evidence: fixture.evidence,
            userDefaults: CovHAssetListFixture.defaults(), isEnabled: { enabled }
        )
        XCTAssertTrue(check.claimOffer(fixture.wallet))
        XCTAssertFalse(check.claimOffer(fixture.wallet), "A second queued check shows nothing")

        let other = try ProtectedFixture(imported: false)
        let vetoed = ProtectedKeychainRecoveryCheck(
            inventory: other.legacy, keystore: other.legacy, evidence: other.evidence,
            userDefaults: CovHAssetListFixture.defaults(), isEnabled: { enabled }
        )
        XCTAssertTrue(vetoed.shouldOffer(other.wallet))
        enabled = false
        XCTAssertFalse(vetoed.claimOffer(other.wallet))
        XCTAssertFalse(vetoed.wasOffered(other.wallet.metaId))
    }

    /// Codex review 4: evidence written by review builds under the old key never counts.
    func testEvidenceFromReviewBuildsDoesNotCount() throws {
        let defaults = CovHAssetListFixture.defaults()
        defaults.set(["w": ["w-entropy"]], forKey: "protectedKeychain.recoveryEvidence.v2")
        let evidence = ProtectedKeychainRecoveryEvidence(userDefaults: defaults)
        XCTAssertFalse(evidence.covers(tag: "w-entropy", walletId: "w"))
        XCTAssertEqual(ProtectedKeychainRecoveryEvidence.storageKey, "protectedKeychain.recoveryEvidence.v3")
    }

    /// Finding 5: a wallet with evidence on any item is never offered.
    func testPartialEvidenceIsNeverOffered() throws {
        let fixture = try ProtectedFixture(imported: false)
        fixture.evidence.record(walletId: fixture.wallet.metaId, tags: [fixture.wallet.metaId + "-entropy"])
        XCTAssertFalse(check(fixture).shouldOffer(fixture.wallet))
    }

    /// Finding 6: a historical TON backup with spacing kept exactly as typed.
    func testTonBackupWithItsExactSpacingIsAccepted() throws {
        let fixture = try ProtectedFixture(imported: false)
        let spaced = recoveryTonPhrase.replacingOccurrences(of: "notice ", with: "notice  ")
        let pair = try TonSwift.Mnemonic.mnemonicToPrivateKey(mnemonicArray: spaced.components(separatedBy: " "))
        let normalized = try TonSwift.Mnemonic.mnemonicToPrivateKey(mnemonicArray: recoveryTonPhrase.components(separatedBy: " "))
        XCTAssertNotEqual(pair.publicKey.data, normalized.publicKey.data, "The spacing is part of the key")
        let (wallet, metaId) = try tonWallet(in: fixture, phrase: spaced, pair: pair)
        let check = check(fixture)

        XCTAssertEqual(check.verify(phrase: recoveryTonPhrase, wallet: wallet), .mismatch)
        XCTAssertEqual(
            check.verify(phrase: " " + spaced, wallet: wallet), .mismatch,
            "Import would not restore this wallet from that text, so it proves nothing"
        )
        XCTAssertEqual(check.verify(phrase: spaced, wallet: wallet), .verified)
        XCTAssertTrue(fixture.evidence.covers(tag: fearless.KeystoreTagV2.entropyTagForMetaId(metaId), walletId: metaId))
    }

    func testTonSigningKeyFromAnotherPhraseIsNeverCredited() throws {
        let fixture = try ProtectedFixture(imported: false)
        let pair = try TonSwift.Mnemonic.mnemonicToPrivateKey(mnemonicArray: recoveryTonPhrase.components(separatedBy: " "))
        let (wallet, metaId) = try tonWallet(in: fixture, phrase: recoveryTonPhrase, pair: pair)
        try fixture.legacy.updateKey(Data(repeating: 5, count: 64), with: fearless.KeystoreTagV2.tonSecretKeyTagForMetaId(metaId))

        XCTAssertEqual(check(fixture).verify(phrase: recoveryTonPhrase, wallet: wallet), .unavailable)
        XCTAssertFalse(fixture.evidence.covers(tag: fearless.KeystoreTagV2.entropyTagForMetaId(metaId), walletId: metaId))
    }

    private func tonWallet(
        in fixture: ProtectedFixture,
        phrase: String,
        pair: TonSwift.KeyPair
    ) throws -> (MetaAccountModel, MetaAccountId) {
        let account = try LegacyTonAccount(
            serializedAddress: JSONEncoder().encode(WalletV4R2(publicKey: pair.publicKey.data).address()),
            publicKey: pair.publicKey.data,
            contractVersion: "v4R2"
        )
        let metaId = UUID().uuidString
        try fixture.legacy.addKey(pair.privateKey.data, with: fearless.KeystoreTagV2.tonSecretKeyTagForMetaId(metaId))
        try fixture.legacy.addKey(Data(phrase.utf8), with: fearless.KeystoreTagV2.entropyTagForMetaId(metaId))
        let wallet = MetaAccountModel(
            metaId: metaId, name: "TON", substrateAccountId: nil, substrateCryptoType: 0, substratePublicKey: nil,
            ethereumAddress: nil, ethereumPublicKey: nil, chainAccounts: [], assetKeysOrder: nil,
            canExportEthereumMnemonic: false, unusedChainIds: nil, selectedCurrency: .defaultCurrency(),
            networkManagmentFilter: nil, assetsVisibility: [], hasBackup: true, favouriteChainIds: [],
            legacyTonAccount: account
        )
        return (wallet, metaId)
    }

    /// Finding 3: while the screen is recorded the keyboard stays down; drag is off.
    @MainActor
    func testRecordedScreenKeepsTheKeyboardDownAndDragOff() throws {
        let fixture = try ProtectedFixture(imported: false)
        let controller = ProtectedKeychainRecoveryCheckViewController(
            wallet: fixture.wallet, check: check(fixture), locale: Locale(identifier: "en"),
            isScreenCaptured: { _ in true }
        ) {}
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.loadViewIfNeeded()
        controller.viewDidAppear(false)

        XCTAssertFalse(controller.phraseView.isFirstResponder)
        XCTAssertEqual(controller.phraseView.textDragInteraction?.isEnabled ?? false, false)
        window.isHidden = true
    }

    /// Finding 4 on screen: Check, then close before the check runs: nothing is recorded.
    @MainActor
    func testClosingWhileCheckingRecordsNothing() throws {
        let fixture = try ProtectedFixture(imported: false)
        let queue = DispatchQueue(label: "recovery-check-test")
        queue.suspend()
        var verified = 0
        let controller = ProtectedKeychainRecoveryCheckViewController(
            wallet: fixture.wallet, check: check(fixture), locale: Locale(identifier: "en"), workQueue: queue
        ) { verified += 1 }
        controller.loadViewIfNeeded()
        controller.phraseView.text = ProtectedFixture.phrase

        controller.didTapCheck()
        controller.didTapClose()
        queue.resume()
        queue.sync {}
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))

        XCTAssertEqual(verified, 0)
        XCTAssertNil(controller.attempt)
        assertNoEvidence(fixture)
    }

    /// Finding 7: the skip action is localized in every language the app ships (`pt.lproj` is in
    /// the repository but not in the app; Portuguese ships as `pt-PT`).
    func testSkipActionIsLocalized() throws {
        let expected = [
            "en": "Not now", "ja": "今はしない", "id": "Nanti saja", "pt-PT": "Agora não",
            "ru": "Не сейчас", "tr": "Şimdi değil", "vi": "Để sau", "zh-Hans": "以后再说"
        ]
        for (language, text) in expected {
            XCTAssertEqual(R.string.localizable.protectedRecoveryLater(preferredLanguages: [language]), text, language)
        }
    }
}

private extension MetaAccountModel {
    func replacingEthereumPublicKeyWithNil() -> MetaAccountModel {
        MetaAccountModel(
            metaId: metaId, name: name, substrateAccountId: substrateAccountId,
            substrateCryptoType: substrateCryptoType, substratePublicKey: substratePublicKey,
            ethereumAddress: ethereumAddress, ethereumPublicKey: nil, chainAccounts: chainAccounts,
            assetKeysOrder: assetKeysOrder, canExportEthereumMnemonic: canExportEthereumMnemonic,
            unusedChainIds: unusedChainIds, selectedCurrency: selectedCurrency,
            networkManagmentFilter: networkManagmentFilter, assetsVisibility: assetsVisibility,
            hasBackup: hasBackup, favouriteChainIds: favouriteChainIds, legacyTonAccount: legacyTonAccount
        )
    }
}

/// Step 1 of 3 on the main screen: one action, one warning, after the other notices; showing it is
/// the one offer and changes nothing else.
final class ProtectedKeychainRecoveryOfferPresenterTests: XCTestCase {
    @MainActor
    func testNotNowRecordsTheOfferAndOpensNothing() throws {
        let fixture = CovHWalletMainFixture()
        fixture.start(hosted: true)

        fixture.interactor.output?.didReceiveRecoveryCheckOffer(for: fixture.wallet)
        let sheet = try XCTUnwrap(fixture.router.sheets.last)
        XCTAssertEqual(sheet.title, R.string.localizable.protectedRecoveryOfferTitle(preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages))
        XCTAssertEqual(sheet.actions.count, 1, "One action")
        XCTAssertEqual(
            fixture.interactor.recoveryOffersClosed, [fixture.wallet.metaId],
            "Recorded when shown: an app lock that closes the sheet never brings it back"
        )

        sheet.dismissCompletion?()

        XCTAssertEqual(fixture.interactor.recoveryOffersClosed, [fixture.wallet.metaId])
        XCTAssertTrue(fixture.router.recoveryChecks.isEmpty)
    }

    @MainActor
    func testCheckOpensTheScreenForThatWallet() throws {
        let fixture = CovHWalletMainFixture()
        fixture.start(hosted: true)
        fixture.interactor.output?.didReceiveRecoveryCheckOffer(for: fixture.wallet)
        let sheet = try XCTUnwrap(fixture.router.sheets.last)

        sheet.actions.first?.handler?()
        sheet.dismissCompletion?()

        XCTAssertEqual(fixture.router.recoveryChecks, [fixture.wallet.metaId])
        XCTAssertEqual(fixture.interactor.recoveryOffersClosed, [fixture.wallet.metaId], "Offered once either way")
    }

    @MainActor
    func testAnOfferNoLongerDueIsNotShown() {
        let fixture = CovHWalletMainFixture()
        fixture.start(hosted: true)
        fixture.interactor.recoveryOfferDue = false
        let before = fixture.router.sheets.count
        fixture.interactor.output?.didReceiveRecoveryCheckOffer(for: fixture.wallet)
        XCTAssertEqual(fixture.router.sheets.count, before)
        XCTAssertTrue(fixture.interactor.recoveryOffersClosed.isEmpty)
    }

    @MainActor
    func testAnOfferForAnotherWalletIsIgnored() {
        let fixture = CovHWalletMainFixture()
        fixture.start(hosted: true)
        let before = fixture.router.sheets.count
        fixture.interactor.output?.didReceiveRecoveryCheckOffer(for: AccountGenerator.generateMetaAccount())
        XCTAssertEqual(fixture.router.sheets.count, before)
    }
}

/// The merge rule: with the flag off the build behaves like today, including the PIN's storage and
/// what an older App Store build finds after a downgrade.
final class ProtectedKeychainFlagOffParityTests: XCTestCase {
    override func tearDown() {
        Keychain.itemRouter = nil
        super.tearDown()
    }

    func testFlagIsOffInThisBuild() {
        XCTAssertFalse(ProtectedKeychainPolicy.isCompiledIn)
        XCTAssertFalse(ProtectedKeychainPolicy.isEnabled)
    }

    func testNewPinIsStoredAsTheDigitsAnOlderBuildReads() {
        let store = PinStoreDouble(value: nil)
        let saved = expectation(description: "saved")
        PinSaveCoordinator.shared.save("135790", using: store, isCurrent: { true }) { ok in
            XCTAssertTrue(ok)
            saved.fulfill()
        }
        wait(for: [saved], timeout: 10)
        XCTAssertEqual(store.value, "135790")
    }

    func testUnlockLeavesThePlainPinAsItIs() {
        let store = PinStoreDouble(value: "246802")
        let interactor = LocalAuthInteractor(
            secretManager: store,
            settingsManager: InMemorySettingsManager(),
            biometryAuth: ParityNoBiometry(),
            locale: Locale(identifier: "en"),
            attemptLimiter: PincodeAttemptLimiter(keystore: InMemoryKeychain()),
            enrollmentGuard: ParityEnrollment(),
            authorizedUnlock: WalletAuthorizedUnlock(notificationCenter: NotificationCenter())
        )
        let output = ParityOutput()
        let done = expectation(description: "unlocked")
        output.onComplete = { done.fulfill() }
        interactor.startAuth(with: output)
        interactor.process(pin: "246802")
        wait(for: [done], timeout: 10)
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        XCTAssertEqual(store.value, "246802")
    }

    func testNothingIsInstalledWhenNothingWasMoved() {
        Keychain.itemRouter = nil
        let authorizationWasAccepting = WalletSecretAuthorization.shared.isAccepting
        let coordinator = ProtectedWalletSecretCoordinator(
            isEnabled: { false },
            allWallets: { [] },
            notificationCenter: NotificationCenter(),
            logger: nil
        )
        coordinator.install(journal: { JournalDouble() }, protected: ProtectedBackendDouble())

        XCTAssertNil(Keychain.itemRouter, "Every keychain call goes where it always went")
        XCTAssertEqual(WalletSecretAuthorization.shared.isAccepting, authorizationWasAccepting)
        XCTAssertFalse(authorizationWasAccepting, "No evaluated context is ever kept")
    }

    func testImportWritesOnlyItemsAnOlderBuildReads() throws {
        let walletKeychain = Keychain(routed: false)
        var request = MetaAccountImportMnemonicRequest(
            mnemonic: try IRMnemonicCreator().mnemonic(fromList: ProtectedFixture.phrase),
            username: "parity",
            substrateDerivationPath: "",
            ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
            cryptoType: .sr25519,
            defaultChainId: nil
        )
        request.universalWalletEnrollment = .generated
        let operation = MetaAccountOperationFactory(
            keystore: walletKeychain,
            watchedAccounts: UniversalWalletWatchedAccountsStore(userDefaults: CovHAssetListFixture.defaults()),
            recoveryEvidence: ProtectedKeychainRecoveryEvidence(userDefaults: CovHAssetListFixture.defaults())
        ).newMetaAccountOperation(request: request, isBackuped: true)
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        let wallet = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        (operation as? PersistenceBoundKeychainOperation)?.commitKeychainChanges()
        let tags: [String] = WalletSecretTag.suffixes.map { wallet.metaId + $0 }.filter { tag in
            (try? walletKeychain.checkKey(for: tag)) == true
        }
        defer { tags.forEach { try? walletKeychain.deleteKey(for: $0) } }

        XCTAssertFalse(tags.isEmpty, "The secrets are the legacy key items every release reads")
        let protectedTags = try ProtectedKeychain().allAccounts().filter { WalletSecretTag.belongs($0, to: wallet.metaId) }
        XCTAssertEqual(protectedTags, [], "Nothing in the protected service")
        let journal = try KeychainProtectedWalletSecretJournal()
        XCTAssertNil(journal.record(for: wallet.metaId), "No journal entry")
    }

    /// Finding 8: the empty-install PIN cleanup decides exactly as the shipping build while
    /// protected storage is not in use, whatever the protected service answers.
    func testEmptyInstallPinCleanupMatchesTheShippingBuild() throws {
        struct Unreadable: Error {}
        let fails: () throws -> [String] = { throw Unreadable() }

        XCTAssertThrowsError(try EmergencyWalletMaterialReader.pinCleanupFindsNoWalletTags(
            legacy: fails, protected: { [] }, protectedInUse: { false }
        ), "Legacy inventory errors surface exactly as before")
        XCTAssertFalse(try EmergencyWalletMaterialReader.pinCleanupFindsNoWalletTags(
            legacy: { ["w-entropy"] }, protected: fails, protectedInUse: { false }
        ))
        XCTAssertTrue(try EmergencyWalletMaterialReader.pinCleanupFindsNoWalletTags(
            legacy: { [] }, protected: fails, protectedInUse: { false }
        ), "Flag off and nothing moved: the protected service cannot stop startup")
        XCTAssertTrue(try EmergencyWalletMaterialReader.pinCleanupFindsNoWalletTags(
            legacy: { [] }, protected: { [] }, protectedInUse: { false }
        ))

        XCTAssertFalse(try EmergencyWalletMaterialReader.pinCleanupFindsNoWalletTags(
            legacy: { [] }, protected: fails, protectedInUse: { true }
        ), "Protected storage in use and unreadable: the PIN stays")
        XCTAssertFalse(try EmergencyWalletMaterialReader.pinCleanupFindsNoWalletTags(
            legacy: { [] }, protected: { ["w-entropy"] }, protectedInUse: { true }
        ))
        XCTAssertFalse(ProtectedKeychainPolicy.isEnabled)
    }

    func testBiometricContextIsNotKeptWhileNothingIsProtected() {
        let authorization = WalletSecretAuthorization(notificationCenter: NotificationCenter())
        authorization.adopt(LAContext())
        XCTAssertNil(authorization.currentContext())
    }
}

private final class ParityNoBiometry: BiometryAuthProtocol {
    var availableBiometryType: AvailableBiometryType { .none }
    func authenticate(localizedReason _: String, completionQueue _: DispatchQueue, completionBlock _: @escaping (Bool) -> Void) {}
}

private final class ParityEnrollment: BiometryEnrollmentGuarding {
    func isCurrentEnrollmentTrusted() -> Bool { false }
    func trustCurrentEnrollment() {}
}

private final class ParityOutput: LocalAuthInteractorOutputProtocol {
    var onComplete: (() -> Void)?
    func didEnterWrongPincode() { XCTFail("wrong PIN") }
    func didCompleteAuth() { onComplete?() }
    func didChangeState(to _: LocalAuthInteractor.LocalAuthState) {}
    func didUnexpectedFail() { XCTFail("unexpected") }
}
