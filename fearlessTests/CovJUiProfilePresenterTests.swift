import XCTest
import UIKit
import SoraFoundation
import SoraKeystore
import SSFModels
@testable import fearless

// MARK: - Profile stubs (shared by the CovJUiProfile* files)

final class CovJUiProfileView: ProfileViewProtocol {
    let controller: UIViewController
    var isSetup = true
    private(set) var states: [ProfileViewState] = []

    init(controller: UIViewController = UIViewController()) {
        self.controller = controller
    }

    func didReceive(state: ProfileViewState) { states.append(state) }
}

final class CovJUiProfileInteractor: ProfileInteractorInputProtocol {
    private(set) weak var output: ProfileInteractorOutputProtocol?
    private(set) var updatedWallets: [MetaAccountModel] = []
    private(set) var currencies: [Currency] = []
    private(set) var logoutCompletions: [() -> Void] = []

    func setup(with output: ProfileInteractorOutputProtocol) { self.output = output }
    func updateWallet(_ wallet: MetaAccountModel) { updatedWallets.append(wallet) }
    func logout(completion: @escaping () -> Void) { logoutCompletions.append(completion) }
    func update(currency: Currency) { currencies.append(currency) }
}

struct CovJUiProfileFactoryRequest {
    let walletId: String
    let languageCode: String
    let localeIdentifier: String
    let currencyId: String
    let balanceTotal: Decimal?
    let issueCount: Int
}

final class CovJUiProfileFactory: ProfileViewModelFactoryProtocol {
    private(set) var requests: [CovJUiProfileFactoryRequest] = []

    func createProfileViewModel(
        from wallet: MetaAccountModel,
        locale: Locale,
        language: Language,
        currency: Currency,
        balance: WalletBalanceInfo?,
        missingAccountIssue: [ChainIssue]
    ) -> ProfileViewModelProtocol {
        requests.append(CovJUiProfileFactoryRequest(
            walletId: wallet.metaId,
            languageCode: language.code,
            localeIdentifier: locale.identifier,
            currencyId: currency.id,
            balanceTotal: balance?.totalFiatValue,
            issueCount: missingAccountIssue.count
        ))
        return ProfileViewModel(
            profileUserViewModel: WalletsManagmentCellViewModel(
                isSelected: false, walletName: wallet.name, fiatBalance: nil, dayChange: nil, accountScoreViewModel: nil
            ),
            profileOptionViewModel: [],
            logoutViewModel: ProfileOptionViewModel(
                title: "Logout", icon: nil, accessoryTitle: nil, accessoryImage: nil, accessoryType: .arrow, option: nil
            )
        )
    }
}

final class CovJUiProfileWireframe: CovJSheetSpy, ProfileWireframeProtocol {
    /// Answers for `present(error:)`, consumed in order; `true` once empty.
    var errorAnswers: [Bool] = []
    private(set) var routes: [String] = []
    private(set) var detailWallets: [MetaAccountModel] = []
    private(set) var selectionOutputs: [WalletsManagmentModuleOutput] = []
    private(set) var pincodeOutputs: [CheckPincodeModuleOutput] = []
    private(set) var currencyWallets: [MetaAccountModel] = []
    private(set) var networkWallets: [MetaAccountModel] = []
    private(set) var tonAccounts: [Bool] = []
    private(set) var importSources: [AccountImportSource] = []
    private(set) var scoreAddresses: [String?] = []

    override func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool {
        _ = super.present(error: error, from: view, locale: locale)
        return errorAnswers.isEmpty ? true : errorAnswers.removeFirst()
    }

    func showAccountDetails(from _: ProfileViewProtocol?, metaAccount: MetaAccountModel) { detailWallets.append(metaAccount) }
    func showAccountSelection(from _: ProfileViewProtocol?, moduleOutput: WalletsManagmentModuleOutput) {
        selectionOutputs.append(moduleOutput)
    }

