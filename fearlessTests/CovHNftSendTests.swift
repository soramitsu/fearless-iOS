import BigInt
import RobinHood
import SoraFoundation
import SSFModels
import SSFQRService
import UIKit
import XCTest
@testable import fearless

final class CovHNftSendViewSpy: CovHNftHostController, NftSendViewInput, Localizable {
    private(set) var fees: [BalanceViewModelProtocol?] = []
    private(set) var scams: [ScamInfo?] = []
    private(set) var recipients: [RecipientViewModel] = []

    func didReceive(feeViewModel: BalanceViewModelProtocol?) { fees.append(feeViewModel) }
    func didReceive(scamInfo: ScamInfo?) { scams.append(scamInfo) }
    func didReceive(viewModel: RecipientViewModel) { recipients.append(viewModel) }
    func applyLocalization() {}
}

final class CovHNftSendInteractorSpy: NftSendInteractorInput {
    var validation: AddressValidationResult = .valid("addr")
    private(set) weak var output: NftSendInteractorOutput?
    private(set) var estimates: [String?] = []
    private(set) var scamLookups: [String] = []
    private(set) var scamInvalidations = 0

    func setup(with output: NftSendInteractorOutput) { self.output = output }
    func estimateFee(for _: NFT, address: String?) { estimates.append(address) }
    func validate(address _: String?, for _: ChainModel) -> AddressValidationResult { validation }
    func fetchScamInfo(for address: String) { scamLookups.append(address) }
    func invalidateScamInfo() { scamInvalidations += 1 }
}

final class CovHNftSendRouterSpy: NftSendRouterInput {
    private(set) var calls: [String] = []
    private(set) var confirms: [(String, ScamInfo?)] = []
    private(set) var selectedWalletIds: [MetaAccountId?] = []

    func presentScan(from _: ControllerBackedProtocol?, moduleOutput _: ScanQRModuleOutput) { calls.append("scan") }
    func presentHistory(from _: ControllerBackedProtocol?, wallet _: MetaAccountModel, chain _: ChainModel, moduleOutput _: ContactsModuleOutput) {
        calls.append("history")
    }

    func presentConfirm(nft _: NFT, receiver: String, scamInfo: ScamInfo?, wallet _: MetaAccountModel, from _: ControllerBackedProtocol?) {
        confirms.append((receiver, scamInfo))
    }

    func showWalletManagment(selectedWalletId: MetaAccountId?, from _: ControllerBackedProtocol?, moduleOutput _: WalletsManagmentModuleOutput?) {
        selectedWalletIds.append(selectedWalletId)
    }

    func dismiss(view _: ControllerBackedProtocol?) { calls.append("dismiss") }
    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool { true }
    func presentFeeNotReceived(from _: ControllerBackedProtocol, locale _: Locale?) { calls.append("noFee") }
    func presentAmountTooHigh(from _: ControllerBackedProtocol, locale _: Locale?) { calls.append("tooHigh") }
}

final class CovHNftSendViewModelFactoryStub: SendViewModelFactoryProtocol {
    func buildRecipientViewModel(address: String, isValid: Bool, canEditing: Bool) -> RecipientViewModel {
        RecipientViewModel(address: address, icon: nil, isValid: isValid, canEditing: canEditing)
    }

    func buildNetworkViewModel(chain: ChainModel, canEdit: Bool) -> SelectNetworkViewModel {
        SelectNetworkViewModel(chainName: chain.name, iconViewModel: nil, canEdit: canEdit)
    }
}

final class CovHNftSendPresenterTests: XCTestCase {
    private struct Context {
        let view = CovHNftSendViewSpy()
        let interactor = CovHNftSendInteractorSpy()
        let router = CovHNftSendRouterSpy()
        let wallet = CovHNftFixtures.wallet()
        let chain: ChainModel
        let nft: NFT
        let presenter: NftSendPresenter

        init(utility: Bool = true) {
            chain = CovHNftFixtures.chain(utility: utility)
            nft = CovHNftFixtures.nft(chain: chain)
            let validating = SendDataValidatingFactory(presentable: router)
            presenter = NftSendPresenter(
                interactor: interactor,
                router: router,
                localizationManager: LocalizationManager.shared,
                nft: nft,
                wallet: wallet,
                logger: Logger.shared,
                viewModelFactory: CovHNftSendViewModelFactoryStub(),
                dataValidatingFactory: validating
            )
            validating.view = view
            presenter.didLoad(view: view)
        }
    }

