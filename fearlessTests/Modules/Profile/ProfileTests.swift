import XCTest
import UIKit
import FearlessFoundation
import FearlessSecureStorage
import RobinHood
import SSFModels
import SSFUtils
import WalletConnectSign
@testable import fearless

final class ProfileTests: XCTestCase {
    func testDidLoad_whenViewProvided_thenSetsUpInteractor() {
        let fixture = makeFixture()
        let view = ProfileViewSpy()

        fixture.presenter.didLoad(view: view)

        XCTAssertTrue(fixture.interactor.output === fixture.presenter)
    }

    func testDidReceiveWalletAndCurrency_whenBothAvailable_thenDeliversProfileState() {
        let wallet = AccountGenerator.generateMetaAccount().replacingName("Main wallet")
        let currency = Currency.defaultCurrency()
        let factory = ProfileViewModelFactorySpy()
        let fixture = makeFixture(viewModelFactory: factory)
        let view = ProfileViewSpy()
        let expectation = expectation(description: "profile state delivered")
        view.onDidReceiveState = { state in
            if case .loaded = state {
                expectation.fulfill()
            }
        }

        fixture.presenter.didLoad(view: view)
        fixture.presenter.didRecieve(selectedCurrency: currency)
        fixture.presenter.didReceive(wallet: wallet)

        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)
        XCTAssertEqual(factory.receivedWallet?.metaId, wallet.metaId)
        XCTAssertEqual(factory.receivedCurrency?.id, currency.id)
        XCTAssertEqual(view.loadedViewModel?.profileUserViewModel.walletName, "Main wallet")
    }

    func testActivateActions_whenWalletIsAvailable_thenRoutesExpectedScreens() {
        let wallet = AccountGenerator.generateMetaAccount()
        let wireframe = ProfileWireframeSpy()
        let fixture = makeFixture(wireframe: wireframe)
        let view = ProfileViewSpy()

        fixture.presenter.didLoad(view: view)
        fixture.presenter.didReceive(wallet: wallet)
        fixture.presenter.didRecieve(selectedCurrency: Currency.defaultCurrency())
        fixture.presenter.activateAccountDetails()
        fixture.presenter.activateOption(.accountList)
        fixture.presenter.activateOption(.changePincode)
        fixture.presenter.activateOption(.language)
        fixture.presenter.activateOption(.polkaswapDisclaimer)
        fixture.presenter.activateOption(.about)
        fixture.presenter.activateOption(.currency)
        fixture.presenter.activateOption(.walletConnect)
        fixture.presenter.didTapAccountScore(address: "0x1234")

        XCTAssertEqual(wireframe.accountDetailsWallet?.metaId, wallet.metaId)
        XCTAssertTrue(wireframe.accountSelectionOutput === fixture.presenter)
        XCTAssertTrue(wireframe.didShowPincodeChange)
        XCTAssertTrue(wireframe.didShowLanguageSelection)
        XCTAssertTrue(wireframe.didShowPolkaswapDisclaimer)
        XCTAssertTrue(wireframe.didShowAbout)
        XCTAssertEqual(wireframe.selectCurrencyWallet?.metaId, wallet.metaId)
        XCTAssertTrue(wireframe.didShowWalletConnect)
        XCTAssertEqual(wireframe.accountScoreAddress, "0x1234")
    }

    func testSwitcherValueChanged_whenBiometryAndAccountScoreChange_thenUpdatesSettings() {
        let settings = InMemorySettingsManager()
        let eventCenter = ProfileAccountScoreEventCenterSpy()
        let fixture = makeFixture(settings: settings, eventCenter: eventCenter)

        fixture.presenter.switcherValueChanged(
            isOn: true,
            index: Int(ProfileOption.biometry.rawValue)
        )
        fixture.presenter.switcherValueChanged(
            isOn: false,
            index: Int(ProfileOption.accountScore.rawValue)
        )

        XCTAssertEqual(settings.biometryEnabled, true)
        XCTAssertEqual(settings.accountScoreEnabled, false)
        XCTAssertTrue(eventCenter.events.contains { $0 is AccountScoreSettingsChanged })
    }

    func testProfileViewModelFactory_whenAccountScoreSetup_thenUsesInjectedEventCenterAndLogger() {
        let eventCenter = ProfileAccountScoreEventCenterSpy()
        let logger = LoggerSpy()
        let loggerExpectation = expectation(description: "profile account score logger")
        logger.onDebug = { message in
            if message.contains("Account statistics fetching error") {
                loggerExpectation.fulfill()
            }
        }
        let factory = ProfileViewModelFactory(
            iconGenerator: ProfileIconGeneratorStub(),
            biometry: ProfileBiometryAuthStub(),
            settings: InMemorySettingsManager(),
            accountScoreFetcher: ProfileAccountStatisticsFetcherStub(),
            eventCenter: eventCenter,
            logger: logger
        )

        let viewModel = factory.createProfileViewModel(
            from: AccountGenerator.generateMetaAccount(),
            locale: Locale(identifier: "en_US"),
            language: Language(code: "en"),
            currency: Currency.defaultCurrency(),
            balance: nil,
            missingAccountIssue: []
        )

        guard let accountScoreViewModel = viewModel.profileUserViewModel.accountScoreViewModel else {
            XCTFail("Expected account score view model")
            return
        }

        accountScoreViewModel.setup(with: nil)

        XCTAssertTrue(eventCenter.observers.contains { $0 === accountScoreViewModel })
        wait(for: [loggerExpectation], timeout: Constants.defaultExpectationDuration)
    }

    func testBackupWalletViewModelFactory_whenAccountScoreSetup_thenUsesInjectedEventCenterAndLogger() {
        let eventCenter = ProfileAccountScoreEventCenterSpy()
        let logger = LoggerSpy()
        let loggerExpectation = expectation(description: "backup account score logger")
        logger.onDebug = { message in
            if message.contains("Account statistics fetching error") {
                loggerExpectation.fulfill()
            }
        }
        let factory = BackupWalletViewModelFactory(
            accountScoreFetcher: ProfileAccountStatisticsFetcherStub(),
            settings: InMemorySettingsManager(),
            eventCenter: eventCenter,
            logger: logger
        )

        let viewModel = factory.createViewModel(
            from: AccountGenerator.generateMetaAccount(),
            locale: Locale(identifier: "en_US"),
            balance: nil,
            exportOptions: [.mnemonic],
            backupAccounts: nil
        )

        guard let accountScoreViewModel = viewModel.profileUserViewModel.accountScoreViewModel else {
            XCTFail("Expected account score view model")
            return
        }

        accountScoreViewModel.setup(with: nil)

        XCTAssertTrue(eventCenter.observers.contains { $0 === accountScoreViewModel })
        wait(for: [loggerExpectation], timeout: Constants.defaultExpectationDuration)
    }

    func testWalletMainContainerViewModelFactory_whenAccountScoreSetup_thenUsesInjectedEventCenterAndLogger() {
        let eventCenter = ProfileAccountScoreEventCenterSpy()
        let logger = LoggerSpy()
        let loggerExpectation = expectation(description: "wallet main account score logger")
        logger.onDebug = { message in
            if message.contains("Account statistics fetching error") {
                loggerExpectation.fulfill()
            }
        }
        let factory = WalletMainContainerViewModelFactory(
            accountScoreFetcher: ProfileAccountStatisticsFetcherStub(),
            settings: InMemorySettingsManager(),
            eventCenter: eventCenter,
            logger: logger
        )

        let viewModel = factory.buildViewModel(
            selectedFilter: .all,
            selectedChains: [],
            selectedMetaAccount: AccountGenerator.generateMetaAccount(),
            locale: Locale(identifier: "en_US")
        )

        guard let accountScoreViewModel = viewModel.accountScoreViewModel else {
            XCTFail("Expected account score view model")
            return
        }

        accountScoreViewModel.setup(with: nil)

        XCTAssertTrue(eventCenter.observers.contains { $0 === accountScoreViewModel })
        wait(for: [loggerExpectation], timeout: Constants.defaultExpectationDuration)
    }

    func testLogout_whenConfirmedAndPincodeChecked_thenLogsOutAndNotifiesWireframe() {
        let wireframe = ProfileWireframeSpy()
        let interactor = ProfileInteractorInputSpy()
        let eventCenter = ProfileAccountScoreEventCenterSpy()
        let fixture = makeFixture(
            interactor: interactor,
            wireframe: wireframe,
            eventCenter: eventCenter
        )
        let view = ProfileViewSpy()
        let expectation = expectation(description: "logout routed")
        wireframe.onLogout = {
            expectation.fulfill()
        }

        fixture.presenter.didLoad(view: view)
        fixture.presenter.logout()
        wireframe.presentedViewModel?.actions.last?.handler?()
        fixture.presenter.didCheck()

        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)
        XCTAssertEqual(interactor.logoutCallCount, 1)
        XCTAssertTrue(wireframe.checkPincodeOutput === fixture.presenter)
        XCTAssertTrue(wireframe.logoutView === view)
        XCTAssertTrue(eventCenter.events.contains { $0 is LogoutEvent })
    }

    private func makeFixture(
        interactor: ProfileInteractorInputSpy = ProfileInteractorInputSpy(),
        wireframe: ProfileWireframeSpy = ProfileWireframeSpy(),
        settings: InMemorySettingsManager = InMemorySettingsManager(),
        viewModelFactory: ProfileViewModelFactoryProtocol = ProfileViewModelFactorySpy(),
        eventCenter: EventCenterProtocol = EventCenter(syncQueue: DispatchQueue(label: "test.profile.events"))
    ) -> ProfileFixture {
        let presenter = ProfilePresenter(
            viewModelFactory: viewModelFactory,
            interactor: interactor,
            wireframe: wireframe,
            logger: LoggerSpy(),
            settings: settings,
            eventCenter: eventCenter,
            localizationManager: LocalizationManager.shared
        )

        return ProfileFixture(
            presenter: presenter,
            interactor: interactor,
            wireframe: wireframe
        )
    }
}

