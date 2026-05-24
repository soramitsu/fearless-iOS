import XCTest
import UIKit
import BigInt
import FearlessFoundation
import FearlessSecureStorage
import SSFModels
import SSFUtils
@testable import fearless

final class NftSendTests: XCTestCase {
    func testDidLoad_whenViewProvided_thenSetsUpAndEstimatesInitialFee() {
        let fixture = makeFixture()
        let view = NftSendViewSpy()

        fixture.presenter.didLoad(view: view)

        XCTAssertTrue(fixture.interactor.output === fixture.presenter)
        XCTAssertEqual(fixture.interactor.estimateFeeCalls.count, 1)
        XCTAssertNil(fixture.interactor.estimateFeeCalls.last?.address)
    }

    func testSearchText_whenAddressChanges_thenUpdatesRecipientAndRefreshesFee() {
        let fixture = makeFixture()
        let view = NftSendViewSpy()
        let recipientExpectation = expectation(description: "recipient view model")
        view.onRecipientViewModel = { recipientExpectation.fulfill() }

        fixture.presenter.didLoad(view: view)
        fixture.presenter.searchTextDidChanged("recipient-address")

        wait(for: [recipientExpectation], timeout: 1)
        XCTAssertEqual(view.recipientViewModel?.address, "recipient-address")
        XCTAssertEqual(view.recipientViewModel?.isValid, true)
        XCTAssertEqual(fixture.interactor.estimateFeeCalls.last?.address, "recipient-address")
    }

    func testActions_whenTapped_thenRoutesToExpectedModules() {
        let fixture = makeFixture()
        let view = NftSendViewSpy()

        fixture.presenter.didLoad(view: view)
        fixture.presenter.didTapScanButton()
        fixture.presenter.didTapHistoryButton()
        fixture.presenter.didTapMyWalletsButton()
        fixture.presenter.didBackButtonTapped()

        XCTAssertTrue(fixture.router.scanView === view)
        XCTAssertTrue(fixture.router.scanOutput === fixture.presenter)
        XCTAssertTrue(fixture.router.historyView === view)
        XCTAssertTrue(fixture.router.historyOutput === fixture.presenter)
        XCTAssertEqual(fixture.router.historyWallet?.metaId, fixture.wallet.metaId)
        XCTAssertTrue(fixture.router.walletManagementView === view)
        XCTAssertEqual(fixture.router.selectedWalletId, fixture.wallet.metaId)
        XCTAssertTrue(fixture.router.walletManagementOutput === fixture.presenter)
        XCTAssertTrue(fixture.router.dismissedView === view)
    }