    func testLoadEstimatesFeeAndButtonsRoute() {
        let context = Context()
        XCTAssertTrue(context.interactor.output === context.presenter)
        XCTAssertEqual(context.interactor.estimates, [nil])

        context.presenter.didTapScanButton()
        context.presenter.didTapHistoryButton()
        context.presenter.didBackButtonTapped()
        context.presenter.didTapMyWalletsButton()
        context.presenter.didTapContinueButton()
        context.presenter.applyLocalization()

        XCTAssertEqual(context.router.calls, ["scan", "history", "dismiss"])
        XCTAssertEqual(context.router.selectedWalletIds, [context.wallet.metaId])
        XCTAssertTrue(context.router.confirms.isEmpty, "no recipient yet")
    }

    func testRecipientSourcesUpdateRecipientViewModel() {
        let context = Context()
        context.interactor.validation = .invalid("typed")
        context.presenter.searchTextDidChanged("typed")
        context.interactor.validation = .valid("contact")
        context.presenter.didSelect(address: "contact")
        context.presenter.didFinishWith(scanType: .walletConnect("wc:uri"))
        let info = SoraQRInfo(address: "scanned", rawPublicKey: Data([1]), username: "user", assetId: "asset", amount: nil)
        context.presenter.didFinishWith(scanType: .qrInfo(.sora(info)))
        let other = CovHNftFixtures.wallet()
        context.presenter.selectedWallet(other, for: 0)
        context.presenter.selectedWallet(CovHNftFixtures.walletWithoutAccounts(), for: 0)

        CovHNftWait.until { context.view.recipients.count == 4 }
        let expectedOther = CovHNftFixtures.address(of: other, on: context.chain)
        XCTAssertEqual(context.view.recipients.map(\.address), ["typed", "contact", "scanned", expectedOther ?? "-"])
        XCTAssertEqual(context.view.recipients.map(\.isValid), [false, true, true, true])
        XCTAssertEqual(context.interactor.estimates, [nil, "typed", "contact", "scanned", expectedOther])
    }

    func testContinueRequiresFeeThenBalanceThenConfirms() {
        let context = Context()
        context.presenter.searchTextDidChanged("receiver")

        context.presenter.didTapContinueButton()
        XCTAssertEqual(context.router.calls, ["noFee"])

        context.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: BigUInt(1_000_000_000_000))))
        context.presenter.didTapContinueButton()
        XCTAssertEqual(context.router.calls, ["noFee", "tooHigh"])

        let asset = context.chain.utilityChainAssets()[0]
        context.presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: BigUInt(5_000_000_000_000))), for: asset)
        let scam = ScamInfo(name: "Scam", address: "receiver", type: .scam, subtype: "Phishing")
        context.presenter.didReceive(scamInfo: scam)
        context.presenter.didTapContinueButton()

        XCTAssertEqual(context.router.confirms.count, 1)
        XCTAssertEqual(context.router.confirms.first?.0, "receiver")
        XCTAssertEqual(context.router.confirms.first?.1, scam)
        XCTAssertEqual(context.view.scams.count, 1)

        CovHNftWait.until { context.view.fees.contains { $0 != nil } }
        XCTAssertFalse(context.view.fees.compactMap { $0 }.first?.amount.isEmpty ?? true)
    }

    func testZeroBalanceAndErrorsKeepContinueBlocked() {
        let context = Context()
        context.presenter.searchTextDidChanged("receiver")
        context.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: BigUInt(1))))
        let asset = context.chain.utilityChainAssets()[0]
        context.presenter.didReceiveAccountInfo(result: .success(nil), for: asset)
        context.presenter.didReceiveAccountInfo(result: .failure(CovHNftError.failed), for: asset)
        context.presenter.didReceiveFee(result: .failure(CovHNftError.failed))
        context.presenter.didTapContinueButton()
        XCTAssertEqual(context.router.calls, ["tooHigh"])
        XCTAssertTrue(context.router.confirms.isEmpty)
    }

    func testFeeWithoutUtilityAssetIsIgnored() {
        let context = Context(utility: false)
        context.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: BigUInt(10))))
        context.presenter.provideFeeViewModel()
        CovHNftWait.spin(0.2)
        XCTAssertTrue(context.view.fees.isEmpty)
    }
}

final class CovHNftScamFetcherStub: ScamInfoFetching {
    var result: ScamInfo?

    func fetch(address _: String, chain _: ChainModel) async throws -> ScamInfo? {
        result
    }
}