final class WalletConnectDisconnectServiceTests: XCTestCase {
    func testDisconnectAllSessions_whenInjectedServiceHasSessions_thenDisconnectsEachTopic() throws {
        let walletConnectService = WalletConnectServiceSpy(sessions: [
            try makeSession(topic: "session-one"),
            try makeSession(topic: "session-two")
        ])
        let expectation = expectation(description: "sessions disconnected")
        expectation.expectedFulfillmentCount = 2
        walletConnectService.onDisconnect = {
            expectation.fulfill()
        }
        let service = WalletConnectDisconnectServiceImpl(
            walletConnectModelFactory: WalletConnectModelFactoryStub(),
            chainAssetFetcher: ChainAssetFetchingStub(),
            walletConnectService: walletConnectService
        )

        service.disconnectAllSessions()

        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)
        XCTAssertEqual(Set(walletConnectService.disconnectedTopics), ["session-one", "session-two"])
    }

    func testDisconnectWallet_whenInjectedServiceHasNoSessions_thenThrowsWithoutDisconnecting() async {
        let walletConnectService = WalletConnectServiceSpy(sessions: [])
        let chainAssetFetcher = ChainAssetFetchingStub()
        let service = WalletConnectDisconnectServiceImpl(
            walletConnectModelFactory: WalletConnectModelFactoryStub(),
            chainAssetFetcher: chainAssetFetcher,
            walletConnectService: walletConnectService
        )

        do {
            try await service.disconnect(wallet: AccountGenerator.generateMetaAccount())
            XCTFail("Expected disconnect to fail when there is no matching session")
        } catch {
            XCTAssertTrue(walletConnectService.disconnectedTopics.isEmpty)
            XCTAssertEqual(chainAssetFetcher.fetchAwaitCallCount, 1)
        }
    }

    private func makeSession(topic: String) throws -> Session {
        let redirect = try AppMetadata.Redirect(native: "", universal: nil)
        let metadata = AppMetadata(
            name: "Dapp",
            description: "Test dapp",
            url: "https://example.com",
            icons: [],
            redirect: redirect
        )

        return Session(
            topic: topic,
            pairingTopic: "\(topic)-pairing",
            peer: metadata,
            requiredNamespaces: [:],
            namespaces: [:],
            sessionProperties: nil,
            scopedProperties: nil,
            expiryDate: Date(timeIntervalSinceNow: 60)
        )
    }
}

