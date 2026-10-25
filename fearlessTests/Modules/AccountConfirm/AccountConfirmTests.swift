import XCTest
@testable import fearless
import SoraKeystore
import Cuckoo
import IrohaCrypto
import RobinHood
import SoraFoundation
import UIKit
import SoraUI
import TonSwift
import struct SSFModels.Currency

class AccountConfirmTests: XCTestCase {

    func testEventCenterRemovalFromObserverDeinitDoesNotRetainObserver() {
        let syncQueue = DispatchQueue(label: "co.jp.soramitsu.fearless.tests.event-center")
        let eventCenter = EventCenter(syncQueue: syncQueue)
        weak var weakObserver: DeinitRemovingEventVisitor?

        autoreleasepool {
            var observer: DeinitRemovingEventVisitor? = DeinitRemovingEventVisitor(eventCenter: eventCenter)
            weakObserver = observer
            eventCenter.add(observer: observer!, dispatchIn: .main)
            syncQueue.sync {}

            observer = nil
        }

        XCTAssertNil(weakObserver)
        syncQueue.sync {}
    }

    func testBitcoinPhraseConfirmationPersistsBothAccountsUnderWalletRoot() throws {
        let storageFacade = UserDataStorageTestFacade()
        let settings = SelectedWalletSettings(
            storageFacade: storageFacade,
            operationQueue: OperationQueue()
        )
        let mnemonic = try IRMnemonicCreator().mnemonic(
            fromList: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        )
        let identityOperation = MetaAccountOperationFactory(keystore: InMemoryKeychain())
            .newMetaAccountOperation(
                request: MetaAccountImportMnemonicRequest(
                    mnemonic: mnemonic,
                    username: "Universal wallet",
                    substrateDerivationPath: "",
                    ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
                    cryptoType: .sr25519,
                    defaultChainId: nil
                ),
                isBackuped: true
            )
        identityOperation.start()
        let wallet = try identityOperation.extractResultData(
            throwing: BaseOperationError.parentOperationCancelled
        ).replacingChainAccounts([])
        let keychain = InMemoryKeychain()
        let request = ChainAccountImportMnemonicRequest(
            mnemonic: mnemonic,
            username: wallet.name,
            derivationPath: "",
            cryptoType: .sr25519,
            isEthereum: false,
            meta: wallet,
            chainId: UniversalWalletRegistry.bitcoinMainnet.chainId
        )
        let repository = AccountRepositoryFactory(storageFacade: storageFacade)
            .createMetaAccountRepository(for: nil, sortDescriptors: [])
        let eventCenter = MockEventCenterProtocol()
        let interactor = AccountConfirmInteractor(
            flow: .chain(request),
            accountOperationFactory: MetaAccountOperationFactory(keystore: keychain),
            accountRepository: AnyDataProviderRepository(repository),
            settings: settings,
            operationManager: OperationManager(),
            eventCenter: eventCenter
        )
        let presenter = MockAccountConfirmInteractorOutputProtocol()
        interactor.presenter = presenter
        let completion = expectation(description: "Bitcoin account persisted")
        completion.assertForOverFulfill = true
        var completionCount = 0
        var selectedAccountChangedCount = 0

        stub(presenter) { stub in
            when(stub.didCompleteConfirmation()).then {
                completionCount += 1
                completion.fulfill()
            }
            when(stub.didReceive(error: any(Error.self))).then { error in
                XCTFail("Unexpected Bitcoin account creation error: \(error)")
                completion.fulfill()
            }
        }
        stub(eventCenter) { stub in
            stub.notify(with: any()).then { event in
                if event is SelectedAccountChanged {
                    selectedAccountChangedCount += 1
                }
            }
        }

        interactor.confirm(words: mnemonic.allWords())
        interactor.confirm(words: mnemonic.allWords())

        wait(for: [completion], timeout: 10)
        XCTAssertEqual(completionCount, 1)
        XCTAssertEqual(selectedAccountChangedCount, 1)
        let updatedWallet = try XCTUnwrap(settings.value)
        let bitcoinAccount = try XCTUnwrap(
            updatedWallet.chainAccounts.first(where: {
                UniversalWalletChainAccountSupport.isValidBitcoinAccount($0)
            })
        )

        XCTAssertTrue(
            try keychain.checkKey(
                for: KeystoreTagV2.entropyTagForMetaId(wallet.metaId)
            )
        )
        XCTAssertFalse(
            try keychain.checkKey(
                for: KeystoreTagV2.entropyTagForMetaId(
                    wallet.metaId,
                    accountId: bitcoinAccount.accountId
                )
            )
        )
        XCTAssertTrue(
            UniversalWalletChainAccountSupport.hasValidDedicatedAccount(
                in: updatedWallet,
                for: UniversalWalletRegistry.taira.chainId
            )
        )
        XCTAssertEqual(
            try KeychainUniversalWalletMnemonicProvider(keystore: keychain)
                .mnemonic(
                    for: updatedWallet,
                    chain: UniversalWalletRegistry.bitcoinMainnetChainModel
                ),
            mnemonic.toString()
        )
    }

    func testMnemonicConfirm() throws {
        // given

        let view = MockAccountConfirmViewProtocol()
        let wireframe = MockAccountConfirmWireframeProtocol()

        let storageFacade = UserDataStorageTestFacade()

        let settings = SelectedWalletSettings(
            storageFacade: storageFacade,
            operationQueue: OperationQueue()
        )
        let keychain = InMemoryKeychain()

        let mnemonicWords = "great fog follow obtain oyster raw patient extend use mirror fix balance blame sudden vessel"

        let mnemonic = try IRMnemonicCreator().mnemonic(fromList: mnemonicWords)
        
        let newAccountRequest = MetaAccountImportMnemonicRequest(
            mnemonic: mnemonic,
            username: "myusername",
            substrateDerivationPath: "",
            ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
            cryptoType: .sr25519,
            defaultChainId: nil
        )

        let accountOperationFactory = MetaAccountOperationFactory(keystore: keychain)

        let repository = AccountRepositoryFactory(storageFacade: storageFacade)
            .createMetaAccountRepository(for: nil, sortDescriptors: [])

        let eventCenter = MockEventCenterProtocol()

        let flow: AccountConfirmFlow = .wallet(newAccountRequest)
        let interactor = AccountConfirmInteractor(flow: flow,
                                                  accountOperationFactory: accountOperationFactory,
                                                  accountRepository: AnyDataProviderRepository(repository),
                                                  settings: settings,
                                                  operationManager: OperationManager(),
                                                  eventCenter: eventCenter)

        let presenter = AccountConfirmPresenter(interactor: interactor,
                                                wireframe: wireframe,
                                                localizationManager: LocalizationManager.shared)
        interactor.presenter = presenter

        let setupExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub.controller.get).thenReturn(UIViewController())

            when(stub.didReceive(words: any([String].self), afterConfirmationFail: any(Bool.self))).then { _ in
                setupExpectation.fulfill()
            }
        }

        let expectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub.proceed(from: any(AccountConfirmViewProtocol?.self),
                               flow: any(AccountConfirmFlow?.self))).then { _ in
                expectation.fulfill()
            }
        }

        let completeExpectation = XCTestExpectation()

        stub(eventCenter) { stub in
            stub.notify(with: any()).then { event in
                if event is SelectedAccountChanged {
                    completeExpectation.fulfill()
                }
            }
        }

        // when

        presenter.didLoad(view: view)

        wait(for: [setupExpectation], timeout: Constants.defaultExpectationDuration)

        presenter.confirm(words: mnemonic.allWords())

        // then

        wait(for: [expectation, completeExpectation], timeout: 10)

        guard let selectedAccount = settings.value else {
            XCTFail("Unexpected empty account")
            return
        }

        XCTAssertEqual(selectedAccount.name, newAccountRequest.username)

        let metaId = selectedAccount.metaId

        XCTAssertTrue(try keychain.checkKey(for: KeystoreTagV2.entropyTagForMetaId(metaId)))

        XCTAssertFalse(try keychain.checkKey(for: KeystoreTagV2.substrateDerivationTagForMetaId(metaId)))
        XCTAssertTrue(try keychain.checkKey(for: KeystoreTagV2.ethereumDerivationTagForMetaId(metaId)))

        XCTAssertTrue(try keychain.checkKey(for: KeystoreTagV2.substrateSecretKeyTagForMetaId(metaId)))
        XCTAssertTrue(try keychain.checkKey(for: KeystoreTagV2.ethereumSecretKeyTagForMetaId(metaId)))

        XCTAssertTrue(try keychain.checkKey(for: KeystoreTagV2.substrateSeedTagForMetaId(metaId)))
        XCTAssertTrue(try keychain.checkKey(for: KeystoreTagV2.ethereumSeedTagForMetaId(metaId)))

        let appOwnedAccounts = selectedAccount.chainAccounts.filter {
            UniversalWalletChainAccountSupport.chainId(
                $0.chainId,
                matches: UniversalWalletRegistry.bitcoinMainnet.chainId
            ) || UniversalWalletChainAccountSupport.chainId(
                $0.chainId,
                matches: UniversalWalletRegistry.taira.chainId
            )
        }
        XCTAssertEqual(appOwnedAccounts.count, 2)
        for account in appOwnedAccounts {
            XCTAssertFalse(
                try keychain.checkKey(
                    for: KeystoreTagV2.entropyTagForMetaId(
                        metaId,
                        accountId: account.accountId
                    )
                )
            )
        }
    }
}

private final class DeinitRemovingEventVisitor: EventVisitorProtocol {
    private let eventCenter: EventCenterProtocol

    init(eventCenter: EventCenterProtocol) {
        self.eventCenter = eventCenter
    }

    deinit {
        eventCenter.remove(observer: self)
    }
}

@MainActor
final class AccountConfirmPresentationTests: XCTestCase {
    private let languages = ["en", "ru", "ja", "zh-Hans", "id", "pt-PT", "tr", "vi"]
    private let categories: [UIContentSizeCategory] = [.large, .accessibilityExtraExtraExtraLarge]