final class CovHNftSendOutputSpy: NftSendInteractorOutput {
    private let lock = NSLock()
    private var storedFees: [Result<RuntimeDispatchInfo, Error>] = []
    private var storedScams: [ScamInfo?] = []
    private var storedInfos: [Result<AccountInfo?, Error>] = []

    var fees: [Result<RuntimeDispatchInfo, Error>] { lock.lock(); defer { lock.unlock() }; return storedFees }
    var scams: [ScamInfo?] { lock.lock(); defer { lock.unlock() }; return storedScams }
    var infos: [Result<AccountInfo?, Error>] { lock.lock(); defer { lock.unlock() }; return storedInfos }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        lock.lock()
        storedFees.append(result)
        lock.unlock()
    }

    func didReceive(scamInfo: ScamInfo?) {
        lock.lock()
        storedScams.append(scamInfo)
        lock.unlock()
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for _: ChainAsset) {
        lock.lock()
        storedInfos.append(result)
        lock.unlock()
    }
}

final class CovHNftSendInteractorTests: XCTestCase {
    private func makeInteractor(
        chain: ChainModel,
        wallet: MetaAccountModel,
        transfer: CovHNftTransferStub,
        adapter: CovHNftAccountInfoAdapterSpy,
        scam: CovHNftScamFetcherStub = CovHNftScamFetcherStub()
    ) -> NftSendInteractor {
        let definer = AddressChainDefiner(
            operationManager: OperationManagerFacade.sharedManager,
            chainModelRepository: AnyDataProviderRepository(ChainRepositoryFactory().createRepository(
                sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
            )),
            wallet: wallet
        )
        return NftSendInteractor(
            transferService: transfer,
            operationManager: OperationManagerFacade.sharedManager,
            scamInfoFetching: scam,
            addressChainDefiner: definer,
            accountInfoSubscriptionAdapter: adapter,
            chain: chain,
            wallet: wallet
        )
    }

    func testSetupSubscribesAndFeeFlows() throws {
        let chain = CovHNftFixtures.chain()
        let wallet = CovHNftFixtures.wallet()
        let transfer = CovHNftTransferStub()
        let adapter = CovHNftAccountInfoAdapterSpy()
        let interactor = makeInteractor(chain: chain, wallet: wallet, transfer: transfer, adapter: adapter)
        let output = CovHNftSendOutputSpy()

        interactor.setup(with: output)
        XCTAssertEqual(adapter.subscriptions.count, 1)
        XCTAssertEqual(adapter.subscriptions.first?.0.asset.id, chain.utilityChainAssets().first?.asset.id)

        let nft = CovHNftFixtures.nft(chain: chain)
        interactor.estimateFee(for: nft, address: nil)
        CovHNftWait.until { !transfer.listeners.isEmpty }
        XCTAssertEqual(transfer.estimates, [""])
        XCTAssertEqual(try output.fees.first?.get().fee, "1000000000000")

        let listener = try XCTUnwrap(transfer.listeners.first)
        listener.didReceiveFee(fee: BigUInt(5))
        listener.didReceiveFeeError(feeError: CovHNftError.failed)
        CovHNftWait.until { output.fees.count == 3 }
        XCTAssertEqual(try output.fees[1].get().fee, "5")
        XCTAssertThrowsError(try output.fees[2].get())

        transfer.fee = .failure(CovHNftError.failed)
        interactor.estimateFee(for: nft, address: "receiver")
        CovHNftWait.until { output.fees.count == 4 }
        XCTAssertThrowsError(try output.fees[3].get())

        interactor.handleAccountInfo(result: .success(nil), accountId: Data(), chainAsset: chain.utilityChainAssets()[0])
        XCTAssertEqual(output.infos.count, 1)
    }

    func testScamLookupAndAddressValidation() throws {
        let chain = CovHNftFixtures.chain()
        let wallet = CovHNftFixtures.wallet()
        let scam = CovHNftScamFetcherStub()
        scam.result = ScamInfo(name: "Bad", address: "bad", type: .theft, subtype: "")
        let adapter = CovHNftAccountInfoAdapterSpy()
        let interactor = makeInteractor(chain: chain, wallet: wallet, transfer: CovHNftTransferStub(), adapter: adapter, scam: scam)
        let output = CovHNftSendOutputSpy()
        interactor.setup(with: output)

        interactor.fetchScamInfo(for: "bad")
        CovHNftWait.until { !output.scams.isEmpty }
        XCTAssertEqual(output.scams.first??.name, "Bad")

        let own = try XCTUnwrap(CovHNftFixtures.address(of: wallet, on: chain))
        let otherAddress = try XCTUnwrap(CovHNftFixtures.address(of: CovHNftFixtures.wallet(), on: chain))
        XCTAssertEqual(interactor.validate(address: own, for: chain), .sameAddress(own))
        XCTAssertEqual(interactor.validate(address: otherAddress, for: chain), .valid(otherAddress))
        XCTAssertEqual(interactor.validate(address: "", for: chain), .invalid(""))
    }

