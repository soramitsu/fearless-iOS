import XCTest
import BigInt
import SoraFoundation
import SSFModels
import SSFQRService
import SSFUtils
@testable import fearless

final class CovHCrossChainPresenterTests: XCTestCase {
    func testNavigationActionsReachTheRouterWithTheCurrentSelection() throws {
        let harness = try CovHCrossChainHarness()
        harness.loadAndSelectSora()
        harness.presenter.didReceiveOrigin(chainAssets: harness.liberland.chainAssets)

        harness.presenter.didTapSelectAsset()
        XCTAssertEqual(harness.router.assetSelections.first?.selected, harness.origin.asset.id)
        XCTAssertEqual(harness.router.assetSelections.first?.offered, [harness.origin.asset.id])

        harness.presenter.didTapSelectDestNetwoek()
        XCTAssertEqual(harness.router.networkSelections.first?.selected, harness.sora.chainId)
        XCTAssertEqual(harness.router.networkSelections.first?.offered, [harness.sora.chainId])

        harness.presenter.didTapBackButton()
        harness.presenter.didTapScanButton()
        harness.presenter.didTapHistoryButton()
        harness.presenter.didTapMyWalletsButton()
        XCTAssertEqual(harness.router.calls, ["asset", "network", "dismiss", "scan", "history", "wallets"])
        XCTAssertEqual(harness.router.historyAssets.map(\.asset.id), [harness.origin.asset.id])
        XCTAssertEqual(harness.router.walletIds, [nil])
    }

    func testSelectedWalletFillsTheRecipientOnTheDestination() throws {
        let harness = try CovHCrossChainHarness()
        harness.presenter.didLoad(view: harness.view)
        let destination = AccountGenerator.generateMetaAccount()
        harness.presenter.selectedWallet(destination, for: 0)
        XCTAssertEqual(harness.view.recipients.last?.address, destination.name)
        XCTAssertEqual(harness.view.recipients.last?.isValid, false, "No destination network is selected yet")

        harness.presenter.didSetup()
        harness.presenter.didReceiveAvailableDestChainAssets(harness.sora.chainAssets)
        let accountId = try XCTUnwrap(destination.fetch(for: harness.sora.accountRequest())?.accountId)
        let expected = try AddressFactory.address(for: accountId, chain: harness.sora)
        XCTAssertEqual(harness.view.recipients.last?.address, expected)
        XCTAssertEqual(harness.view.recipients.last?.isValid, true)
        XCTAssertTrue(harness.interactor.fetchedAddresses.contains(expected))

        harness.presenter.didTapMyWalletsButton()
        XCTAssertEqual(harness.router.walletIds, [destination.metaId])
    }

    func testOnlyReviewedOriginAssetsCanBeSelected() throws {
        let harness = try CovHCrossChainHarness()
        harness.loadAndSelectSora()
        let loadingBefore = harness.view.loadingStates.count
        let originsBefore = harness.interactor.origins.count

        harness.presenter.assetSelection(didCompleteWith: nil, contextTag: nil)
        harness.presenter.assetSelection(didCompleteWith: harness.utility, contextTag: nil)
        XCTAssertEqual(harness.view.loadingStates.count, loadingBefore)
        XCTAssertEqual(harness.interactor.origins.count, originsBefore)

        harness.presenter.assetSelection(didCompleteWith: harness.origin, contextTag: nil)
        XCTAssertEqual(harness.view.loadingStates.last, true)
        XCTAssertEqual(harness.interactor.origins.last??.asset.id, harness.origin.asset.id)
    }

    func testDestinationSelectionAcceptsOnlyReviewedNetworks() throws {
        let harness = try CovHCrossChainHarness()
        harness.presenter.didLoad(view: harness.view)
        let listView = CovHCrossChainSelectNetworkView()
        harness.presenter.chainSelection(view: listView, didCompleteWith: nil, contextTag: nil)
        harness.presenter.chainSelection(view: listView, didCompleteWith: harness.liberland, contextTag: nil)
        XCTAssertTrue(harness.interactor.destinations.isEmpty)

        harness.presenter.chainSelection(view: listView, didCompleteWith: harness.sora, contextTag: nil)
        XCTAssertEqual(harness.interactor.destinations.map(\.chainId), [harness.sora.chainId])
        XCTAssertEqual(harness.view.loadingStates.last, true)
    }