final class WalletConnectServiceImplTests: XCTestCase {
    func testConnect_whenUriIsInvalid_thenThrowsLocalizedContentError() async {
        let localizationManager = WalletConnectLocalizationManagerStub(selectedLocalization: "en")
        let service = WalletConnectServiceImpl(localizationManager: localizationManager)
        let preferredLanguages = localizationManager.selectedLocale.rLanguages

        do {
            try await service.connect(uri: "not-a-wallet-connect-uri")
            XCTFail("Expected invalid WalletConnect URI to fail before pairing")
        } catch let error as ConvenienceContentError {
            XCTAssertEqual(
                error.title,
                R.string.localizable.walletConnectInvalidUrlTitle(preferredLanguages: preferredLanguages)
            )
            XCTAssertEqual(
                error.message,
                R.string.localizable.walletConnectInvalidUrlMessage(preferredLanguages: preferredLanguages)
            )
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private struct ProfileFixture {
    let presenter: ProfilePresenter
    let interactor: ProfileInteractorInputSpy
    let wireframe: ProfileWireframeSpy
}

private final class ProfileViewSpy: ProfileViewProtocol {
    let controller = UIViewController()
    let isSetup = true
    private(set) var loadedViewModel: ProfileViewModelProtocol?
    var onDidReceiveState: ((ProfileViewState) -> Void)?

    func didReceive(state: ProfileViewState) {
        if case let .loaded(viewModel) = state {
            loadedViewModel = viewModel
        }
        onDidReceiveState?(state)
    }
}

private final class ProfileInteractorInputSpy: ProfileInteractorInputProtocol {
    private(set) weak var output: ProfileInteractorOutputProtocol?
    private(set) var updatedWallet: MetaAccountModel?
    private(set) var updatedCurrency: Currency?
    private(set) var logoutCallCount = 0

    func setup(with output: ProfileInteractorOutputProtocol) {
        self.output = output
    }

    func updateWallet(_ wallet: MetaAccountModel) {
        updatedWallet = wallet
    }

    func logout(completion: @escaping () -> Void) {
        logoutCallCount += 1
        completion()
    }

    func update(currency: Currency) {
        updatedCurrency = currency
    }
}

private final class ProfileViewModelFactorySpy: ProfileViewModelFactoryProtocol {
    private(set) var receivedWallet: MetaAccountModel?
    private(set) var receivedCurrency: Currency?
    private(set) var receivedBalance: WalletBalanceInfo?
    private(set) var receivedMissingAccountIssue: [ChainIssue]?

    func createProfileViewModel(
        from wallet: MetaAccountModel,
        locale _: Locale,
        language _: Language,
        currency: Currency,
        balance: WalletBalanceInfo?,
        missingAccountIssue: [ChainIssue]
    ) -> ProfileViewModelProtocol {
        receivedWallet = wallet
        receivedCurrency = currency
        receivedBalance = balance
        receivedMissingAccountIssue = missingAccountIssue

        return ProfileViewModel(
            profileUserViewModel: WalletsManagmentCellViewModel(
                isSelected: false,
                walletName: wallet.name,
                fiatBalance: nil,
                dayChange: nil,
                accountScoreViewModel: nil
            ),
            profileOptionViewModel: [],
            logoutViewModel: ProfileOptionViewModel(
                title: "Logout",
                icon: nil,
                accessoryTitle: nil,
                accessoryImage: nil,
                accessoryType: .arrow,
                option: nil
            )
        )
    }
}

private final class ProfileWireframeSpy: ProfileWireframeProtocol {
    private(set) var accountDetailsWallet: MetaAccountModel?
    private(set) weak var accountSelectionOutput: WalletsManagmentModuleOutput?
    private(set) var didShowPincodeChange = false
    private(set) var didShowLanguageSelection = false
    private(set) var didShowPolkaswapDisclaimer = false
    private(set) var didShowAbout = false
    private(set) var didShowWalletConnect = false
    private(set) var selectCurrencyWallet: MetaAccountModel?
    private(set) weak var checkPincodeOutput: CheckPincodeModuleOutput?
    private(set) weak var logoutView: ProfileViewProtocol?
    private(set) weak var closedView: ControllerBackedProtocol?
    private(set) var accountScoreAddress: String?
    private(set) var presentedViewModel: SheetAlertPresentableViewModel?
    private(set) var presentedErrors: [Error] = []
    var onLogout: (() -> Void)?

    func showAccountDetails(from _: ProfileViewProtocol?, metaAccount: MetaAccountModel) {
        accountDetailsWallet = metaAccount
    }

    func showAccountSelection(
        from _: ProfileViewProtocol?,
        moduleOutput: WalletsManagmentModuleOutput
    ) {
        accountSelectionOutput = moduleOutput
    }

    func showLanguageSelection(from _: ProfileViewProtocol?) {
        didShowLanguageSelection = true
    }

    func showPincodeChange(from _: ProfileViewProtocol?) {
        didShowPincodeChange = true
    }

    func showAbout(from _: ProfileViewProtocol?) {
        didShowAbout = true
    }

    func logout(from view: ProfileViewProtocol?) {
        logoutView = view
        onLogout?()
    }

    func showCheckPincode(
        from _: ProfileViewProtocol?,
        output: CheckPincodeModuleOutput
    ) {
        checkPincodeOutput = output
    }

    func showSelectCurrency(from _: ProfileViewProtocol?, with wallet: MetaAccountModel) {
        selectCurrencyWallet = wallet
    }

    func close(view: ControllerBackedProtocol?) {
        closedView = view
    }

    func showPolkaswapDisclaimer(from _: ControllerBackedProtocol?) {
        didShowPolkaswapDisclaimer = true
    }

    func showWalletConnect(from _: ControllerBackedProtocol?) {
        didShowWalletConnect = true
    }

    func presentAccountScore(address: String?, from _: ControllerBackedProtocol?) {
        accountScoreAddress = address
    }

    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        presentedErrors.append(error)
        return true
    }

    func present(
        viewModel: SheetAlertPresentableViewModel,
        from _: ControllerBackedProtocol?
    ) {
        presentedViewModel = viewModel
    }

    func present(
        message _: String?,
        title _: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {}

    func presentInfo(
        message _: String?,
        title _: String,
        from _: ControllerBackedProtocol?
    ) {}
}

private final class LoggerSpy: LoggerProtocol {
    var onDebug: ((String) -> Void)?

    func verbose(message _: String, file _: String, function _: String, line _: Int) {}
    func debug(message: String, file _: String, function _: String, line _: Int) {
        onDebug?(message)
    }

    func info(message _: String, file _: String, function _: String, line _: Int) {}
    func warning(message _: String, file _: String, function _: String, line _: Int) {}
    func error(message _: String, file _: String, function _: String, line _: Int) {}
    func customError(error _: Error, file _: String, function _: String, line _: Int) {}
}

private final class ProfileAccountScoreEventCenterSpy: EventCenterProtocol {
    private(set) var observers: [EventVisitorProtocol] = []
    private(set) var events: [EventProtocol] = []

    func notify(with event: EventProtocol) {
        events.append(event)
    }

    func add(observer: EventVisitorProtocol, dispatchIn _: DispatchQueue?) {
        observers.append(observer)
    }

    func remove(observer _: EventVisitorProtocol) {}
}

private enum ProfileAccountScoreDependencyTestError: Error {
    case subscription
    case unusedIcon
}

private struct ProfileAccountStatisticsFetcherStub: AccountStatisticsFetching {
    func subscribeForStatistics(
        address _: String
    ) async throws -> AsyncThrowingStream<AccountStatisticsResponse, Error> {
        throw ProfileAccountScoreDependencyTestError.subscription
    }

    func fetchStatistics(address _: String) async throws -> AccountStatisticsResponse? {
        nil
    }
}

private struct ProfileIconGeneratorStub: IconGenerating {
    func generateFromAddress(_: String) throws -> DrawableIcon {
        throw ProfileAccountScoreDependencyTestError.unusedIcon
    }
}

private struct ProfileBiometryAuthStub: BiometryAuthProtocol {
    let availableBiometryType: AvailableBiometryType = .none

    func authenticate(
        localizedReason _: String,
        completionQueue: DispatchQueue,
        completionBlock: @escaping (Bool) -> Void
    ) {
        completionQueue.async {
            completionBlock(false)
        }
    }
}

private final class WalletConnectServiceSpy: WalletConnectService {
    private let sessions: [Session]
    private let queue = DispatchQueue(label: "jp.co.soramitsu.fearless.tests.walletConnectServiceSpy")
    private var disconnectedTopicsStorage: [String] = []
    var onDisconnect: (() -> Void)?

    var disconnectedTopics: [String] {
        queue.sync { disconnectedTopicsStorage }
    }

    init(sessions: [Session]) {
        self.sessions = sessions
    }

    func setup() {}
    func throttle() {}
    func set(listener _: WalletConnectServiceDelegate) {}
    func connect(uri _: String) async throws {}

    func disconnect(topic: String) async throws {
        let disconnectCallback = queue.sync { () -> (() -> Void)? in
            disconnectedTopicsStorage.append(topic)
            return onDisconnect
        }

        disconnectCallback?()
    }

    func getSessions() -> [Session] {
        sessions
    }

    func submit(proposalDecision _: WalletConnectProposalDecision) async throws {}
    func submit(signDecision _: WalletConnectSignDecision) async throws {}
}

private final class WalletConnectLocalizationManagerStub: LocalizationManagerProtocol {
    var selectedLocalization: String
    let availableLocalizations: [String]

    init(selectedLocalization: String) {
        self.selectedLocalization = selectedLocalization
        availableLocalizations = [selectedLocalization]
    }

    func addObserver(
        with _: AnyObject,
        queue _: DispatchQueue?,
        closure _: @escaping LocalizationChangeClosure
    ) {}

    func removeObserver(by _: AnyObject) {}
}

private final class ChainAssetFetchingStub: ChainAssetFetchingProtocol {
    private let result: Result<[ChainAsset], Error>
    private(set) var fetchAwaitCallCount = 0

    init(result: Result<[ChainAsset], Error> = .success([])) {
        self.result = result
    }

    func fetch(
        shouldUseCache _: Bool,
        filters _: [ChainAssetsFetching.Filter],
        sortDescriptors _: [ChainAssetsFetching.SortDescriptor],
        completionBlock: @escaping (Result<[ChainAsset], Error>?) -> Void
    ) {
        completionBlock(result)
    }

    func fetchAwaitOperation(
        shouldUseCache _: Bool,
        filters _: [ChainAssetsFetching.Filter],
        sortDescriptors _: [ChainAssetsFetching.SortDescriptor]
    ) -> BaseOperation<[ChainAsset]> {
        ClosureOperation { try self.resolve() }
    }

    func fetchAwait(
        shouldUseCache _: Bool,
        filters _: [ChainAssetsFetching.Filter],
        sortDescriptors _: [ChainAssetsFetching.SortDescriptor]
    ) async throws -> [ChainAsset] {
        fetchAwaitCallCount += 1
        return try resolve()
    }

    private func resolve() throws -> [ChainAsset] {
        switch result {
        case let .success(chainAssets):
            return chainAssets
        case let .failure(error):
            throw error
        }
    }
}

private final class WalletConnectModelFactoryStub: WalletConnectModelFactory {
    func createSessionNamespaces(
        from _: Session.Proposal,
        wallets _: [MetaAccountModel],
        chains _: [ChainModel],
        optionalChainIds _: [ChainModel.Id]?
    ) throws -> [String: SessionNamespace] {
        [:]
    }

    func resolveChain(
        for _: Blockchain,
        chains _: [ChainModel]
    ) throws -> ChainModel {
        throw fearless.ConvenienceError(error: "Unexpected chain resolution")
    }

    func resolveChains(
        for _: Set<Blockchain>,
        chains _: [ChainModel]
    ) -> [ChainModel] {
        []
    }

    func parseMethod(from _: Request) throws -> WalletConnectMethod {
        throw fearless.ConvenienceError(error: "Unexpected method parsing")
    }
}