    func showLanguageSelection(from _: ProfileViewProtocol?) { routes.append("language") }
    func showPincodeChange(from _: ProfileViewProtocol?) { routes.append("pincode") }
    func showAbout(from _: ProfileViewProtocol?) { routes.append("about") }
    func logout(from _: ProfileViewProtocol?) { routes.append("logout") }
    func showCheckPincode(from _: ProfileViewProtocol?, output: CheckPincodeModuleOutput) { pincodeOutputs.append(output) }
    func showSelectCurrency(from _: ProfileViewProtocol?, with wallet: MetaAccountModel) { currencyWallets.append(wallet) }
    func close(view _: ControllerBackedProtocol?) { routes.append("close") }
    func showPolkaswapDisclaimer(from _: ControllerBackedProtocol?) { routes.append("polkaswap") }
    func showWalletConnect(from _: ControllerBackedProtocol?) { routes.append("walletConnect") }
    func showNetworkAssets(from _: ControllerBackedProtocol?, wallet: MetaAccountModel) { networkWallets.append(wallet) }
    func showTonConnectCapability(from _: ControllerBackedProtocol?, hasTonAccount: Bool) { tonAccounts.append(hasTonAccount) }
    func showIrohaConnect(from _: ControllerBackedProtocol?) { routes.append("iroha") }
    func showCreateNewWallet(from _: ControllerBackedProtocol?) { routes.append("create") }
    func showImportWallet(defaultSource: AccountImportSource, from _: ControllerBackedProtocol?) { importSources.append(defaultSource) }
    func showBackupSelectWallet(from _: ControllerBackedProtocol?) { routes.append("backup") }
    func showGetPreinstalledWallet(from _: ControllerBackedProtocol?) { routes.append("preinstalled") }
    func presentAccountScore(address: String?, from _: ControllerBackedProtocol?) { scoreAddresses.append(address) }
}

final class CovJUiProfileEvents: EventVisitorProtocol {
    private(set) var logouts = 0
    private(set) var scoreChanges = 0

    func processLogout() { logouts += 1 }
    func processAccountScoreSettingsChanged() { scoreChanges += 1 }
}

final class CovJUiProfileFixture {
    let view: CovJUiProfileView
    let interactor: CovJUiProfileInteractor
    let wireframe: CovJUiProfileWireframe
    let factory: CovJUiProfileFactory
    let settings: InMemorySettingsManager
    let eventCenter: EventCenter
    let presenter: ProfilePresenter

    init(localization: LocalizationManagerProtocol, policy: IrohaConnectReleasePolicy) {
        let view = CovJUiProfileView()
        let interactor = CovJUiProfileInteractor()
        let wireframe = CovJUiProfileWireframe()
        let factory = CovJUiProfileFactory()
        let settings = InMemorySettingsManager()
        let eventCenter = EventCenter()
        self.view = view
        self.interactor = interactor
        self.wireframe = wireframe
        self.factory = factory
        self.settings = settings
        self.eventCenter = eventCenter
        presenter = ProfilePresenter(
            viewModelFactory: factory,
            interactor: interactor,
            wireframe: wireframe,
            logger: Logger.shared,
            settings: settings,
            eventCenter: eventCenter,
            localizationManager: localization,
            irohaConnectPolicy: policy
        )
    }

    static func balance(total: Decimal, currency: Currency = .defaultCurrency()) -> WalletBalanceInfo {
        WalletBalanceInfo(
            totalFiatValue: total, enabledAssetFiatBalance: total,
            dayChangePercent: 0, dayChangeValue: 0,
            totalDayChangePercent: 0, totalDayChangeValue: 0,
            currency: currency, prices: [], accountInfos: [:], exclusions: PortfolioExclusions(), filteredPart: nil
        )
    }
}

// MARK: - Presenter

final class CovJUiProfilePresenterTests: XCTestCase {
    private let languages = Locale(identifier: "en").rLanguages

    private func fixture(policy: IrohaConnectReleasePolicy = .production) throws -> CovJUiProfileFixture {
        CovJUiProfileFixture(localization: try XCTUnwrap(LocalizationManager(localization: "en")), policy: policy)
    }

    /// Loads the view and delivers a wallet and a currency, the two inputs a state needs.
    private func loaded(_ f: CovJUiProfileFixture, wallet: MetaAccountModel) -> Bool {
        f.presenter.didLoad(view: f.view)
        f.presenter.didReceive(wallet: wallet)
        f.presenter.didRecieve(selectedCurrency: .defaultCurrency())
        return CovJWait.until { f.view.states.count == 1 }
    }

