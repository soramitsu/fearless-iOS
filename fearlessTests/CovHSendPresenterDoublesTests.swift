import XCTest
import BigInt
import RobinHood
import SoraFoundation
import SSFModels
@testable import fearless

final class CovHSendPresenterHarness {
    let interactor = CovHSendPresenterInteractorStub()
    let router = CovHSendRouterSpy()
    let view = CovHSendViewSpy()
    let logger = CovHSendLogger()
    let wallet = AccountGenerator.generateMetaAccount()
    let presenter: SendPresenter

    init(initialData: SendFlowInitialData) {
        presenter = SendPresenter(
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared,
            viewModelFactory: CovHSendViewModelFactoryStub(),
            dataValidatingFactory: SendDataValidatingFactory(presentable: router),
            logger: logger,
            wallet: wallet,
            initialData: initialData,
            pasteboard: CovHSendPasteboard()
        )
    }

    func load() {
        presenter.didLoad(view: view)
    }

    static func accountInfo(_ amount: Decimal, precision: UInt16) -> AccountInfo? {
        guard let planks = amount.toSubstrateAmount(precision: Int16(precision)) else { return nil }
        return AccountInfo(nonce: 0, consumers: 0, providers: 1, data: AccountData(free: planks, reserved: .zero, frozen: .zero))
    }

    static func bokolo() -> (bokolo: ChainAsset, xor: ChainAsset) {
        let xor = AssetModel(id: "xor", name: "XOR", symbol: "XOR", precision: 18, currencyId: "0x0200000000", isUtility: true, isNative: true)
        let bokolo = AssetModel(
            id: "bokolo", name: "Bokolo", symbol: "XSTUSD", precision: 18,
            currencyId: BokoloConstants.bokoloCashAssetCurrencyId, isUtility: false, isNative: false
        )
        let chain = CovHSendFixtures.chain(name: "Covh Bokolo", assets: [xor, bokolo])
        return (ChainAsset(chain: chain, asset: bokolo), ChainAsset(chain: chain, asset: xor))
    }
}

final class CovHSendPresenterInteractorStub: SendInteractorInput {
    let dependencyContainer = SendDepencyContainer(wallet: AccountGenerator.generateMetaAccount(), operationManager: OperationManager())
    var updated: [ChainAsset] = []
    var estimates: [BigUInt] = []
    var scamRequests: [String] = []
    var xorless: [XorlessTransfer] = []
    var possibleChains: [ChainModel]?
    var convertResult: Result<SwapValues?, Error> = .success(nil)
    var feeAsset: ((ChainAsset?) -> ChainAsset?) = { chainAsset in
        guard let chainAsset else { return nil }
        return chainAsset.chain.utilityChainAssets().first ?? chainAsset
    }

    func setup(with _: SendInteractorOutput) {}
    func updateSubscriptions(for chainAsset: ChainAsset) { updated.append(chainAsset) }
    func defineAvailableChains(for _: ChainAsset, wallet _: MetaAccountModel, completionBlock: @escaping ([ChainModel]?) -> Void) {
        completionBlock(nil)
    }

    func estimateFee(for amount: BigUInt, tip _: BigUInt?, for _: String?, chainAsset _: ChainAsset) { estimates.append(amount) }
    func validate(address: String?, for _: ChainModel) -> AddressValidationResult {
        guard let address, !address.isEmpty else { return .invalid(address) }
        return .valid(address)
    }

    func invalidateScamInfo() {}
    func fetchScamInfo(for address: String, chain _: ChainModel) { scamRequests.append(address) }
    func getFeePaymentChainAsset(for chainAsset: ChainAsset?) -> ChainAsset? { feeAsset(chainAsset) }
    func getPossibleChains(for _: String) async -> [ChainModel]? { possibleChains }
    func calculateEquilibriumBalance(chainAsset _: ChainAsset, amount _: Decimal) {}
    func didReceive(xorlessTransfer: XorlessTransfer) { xorless.append(xorlessTransfer) }
    func convert(chainAsset _: ChainAsset, toChainAsset _: ChainAsset, amount _: BigUInt) async throws -> SwapValues? {
        try convertResult.get()
    }

    func provideConstants(for _: ChainAsset) {}
}

final class CovHSendRouterSpy: SendRouterInput {
    var calls: [String] = []
    var sheets: [SheetAlertPresentableViewModel] = []
    var errors: [Error] = []
    var confirmations: [SendConfirmTransferCall] = []
    var networkPickerChains: [[ChainModel]?] = []
    var assetPickerOffers: [[ChainAsset]?] = []
    var assetPickerSelections: [AssetModel.Id?] = []
    var historyAssets: [ChainAsset] = []