    func testContinue_whenRecipientAndFundsAreAvailable_thenRoutesToConfirm() {
        let fixture = makeFixture()
        let view = NftSendViewSpy()
        let recipientExpectation = expectation(description: "recipient view model")
        let feeExpectation = expectation(description: "fee view model")
        view.onRecipientViewModel = { recipientExpectation.fulfill() }
        view.onFeeViewModel = { feeExpectation.fulfill() }

        fixture.presenter.didLoad(view: view)
        fixture.presenter.searchTextDidChanged("recipient-address")
        fixture.presenter.didReceiveAccountInfo(
            result: .success(makeAccountInfo(free: 10_000)),
            for: fixture.utilityChainAsset
        )
        fixture.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 5)))

        wait(for: [recipientExpectation, feeExpectation], timeout: 1)
        fixture.presenter.didTapContinueButton()

        XCTAssertTrue(fixture.router.confirmView === view)
        XCTAssertEqual(fixture.router.confirmReceiver, "recipient-address")
        XCTAssertEqual(fixture.router.confirmWallet?.metaId, fixture.wallet.metaId)
        XCTAssertEqual(fixture.router.confirmNft, fixture.nft)
    }

    func testContactsOutput_whenAddressSelected_thenUpdatesRecipient() {
        let fixture = makeFixture()
        let view = NftSendViewSpy()
        let recipientExpectation = expectation(description: "recipient view model")
        view.onRecipientViewModel = { recipientExpectation.fulfill() }

        fixture.presenter.didLoad(view: view)
        fixture.presenter.didSelect(address: "contact-address")

        wait(for: [recipientExpectation], timeout: 1)
        XCTAssertEqual(view.recipientViewModel?.address, "contact-address")
        XCTAssertEqual(fixture.interactor.estimateFeeCalls.last?.address, "contact-address")
    }

    func testSendViewModelFactory_whenAccountScoreSetup_thenUsesInjectedEventCenterAndLogger() {
        let eventCenter = EventCenterSpy()
        let logger = LoggerSpy()
        let loggerExpectation = expectation(description: "logger debug")
        logger.onDebug = { message in
            if message.contains("Account statistics fetching error") {
                loggerExpectation.fulfill()
            }
        }

        let factory = SendViewModelFactory(
            iconGenerator: IconGeneratorStub(),
            accountScoreFetcher: AccountStatisticsFetcherStub(),
            settings: InMemorySettingsManager(),
            eventCenter: eventCenter,
            logger: logger
        )
        let viewModel = factory.buildAccountScoreViewModel(
            address: "0x1234",
            chain: makeNomisSupportedChain()
        )

        viewModel?.setup(with: nil)

        XCTAssertTrue(eventCenter.addedObserver === viewModel)
        wait(for: [loggerExpectation], timeout: 1)
    }

    private func makeFixture() -> NftSendFixture {
        let interactor = NftSendInteractorInputSpy()
        let router = NftSendRouterSpy()
        let wallet = AccountGenerator.generateMetaAccount().replacingName("Wallet")
        let nft = makeNFT()
        let presenter = NftSendPresenter(
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared,
            nft: nft,
            wallet: wallet,
            logger: LoggerSpy(),
            viewModelFactory: SendViewModelFactorySpy(),
            dataValidatingFactory: SendDataValidatingFactory(presentable: router)
        )

        return NftSendFixture(
            presenter: presenter,
            interactor: interactor,
            router: router,
            wallet: wallet,
            nft: nft,
            utilityChainAsset: nft.chain.utilityChainAssets()[0]
        )
    }

    private func makeNFT() -> NFT {
        let asset = makeUtilityAsset()
        let chain = ChainModelGenerator.generateChain(generatingAssets: 0, addressPrefix: 0)
        chain.assets = [asset]

        return NFT(
            chain: chain,
            tokenId: "1",
            title: "NFT #1",
            description: nil,
            smartContract: nil,
            metadata: nil,
            mediaThumbnail: nil,
            media: nil,
            tokenType: .erc721,
            collectionName: "Collection",
            collection: nil
        )
    }

    private func makeUtilityAsset() -> AssetModel {
        AssetModel(
            id: "utility",
            name: "DOT",
            symbol: "dot",
            precision: 2,
            icon: nil,
            currencyId: nil,
            existentialDeposit: nil,
            color: nil,
            isUtility: true,
            isNative: true,
            staking: nil,
            purchaseProviders: nil,
            type: nil,
            ethereumType: nil,
            priceProvider: nil,
            coingeckoPriceId: nil
        )
    }

    private func makeAccountInfo(free: BigUInt) -> AccountInfo {
        AccountInfo(
            nonce: 0,
            consumers: 0,
            providers: 0,
            data: AccountData(free: free, reserved: 0, frozen: 0, flags: 0)
        )
    }

    private func makeNomisSupportedChain() -> ChainModel {
        ChainModel(
            rank: nil,
            disabled: false,
            chainId: "137",
            paraId: nil,
            name: "Polygon",
            xcm: nil,
            nodes: [
                ChainNodeModel(
                    url: URL(string: "wss://polygon.node")!,
                    name: "Polygon",
                    apikey: nil
                )
            ],
            addressPrefix: 0,
            icon: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }
}

private struct NftSendFixture {
    let presenter: NftSendPresenter
    let interactor: NftSendInteractorInputSpy
    let router: NftSendRouterSpy
    let wallet: MetaAccountModel
    let nft: NFT
    let utilityChainAsset: ChainAsset
}

private final class NftSendViewSpy: NftSendViewInput {
    let controller = UIViewController()
    let isSetup = true

    var onFeeViewModel: (() -> Void)?
    var onRecipientViewModel: (() -> Void)?

    private(set) var feeViewModel: BalanceViewModelProtocol?
    private(set) var scamInfo: ScamInfo?
    private(set) var recipientViewModel: RecipientViewModel?

    func didReceive(feeViewModel: BalanceViewModelProtocol?) {
        self.feeViewModel = feeViewModel
        onFeeViewModel?()
    }

    func didReceive(scamInfo: ScamInfo?) {
        self.scamInfo = scamInfo
    }

    func didReceive(viewModel: RecipientViewModel) {
        recipientViewModel = viewModel
        onRecipientViewModel?()
    }
}

private final class NftSendInteractorInputSpy: NftSendInteractorInput {
    private(set) weak var output: NftSendInteractorOutput?
    private(set) var estimateFeeCalls: [(nft: NFT, address: String?)] = []
    var validationResult: AddressValidationResult = .valid("recipient-address")