    func testStateNeedsWalletAndCurrencyThenUsesFactory() throws {
        let f = try fixture()
        f.presenter.didLoad(view: f.view)
        XCTAssertTrue(f.interactor.output === f.presenter)

        let wallet = AccountGenerator.generateMetaAccount()
        f.presenter.didReceive(wallet: wallet)
        CovJWait.drain()
        XCTAssertTrue(f.factory.requests.isEmpty, "no currency yet")
        XCTAssertTrue(f.view.states.isEmpty)

        f.presenter.didRecieve(selectedCurrency: .euro())
        XCTAssertTrue(CovJWait.until { f.view.states.count == 1 })
        let request = try XCTUnwrap(f.factory.requests.last)
        XCTAssertEqual(request.walletId, wallet.metaId)
        XCTAssertEqual(request.currencyId, "eur")
        XCTAssertEqual(request.languageCode, "en")
        XCTAssertEqual(request.localeIdentifier, "en")
        XCTAssertNil(request.balanceTotal)
        XCTAssertEqual(request.issueCount, 0)
        guard case let .loaded(model) = f.view.states.last else {
            return XCTFail("a loaded state is expected")
        }
        XCTAssertEqual(model.profileUserViewModel.walletName, wallet.name)
    }

    func testMissingAccountsAndOwnBalanceRefreshState() throws {
        let f = try fixture()
        let wallet = AccountGenerator.generateMetaAccount()
        XCTAssertTrue(loaded(f, wallet: wallet))

        f.presenter.didReceiveMissingAccount(issues: [.missingAccount(chains: [])])
        XCTAssertEqual(f.factory.requests.last?.issueCount, 1)

        f.presenter.didReceiveWalletBalances(.success([
            wallet.metaId: CovJUiProfileFixture.balance(total: 42),
            "another-wallet": CovJUiProfileFixture.balance(total: 7)
        ]))
        XCTAssertTrue(CovJWait.until { f.factory.requests.last?.balanceTotal == 42 })
        XCTAssertEqual(f.factory.requests.last?.issueCount, 1)

        let count = f.factory.requests.count
        f.presenter.didReceiveWalletBalances(.failure(CovJError("balances")))
        CovJWait.drain()
        XCTAssertEqual(f.factory.requests.count, count, "a balance failure keeps the shown state")
    }

    func testBalancesBeforeAWalletAreIgnored() throws {
        let f = try fixture()
        f.presenter.didLoad(view: f.view)
        f.presenter.didRecieve(selectedCurrency: .defaultCurrency())
        f.presenter.didReceiveWalletBalances(.success(["any": CovJUiProfileFixture.balance(total: 1)]))
        CovJWait.drain()
        XCTAssertTrue(f.factory.requests.isEmpty)
        XCTAssertTrue(f.view.states.isEmpty)
    }

    func testUserDataErrorFallsBackToUndefinedErrorWhenNotPresentable() throws {
        let f = try fixture()
        f.wireframe.errorAnswers = [false, true]
        f.presenter.didReceiveUserDataProvider(error: CovJError("provider"))
        XCTAssertEqual(f.wireframe.errors.count, 2)
        XCTAssertEqual(f.wireframe.errors.first as? CovJError, CovJError("provider"))
        XCTAssertEqual(f.wireframe.errors.last as? CommonError, .undefined)

        f.presenter.didReceiveUserDataProvider(error: CovJError("presentable"))
        XCTAssertEqual(f.wireframe.errors.count, 3)
    }

    func testAccountDetailsNeedAWallet() throws {
        let f = try fixture()
        f.presenter.didLoad(view: f.view)
        f.presenter.activateAccountDetails()
        XCTAssertTrue(f.wireframe.detailWallets.isEmpty)

        let wallet = AccountGenerator.generateMetaAccount()
        f.presenter.didReceive(wallet: wallet)
        f.presenter.activateAccountDetails()
        XCTAssertEqual(f.wireframe.detailWallets.map(\.metaId), [wallet.metaId])
    }

