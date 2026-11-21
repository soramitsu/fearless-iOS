import XCTest
import UIKit
import SoraFoundation
import SoraUI
import SSFModels
@testable import fearless

final class CovHWalletMainFixture {
    let wallet = AccountGenerator.generateMetaAccount()
    let view = CovHWalletMainView()
    let router = CovHWalletMainRouter()
    let interactor = CovHWalletMainInteractor()
    let factory = CovHWalletMainFactory()
    let notice = CovHUpdateNotice()
    let modules = CovHWalletModules()
    var window: UIWindow?
    lazy var presenter = WalletMainContainerPresenter(
        balanceInfoModuleInput: modules, assetListModuleInput: modules, nftModuleInput: modules,
        wallet: wallet, viewModelFactory: factory, interactor: interactor, router: router,
        updateSecurityNotice: notice, localizationManager: LocalizationManager.shared
    )

    func start(hosted: Bool = false) {
        if hosted {
            let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
            let host = scene.map(UIWindow.init(windowScene:)) ?? UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            host.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
            host.rootViewController = view
            host.makeKeyAndVisible()
            view.loadViewIfNeeded()
            view.view.layoutIfNeeded()
            window = host
        }
        presenter.didLoad(view: view)
    }

    deinit {
        window?.isHidden = true
        window?.rootViewController = nil
    }
}

final class CovHWalletMainView: UIViewController, WalletMainContainerViewInput {
    var models: [WalletMainContainerViewModel] = []
    var availability: [Bool] = []
    var sync: [WalletSyncUpdate] = []
    func didReceiveViewModel(_ viewModel: WalletMainContainerViewModel) { models.append(viewModel) }
    func didReceiveNftAvailability(isNftAvailable: Bool) { availability.append(isNftAvailable) }
    func didReceive(syncUpdate: WalletSyncUpdate) { sync.append(syncUpdate) }
}

final class CovHWalletMainFactory: WalletMainContainerViewModelFactoryProtocol {
    var filters: [NetworkManagmentFilter] = []
    var chains: [[ChainModel]] = []
    var wallets: [MetaAccountModel] = []
    func buildViewModel(
        selectedFilter: NetworkManagmentFilter, selectedChains: [ChainModel], selectedMetaAccount: MetaAccountModel, locale: Locale
    ) -> WalletMainContainerViewModel {
        filters.append(selectedFilter)
        chains.append(selectedChains)
        wallets.append(selectedMetaAccount)
        return WalletMainContainerViewModel(
            walletName: selectedMetaAccount.name, selectedFilter: "filter", selectedFilterImage: nil, address: nil, accountScoreViewModel: nil
        )
    }
}

final class CovHWalletModules: BalanceInfoModuleInput, ChainAssetListModuleInput, MainNftContainerModuleInput {
    var balanceTypes: [BalanceInfoType] = []
    var filters: [[ChainAssetsFetching.Filter]] = []
    var networkFilters: [NetworkManagmentFilter?] = []
    var chains: [[ChainModel]?] = []
    func replace(infoType: BalanceInfoType) { balanceTypes.append(infoType) }
    func updateChainAssets(
        using filters: [ChainAssetsFetching.Filter], sorts: [ChainAssetsFetching.SortDescriptor], networkFilter: NetworkManagmentFilter?
    ) {
        self.filters.append(filters)
        networkFilters.append(networkFilter)
    }
    func didSelect(chains: [ChainModel]?) { self.chains.append(chains) }
}

final class CovHUpdateNotice: UpdateSecurityNoticeTracking {
    var isPending = false
    var acknowledgements = 0
    func recordStartup(hadStoredWallets: Bool) { isPending = hadStoredWallets }
    func acknowledge() { acknowledgements += 1; isPending = false }
}