    func testContactsAndScansSetTheRecipient() throws {
        let harness = try CovHCrossChainHarness()
        harness.loadAndSelectSora()
        harness.presenter.didFinishWith(scanType: .walletConnect("wc:1"))
        XCTAssertTrue(harness.view.recipients.isEmpty, "A WalletConnect code carries no address")

        let address = harness.soraAddress(byte: 7)
        harness.presenter.didSelect(address: address)
        XCTAssertEqual(harness.view.recipients.last?.address, address)
        XCTAssertEqual(harness.view.recipients.last?.isValid, true)
        XCTAssertEqual(harness.interactor.fetchedAddresses.last, address)
    }

    func testInteractorFailuresAreLoggedAndStillSettleLoading() throws {
        let harness = try CovHCrossChainHarness()
        harness.loadAndSelectSora()
        let accountId = Data(repeating: 1, count: 32)
        harness.presenter.didReceiveAccountInfo(result: .failure(CovHSendError.failed), accountId: accountId, chainAsset: harness.origin)
        harness.presenter.didReceiveExistentialDeposit(result: .failure(CovHSendError.failed))
        harness.presenter.didReceiveDestinationFee(result: .failure(CovHSendError.failed))
        harness.presenter.didReceiveOriginFee(result: .failure(CovHSendError.failed))
        harness.presenter.didReceiveDestinationAccountInfo(accountInfo: nil)
        harness.presenter.didReceiveDestinationAccountInfoError(error: CovHSendError.failed)
        harness.presenter.didReceiveAssetAccountInfoError(error: CovHSendError.failed)
        XCTAssertGreaterThanOrEqual(harness.logger.errors.count, 6)
        XCTAssertEqual(harness.view.loadingStates.last, true, "The destination deposit is still missing")
        harness.presenter.didReceiveDestinationExistentialDeposit(result: .success(.zero))
        XCTAssertEqual(harness.view.loadingStates.last, false, "Every lookup has settled, failures included")
    }
}

final class CovHCrossChainHarness {
    let presenter: CrossChainPresenter
    let interactor = CovHCrossChainInteractorStub()
    let router = CovHCrossChainRouterSpy()
    let view = CovHCrossChainViewSpy()
    let logger = CovHSendLogger()
    let liberland: ChainModel
    let sora: ChainModel
    let origin: ChainAsset
    let utility: ChainAsset
    let wallet = AccountGenerator.generateMetaAccount()

    init(symbol: String = "LLD") throws {
        let chains = try Self.registryChains()
        liberland = try XCTUnwrap(chains.first { $0.chainId == ReviewedXcmRouteRegistry.liberlandChainId })
        sora = try XCTUnwrap(chains.first { $0.chainId == ReviewedXcmRouteRegistry.soraChainId })
        let definition = try XCTUnwrap(ReviewedXcmRouteRegistry.routes.first { $0.originSymbol == symbol })
        origin = try XCTUnwrap(liberland.chainAssets.first { $0.asset.id == definition.originAssetId })
        let originAssetId = origin.asset.id
        utility = try XCTUnwrap(liberland.chainAssets.first { $0.asset.id != originAssetId })
        let validating = SendDataValidatingFactory(presentable: router)
        presenter = CrossChainPresenter(
            originChainAsset: origin,
            reviewedRoute: ReviewedCrossChainRouteContext(definition: definition, providerId: "sora-liberland-xcm"),
            wallet: wallet,
            viewModelFactory: CrossChainViewModelFactory(iconGenerator: UniversalIconGenerator()),
            dataValidatingFactory: validating,
            logger: logger,
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared
        )
        validating.view = view
    }

    func loadAndSelectSora() {
        presenter.didLoad(view: view)
        presenter.didSetup()
        presenter.didReceiveAvailableDestChainAssets(sora.chainAssets)
    }

    func soraAddress(byte: UInt8) -> String {
        (try? AddressFactory.address(for: Data(repeating: byte, count: 32), chain: sora)) ?? ""
    }

    static func registryChains() throws -> [ChainModel] {
        let url = try XCTUnwrap(Bundle(for: CovHCrossChainPresenterTests.self).url(
            forResource: "chains_v13_owned_20261029", withExtension: "json", subdirectory: "Registry"
        ))
        let data = try Data(contentsOf: url)
        if let decoded = try? JSONDecoder().decode([ChainModel].self, from: data) {
            return decoded
        }
        return try JSONDecoder().decode([ChainModel].self, from: ChainSyncService.coerceChainsPayloadForCompatibility(data))
    }
}