    func setup(with output: NftSendInteractorOutput) {
        self.output = output
    }

    func estimateFee(for nft: NFT, address: String?) {
        estimateFeeCalls.append((nft, address))
    }

    func validate(address _: String?, for _: ChainModel) -> AddressValidationResult {
        validationResult
    }
}

private final class NftSendRouterSpy: NftSendRouterInput {
    private(set) weak var dismissedView: ControllerBackedProtocol?
    private(set) weak var scanView: ControllerBackedProtocol?
    private(set) weak var scanOutput: ScanQRModuleOutput?
    private(set) weak var historyView: ControllerBackedProtocol?
    private(set) weak var historyOutput: ContactsModuleOutput?
    private(set) var historyWallet: MetaAccountModel?
    private(set) var historyChain: ChainModel?
    private(set) weak var confirmView: ControllerBackedProtocol?
    private(set) var confirmNft: NFT?
    private(set) var confirmReceiver: String?
    private(set) var confirmScamInfo: ScamInfo?
    private(set) var confirmWallet: MetaAccountModel?
    private(set) weak var walletManagementView: ControllerBackedProtocol?
    private(set) weak var walletManagementOutput: WalletsManagmentModuleOutput?
    private(set) var selectedWalletId: MetaAccountId?
    private(set) var presentedMessages: [(message: String?, title: String)] = []
    private(set) var presentedError: Error?

    func dismiss(view: ControllerBackedProtocol?) {
        dismissedView = view
    }

    func presentScan(
        from view: ControllerBackedProtocol?,
        moduleOutput: ScanQRModuleOutput
    ) {
        scanView = view
        scanOutput = moduleOutput
    }

    func presentHistory(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chain: ChainModel,
        moduleOutput: ContactsModuleOutput
    ) {
        historyView = view
        historyWallet = wallet
        historyChain = chain
        historyOutput = moduleOutput
    }

    func presentConfirm(
        nft: NFT,
        receiver: String,
        scamInfo: ScamInfo?,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?
    ) {
        confirmNft = nft
        confirmReceiver = receiver
        confirmScamInfo = scamInfo
        confirmWallet = wallet
        confirmView = view
    }

    func showWalletManagment(
        selectedWalletId: MetaAccountId?,
        from view: ControllerBackedProtocol?,
        moduleOutput: WalletsManagmentModuleOutput?
    ) {
        self.selectedWalletId = selectedWalletId
        walletManagementView = view
        walletManagementOutput = moduleOutput
    }

    func present(
        viewModel _: SheetAlertPresentableViewModel,
        from _: ControllerBackedProtocol?
    ) {}

    func present(
        message: String?,
        title: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {
        presentedMessages.append((message, title))
    }

    func presentInfo(
        message: String?,
        title: String,
        from _: ControllerBackedProtocol?
    ) {
        presentedMessages.append((message, title))
    }

    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        presentedError = error
        return true
    }
}

private struct SendViewModelFactorySpy: SendViewModelFactoryProtocol {
    func buildRecipientViewModel(
        address: String,
        isValid: Bool,
        canEditing: Bool
    ) -> RecipientViewModel {
        RecipientViewModel(address: address, icon: nil, isValid: isValid, canEditing: canEditing)
    }

    func buildNetworkViewModel(chain: ChainModel, canEdit: Bool) -> SelectNetworkViewModel {
        SelectNetworkViewModel(chainName: chain.name, iconViewModel: nil, canEdit: canEdit)
    }

    func buildAccountScoreViewModel(address _: String?, chain _: ChainModel) -> AccountScoreViewModel? {
        nil
    }
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

private final class EventCenterSpy: EventCenterProtocol {
    private(set) weak var addedObserver: EventVisitorProtocol?

    func notify(with _: EventProtocol) {}

    func add(observer: EventVisitorProtocol, dispatchIn _: DispatchQueue?) {
        addedObserver = observer
    }

    func remove(observer _: EventVisitorProtocol) {}
}

private enum SendViewModelFactoryTestError: Error {
    case subscription
    case unusedIcon
}

private struct AccountStatisticsFetcherStub: AccountStatisticsFetching {
    func subscribeForStatistics(
        address _: String
    ) async throws -> AsyncThrowingStream<AccountStatisticsResponse, Error> {
        throw SendViewModelFactoryTestError.subscription
    }

    func fetchStatistics(address _: String) async throws -> AccountStatisticsResponse? {
        nil
    }
}

private struct IconGeneratorStub: IconGenerating {
    func generateFromAddress(_: String) throws -> DrawableIcon {
        throw SendViewModelFactoryTestError.unusedIcon
    }
}