    func testOptionsRouteToWireframe() throws {
        let f = try fixture()
        f.presenter.didLoad(view: f.view)
        for option in [ProfileOption.currency, .networkAssets, .tonConnect] {
            f.presenter.activateOption(option)
        }
        XCTAssertTrue(f.wireframe.currencyWallets.isEmpty, "wallet options wait for a wallet")
        XCTAssertTrue(f.wireframe.networkWallets.isEmpty)
        XCTAssertTrue(f.wireframe.tonAccounts.isEmpty)

        let wallet = AccountGenerator.generateMetaAccount()
        f.presenter.didReceive(wallet: wallet)
        let options: [ProfileOption] = [
            .accountList, .changePincode, .language, .polkaswapDisclaimer, .about, .walletConnect,
            .biometry, .accountScore, .soundEffects, .hapticFeedback, .irohaConnect,
            .currency, .networkAssets, .tonConnect
        ]
        options.forEach { f.presenter.activateOption($0) }

        XCTAssertEqual(f.wireframe.routes, ["pincode", "language", "polkaswap", "about", "walletConnect"])
        XCTAssertEqual(f.wireframe.selectionOutputs.count, 1)
        XCTAssertTrue(f.wireframe.selectionOutputs.first === f.presenter)
        XCTAssertEqual(f.wireframe.currencyWallets.map(\.metaId), [wallet.metaId])
        XCTAssertEqual(f.wireframe.networkWallets.map(\.metaId), [wallet.metaId])
        XCTAssertEqual(f.wireframe.tonAccounts, [false])
    }

    func testTonConnectSeesTonAccountAndIrohaConnectFollowsPolicy() throws {
        let f = try fixture(policy: .enabledForTests)
        f.presenter.didLoad(view: f.view)
        let ton = SSFModels.ChainAccountModel(
            chainId: UniversalWalletRegistry.tonMainnetRegistryEntry.chainId,
            accountId: Data(repeating: 7, count: 32),
            publicKey: Data(repeating: 8, count: 32),
            cryptoType: 0,
            ethereumBased: false
        )
        f.presenter.didReceive(wallet: AccountGenerator.generateMetaAccount(with: [ton]))
        f.presenter.activateOption(.tonConnect)
        f.presenter.activateOption(.irohaConnect)
        XCTAssertEqual(f.wireframe.tonAccounts, [true])
        XCTAssertEqual(f.wireframe.routes, ["iroha"])
    }

    func testRecoveryOptionsWithoutAViewDoNothing() throws {
        let f = try fixture()
        f.presenter.activateOption(.previousData)
        f.presenter.activateOption(.emergencyMaterial)
        XCTAssertTrue(f.wireframe.routes.isEmpty)
        XCTAssertTrue(f.wireframe.sheets.isEmpty)
    }

    func testSwitchersWriteSettingsAndAnnounceAccountScore() throws {
        let defaults = UserDefaults.standard
        let storedSound = defaults.object(forKey: FWFeedbackSettings.soundKey)
        let storedHaptics = defaults.object(forKey: FWFeedbackSettings.hapticsKey)
        defer {
            for (key, value) in [(FWFeedbackSettings.soundKey, storedSound), (FWFeedbackSettings.hapticsKey, storedHaptics)] {
                if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
            }
        }

        let f = try fixture()
        let events = CovJUiProfileEvents()
        f.eventCenter.add(observer: events, dispatchIn: .main)

        f.presenter.switcherValueChanged(isOn: true, index: Int(ProfileOption.biometry.rawValue))
        XCTAssertEqual(f.settings.biometryEnabled, true)
        f.presenter.switcherValueChanged(isOn: true, index: Int(ProfileOption.accountScore.rawValue))
        XCTAssertEqual(f.settings.accountScoreEnabled, true)
        XCTAssertTrue(CovJWait.until { events.scoreChanges == 1 })

        let sound = FWFeedbackSettings.shared.soundEnabled
        f.presenter.switcherValueChanged(isOn: !sound, index: Int(ProfileOption.soundEffects.rawValue))
        XCTAssertEqual(FWFeedbackSettings.shared.soundEnabled, !sound)
        f.presenter.switcherValueChanged(isOn: false, index: Int(ProfileOption.hapticFeedback.rawValue))
        XCTAssertFalse(FWFeedbackSettings.shared.hapticsEnabled)

        f.presenter.switcherValueChanged(isOn: false, index: Int(ProfileOption.walletConnect.rawValue))
        f.presenter.switcherValueChanged(isOn: false, index: 999)
        XCTAssertEqual(f.settings.biometryEnabled, true, "other rows change nothing")
        XCTAssertEqual(f.settings.accountScoreEnabled, true)
    }