final class CovHWalletMainInteractor: WalletMainContainerInteractorInput {
    weak var output: WalletMainContainerInteractorOutput?
    var uris: [String] = []
    var error: Error?
    var notices: [StoredWalletRecordsNotice] = []
    var passwordAcknowledgements = 0
    var switches: [[UniversalWalletNoPasswordAccount]] = []
    var arrivals: [[UniversalWalletOldAddressArrival]] = []
    func setup(with output: WalletMainContainerInteractorOutput) { self.output = output }
    func walletConnect(uri: String) async throws {
        uris.append(uri)
        if let error { throw error }
    }
    func acknowledge(_ notice: StoredWalletRecordsNotice) { notices.append(notice) }
    func acknowledgeUniversalWalletPasswordNotice() { passwordAcknowledgements += 1 }
    func switchNoPasswordAccounts(_ accounts: [UniversalWalletNoPasswordAccount]) { switches.append(accounts) }
    func acknowledgeOldAddressArrivals(_ arrivals: [UniversalWalletOldAddressArrival]) { self.arrivals.append(arrivals) }
}

final class CovHWalletMainRouter: WalletMainContainerRouterInput {
    var calls: [String] = []
    var wallets: [MetaAccountModel] = []
    var actions: [WalletHomeAction] = []
    var assets: [ChainAsset] = []
    var sheets: [SheetAlertPresentableViewModel] = []
    var errors: [Error] = []
    var scoreAddress: String?
    var statusCount = 0
    func showWalletManagment(from view: WalletMainContainerViewInput?, moduleOutput: WalletsManagmentModuleOutput?) { calls.append("wallets") }
    func showScanQr(from view: WalletMainContainerViewInput?, moduleOutput: ScanQRModuleOutput) { calls.append("qr") }
    func showSearch(from view: WalletMainContainerViewInput?, wallet: MetaAccountModel) { calls.append("search"); wallets.append(wallet) }
    func showSelectNetwork(from view: WalletMainContainerViewInput?, wallet: MetaAccountModel, delegate: NetworkManagmentModuleOutput?) {
        calls.append("network"); wallets.append(wallet)
    }
    func showSelectCurrency(from view: WalletMainContainerViewInput?, wallet: MetaAccountModel) { calls.append("currency"); wallets.append(wallet) }
    func showSendFlow(from view: ControllerBackedProtocol?, wallet: MetaAccountModel, initialData: SendFlowInitialData) {
        calls.append("send"); wallets.append(wallet)
    }
    func showControllerAccountFlow(from view: ControllerBackedProtocol?, chainAsset: ChainAsset, wallet: MetaAccountModel) {
        calls.append("controller"); assets.append(chainAsset); wallets.append(wallet)
    }
    func showMainStaking(from view: WalletMainContainerViewInput?) { calls.append("staking") }
    func showWalletDetails(from view: WalletMainContainerViewInput?, wallet: MetaAccountModel) { calls.append("details"); wallets.append(wallet) }
    func showAssetPicker(from view: WalletMainContainerViewInput?, wallet: MetaAccountModel, action: WalletHomeAction, output: SelectAssetModuleOutput) {
        calls.append("picker"); actions.append(action); wallets.append(wallet)
    }
    func showReceive(from view: WalletMainContainerViewInput?, wallet: MetaAccountModel, chainAsset: ChainAsset) {
        calls.append("receive"); wallets.append(wallet); assets.append(chainAsset)
    }
    func showAssetDetails(from view: WalletMainContainerViewInput?, chainAsset: ChainAsset) { calls.append("asset"); assets.append(chainAsset) }
    func showSwap(from view: WalletMainContainerViewInput?) { calls.append("swap") }
    func showCreateNewWallet(from view: ControllerBackedProtocol?) { calls.append("create") }
    func showImportWallet(defaultSource: AccountImportSource, from view: ControllerBackedProtocol?) { calls.append("import") }
    func showBackupSelectWallet(from view: ControllerBackedProtocol?) { calls.append("backup") }
    func showGetPreinstalledWallet(from view: ControllerBackedProtocol?) { calls.append("preinstalled") }
    func presentAccountScore(address: String?, from view: ControllerBackedProtocol?) { calls.append("score"); scoreAddress = address }
    func presentStatus(with viewModel: ApplicationStatusAlertEvent, animated: Bool) { statusCount += 1 }
    func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool { errors.append(error); return true }
    func present(viewModel: SheetAlertPresentableViewModel, from view: ControllerBackedProtocol?) { sheets.append(viewModel) }
    func present(message: String?, title: String, closeAction: String?, from view: ControllerBackedProtocol?, actions: [SheetAlertPresentableAction]) {
        sheets.append(SheetAlertPresentableViewModel(title: title, message: message, actions: actions, closeAction: closeAction))
    }
}