final class CovHCrossChainInteractorStub: CrossChainInteractorInput {
    var origins: [ChainAsset?] = []
    var destinations: [ChainModel] = []
    var fetchedAddresses: [String] = []
    var estimates = 0

    func setup(with _: CrossChainInteractorOutput) {}
    func didReceive(originChainAsset: ChainAsset?) { origins.append(originChainAsset) }
    func didReceive(destinationChain: ChainModel) { destinations.append(destinationChain) }
    func estimateFee(originChainAsset _: ChainAsset, destinationChainModel _: ChainModel, amount _: Decimal?) { estimates += 1 }
    func validate(address: String?, for chain: ChainModel) -> AddressValidationResult {
        guard let address, (try? AddressFactory.accountId(from: address, chain: chain)) != nil else {
            return .invalid(address)
        }
        return .valid(address)
    }

    func fetchDestinationAccountInfo(address: String) { fetchedAddresses.append(address) }
}

final class CovHCrossChainViewSpy: UIViewController, CrossChainViewInput, Localizable {
    var loadingStates: [Bool] = []
    var recipients: [RecipientViewModel] = []

    func didReceive(assetBalanceViewModel _: AssetBalanceViewModelProtocol?) {}
    func didReceive(amountInputViewModel _: IAmountInputViewModel?) {}
    func didReceive(originSelectNetworkViewModel _: SelectNetworkViewModel) {}
    func didReceive(destSelectNetworkViewModel _: SelectNetworkViewModel?) {}
    func didReceive(originFeeViewModel _: LocalizableResource<BalanceViewModelProtocol>?) {}
    func didReceive(destinationFeeViewModel _: LocalizableResource<BalanceViewModelProtocol>?) {}
    func didReceive(recipientViewModel: RecipientViewModel) { recipients.append(recipientViewModel) }
    func setButtonLoadingState(isLoading: Bool) { loadingStates.append(isLoading) }
    func applyLocalization() {}
}

final class CovHCrossChainSelectNetworkView: UIViewController, SelectNetworkViewInput {
    func didReload() {}
    func bind(viewModel _: TextSearchViewModel?) {}
}

final class CovHCrossChainRouterSpy: CrossChainRouterInput {
    var calls: [String] = []
    var assetSelections: [(selected: AssetModel.Id?, offered: [AssetModel.Id])] = []
    var networkSelections: [(selected: ChainModel.Id?, offered: [ChainModel.Id])] = []
    var historyAssets: [ChainAsset] = []
    var walletIds: [MetaAccountId?] = []
    var messages: [String] = []

    func showSelectNetwork(
        from _: ControllerBackedProtocol?, wallet _: MetaAccountModel, selectedChainId: ChainModel.Id?, chainModels: [ChainModel]?,
        contextTag _: Int?, delegate _: SelectNetworkDelegate?
    ) {
        calls.append("network")
        networkSelections.append((selectedChainId, chainModels?.map(\.chainId) ?? []))
    }

    func showSelectAsset(
        from _: ControllerBackedProtocol?, wallet _: MetaAccountModel, chainAssets: [ChainAsset]?, selectedAssetId: AssetModel.Id?,
        output _: SelectAssetModuleOutput
    ) {
        calls.append("asset")
        assetSelections.append((selectedAssetId, chainAssets?.map(\.asset.id) ?? []))
    }

    func showConfirmation(from _: ControllerBackedProtocol?, data _: CrossChainConfirmationData) { calls.append("confirm") }
    func presentScan(from _: ControllerBackedProtocol?, moduleOutput _: ScanQRModuleOutput) { calls.append("scan") }
    func presentHistory(from _: ControllerBackedProtocol?, wallet _: MetaAccountModel, chainAsset: ChainAsset, moduleOutput _: ContactsModuleOutput) {
        calls.append("history")
        historyAssets.append(chainAsset)
    }

    func showWalletManagment(selectedWalletId: MetaAccountId?, from _: ControllerBackedProtocol?, moduleOutput _: WalletsManagmentModuleOutput?) {
        calls.append("wallets")
        walletIds.append(selectedWalletId)
    }

    func present(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {
        messages.append(viewModel.message ?? viewModel.title)
    }

    func present(message: String?, title: String, closeAction _: String?, from _: ControllerBackedProtocol?, actions _: [SheetAlertPresentableAction]) {
        messages.append(message ?? title)
    }

    func presentInfo(message: String?, title: String, from _: ControllerBackedProtocol?) {
        messages.append(message ?? title)
    }

    func dismiss(view _: ControllerBackedProtocol?) { calls.append("dismiss") }
}