    private final class Presenter: AccountConfirmPresenterProtocol {
        weak var view: AccountConfirmViewProtocol?
        var loaded = 0
        var resets = 0
        var skips = 0
        var confirmed: [[String]] = []
        var resetWords: [String] = []
        func didLoad(view: AccountConfirmViewProtocol) { self.view = view; loaded += 1 }
        func requestWords() { resets += 1; view?.didReceive(words: resetWords, afterConfirmationFail: false) }
        func confirm(words: [String]) { confirmed.append(words) }
        func skip() { skips += 1 }
    }

    func testConfirmationBaselineAllLocalesAndTypeSizes() async throws {
        for language in languages {
            for category in categories {
                let localization = try XCTUnwrap(LocalizationManager(localization: language))
                let presenter = Presenter()
                let controller = makeController(presenter, localization: localization, skip: true)
                let window = try show(controller, category: category)
                defer { close(window) }
                let words = fixtures("fixture", count: 24)
                controller.didReceive(words: words, afterConfirmationFail: false)
                await settle(window)
                let buttons = wordButtons(controller)
                XCTAssertEqual(buttons.compactMap { $0.imageWithTitleView?.title }, words)
                XCTAssertEqual(presenter.loaded, 1)
                let name = language + "-" + category.rawValue
                capture(window, name: name + "-top")
                if FWAppearance.accountConfirmRestyled { assertWordLayout(buttons) }
                for button in buttons {
                    let expectedFont = FWAppearance.accountConfirmRestyled
                        ? UIFont.fw(
                            .phraseWord,
                            locale: localization.selectedLocale,
                            compatibleWith: button.traitCollection
                        )
                        : UIFont.p1Paragraph
                    XCTAssertEqual(
                        button.imageWithTitleView?.titleFont?.pointSize ?? 0,
                        expectedFont.pointSize,
                        accuracy: 0.1
                    )
                }
                let scroll = try scrollView(controller)
                scroll.setContentOffset(
                    CGPoint(x: 0, y: max(0, scroll.contentSize.height - scroll.bounds.height)),
                    animated: false
                )
                await settle(window)
                capture(window, name: name + "-pending")
                let next = try nextButton(controller, locale: localization.selectedLocale)
                XCTAssertFalse(next.isEnabled)
                XCTAssertFalse(next.accessibilityActivate())
                for (index, action) in descendants(controller.view).compactMap({ $0 as? TriangularedButton })
                    .enumerated()
                {
                    if FWAppearance.accountConfirmRestyled {
                        assertVisibleLabelsFit(action)
                        XCTAssertGreaterThanOrEqual(action.bounds.height, 44)
                    }
                    await reveal(action, in: window, scroll: nil)
                    capture(window, name: name + "-action-\(index)")
                }
                for button in buttons.prefix(3) { await activate(button, in: window, scroll: scroll) }
                scroll.setContentOffset(.zero, animated: false)
                await settle(window)
                capture(window, name: name + "-selected")
                let skip = try XCTUnwrap(
                    descendants(controller.view).compactMap { $0 as? TriangularedButton }
                        .first { $0 !== next }
                )
                await activate(skip, in: window, scroll: nil)
                XCTAssertEqual(presenter.skips, 1)
                XCTAssertTrue(presenter.confirmed.isEmpty)
            }
        }
    }

    func testSelectionOrderDeselectResetAndRetryPreserveCallbacks() async throws {
        let localization = try XCTUnwrap(LocalizationManager(localization: "en"))
        let presenter = Presenter()
        let controller = makeController(presenter, localization: localization, skip: false)
        let window = try show(controller, category: .large)
        defer { close(window) }
        let words = fixtures("fixture", count: 12)
        controller.didReceive(words: words, afterConfirmationFail: false)
        await settle(window)
        let scroll = try scrollView(controller)
        let next = try nextButton(controller, locale: localization.selectedLocale)
        let buttons = wordButtons(controller)
        XCTAssertEqual(descendants(controller.view).compactMap { $0 as? TriangularedButton }.count, 1)
        let order = [11] + Array(0 ..< 11)
        for index in order { await activate(buttons[index], in: window, scroll: scroll) }
        XCTAssertTrue(next.isEnabled)
        await activate(buttons[3], in: window, scroll: scroll)
        XCTAssertFalse(next.isEnabled)
        await activate(buttons[3], in: window, scroll: scroll)
        XCTAssertTrue(next.isEnabled)
        capture(window, name: "all-selected-reordered")
        await activate(next, in: window, scroll: nil)
        let expected = order.filter { $0 != 3 }.map { words[$0] } + [words[3]]
        XCTAssertEqual(presenter.confirmed, [expected])
        presenter.resetWords = fixtures("reset", count: 12)
        let retry = try XCTUnwrap(controller.navigationItem.rightBarButtonItem?.customView as? UIButton)
        await activate(retry, in: window, scroll: nil)
        await settle(window)
        XCTAssertEqual(presenter.resets, 1)
        XCTAssertEqual(wordButtons(controller).compactMap { $0.imageWithTitleView?.title }, presenter.resetWords)
        XCTAssertFalse(next.isEnabled)
        let retryWords = fixtures("retry", count: 12)
        controller.didReceive(words: retryWords, afterConfirmationFail: true)
        await settle(window)
        XCTAssertEqual(wordButtons(controller).compactMap { $0.imageWithTitleView?.title }, retryWords)
        XCTAssertFalse(next.isEnabled)
        XCTAssertEqual(presenter.confirmed, [expected])
        capture(window, name: "after-failed-confirmation-rebind")
        controller.didReceive(words: [], afterConfirmationFail: false)
        await settle(window)
        XCTAssertTrue(wordButtons(controller).isEmpty)
        XCTAssertFalse(next.isEnabled)
        XCTAssertFalse(next.accessibilityActivate())
        capture(window, name: "empty-rebind")
    }