    func testSetupWithoutUtilityAssetDoesNotSubscribe() {
        let adapter = CovHNftAccountInfoAdapterSpy()
        let interactor = makeInteractor(
            chain: CovHNftFixtures.chain(utility: false),
            wallet: CovHNftFixtures.wallet(),
            transfer: CovHNftTransferStub(),
            adapter: adapter
        )
        interactor.setup(with: CovHNftSendOutputSpy())
        XCTAssertTrue(adapter.subscriptions.isEmpty)
    }
}

final class CovHNftSendRoutingTests: XCTestCase {
    func testRouterPresentsScanHistoryAndWallets() throws {
        let host = CovHNftHostController()
        let navigation = CovHNftNavigationSpy(rootViewController: host)
        let router = NftSendRouter()
        let wallet = CovHNftFixtures.wallet()
        let output = CovHNftSendModuleOutputSpy()

        router.presentScan(from: host, moduleOutput: output)
        XCTAssertTrue(host.presented.last is ScanQRViewController)

        router.presentHistory(from: host, wallet: wallet, chain: CovHNftFixtures.chain(), moduleOutput: output)
        XCTAssertEqual(host.presented.count, 1, "a chain without history has no contacts screen")

        router.presentHistory(from: host, wallet: wallet, chain: CovHNftFixtures.chain(historyType: "etherscan"), moduleOutput: output)
        let contacts = try XCTUnwrap(host.presented.last as? FearlessNavigationController)
        XCTAssertTrue(contacts.viewControllers.first is ContactsViewController)

        router.showWalletManagment(selectedWalletId: wallet.metaId, from: host, moduleOutput: output)
        XCTAssertEqual(host.presented.count, 3)

        let chain = CovHNftFixtures.chain()
        router.presentConfirm(nft: CovHNftFixtures.nft(chain: chain), receiver: "r", scamInfo: nil, wallet: wallet, from: host)
        XCTAssertTrue(navigation.pushed.isEmpty, "substrate NFTs have no transfer service")
    }

    func testAssembliesRefuseNftsWithoutTransferService() {
        let substrate = CovHNftFixtures.chain()
        let ethereum = CovHNftFixtures.chain(ethereum: true)
        let wallet = CovHNftFixtures.wallet()

        XCTAssertNil(NftSendAssembly.configureModule(nft: CovHNftFixtures.nft(chain: substrate), wallet: wallet))
        XCTAssertNil(NftSendAssembly.configureModule(nft: CovHNftFixtures.nft(chain: ethereum), wallet: wallet))
        XCTAssertNil(NftSendAssembly.configureModule(nft: CovHNftFixtures.nft(chain: substrate), wallet: CovHNftFixtures.walletWithoutAccounts()))

        XCTAssertNil(NftSendConfirmAssembly.configureModule(
            wallet: wallet, nft: CovHNftFixtures.nft(chain: substrate), receiverAddress: "r", scamInfo: nil
        ))
        XCTAssertNil(NftSendConfirmAssembly.configureModule(
            wallet: wallet, nft: CovHNftFixtures.nft(chain: ethereum), receiverAddress: "r", scamInfo: nil
        ))
        XCTAssertNil(NftSendConfirmAssembly.configureModule(
            wallet: CovHNftFixtures.walletWithoutAccounts(), nft: CovHNftFixtures.nft(chain: substrate), receiverAddress: "r", scamInfo: nil
        ))
    }
}

final class CovHNftSendModuleOutputSpy: ScanQRModuleOutput, ContactsModuleOutput, WalletsManagmentModuleOutput {
    func didFinishWith(scanType _: QRMatcherType) {}
    func didSelect(address _: String) {}
    func showAddNewWallet() {}
    func showImportWallet(defaultSource _: AccountImportSource) {}
    func showImportGoogle() {}
    func showGetPreinstalledWallet() {}
    func selectedWallet(_: MetaAccountModel, for _: Int) {}
}