    func testLogoutAsksBeforeCheckingPincode() throws {
        let f = try fixture()
        f.presenter.didLoad(view: f.view)
        f.presenter.logout()

        let sheet = try XCTUnwrap(f.wireframe.sheets.first)
        let logoutTitle = R.string.localizable.profileLogoutTitle(preferredLanguages: languages)
        XCTAssertEqual(sheet.title, logoutTitle)
        XCTAssertEqual(sheet.message, R.string.localizable.profileLogoutDescription(preferredLanguages: languages))
        XCTAssertEqual(sheet.actions.map(\.title), [R.string.localizable.commonCancel(preferredLanguages: languages), logoutTitle])
        XCTAssertNil(sheet.closeAction)
        XCTAssertNotNil(sheet.icon)
        XCTAssertNil(sheet.actions.first?.handler)
        XCTAssertTrue(f.wireframe.pincodeOutputs.isEmpty)

        sheet.actions.last?.handler?()
        XCTAssertEqual(f.wireframe.pincodeOutputs.count, 1)
        XCTAssertTrue(f.wireframe.pincodeOutputs.first === f.presenter)
    }

    func testCheckedPincodeLogsOutThenNotifies() throws {
        let f = try fixture()
        let events = CovJUiProfileEvents()
        f.eventCenter.add(observer: events, dispatchIn: .main)
        f.presenter.didLoad(view: f.view)

        f.presenter.didCheck()
        XCTAssertEqual(f.interactor.logoutCompletions.count, 1)
        XCTAssertTrue(f.wireframe.routes.isEmpty, "the wireframe waits for the interactor")

        f.interactor.logoutCompletions.first?()
        XCTAssertTrue(CovJWait.until { f.wireframe.routes == ["logout"] && events.logouts == 1 })

        f.presenter.close(view: f.view)
        XCTAssertEqual(f.wireframe.routes, ["logout", "close"])
    }

    func testAccountScoreAndWalletManagementOutputsRoute() throws {
        let f = try fixture()
        f.presenter.didLoad(view: f.view)
        f.presenter.didTapAccountScore(address: "0xscore")
        f.presenter.didTapAccountScore(address: nil)
        XCTAssertEqual(f.wireframe.scoreAddresses, ["0xscore", nil])

        f.presenter.showAddNewWallet()
        f.presenter.showImportWallet(defaultSource: .seed)
        f.presenter.showImportGoogle()
        f.presenter.showGetPreinstalledWallet()
        XCTAssertEqual(f.wireframe.routes, ["create", "backup", "preinstalled"])
        XCTAssertEqual(f.wireframe.importSources, [.seed])
    }

    func testLocalizationRefreshesOnlyASetUpView() throws {
        let f = try fixture()
        XCTAssertTrue(loaded(f, wallet: AccountGenerator.generateMetaAccount()))

        f.view.isSetup = false
        f.presenter.applyLocalization()
        CovJWait.drain()
        XCTAssertEqual(f.view.states.count, 1)

        f.view.isSetup = true
        f.presenter.applyLocalization()
        XCTAssertTrue(CovJWait.until { f.view.states.count == 2 })
    }

    func testMetaAccountChangeUpdatesCurrencyOnlyForTheShownWallet() throws {
        let f = try fixture()
        let wallet = AccountGenerator.generateMetaAccount()
        XCTAssertTrue(loaded(f, wallet: wallet))

        f.presenter.processMetaAccountChanged(event: MetaAccountModelChangedEvent(account: AccountGenerator.generateMetaAccount()))
        f.presenter.processMetaAccountChanged(event: MetaAccountModelChangedEvent(account: wallet.replacingName("Renamed")))
        XCTAssertTrue(f.interactor.currencies.isEmpty, "same currency or another wallet")
        f.presenter.activateAccountDetails()
        XCTAssertEqual(f.wireframe.detailWallets.last?.name, "Renamed")

        f.presenter.processMetaAccountChanged(event: MetaAccountModelChangedEvent(account: wallet.replacingCurrency(.euro())))
        XCTAssertEqual(f.interactor.currencies.map(\.id), ["eur"])
        f.presenter.activateAccountDetails()
        XCTAssertEqual(f.wireframe.detailWallets.last?.selectedCurrency.id, "eur")
    }
}