    func presentFormWarning(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) { sheets.append(viewModel) }
    func present(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) { sheets.append(viewModel) }
    func present(message: String?, title: String, closeAction: String?, from _: ControllerBackedProtocol?, actions: [SheetAlertPresentableAction]) {
        sheets.append(SheetAlertPresentableViewModel(title: title, message: message, actions: actions, isInfo: false, closeAction: closeAction))
    }

    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        errors.append(error)
        return true
    }

    func presentReceive(leavingSendFlowFrom _: ControllerBackedProtocol?, chainAsset _: ChainAsset, wallet _: MetaAccountModel) {
        calls.append("receive")
    }

    func dismiss(view _: ControllerBackedProtocol?) { calls.append("dismiss") }
    func presentConfirm(
        from _: ControllerBackedProtocol?, wallet _: MetaAccountModel, chainAsset _: ChainAsset, call: SendConfirmTransferCall,
        scamInfo _: ScamInfo?, feeViewModel _: BalanceViewModelProtocol?, selection _: SelectedWalletAuthority.Lease?
    ) {
        confirmations.append(call)
    }

    func presentScan(from _: ControllerBackedProtocol?, moduleOutput _: ScanQRModuleOutput) { calls.append("scan") }
    func presentHistory(from _: ControllerBackedProtocol?, wallet _: MetaAccountModel, chainAsset: ChainAsset, moduleOutput _: ContactsModuleOutput) {
        calls.append("history")
        historyAssets.append(chainAsset)
    }

    func showSelectNetwork(
        from _: ControllerBackedProtocol?, wallet _: MetaAccountModel, selectedChainId _: ChainModel.Id?, chainModels: [ChainModel]?,
        delegate _: SelectNetworkDelegate?
    ) {
        calls.append("network")
        networkPickerChains.append(chainModels)
    }

    func showSelectAsset(
        from _: ControllerBackedProtocol?, wallet _: MetaAccountModel, selectedAssetId: AssetModel.Id?, chainAssets: [ChainAsset]?,
        output _: SelectAssetModuleOutput
    ) {
        calls.append("asset")
        assetPickerSelections.append(selectedAssetId)
        assetPickerOffers.append(chainAssets)
    }

    func showManageAsset(from _: ControllerBackedProtocol?, wallet _: MetaAccountModel) { calls.append("manage") }
}

struct CovHSendViewModelFactoryStub: SendViewModelFactoryProtocol {
    func buildRecipientViewModel(address: String, isValid: Bool, canEditing: Bool) -> RecipientViewModel {
        RecipientViewModel(address: address, icon: nil, isValid: isValid, canEditing: canEditing)
    }

    func buildNetworkViewModel(chain: ChainModel, canEdit: Bool) -> SelectNetworkViewModel {
        SelectNetworkViewModel(chainName: chain.name, iconViewModel: nil, canEdit: canEdit)
    }

    func buildAccountScoreViewModel(address _: String?, chain _: ChainModel) -> AccountScoreViewModel? { nil }
}

final class CovHSendViewSpy: UIViewController, SendViewInput {
    var feeModels: [BalanceViewModelProtocol?] = []
    var recipients: [RecipientViewModel] = []
    var networks: [SelectNetworkViewModel] = []
    var assetBalances = 0
    var amountInputs = 0
    var blocked: [Bool] = []
    var feeStops = 0
    var tipStops = 0
    var presentedSheets: [SheetAlertPresentableViewModel] = []

    override func present(_ controller: UIViewController, animated _: Bool, completion _: (() -> Void)? = nil) {
        let viewModel = Mirror(reflecting: controller).children.first { $0.label == "viewModel" }?.value
        if let viewModel = viewModel as? SheetAlertPresentableViewModel {
            presentedSheets.append(viewModel)
        }
    }

    var loadableContentView: UIView { view }
    var shouldDisableInteractionWhenLoading: Bool { false }
    func didStartLoading() {}
    func didStopLoading() {}
    func didReceive(assetBalanceViewModel _: AssetBalanceViewModelProtocol?) { assetBalances += 1 }
    func didReceive(amountInputViewModel _: IAmountInputViewModel?) { amountInputs += 1 }
    func didReceive(selectNetworkViewModel: SelectNetworkViewModel) { networks.append(selectNetworkViewModel) }
    func didReceive(feeViewModel: BalanceViewModelProtocol?) { feeModels.append(feeViewModel) }
    func didReceive(tipViewModel _: TipViewModel?) {}
    func didReceive(scamInfo _: ScamInfo?) {}
    func didStartFeeCalculation() {}
    func didStopFeeCalculation() { feeStops += 1 }
    func didStopTipCalculation() { tipStops += 1 }
    func didReceive(viewModel: RecipientViewModel) { recipients.append(viewModel) }
    func didReceive(accountScoreViewModel _: AccountScoreViewModel?) {}
    func didBlockUserInteractive(isUserInteractiveAmount: Bool) { blocked.append(isUserInteractiveAmount) }
    func setInputAccessoryView(visible _: Bool) {}
    func setHistoryButton(isVisible _: Bool) {}
    func switchEnableSendAllState(enabled _: Bool) {}
    func switchEnableSendAllVisibility(isVisible _: Bool) {}
}