    func testLiveLocaleTypeAndWidthPreserveSelection() async throws {
        let localization = try XCTUnwrap(LocalizationManager(localization: "en"))
        let presenter = Presenter()
        let controller = makeController(presenter, localization: localization, skip: true)
        let window = try show(controller, category: .large)
        defer { close(window) }
        let words = fixtures("fixture", count: 12)
        controller.didReceive(words: words, afterConfirmationFail: false)
        await settle(window)
        let buttons = wordButtons(controller)
        let scroll = try scrollView(controller)
        for button in buttons.prefix(2) { await activate(button, in: window, scroll: scroll) }
        localization.selectedLocalization = "ja"
        if #available(iOS 17.0, *) {
            window.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        }
        controller.applyLocalization()
        await settle(window)
        XCTAssertEqual(presenter.loaded, 1)
        XCTAssertEqual(wordButtons(controller), buttons)
        for button in buttons {
            XCTAssertEqual(
                button.imageWithTitleView?.titleFont?.pointSize ?? 0,
                UIFont.fw(.phraseWord, locale: localization.selectedLocale, compatibleWith: button.traitCollection)
                    .pointSize,
                accuracy: 0.1
            )
        }
        let next = try nextButton(controller, locale: localization.selectedLocale)
        XCTAssertFalse(next.isEnabled)
        XCTAssertEqual(
            controller.navigationItem.rightBarButtonItem?.customView?.accessibilityLabel,
            R.string.localizable.commonReset(preferredLanguages: ["ja"])
        )
        for width: CGFloat in [640, 320] {
            window.frame.size.width = width
            window.setNeedsLayout()
            await settle(window)
            assertWordLayout(buttons)
            capture(window, name: "live-ja-AX5-width-\(Int(width))")
        }
        await activate(buttons[0], in: window, scroll: scroll)
        XCTAssertFalse(next.isEnabled)
        let initialWordFont = try XCTUnwrap(buttons.first?.imageWithTitleView?.titleFont)
        if #available(iOS 17.0, *) { window.traitOverrides.legibilityWeight = .bold }
        await settle(window)
        let initialTraits = try XCTUnwrap(initialWordFont.fontDescriptor
            .object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any])
        let initialWeight = try XCTUnwrap(initialTraits[.weight] as? NSNumber).doubleValue
        // iOS 18 resolves a later reference font differently from the font applied during trait change.
        // Assert the visible Bold Text contract and its reversal, rather than that later font's name.
        for button in buttons {
            let font = try XCTUnwrap(button.imageWithTitleView?.titleFont)
            let traits = try XCTUnwrap(font.fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any])
            XCTAssertEqual(button.traitCollection.legibilityWeight, .bold)
            XCTAssertGreaterThan(try XCTUnwrap(traits[.weight] as? NSNumber).doubleValue, initialWeight)
            XCTAssertEqual(font.pointSize, initialWordFont.pointSize, accuracy: 0.1)
        }
        assertWordLayout(buttons)
        capture(window, name: "live-ja-AX5-bold-after-deselect")
        if #available(iOS 17.0, *) { window.traitOverrides.legibilityWeight = .regular }
        await settle(window)
        for button in buttons { XCTAssertEqual(button.imageWithTitleView?.titleFont, initialWordFont) }
        assertWordLayout(buttons)
        capture(window, name: "live-ja-AX5-regular-restored")
        await activate(buttons[0], in: window, scroll: scroll)
        for button in buttons.dropFirst(2) { await activate(button, in: window, scroll: scroll) }
        XCTAssertTrue(next.isEnabled)
        await activate(next, in: window, scroll: nil)
        XCTAssertEqual(presenter.confirmed, [[words[1], words[0]] + Array(words.dropFirst(2))])
    }

    func testOversizedSyntheticWordDoesNotHideFollowingChoices() async throws {
        let localization = try XCTUnwrap(LocalizationManager(localization: "en"))
        let controller = makeController(Presenter(), localization: localization, skip: false)
        let window = try show(controller, category: .accessibilityExtraExtraExtraLarge)
        defer { close(window) }
        let words = ["fixture01", String(repeating: "synthetic", count: 8), "fixture03"]
        controller.didReceive(words: words, afterConfirmationFail: false)
        await settle(window)
        let buttons = wordButtons(controller)
        XCTAssertEqual(buttons.compactMap { $0.imageWithTitleView?.title }, words)
        assertWordLayout(buttons)
        let scroll = try scrollView(controller)
        let wordFrame = buttons[1].convert(buttons[1].bounds, to: scroll)
        let maximumOffset = max(0, scroll.contentSize.height - scroll.bounds.height)
        for (index, offset) in [wordFrame.minY, wordFrame.midY - scroll.bounds.height / 2, maximumOffset].enumerated() {
            scroll.setContentOffset(CGPoint(x: 0, y: min(maximumOffset, max(0, offset))), animated: false)
            await settle(window)
            capture(window, name: "oversized-synthetic-word-\(index)")
        }
    }

    func testDuplicateWordIdentityAndAccessibleActivationKeepExactOrder() async throws {
        let localization = try XCTUnwrap(LocalizationManager(localization: "en"))
        let presenter = Presenter()
        let controller = makeController(presenter, localization: localization, skip: false)
        let window = try show(controller, category: .large)
        defer { close(window) }
        let words = ["fixtureRepeat", "fixtureRepeat", "fixtureOther"]
        controller.didReceive(words: words, afterConfirmationFail: false)
        await settle(window)
        let buttons = wordButtons(controller)
        let next = try nextButton(controller, locale: localization.selectedLocale)
        XCTAssertEqual(buttons.map(\.accessibilityLabel), words.map { Optional($0) })
        XCTAssertTrue(buttons.allSatisfy { $0.accessibilityTraits.contains(.button) })
        buttons[0].isEnabled = false
        XCTAssertFalse(buttons[0].accessibilityActivate())
        buttons[0].isEnabled = true
        for index in [1, 0, 1, 2, 1] {
            XCTAssertTrue(buttons[index].accessibilityActivate())
            await settle(window)
        }
        XCTAssertTrue(next.isEnabled)
        await activate(next, in: window, scroll: nil)
        XCTAssertEqual(presenter.confirmed, [[words[0], words[2], words[1]]])
        capture(window, name: "duplicate-identity-and-accessible-activation")
    }


    // Public IC07 fixtures written by historical iOS 4.0.4; expectations are not RC-derived.
    private let historicalCanonicalTonPhrase = "cluster notice abandon frost gospel boring element situate click mix vague replace imitate garment useful crater resource dose tenant theme foam ancient phrase slight"

    func testHistoricalDoubleSpaceConfirmationHasNoBlankChoice() async throws {
        try await assertHistoricalConfirmationChoices(
            phrase: historicalCanonicalTonPhrase.replacingOccurrences(of: "abandon frost", with: "abandon  frost"),
            address: "UQDvaKHy6izOBPGdot4wtkje_R2PF_RQl86qPA3e4p3-P84h",
            publicKey: "2d4279cae4f717c80f4b56f4d67b6c189d5fcd260a2a75673c8014fd41da2ea3", name: "double-space"
        )
    }

    func testHistoricalTrailingSpaceConfirmationHasNoBlankChoice() async throws {
        try await assertHistoricalConfirmationChoices(
            phrase: historicalCanonicalTonPhrase + " ", address: "UQCzKbSV4o5EZJ1V0Ld9VpWUAwyLfNv4gyx00SeEFg1rtZEY",
            publicKey: "f14148c55ccec237ef9d9f23b42e7e76faf019814c5001326433c7e64c09abcb", name: "trailing-space"
        )
    }

    func testHistoricalLeadingSpaceConfirmationHasNoBlankChoice() async throws {
        try await assertHistoricalConfirmationChoices(
            phrase: " " + historicalCanonicalTonPhrase, address: "UQDOGZbd-5sN775xG9AiCozK4jM5lpdLfj_khrp9NAc4Nm50",
            publicKey: "b9588e31c14c27cb4826927f2b8a0a0037823e7c619391bfc1435aa5d73930c7", name: "leading-space"
        )
    }

    func testHistoricalLineBreakConfirmationNamesItsSignificantSeparator() async throws {
        try await assertHistoricalConfirmationChoices(
            phrase: historicalCanonicalTonPhrase.replacingOccurrences(of: "replace imitate", with: "replace\nimitate"),
            address: "UQCUK6IuxFKqWmDLauEd_NAekoFIF0Wk0ZtgCReipRp_qY5N",
            publicKey: "b16e6d3125e0112bd863148b12cf978beb31d6a54bb21998fea1a0d6cf8eebef", name: "line-break"
        )
    }

    func testHistoricalRepeatedEmptyChoicesRemainReadable() async throws {
        try await assertHistoricalConfirmationChoices(
            phrase: historicalCanonicalTonPhrase.replacingOccurrences(of: "abandon frost", with: "abandon  frost")
                .replacingOccurrences(of: "click mix", with: "click  mix") + " ",
            address: "UQDAvPv3OlQQnILPvED5YznIIVJVsbyhpsTNHfuOIh6jDv9q",
            publicKey: "3a549170be054e76b1dec7ec3f8e64724f1946d9681eeb8038176a9744598c1f", name: "repeated-space"
        )
    }

    func testCanonicalTonFactoryConfirmsUsingActualChoices() async throws {
        let native = try LegacyNativeTonFixture.account()
        let wallet = tonConfirmationWallet(native)
        let mnemonic = LegacyTonMnemonic(phrase: historicalCanonicalTonPhrase)
        let settings = SelectedWalletSettings(storageFacade: UserDataStorageTestFacade(), operationQueue: OperationQueue())
        let controller = try XCTUnwrap(ExportMnemonicConfirmViewFactory.createViewForMnemonic(
            mnemonic, wallet: wallet, backupProof: nil, settings: settings
        )?.controller as? AccountConfirmViewController)
        let presenter = try XCTUnwrap(controller.presenter as? AccountConfirmPresenter)
        let wireframe = MockAccountConfirmWireframeProtocol()
        var completions = 0
        stub(wireframe) { stub in
            when(stub.proceed(from: any(AccountConfirmViewProtocol?.self), flow: any(AccountConfirmFlow?.self)))
                .then { _ in completions += 1 }
        }
        presenter.wireframe = wireframe
        let window = try show(controller, category: .large)
        defer { close(window) }
        await settle(window)
        let scroll = try scrollView(controller)
        var choices = wordButtons(controller)
        XCTAssertEqual(choices.count, mnemonic.allWords().count)
        for word in mnemonic.allWords() {
            let index = try XCTUnwrap(choices.firstIndex { $0.imageWithTitleView?.title == word })
            await activate(choices.remove(at: index), in: window, scroll: scroll)
        }
        let confirm = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? TriangularedButton }.first)
        XCTAssertTrue(confirm.isEnabled)
        capture(window, name: "ton-canonical-correct-sequence")
        await activate(confirm, in: window, scroll: nil)
        XCTAssertEqual(completions, 1)
        XCTAssertNil(settings.value, "Unproven confirmation must not mark or select a wallet")
        XCTAssertEqual(mnemonic.entropy(), Data(historicalCanonicalTonPhrase.utf8))
    }


    private final class ExportConfirmationWireframe: AccountConfirmWireframeProtocol {
        var completed = 0
        var mismatches = 0
        func proceed(from _: AccountConfirmViewProtocol?, flow _: AccountConfirmFlow?) { completed += 1 }
        func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool { true }
        func present(message _: String?, title _: String, closeAction _: String?, from _: ControllerBackedProtocol?, actions _: [SheetAlertPresentableAction]) { mismatches += 1 }
    }

    private func expectedConfirmationTitle(_ word: String, locale: Locale) -> String {
        let languages = locale.rLanguages
        if word.isEmpty { return "[" + R.string.localizable.confirmationExactEmpty(preferredLanguages: languages) + "]" }
        return word.replacingOccurrences(of: "\n", with: " [" + R.string.localizable.confirmationExactLineBreak(preferredLanguages: languages) + "] ")
            .replacingOccurrences(of: "\t", with: " [" + R.string.localizable.confirmationExactTab(preferredLanguages: languages) + "] ")
            .replacingOccurrences(of: "\r", with: " [" + R.string.localizable.confirmationExactCarriageReturn(preferredLanguages: languages) + "] ")
            .replacingOccurrences(of: "\u{00a0}", with: " [U+00A0] ")
    }

    func testSignificantWhitespaceNamesAcrossLocalesAndSizesRetainExactTokens() async throws {
        // Synthetic display-only controls extend the historical LF/empty cases to TAB/CR/NBSP.
        let words = ["", "before\nafter", "before\tafter", "before\rafter", "\u{00a0}", "", "repeat"]
        for language in languages {
            for category in categories {
                let localization = try XCTUnwrap(LocalizationManager(localization: language))
                let presenter = Presenter()
                let controller = makeController(presenter, localization: localization, skip: false)
                controller.showsExactMnemonicSpacing = true
                let window = try show(controller, category: category)
                defer { close(window) }
                controller.didReceive(words: words, afterConfirmationFail: false)
                await settle(window)
                let choices = wordButtons(controller)
                XCTAssertEqual(choices.map { $0.imageWithTitleView?.title }, words.map { Optional(expectedConfirmationTitle($0, locale: localization.selectedLocale)) })
                XCTAssertEqual(choices.map(\.accessibilityLabel), choices.map { $0.imageWithTitleView?.title })
                assertWordLayout(choices)
                let scroll = try scrollView(controller)
                for (index, choice) in choices.enumerated() {
                    await reveal(choice, in: window, scroll: scroll)
                    capture(window, name: "ton-spacing-\(language)-\(category.rawValue)-\(index)")
                    await activate(choice, in: window, scroll: scroll)
                }
                // Distinct empty choices retain distinct controls despite identical labels.
                await activate(choices[0], in: window, scroll: scroll)
                let next = try nextButton(controller, locale: localization.selectedLocale)
                XCTAssertFalse(next.isEnabled)
                await activate(choices[0], in: window, scroll: scroll)
                await activate(next, in: window, scroll: nil)
                XCTAssertEqual(presenter.confirmed, [Array(words.dropFirst()) + [words[0]]])
            }
        }
    }

    func testLiveSpacingLocaleAndStaleResetControlCannotChangeRawConfirmation() async throws {
        let localization = try XCTUnwrap(LocalizationManager(localization: "en"))
        let presenter = Presenter()
        let controller = makeController(presenter, localization: localization, skip: false)
        controller.showsExactMnemonicSpacing = true
        let window = try show(controller, category: .large)
        defer { close(window) }
        let words = ["", "left\tright", "tail"]
        presenter.resetWords = words
        controller.didReceive(words: words, afterConfirmationFail: false)
        await settle(window)
        let old = wordButtons(controller)
        let scroll = try scrollView(controller)
        await activate(old[0], in: window, scroll: scroll)
        localization.selectedLocalization = "ru"
        controller.applyLocalization()
        await settle(window)
        XCTAssertEqual(wordButtons(controller), old)
        XCTAssertEqual(old[0].accessibilityLabel, expectedConfirmationTitle("", locale: localization.selectedLocale))
        let reset = try XCTUnwrap(controller.navigationItem.rightBarButtonItem?.customView as? UIButton)
        await activate(reset, in: window, scroll: nil)
        let next = try nextButton(controller, locale: localization.selectedLocale)
        old.forEach { $0.sendActions(for: .touchUpInside) }
        XCTAssertFalse(next.isEnabled)
        let fresh = wordButtons(controller)
        XCTAssertFalse(fresh.contains { old.contains($0) })
        for choice in fresh { await activate(choice, in: window, scroll: scroll) }
        await activate(next, in: window, scroll: nil)
        XCTAssertEqual(presenter.confirmed, [words])
    }

    func testActualHistoricalFactoryInstructionIsFullyReachableAtLargestTextInEveryLocale() async throws {
        let phrase = historicalCanonicalTonPhrase + " "
        let mnemonic = LegacyTonMnemonic(phrase: phrase)
        let native = try LegacyTonAccount(
            serializedAddress: JSONEncoder().encode(TonSwift.Address.parse("UQCzKbSV4o5EZJ1V0Ld9VpWUAwyLfNv4gyx00SeEFg1rtZEY")),
            publicKey: Data(hexStringSSF: "f14148c55ccec237ef9d9f23b42e7e76faf019814c5001326433c7e64c09abcb"), contractVersion: "v4R2"
        )
        for language in languages {
            let localization = try XCTUnwrap(LocalizationManager(localization: language))
            let settings = SelectedWalletSettings(storageFacade: UserDataStorageTestFacade(), operationQueue: OperationQueue())
            let controller = try XCTUnwrap(ExportMnemonicConfirmViewFactory.createViewForMnemonic(
                mnemonic, wallet: tonConfirmationWallet(native), backupProof: nil, settings: settings
            )?.controller as? AccountConfirmViewController)
            controller.localizationManager = localization
            let window = try show(controller, category: .accessibilityExtraExtraExtraLarge)
            defer { close(window) }
            await settle(window)
            XCTAssertTrue(controller.showsExactMnemonicSpacing)
            XCTAssertEqual(controller.traitCollection.preferredContentSizeCategory, .accessibilityExtraExtraExtraLarge)
            let expected = R.string.localizable.confirmationExactDetails(preferredLanguages: [language])
            let instruction = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? UILabel }.first { $0.text == expected })
            XCTAssertEqual(instruction.numberOfLines, 0)
            XCTAssertFalse(instruction.adjustsFontSizeToFitWidth)
            XCTAssertFalse(instruction.isHidden)
            XCTAssertGreaterThan(instruction.alpha, 0)
            let fitting = instruction.sizeThatFits(CGSize(width: instruction.bounds.width, height: .greatestFiniteMagnitude))
            XCTAssertGreaterThan(fitting.height, instruction.font.lineHeight)
            XCTAssertLessThanOrEqual(fitting.height, instruction.bounds.height + 0.5, "Entire localized instruction must fit its label")
            if FWAppearance.accountConfirmRestyled {
                XCTAssertEqual(instruction.font, UIFont.fw(.bodyL, locale: localization.selectedLocale, compatibleWith: instruction.traitCollection))
            }
            let scroll = try scrollView(controller)
            let visibleViewport = scroll.convert(scroll.bounds, to: window).intersection(window.bounds)
            // Check every vertical slice, not just the heading or the last line of a tall label.
            let sliceHeight = min(instruction.font.lineHeight * 2, visibleViewport.height / 2)
            XCTAssertGreaterThan(sliceHeight, 0)
            var sliceY: CGFloat = 0
            var sliceIndex = 0
            while sliceY < instruction.bounds.height {
                let slice = CGRect(x: 0, y: sliceY, width: instruction.bounds.width,
                                   height: min(sliceHeight, instruction.bounds.height - sliceY))
                scroll.scrollRectToVisible(instruction.convert(slice, to: scroll), animated: false)
                await settle(window)
                let visibleSlice = instruction.convert(slice, to: window)
                XCTAssertGreaterThanOrEqual(visibleSlice.minY, visibleViewport.minY - 0.5)
                XCTAssertLessThanOrEqual(visibleSlice.maxY, visibleViewport.maxY + 0.5)
                XCTAssertGreaterThanOrEqual(visibleSlice.minX, visibleViewport.minX - 0.5)
                XCTAssertLessThanOrEqual(visibleSlice.maxX, visibleViewport.maxX + 0.5)
                capture(window, name: "ton-instruction-\(language)-AX5-restyled-\(FWAppearance.accountConfirmRestyled)-slice-\(sliceIndex)")
                sliceY += sliceHeight
                sliceIndex += 1
            }
            let choices = wordButtons(controller)
            assertWordLayout(choices)
            for choice in choices {
                XCTAssertTrue(choice is AccountConfirmWordButton)
                let expectedFont: UIFont = FWAppearance.accountConfirmRestyled
                    ? .fw(.phraseWord, locale: localization.selectedLocale, compatibleWith: choice.traitCollection)
                    : .legacySora(size: 14, weight: .regular, textStyle: .callout, compatibleWith: choice.traitCollection)
                XCTAssertEqual(choice.imageWithTitleView?.titleFont, expectedFont)
                for label in descendants(choice).compactMap({ $0 as? UILabel }).filter({ isVisible($0) }) {
                    XCTAssertEqual(label.font, expectedFont, "The actual displayed word must use the compiled mode's font")
                }
            }
            let confirm = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? TriangularedButton }.first)
            await reveal(confirm, in: window, scroll: nil)
            capture(window, name: "ton-instruction-\(language)-AX5-restyled-\(FWAppearance.accountConfirmRestyled)-confirm-footer")
            assertVisibleLabelsFit(confirm)
            let footerFrame = confirm.convert(confirm.bounds, to: window)
            let geometry = XCTAttachment(string: "footer=\(footerFrame); window=\(window.bounds); scale=\(window.screen.scale)")
            geometry.name = "confirm-footer-geometry-\(language)-restyled-\(FWAppearance.accountConfirmRestyled)"
            geometry.lifetime = .keepAlways
            add(geometry)
            // UIKit coordinate conversion can leave sub-pixel floating-point residue at an exact edge.
            let physicalPixel: (CGFloat) -> CGFloat = { ($0 * window.screen.scale).rounded() }
            XCTAssertGreaterThanOrEqual(physicalPixel(footerFrame.minX), 0)
            XCTAssertLessThanOrEqual(physicalPixel(footerFrame.maxX), physicalPixel(window.bounds.width))
            XCTAssertGreaterThanOrEqual(physicalPixel(footerFrame.minY), 0)
            XCTAssertLessThanOrEqual(physicalPixel(footerFrame.maxY), physicalPixel(window.bounds.height))
            XCTAssertGreaterThanOrEqual(footerFrame.height, 44)
            let empty = try XCTUnwrap(choices.first { $0.accessibilityLabel == expectedConfirmationTitle("", locale: localization.selectedLocale) })
            await reveal(empty, in: window, scroll: scroll)
            capture(window, name: "ton-instruction-\(language)-AX5-restyled-\(FWAppearance.accountConfirmRestyled)-empty-choice")
            await activate(empty, in: window, scroll: scroll)
            XCTAssertEqual(mnemonic.entropy(), Data(phrase.utf8))
            XCTAssertNil(settings.value)
        }
    }

    func testOrdinaryFactoryHeadingIsCompleteAcrossLocalesAndTextSizes() async throws {
        for language in languages {
            for category in categories {
                let fixture = try ordinaryTextFixture(language: language, creating: true)
                let window = try show(fixture.controller, category: category)
                defer { close(window) }
                await settle(window)
                let heading = try XCTUnwrap(descendants(window).compactMap { $0 as? UILabel }
                    .first { $0.text == fixture.controller.title && self.isVisible($0) })
                let expected: UIFont = FWAppearance.accountConfirmRestyled
                    ? .fw(.titleL, locale: Locale(identifier: language), compatibleWith: heading.traitCollection)
                    : .legacySora(size: 18, weight: .bold, textStyle: .title3, compatibleWith: heading.traitCollection)
                XCTAssertEqual(heading.font.fontName, expected.fontName)
                XCTAssertEqual(heading.font.pointSize, expected.pointSize, accuracy: 0.01, "Actual displayed heading must follow its current traits")
                XCTAssertTrue(heading.accessibilityTraits.contains(.header))
                assertCompleteLabel(heading)
                try await assertLabelSlicesReachable(heading, controller: fixture.controller, window: window,
                                                    name: "ordinary-heading-\(language)-\(category.rawValue)")
                XCTAssertNil(fixture.settings.value)
            }
        }
    }

    func testOrdinaryFactoryInstructionScalesAndRemainsFullyReachable() async throws {
        for language in languages {
            for category in categories {
                let fixture = try ordinaryTextFixture(language: language, creating: false)
                let window = try show(fixture.controller, category: category)
                defer { close(window) }
                await settle(window)
                let expectedText = R.string.localizable.accountConfirmationDetails(preferredLanguages: [language])
                let instruction = try XCTUnwrap(descendants(fixture.controller.view).compactMap { $0 as? UILabel }
                    .first { $0.text == expectedText })
                let expected: UIFont = FWAppearance.accountConfirmRestyled
                    ? .fw(.bodyL, locale: Locale(identifier: language), compatibleWith: instruction.traitCollection)
                    : .legacySora(size: 16, weight: .regular, textStyle: .body, compatibleWith: instruction.traitCollection)
                XCTAssertEqual(instruction.font.fontName, expected.fontName)
                XCTAssertEqual(instruction.font.pointSize, expected.pointSize, accuracy: 0.01, "Actual instruction must respect the requested text size")
                XCTAssertEqual(instruction.numberOfLines, 0)
                assertCompleteLabel(instruction)
                try await assertLabelSlicesReachable(instruction, controller: fixture.controller, window: window,
                                                    name: "ordinary-instruction-\(language)-\(category.rawValue)")
                XCTAssertNil(fixture.settings.value)
            }
        }
    }

    func testValidPhrasePendingAndSelectedWordsRemainFullyReachableAtLargestText() async throws {
        for creating in [true, false] {
            let fixture = try ordinaryTextFixture(language: "en", creating: creating)
            let controller = fixture.controller
            let window = try show(controller, category: .accessibilityExtraExtraExtraLarge)
            defer { close(window) }
            window.traitCollection.performAsCurrent {
                controller.didReceive(words: fixture.words, afterConfirmationFail: false)
            }
            await settle(window)
            let choices = wordButtons(controller)
            assertWordLayout(choices)
            XCTAssertEqual(choices.compactMap { $0.imageWithTitleView?.title }, fixture.words)
            let scroll = try scrollView(controller)
            for (index, choice) in choices.enumerated() {
                try await assertChoiceReadable(choice, controller: controller, window: window,
                                               name: "valid-phrase-\(creating)-pending-\(index)")
                await activate(choice, in: window, scroll: scroll, dispatchWithDisplayedTraits: true)
            }
            for (index, choice) in choices.enumerated() {
                try await assertChoiceReadable(choice, controller: controller, window: window,
                                               name: "valid-phrase-\(creating)-selected-\(index)")
            }
            let next = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? TriangularedButton }
                .first { $0.imageWithTitleView?.title == controller.nextButtonTitle.value(for: Locale(identifier: "en")) })
            XCTAssertTrue(next.isEnabled)
            await activate(next, in: window, scroll: nil, dispatchWithDisplayedTraits: true)
            XCTAssertEqual(fixture.presenter.confirmed, [fixture.words])
            fixture.presenter.resetWords = fixture.words
            let reset = try XCTUnwrap(controller.navigationItem.rightBarButtonItem?.customView as? UIButton)
            await activate(reset, in: window, scroll: nil, dispatchWithDisplayedTraits: true)
            XCTAssertEqual(fixture.presenter.resets, 1)
            XCTAssertFalse(next.isEnabled)
            XCTAssertFalse(wordButtons(controller).contains { choices.contains($0) })
            XCTAssertNil(fixture.settings.value)
        }
    }

    func testOrdinaryFactoryLiveTextKeepsHeadingSelectionAndNativeBack() async throws {
        let fixture = try ordinaryTextFixture(language: "en", creating: true)
        let controller = fixture.controller
        let window = try show(controller, category: .large)
        defer { close(window) }
        let navigation = try XCTUnwrap(controller.navigationController)
        let previous = UIViewController()
        navigation.setViewControllers([previous, controller], animated: false)
        window.traitCollection.performAsCurrent {
            controller.didReceive(words: fixture.words, afterConfirmationFail: false)
        }
        await settle(window)
        let choices = wordButtons(controller)
        let reset = try XCTUnwrap(controller.navigationItem.rightBarButtonItem?.customView as? UIButton)
        await activate(choices[0], in: window, scroll: try scrollView(controller), dispatchWithDisplayedTraits: true)
        for (language, category) in [("ru", UIContentSizeCategory.accessibilityExtraExtraExtraLarge), ("ja", .large)] {
            controller.localizationManager?.selectedLocalization = language
            if #available(iOS 17.0, *) { window.traitOverrides.preferredContentSizeCategory = category }
            await settle(window)
            window.traitCollection.performAsCurrent { controller.applyLocalization() }
            await settle(window)
            XCTAssertEqual(controller.title, R.string.localizable.accountConfirmationTitle(preferredLanguages: [language]))
            XCTAssertEqual(wordButtons(controller), choices)
            XCTAssertTrue(controller.navigationItem.rightBarButtonItem?.customView === reset)
            let heading = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? UILabel }
                .first { $0.text == controller.title })
            XCTAssertTrue(heading.accessibilityTraits.contains(.header))
            assertCompleteLabel(heading)
            try await assertLabelSlicesReachable(heading, controller: controller, window: window,
                                                name: "ordinary-live-heading-\(language)")
        }
        for choice in choices.dropFirst() {
            await activate(choice, in: window, scroll: try scrollView(controller), dispatchWithDisplayedTraits: true)
        }
        let finalLocale = try XCTUnwrap(controller.localizationManager?.selectedLocale)
        await activate(try nextButton(controller, locale: finalLocale),
                       in: window, scroll: nil, dispatchWithDisplayedTraits: true)
        XCTAssertEqual(fixture.presenter.confirmed, [fixture.words])
        fixture.presenter.resetWords = fixture.words
        await activate(reset, in: window, scroll: nil, dispatchWithDisplayedTraits: true)
        XCTAssertEqual(fixture.presenter.resets, 1)
        let back = try XCTUnwrap(descendants(navigation.navigationBar).compactMap { $0 as? UIControl }.first {
            let frame = $0.convert($0.bounds, to: window)
            return self.isVisible($0) && frame.width > 0 && frame.maxX < window.bounds.midX && $0 !== reset
        })
        await activate(back, in: window, scroll: nil)
        XCTAssertTrue(navigation.topViewController === previous, "The original native Back control must still navigate")
        XCTAssertNil(fixture.settings.value)
    }

    func testOrdinaryFactoryWordsFollowLiveTextAndBoldWithoutReplacingChoices() async throws {
        for creating in [true, false] {
            let fixture = try ordinaryTextFixture(language: "en", creating: creating)
            let controller = fixture.controller
            let window = try show(controller, category: .large)
            defer { close(window) }
            window.traitCollection.performAsCurrent {
                controller.didReceive(words: fixture.words, afterConfirmationFail: false)
            }
            await settle(window)
            let choices = wordButtons(controller)
            let reset = try XCTUnwrap(controller.navigationItem.rightBarButtonItem?.customView as? UIButton)
            let scroll = try scrollView(controller)
            await activate(choices[0], in: window, scroll: scroll, dispatchWithDisplayedTraits: true)
            for (category, weight) in [
                (UIContentSizeCategory.accessibilityExtraExtraExtraLarge, UILegibilityWeight.regular),
                (.accessibilityExtraExtraExtraLarge, .bold),
                (.large, .regular)
            ] {
                if #available(iOS 17.0, *) {
                    window.traitOverrides.preferredContentSizeCategory = category
                    window.traitOverrides.legibilityWeight = weight
                }
                await settle(window)
                XCTAssertEqual(wordButtons(controller), choices)
                XCTAssertTrue(controller.navigationItem.rightBarButtonItem?.customView === reset)
                for choice in choices { try assertOrdinaryChoiceFont(choice) }
                // The separate normal-target test retains the 44pt accessibility requirement.
                assertWordLayout(choices, minimumHeight: 1)
                await reveal(choices[0], in: window, scroll: scroll)
                capture(window, name: "ordinary-word-live-\(creating)-\(category.rawValue)-\(weight.rawValue)")
            }
            for choice in choices.dropFirst() {
                await activate(choice, in: window, scroll: scroll, dispatchWithDisplayedTraits: true)
            }
            let next = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? TriangularedButton }
                .first { $0.imageWithTitleView?.title == controller.nextButtonTitle.value(for: Locale(identifier: "en")) })
            XCTAssertTrue(next.isEnabled)
            await activate(next, in: window, scroll: nil, dispatchWithDisplayedTraits: true)
            XCTAssertEqual(fixture.presenter.confirmed, [fixture.words])
            fixture.presenter.resetWords = fixture.words
            await activate(reset, in: window, scroll: nil, dispatchWithDisplayedTraits: true)
            XCTAssertFalse(next.isEnabled)
            XCTAssertFalse(wordButtons(controller).contains { choices.contains($0) })
            XCTAssertNil(fixture.settings.value)
        }
    }

    func testValidWideOrdinaryWordAndFollowingChoicesRemainReachableAtNormalText() async throws {
        try await assertValidWideOrdinaryPhrase(category: .large)
    }

    func testValidWideOrdinaryWordAndFollowingChoicesRemainReachableAtLargestText() async throws {
        try await assertValidWideOrdinaryPhrase(category: .accessibilityExtraExtraExtraLarge)
    }

    func testOrdinaryFactoryNormalChoicesMeetMinimumHitTarget() async throws {
        let fixture = try ordinaryTextFixture(
            language: "en", creating: true,
            publicMnemonicPhrase: "ill abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon able"
        )
        XCTAssertEqual(fixture.words.first, "ill")
        let window = try show(fixture.controller, category: .large)
        defer { close(window) }
        window.traitCollection.performAsCurrent {
            fixture.controller.didReceive(words: fixture.words, afterConfirmationFail: false)
        }
        await settle(window)
        let choices = wordButtons(fixture.controller)
        await reveal(try XCTUnwrap(choices.first), in: window, scroll: try scrollView(fixture.controller))
        capture(window, name: "ordinary-normal-word-minimum-target")
        assertWordLayout(choices)
        for choice in choices { XCTAssertGreaterThanOrEqual(choice.bounds.width, 44) }
        let shortest = try XCTUnwrap(choices.first)
        for x: CGFloat in [-21.9, 21.9] {
            for y: CGFloat in [-21.9, 21.9] {
                let point = shortest.convert(CGPoint(x: shortest.bounds.midX + x, y: shortest.bounds.midY + y), to: window)
                let hit = window.hitTest(point, with: nil)
                XCTAssertTrue(hit === shortest || hit?.isDescendant(of: shortest) == true,
                              "The entire 44pt minimum target must belong to the actual short-word control")
            }
        }
        XCTAssertTrue(shortest.accessibilityActivate())
        await settle(window)
        XCTAssertFalse(try nextButton(fixture.controller, locale: Locale(identifier: "en")).isEnabled)
        XCTAssertTrue(fixture.presenter.confirmed.isEmpty)
        XCTAssertNil(fixture.settings.value)
    }

    private func assertValidWideOrdinaryPhrase(category: UIContentSizeCategory) async throws {
        // Public BIP39 checksum-valid input; the actual mnemonic creator validates it below.
        let phrase = "mushroom abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon able"
        let fixture = try ordinaryTextFixture(language: "en", creating: true, publicMnemonicPhrase: phrase)
        XCTAssertEqual(fixture.words.joined(separator: " "), phrase)
        let controller = fixture.controller
        let window = try show(controller, category: category)
        defer { close(window) }
        window.traitCollection.performAsCurrent {
            controller.didReceive(words: fixture.words, afterConfirmationFail: false)
        }
        await settle(window)
        let choices = wordButtons(controller)
        XCTAssertEqual(choices.count, fixture.words.count)
        XCTAssertEqual(choices.compactMap { $0.imageWithTitleView?.title }, fixture.words)
        capture(window, name: "ordinary-wide-public-\(category.rawValue)-pending-before")
        for choice in choices { try assertOrdinaryChoiceFont(choice) }
        // This control isolates full phrase reachability; minimum target size is asserted separately.
        let minimumHeight: CGFloat = category == .large ? 1 : 44
        assertWordLayout(choices, minimumHeight: minimumHeight)
        // Do not fabricate control activation after the layout assertion proves missing rows.
        guard choices.allSatisfy({ $0.bounds.width > 0 && $0.bounds.height >= minimumHeight }) else { return }
        let scroll = try scrollView(controller)
        for (index, choice) in choices.enumerated() {
            try await assertChoiceReadable(choice, controller: controller, window: window,
                                           name: "ordinary-wide-public-\(category.rawValue)-pending-\(index)", minimumHeight: minimumHeight)
            await activate(choice, in: window, scroll: scroll, dispatchWithDisplayedTraits: true)
        }
        for (index, choice) in choices.enumerated() {
            try await assertChoiceReadable(choice, controller: controller, window: window,
                                           name: "ordinary-wide-public-\(category.rawValue)-selected-\(index)", minimumHeight: minimumHeight)
        }
        let next = try nextButton(controller, locale: Locale(identifier: "en"))
        XCTAssertTrue(next.isEnabled)
        await activate(next, in: window, scroll: nil, dispatchWithDisplayedTraits: true)
        XCTAssertEqual(fixture.presenter.confirmed, [fixture.words])
        XCTAssertNil(fixture.settings.value)
    }

    private func assertOrdinaryChoiceFont(_ choice: RoundedButton) throws {
        let expected: UIFont = FWAppearance.accountConfirmRestyled
            ? .fw(.phraseWord, locale: Locale(identifier: "en"), compatibleWith: choice.traitCollection)
            : .legacySora(size: 14, weight: .regular, textStyle: .callout, compatibleWith: choice.traitCollection)
        let labels = descendants(choice).compactMap { $0 as? UILabel }.filter { isVisible($0) }
        XCTAssertFalse(labels.isEmpty, "A real rendered word label is required")
        for label in labels {
            XCTAssertEqual(label.font.fontName, expected.fontName, "Rendered word must follow its own current Bold Text trait")
            XCTAssertEqual(label.font.pointSize, expected.pointSize, accuracy: 0.01,
                           "Rendered word must follow its own current Dynamic Type trait")
        }
    }

    private func ordinaryTextFixture(
        language: String, creating: Bool,
        publicMnemonicPhrase: String = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    ) throws -> (
        controller: AccountConfirmViewController, words: [String], presenter: Presenter, settings: SelectedWalletSettings
    ) {
        let settings = SelectedWalletSettings(storageFacade: UserDataStorageTestFacade(), operationQueue: OperationQueue())
        let controller: AccountConfirmViewController
        let words: [String]
        if creating {
            let mnemonic = try IRMnemonicCreator().mnemonic(fromList: publicMnemonicPhrase)
            let request = MetaAccountImportMnemonicRequest(
                mnemonic: mnemonic, username: "Public heading fixture", substrateDerivationPath: "",
                ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
                cryptoType: .sr25519, defaultChainId: nil
            )
            controller = try XCTUnwrap(AccountConfirmViewFactory.createViewForOnboarding(flow: .wallet(request))?.controller as? AccountConfirmViewController)
            words = mnemonic.allWords()
        } else {
            let mnemonic = LegacyTonMnemonic(phrase: historicalCanonicalTonPhrase)
            controller = try XCTUnwrap(ExportMnemonicConfirmViewFactory.createViewForMnemonic(
                mnemonic, wallet: tonConfirmationWallet(try LegacyNativeTonFixture.account()), backupProof: nil, settings: settings
            )?.controller as? AccountConfirmViewController)
            words = mnemonic.allWords()
        }
        let presenter = Presenter()
        controller.presenter = presenter
        controller.localizationManager = try XCTUnwrap(LocalizationManager(localization: language))
        return (controller, words, presenter, settings)
    }

    private func assertCompleteLabel(_ label: UILabel, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(label.adjustsFontSizeToFitWidth, file: file, line: line)
        let fitting = label.sizeThatFits(CGSize(
            width: label.numberOfLines == 1 ? .greatestFiniteMagnitude : label.bounds.width,
            height: .greatestFiniteMagnitude
        ))
        XCTAssertLessThanOrEqual(fitting.width, label.bounds.width + 0.5, "Full text must not be ellipsized", file: file, line: line)
        XCTAssertLessThanOrEqual(fitting.height, label.bounds.height + 0.5, file: file, line: line)
    }

    private func assertLabelSlicesReachable(
        _ label: UILabel, controller: UIViewController, window: UIWindow, name: String
    ) async throws {
        let scroll = try scrollView(controller)
        let isScrolling = label.isDescendant(of: scroll)
        let viewport = isScrolling ? scroll.convert(scroll.bounds, to: window).intersection(window.bounds) : window.bounds
        let height = min(label.font.lineHeight, viewport.height / 2)
        XCTAssertGreaterThan(height, 0)
        guard height > 0 else { return }
        var y: CGFloat = 0
        var index = 0
        while y < label.bounds.height {
            let slice = CGRect(x: 0, y: y, width: label.bounds.width, height: min(height, label.bounds.height - y))
            if isScrolling { scroll.scrollRectToVisible(label.convert(slice, to: scroll), animated: false) }
            await settle(window)
            let frame = label.convert(slice, to: window)
            XCTAssertGreaterThanOrEqual(frame.minX, viewport.minX - 0.5)
            XCTAssertLessThanOrEqual(frame.maxX, viewport.maxX + 0.5)
            XCTAssertGreaterThanOrEqual(frame.minY, viewport.minY - 0.5)
            XCTAssertLessThanOrEqual(frame.maxY, viewport.maxY + 0.5)
            capture(window, name: name + "-slice-\(index)-restyled-\(FWAppearance.accountConfirmRestyled)")
            y += height
            index += 1
        }
    }

    private func assertChoiceReadable(
        _ choice: RoundedButton, controller: UIViewController, window: UIWindow, name: String, minimumHeight: CGFloat = 44
    ) async throws {
        assertWordLayout([choice], minimumHeight: minimumHeight)
        for label in descendants(choice).compactMap({ $0 as? UILabel }).filter({ isVisible($0) }) {
            assertCompleteLabel(label)
            try await assertLabelSlicesReachable(label, controller: controller, window: window, name: name)
        }
        await reveal(choice, in: window, scroll: try scrollView(controller))
        let frame = choice.convert(choice.bounds, to: window)
        let hit = window.hitTest(CGPoint(x: frame.midX, y: frame.midY), with: nil)
        XCTAssertTrue(hit === choice || hit?.isDescendant(of: choice) == true)
    }

    func testOrdinaryFactoryFootersFitAtNormalTextInEveryLocale() async throws {
        try await assertOrdinaryFactoryFooters(category: .large)
    }

    func testOrdinaryFactoryFootersFitAtLargestTextInEveryLocale() async throws {
        try await assertOrdinaryFactoryFooters(category: .accessibilityExtraExtraExtraLarge)
    }

    func testOrdinaryFooterLiveTypeAndLocalePreserveControlsAndSelection() async throws {
        let localization = try XCTUnwrap(LocalizationManager(localization: "en"))
        let presenter = Presenter()
        let controller = makeController(presenter, localization: localization, skip: true)
        let window = try show(controller, category: .large)
        defer { close(window) }
        let words = ["abandon", "about", "abandon"]
        window.traitCollection.performAsCurrent { controller.didReceive(words: words, afterConfirmationFail: false) }
        await settle(window)
        let choices = wordButtons(controller)
        let scroll = try scrollView(controller)
        let next = try nextButton(controller, locale: localization.selectedLocale)
        let actions = descendants(controller.view).compactMap { $0 as? TriangularedButton }
        await activate(choices[0], in: window, scroll: scroll, dispatchWithDisplayedTraits: true)
        for (language, category) in [("ru", UIContentSizeCategory.accessibilityExtraExtraExtraLarge), ("en", .large)] {
            localization.selectedLocalization = language
            if #available(iOS 17.0, *) { window.traitOverrides.preferredContentSizeCategory = category }
            await settle(window)
            window.traitCollection.performAsCurrent { controller.applyLocalization() }
            await settle(window)
            XCTAssertEqual(wordButtons(controller), choices)
            XCTAssertEqual(descendants(controller.view).compactMap { $0 as? TriangularedButton }, actions)
            XCTAssertFalse(next.isEnabled)
            for (index, action) in actions.enumerated() {
                await reveal(action, in: window, scroll: nil)
                capture(window, name: "ordinary-live-\(language)-\(category.rawValue)-action-\(index)")
                assertVisibleLabelsFit(action)
                if !FWAppearance.accountConfirmRestyled {
                    let expected: UIFont = action === next
                        ? .legacySora(size: 16, weight: .bold, textStyle: .headline, compatibleWith: action.traitCollection)
                        : .legacySora(size: 14, weight: .bold, textStyle: .subheadline, compatibleWith: action.traitCollection)
                    for label in descendants(action).compactMap({ $0 as? UILabel }).filter({ isVisible($0) }) {
                        XCTAssertEqual(label.font, expected)
                    }
                    if category == .large {
                        XCTAssertEqual(action.bounds.height, action === next ? 52 : UIConstants.actionHeight, accuracy: 0.5)
                    }
                }
            }
        }
        for choice in choices.dropFirst() { await activate(choice, in: window, scroll: scroll, dispatchWithDisplayedTraits: true) }
        await activate(next, in: window, scroll: nil, dispatchWithDisplayedTraits: true)
        XCTAssertEqual(presenter.confirmed, [words])
        XCTAssertEqual(presenter.loaded, 1)
    }

    private func assertOrdinaryFactoryFooters(category: UIContentSizeCategory) async throws {
        let ordinary = try IRMnemonicCreator().mnemonic(
            fromList: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        )
        let canonical = LegacyTonMnemonic(phrase: historicalCanonicalTonPhrase)
        let native = try LegacyNativeTonFixture.account()
        for language in languages {
            for creating in [true, false] {
                let localization = try XCTUnwrap(LocalizationManager(localization: language))
                let settings = SelectedWalletSettings(storageFacade: UserDataStorageTestFacade(), operationQueue: OperationQueue())
                let controller: AccountConfirmViewController
                let words: [String]
                if creating {
                    let request = MetaAccountImportMnemonicRequest(
                        mnemonic: ordinary, username: "Public footer fixture", substrateDerivationPath: "",
                        ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
                        cryptoType: .sr25519, defaultChainId: nil
                    )
                    controller = try XCTUnwrap(AccountConfirmViewFactory.createViewForOnboarding(flow: .wallet(request))?.controller as? AccountConfirmViewController)
                    words = ordinary.allWords()
                } else {
                    controller = try XCTUnwrap(ExportMnemonicConfirmViewFactory.createViewForMnemonic(
                        canonical, wallet: tonConfirmationWallet(native), backupProof: nil, settings: settings
                    )?.controller as? AccountConfirmViewController)
                    words = canonical.allWords()
                }
                // Keep the actual factory's titles/skip configuration, but never create a shared wallet.
                let presenter = Presenter()
                controller.presenter = presenter
                controller.localizationManager = localization
                let window = try show(controller, category: category)
                defer { close(window) }
                window.traitCollection.performAsCurrent {
                    controller.didReceive(words: words, afterConfirmationFail: false)
                }
                await settle(window)
                XCTAssertFalse(controller.showsExactMnemonicSpacing)
                XCTAssertEqual(presenter.loaded, 1)
                let actions = descendants(controller.view).compactMap { $0 as? TriangularedButton }
                XCTAssertEqual(actions.count, creating ? 2 : 1)
                let nextTitle = creating
                    ? R.string.localizable.commonContinue(preferredLanguages: [language])
                    : R.string.localizable.commonConfirm(preferredLanguages: [language])
                let next = try XCTUnwrap(actions.first { $0.imageWithTitleView?.title == nextTitle })
                XCTAssertFalse(next.isEnabled)
                XCTAssertFalse(next.accessibilityActivate())
                let name = "ordinary-footer-\(creating ? "create" : "canonical-backup")-\(language)-\(category.rawValue)-restyled-\(FWAppearance.accountConfirmRestyled)"
                for (index, action) in actions.enumerated() {
                    await reveal(action, in: window, scroll: nil)
                    capture(window, name: name + "-pending-\(index)")
                    assertVisibleLabelsFit(action)
                    let frame = action.convert(action.bounds, to: window)
                    let pixel: (CGFloat) -> CGFloat = { ($0 * window.screen.scale).rounded() }
                    XCTAssertGreaterThanOrEqual(pixel(frame.minX), 0)
                    XCTAssertLessThanOrEqual(pixel(frame.maxX), pixel(window.bounds.width))
                    XCTAssertGreaterThanOrEqual(pixel(frame.minY), 0)
                    XCTAssertLessThanOrEqual(pixel(frame.maxY), pixel(window.bounds.height))
                    XCTAssertGreaterThanOrEqual(frame.height, 44)
                    let geometry = XCTAttachment(string: "action=\(index); frame=\(frame); window=\(window.bounds); scale=\(window.screen.scale)")
                    geometry.name = name + "-geometry-\(index)"
                    geometry.lifetime = .keepAlways
                    add(geometry)
                    if !FWAppearance.accountConfirmRestyled {
                        let expected: UIFont = action === next
                            ? .legacySora(size: 16, weight: .bold, textStyle: .headline, compatibleWith: action.traitCollection)
                            : .legacySora(size: 14, weight: .bold, textStyle: .subheadline, compatibleWith: action.traitCollection)
                        for label in descendants(action).compactMap({ $0 as? UILabel }).filter({ isVisible($0) }) {
                            XCTAssertEqual(label.font, expected)
                        }
                        if category == .large {
                            XCTAssertEqual(action.bounds.height, action === next ? 52 : UIConstants.actionHeight, accuracy: 0.5)
                        }
                    }
                }
                if creating {
                    let skip = try XCTUnwrap(actions.first { $0 !== next })
                    XCTAssertEqual(skip.imageWithTitleView?.title, R.string.localizable.confirmationSkipAction(preferredLanguages: [language]))
                    XCTAssertGreaterThanOrEqual(next.convert(next.bounds, to: window).minY - skip.convert(skip.bounds, to: window).maxY, 7.5)
                    await activate(skip, in: window, scroll: nil, dispatchWithDisplayedTraits: true)
                    XCTAssertEqual(presenter.skips, 1)
                    XCTAssertTrue(presenter.confirmed.isEmpty)
                }
                let scroll = try scrollView(controller)
                for choice in wordButtons(controller) { await activate(choice, in: window, scroll: scroll, dispatchWithDisplayedTraits: true) }
                XCTAssertTrue(next.isEnabled)
                await reveal(next, in: window, scroll: nil)
                assertVisibleLabelsFit(next)
                capture(window, name: name + "-enabled")
                await activate(next, in: window, scroll: nil, dispatchWithDisplayedTraits: true)
                XCTAssertEqual(presenter.confirmed, [words])
                XCTAssertEqual(canonical.entropy(), Data(historicalCanonicalTonPhrase.utf8))
                XCTAssertNil(settings.value)
            }
        }
    }

    func testWrongHistoricalSequenceRemainsRejectedBeforeCorrectRetry() async throws {
        let mnemonic = LegacyTonMnemonic(phrase: historicalCanonicalTonPhrase + " ")
        let native = try LegacyTonAccount(serializedAddress: JSONEncoder().encode(TonSwift.Address.parse("UQCzKbSV4o5EZJ1V0Ld9VpWUAwyLfNv4gyx00SeEFg1rtZEY")),
            publicKey: Data(hexStringSSF: "f14148c55ccec237ef9d9f23b42e7e76faf019814c5001326433c7e64c09abcb"), contractVersion: "v4R2")
        let settings = SelectedWalletSettings(storageFacade: UserDataStorageTestFacade(), operationQueue: OperationQueue())
        let controller = try XCTUnwrap(ExportMnemonicConfirmViewFactory.createViewForMnemonic(mnemonic,
            wallet: tonConfirmationWallet(native), backupProof: nil, settings: settings)?.controller as? AccountConfirmViewController)
        let wireframe = ExportConfirmationWireframe()
        let presenter = try XCTUnwrap(controller.presenter as? AccountConfirmPresenter)
        presenter.wireframe = wireframe
        let window = try show(controller, category: .large)
        defer { close(window) }
        await settle(window)
        let scroll = try scrollView(controller)
        let confirm = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? TriangularedButton }.first)
        for (attempt, sequence) in [Array(mnemonic.allWords().reversed()), mnemonic.allWords()].enumerated() {
            var choices = wordButtons(controller)
            for word in sequence {
                let title = expectedConfirmationTitle(word, locale: LocalizationManager.shared.selectedLocale)
                let index = try XCTUnwrap(choices.firstIndex { $0.imageWithTitleView?.title == title })
                await activate(choices.remove(at: index), in: window, scroll: scroll)
            }
            await activate(confirm, in: window, scroll: nil)
            await settle(window)
            if attempt == 0 {
                // The protocol's default-argument presentation opens the actual mismatch sheet.
                let sheet = try XCTUnwrap(controller.presentedViewController as? SheetAletViewController)
                XCTAssertEqual(wireframe.completed, 0)
                XCTAssertNil(settings.value)
                let ok = R.string.localizable.commonOk(preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages)
                let close = try XCTUnwrap(descendants(sheet.view).compactMap { $0 as? TriangularedButton }
                    .first { $0.imageWithTitleView?.title == ok })
                capture(window, name: "ton-wrong-sequence-actual-mismatch-sheet")
                await activate(close, in: window, scroll: nil)
                XCTAssertNil(controller.presentedViewController)
            }
        }
        XCTAssertEqual(wireframe.completed, 1)
        XCTAssertNil(settings.value)
        XCTAssertEqual(mnemonic.entropy(), Data((historicalCanonicalTonPhrase + " ").utf8))
    }

    private func tonConfirmationWallet(_ native: LegacyTonAccount) -> MetaAccountModel {
        MetaAccountModel(metaId: "public-ton-confirmation", name: "Public legacy TON confirmation", substrateAccountId: nil,
            substrateCryptoType: CryptoType.ed25519.rawValue, substratePublicKey: nil, ethereumAddress: nil, ethereumPublicKey: nil,
            chainAccounts: [], assetKeysOrder: nil, canExportEthereumMnemonic: true, unusedChainIds: nil,
            selectedCurrency: Currency.defaultCurrency(), networkManagmentFilter: "-239", assetsVisibility: [],
            hasBackup: false, favouriteChainIds: [], legacyTonAccount: native)
    }

    private func assertHistoricalConfirmationChoices(phrase: String, address: String, publicKey: String, name: String) async throws {
        let native = try LegacyTonAccount(serializedAddress: JSONEncoder().encode(TonSwift.Address.parse(address)),
            publicKey: Data(hexStringSSF: publicKey), contractVersion: "v4R2")
        let wallet = tonConfirmationWallet(native)
        let keys = InMemoryKeychain()
        let tag = KeystoreTagV2.entropyTagForMetaId(wallet.metaId)
        try keys.saveKey(Data(phrase.utf8), with: tag)
        let chain = ChainAccountRecordsFixture.chain(id: "-239")
        let account = try XCTUnwrap(wallet.fetch(for: chain.accountRequest()))
        let reader = VerifiedMnemonicExportReader(keystore: keys)
        let exported = try reader.fetch(wallet: wallet, info: ChainAccountInfo(chain: chain, account: account))
        XCTAssertEqual(exported.mnemonic.entropy(), Data(phrase.utf8))
        XCTAssertEqual(wallet.legacyTonAccount?.publicKey, try Data(hexStringSSF: publicKey))
        let settings = SelectedWalletSettings(storageFacade: UserDataStorageTestFacade(), operationQueue: OperationQueue())
        let controller = try XCTUnwrap(ExportMnemonicConfirmViewFactory.createViewForMnemonic(
            exported.mnemonic, wallet: wallet, backupProof: nil, settings: settings
        )?.controller as? AccountConfirmViewController)
        let wireframe = ExportConfirmationWireframe()
        let presenter = try XCTUnwrap(controller.presenter as? AccountConfirmPresenter)
        presenter.wireframe = wireframe
        let window = try show(controller, category: .large)
        defer { close(window) }
        await settle(window)
        let choices = wordButtons(controller)
        XCTAssertEqual(choices.count, exported.mnemonic.allWords().count)
        let scroll = try scrollView(controller)
        let special = choices.filter { ($0.imageWithTitleView?.title ?? "").contains("[") }
        for (index, choice) in special.enumerated() {
            await reveal(choice, in: window, scroll: scroll)
            capture(window, name: "ton-" + name + "-choice-\(index)")
        }
        for choice in choices {
            let title = choice.imageWithTitleView?.title ?? ""
            let accessible = choice.accessibilityLabel ?? ""
            XCTAssertFalse(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Significant empty token must have a visible label")
            XCTAssertFalse(accessible.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Significant empty token must have an accessible name")
            XCTAssertFalse(title.contains("\n") || title.contains("\t"), "Significant whitespace must be explicitly named, not rendered as invisible spacing")
            XCTAssertFalse(accessible.contains("\n") || accessible.contains("\t"), "Assistive name must distinguish the separator")
        }
        var pending = choices
        for word in exported.mnemonic.allWords() {
            let title = expectedConfirmationTitle(word, locale: LocalizationManager.shared.selectedLocale)
            let index = try XCTUnwrap(pending.firstIndex { $0.imageWithTitleView?.title == title })
            await activate(pending.remove(at: index), in: window, scroll: scroll)
        }
        let confirm = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? TriangularedButton }.first)
        XCTAssertTrue(confirm.isEnabled)
        await activate(confirm, in: window, scroll: nil)
        XCTAssertEqual(wireframe.completed, 1, "Correct raw historical sequence must reach the actual interactor")
        XCTAssertEqual(wireframe.mismatches, 0)
        XCTAssertEqual(try keys.fetchKey(for: tag), Data(phrase.utf8))
        XCTAssertNil(settings.value)
    }

    private func makeController(
        _ presenter: Presenter,
        localization: LocalizationManager,
        skip: Bool
    ) -> AccountConfirmViewController {
        let controller = AccountConfirmViewController(nib: R.nib.accountConfirmViewController)
        controller.presenter = presenter
        controller.localizationManager = localization
        if skip {
            controller
                .skipButtonTitle = LocalizableResource {
                    R.string.localizable.confirmationSkipAction(preferredLanguages: $0.rLanguages)
                }
        }
        return controller
    }

    private func fixtures(_ prefix: String, count: Int) -> [String] {
        (1 ... count).map { prefix + String(format: "%02d", $0) }
    }

    private func wordButtons(_ controller: UIViewController) -> [RoundedButton] {
        descendants(controller.view).compactMap { $0 as? RoundedButton }
    }

    private func nextButton(_ controller: UIViewController, locale: Locale) throws -> TriangularedButton {
        try XCTUnwrap(
            descendants(controller.view).compactMap { $0 as? TriangularedButton }
                .first {
                    $0.imageWithTitleView?.title == R.string.localizable
                        .commonContinue(preferredLanguages: locale.rLanguages)
                }
        )
    }

    private func scrollView(_ controller: UIViewController) throws -> UIScrollView {
        try XCTUnwrap(descendants(controller.view).compactMap { $0 as? UIScrollView }.first)
    }

    private func assertWordLayout(
        _ buttons: [RoundedButton], minimumHeight: CGFloat = 44, file: StaticString = #filePath, line: UInt = #line
    ) {
        for button in buttons {
            guard let parent = button.superview
            else { XCTFail("Choice has no parent", file: file, line: line); continue }
            XCTAssertGreaterThanOrEqual(button.frame.minX, 0, file: file, line: line)
            XCTAssertLessThanOrEqual(button.frame.maxX, parent.bounds.width + 0.5, file: file, line: line)
            XCTAssertGreaterThan(button.bounds.width, 0, file: file, line: line)
            XCTAssertGreaterThanOrEqual(button.bounds.height, minimumHeight, file: file, line: line)
            assertVisibleLabelsFit(button, file: file, line: line)
        }
        for (index, button) in buttons.enumerated() {
            for other in buttons.dropFirst(index + 1) {
                guard let parent = button.superview else { continue }
                let otherFrame = other.convert(other.bounds, to: parent)
                let overlap = button.frame.intersection(otherFrame)
                XCTAssertTrue(overlap.isNull || overlap.width < 0.5 || overlap.height < 0.5,
                              "Choices overlap: \(button.frame) and \(otherFrame)", file: file, line: line)
            }
        }
    }

    private func assertVisibleLabelsFit(_ view: UIView, file: StaticString = #filePath, line: UInt = #line) {
        for label in descendants(view).compactMap({ $0 as? UILabel }).filter({ self.isVisible($0) }) {
            let frame = label.convert(label.bounds, to: view)
            XCTAssertGreaterThanOrEqual(frame.minX, -0.5, file: file, line: line)
            XCTAssertLessThanOrEqual(frame.maxX, view.bounds.width + 0.5, file: file, line: line)
            XCTAssertGreaterThanOrEqual(frame.minY, -0.5, file: file, line: line)
            XCTAssertLessThanOrEqual(frame.maxY, view.bounds.height + 0.5, file: file, line: line)
            let fitting = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
            XCTAssertLessThanOrEqual(fitting.height, label.bounds.height + 0.5, file: file, line: line)
        }
    }

    private func isVisible(_ view: UIView) -> Bool {
        guard !view.isHidden, view.alpha > 0 else { return false }
        return view.superview.map { isVisible($0) } ?? true
    }

    private func reveal(_ control: UIControl, in window: UIWindow, scroll requestedScroll: UIScrollView?) async {
        var ancestor = control.superview
        var scroll = requestedScroll
        while scroll == nil, let current = ancestor {
            scroll = current as? UIScrollView
            ancestor = current.superview
        }
        if let scroll, control.isDescendant(of: scroll) {
            scroll.scrollRectToVisible(control.convert(control.bounds, to: scroll), animated: false)
        }
        await settle(window)
    }

    private func activate(
        _ control: UIControl, in window: UIWindow, scroll: UIScrollView?, dispatchWithDisplayedTraits: Bool = false
    ) async {
        await reveal(control, in: window, scroll: scroll)
        let frame = control.convert(control.bounds, to: window)
        let point = CGPoint(x: frame.midX, y: frame.midY)
        let hit = window.hitTest(point, with: nil)
        XCTAssertTrue(
            hit === control || hit?.isDescendant(of: control) == true,
            "Expected actual hit path for \(control): hit \(String(describing: hit))"
        )
        if dispatchWithDisplayedTraits {
            // The fixture overrides only this window, not the simulator-wide text-size setting.
            window.traitCollection.performAsCurrent { control.sendActions(for: .touchUpInside) }
        } else {
            control.sendActions(for: .touchUpInside)
        }
        await settle(window)
    }

    private func show(_ controller: UIViewController, category: UIContentSizeCategory) throws -> UIWindow {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        window.overrideUserInterfaceStyle = .dark
        if #available(iOS 17.0, *) { window.traitOverrides.preferredContentSizeCategory = category }
        window.traitCollection.performAsCurrent {
            window.rootViewController = FearlessNavigationController(rootViewController: controller)
            window.makeKeyAndVisible()
            window.layoutIfNeeded()
        }
        return window
    }

    private func settle(_ window: UIWindow) async {
        try? await Task.sleep(nanoseconds: 100_000_000)
        for _ in 0 ..< 60 {
            window.layoutIfNeeded()
            let moving = descendants(window).contains { !($0.layer.animationKeys() ?? []).isEmpty }
            if !moving { return }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail("Confirmation animations did not settle within three seconds")
    }

    private func close(_ window: UIWindow) {
        window.isHidden = true
        window.rootViewController = nil
    }

    private func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap { descendants($0) } }

    private func capture(_ window: UIWindow, name: String) {
        let picture = XCTAttachment(image: UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            XCTAssertTrue(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
        })
        picture.name = "confirm-baseline-" + name
        picture.lifetime = .keepAlways
        add(picture)
        let metrics = descendants(window).compactMap { view -> String? in
            guard let label = view as? UILabel else { return nil }
            return "label=\(label.text ?? ""); font=\(label.font.fontName); size=\(label.font.pointSize); frame=\(label.convert(label.bounds, to: window)); fitting=\(label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)))"
        }.joined(separator: "\n")
        let diagnostic = XCTAttachment(string: metrics)
        diagnostic.name = "confirm-metrics-" + name
        diagnostic.lifetime = .keepAlways
        add(diagnostic)
    }
}
