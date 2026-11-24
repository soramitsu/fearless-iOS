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
}

/// Step 1 of 3 on the main screen: one action, one warning, after the other notices; any close
/// counts as the one offer and changes nothing else.
final class ProtectedKeychainRecoveryOfferPresenterTests: XCTestCase {
    @MainActor
    func testNotNowRecordsTheOfferAndOpensNothing() throws {
        let fixture = CovHWalletMainFixture()
        fixture.start(hosted: true)

        fixture.interactor.output?.didReceiveRecoveryCheckOffer(for: fixture.wallet)
        let sheet = try XCTUnwrap(fixture.router.sheets.last)
        XCTAssertEqual(sheet.title, R.string.localizable.protectedRecoveryOfferTitle(preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages))
        XCTAssertEqual(sheet.actions.count, 1, "One action")

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
