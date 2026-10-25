import Foundation
import BigInt
import SSFModels

typealias SendModuleCreationResult = (view: SendViewInput, input: SendModuleInput)

protocol SendViewInput: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(assetBalanceViewModel: AssetBalanceViewModelProtocol?)
    func didReceive(amountInputViewModel: IAmountInputViewModel?)
    func didReceive(selectNetworkViewModel: SelectNetworkViewModel)
    func didReceive(feeViewModel: BalanceViewModelProtocol?)
    func didReceive(tipViewModel: TipViewModel?)
    func didReceive(scamInfo: ScamInfo?)
    func didStartFeeCalculation()
    func didStopFeeCalculation()
    func didStopTipCalculation()
    func didReceive(viewModel: RecipientViewModel)
    func didReceive(accountScoreViewModel: AccountScoreViewModel?)
    func didBlockUserInteractive(isUserInteractiveAmount: Bool)
    func setInputAccessoryView(visible: Bool)
    func setHistoryButton(isVisible: Bool)
    func switchEnableSendAllState(enabled: Bool)
    func switchEnableSendAllVisibility(isVisible: Bool)
}

protocol SendViewOutput: AnyObject {
    func didLoad(view: SendViewInput)
    func didTapBackButton()
    func didTapContinueButton()
    func didTapScanButton()
    func didTapHistoryButton()
    func didTapPasteButton()
    func didTapSelectAsset()
    func didTapSelectNetwork()
    func searchTextDidChanged(_ text: String)
    func selectAmountPercentage(_ percentage: Float, validate: Bool)
    func didEditAmount(_ newValue: Decimal) -> () -> Void
    func updateAmount(_ newValue: Decimal)
    func didSwitchSendAll(_ enabled: Bool)
}

protocol SendInteractorInput: AnyObject {
    var dependencyContainer: SendDepencyContainer { get }

    func setup(with output: SendInteractorOutput)
    func updateSubscriptions(for chainAsset: ChainAsset)
    func defineAvailableChains(
        for chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        completionBlock: @escaping ([ChainModel]?) -> Void
    )
    func estimateFee(for amount: BigUInt, tip: BigUInt?, for address: String?, chainAsset: ChainAsset)
    func validate(address: String?, for chain: ChainModel) -> AddressValidationResult
    func invalidateScamInfo()
    func fetchScamInfo(for address: String, chain: ChainModel)
    func getFeePaymentChainAsset(for chainAsset: ChainAsset?) -> ChainAsset?
    func getPossibleChains(for address: String) async -> [ChainModel]?
    func calculateEquilibriumBalance(chainAsset: ChainAsset, amount: Decimal)
    func didReceive(xorlessTransfer: XorlessTransfer)
    func convert(chainAsset: ChainAsset, toChainAsset: ChainAsset, amount: BigUInt) async throws -> SwapValues?
    func provideConstants(for chainAsset: ChainAsset)
}

protocol SendInteractorOutput: AnyObject {
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset)
    func didReceiveMinimumBalance(result: Result<BigUInt, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceiveTip(result: Result<BigUInt, Error>)
    func didReceive(scamInfo: ScamInfo?)
    func didReceive(possibleChains: [ChainModel]?)
    func didReceive(eqTotalBalance: Decimal)
    func didReceiveDependencies(for chainAsset: ChainAsset)
    func didReceiveDependenciesError(_ error: Error, for chainAsset: ChainAsset)
    func didReceiveAssetAccountInfo(assetAccountInfo: AssetAccountInfo?)
    func didReceiveAssetAccountInfoError(error: Error)
}

protocol SendRouterInput: SheetAlertPresentable,
    ErrorPresentable,
    BaseErrorPresentable,
    PresentDismissable,
    SendUnavailableReceivePresenting {
    func presentFormWarning(viewModel: SheetAlertPresentableViewModel, from view: ControllerBackedProtocol?)
    func presentConfirm(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        call: SendConfirmTransferCall,
        scamInfo: ScamInfo?,
        feeViewModel: BalanceViewModelProtocol?,
        selection: SelectedWalletAuthority.Lease?
    )
    func presentScan(
        from view: ControllerBackedProtocol?,
        moduleOutput: ScanQRModuleOutput
    )

    func presentHistory(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        moduleOutput: ContactsModuleOutput
    )

    func showSelectNetwork(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        selectedChainId: ChainModel.Id?,
        chainModels: [ChainModel]?,
        delegate: SelectNetworkDelegate?
    )

    func showSelectAsset(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        selectedAssetId: AssetModel.Id?,
        chainAssets: [ChainAsset]?,
        output: SelectAssetModuleOutput
    )
    func showManageAsset(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel
    )
}

protocol SendModuleInput: AnyObject {}

protocol SendModuleOutput: AnyObject {}

/// Exact registry identities only. A ticker or shared price never grants a network switch.
enum SendNetworkSelection {
    static func members(for current: ChainAsset, among candidates: [ChainAsset], catalog: CanonicalTokenGroupCatalog = .bundled) -> [ChainAsset] {
        guard let group = catalog.group(for: current) else {
            return candidates.filter { $0.assetKey == current.assetKey }
        }
        return catalog.members(of: group, among: candidates)
    }

    static func member(for current: ChainAsset, on chain: ChainModel, catalog: CanonicalTokenGroupCatalog = .bundled) -> ChainAsset? {
        let matches = members(for: current, among: chain.chainAssets, catalog: catalog)
        // Ambiguous registry input never silently chooses the first asset on a network.
        return matches.count == 1 ? matches.first : nil
    }
}

/// A new selection or quote invalidates all callbacks from the previous request.
final class SendRequestScope {
    private let lock = NSLock()
    private var identifier = UUID()

    @discardableResult
    func begin() -> UUID {
        lock.lock(); defer { lock.unlock() }
        identifier = UUID()
        return identifier
    }

    func snapshot() -> UUID {
        lock.lock(); defer { lock.unlock() }
        return identifier
    }

    func isCurrent(_ request: UUID) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return identifier == request
    }
}

final class SendScopedFeeListener: TransferFeeEstimationListener {
    private let scope: SendRequestScope
    private let request: UUID
    private let deliver: (Result<RuntimeDispatchInfo, Error>) -> Void

    init(scope: SendRequestScope, request: UUID, deliver: @escaping (Result<RuntimeDispatchInfo, Error>) -> Void) {
        self.scope = scope
        self.request = request
        self.deliver = deliver
    }

    func didReceiveFee(fee: BigUInt) { receive(.success(RuntimeDispatchInfo(feeValue: fee))) }
    func didReceiveFeeError(feeError: Error) { receive(.failure(feeError)) }

    private func receive(_ result: Result<RuntimeDispatchInfo, Error>) {
        DispatchQueue.main.async { [self] in
            guard scope.isCurrent(request) else { return }
            deliver(result)
        }
    }
}

/// A live balance belongs to the account and selection that subscribed to it.
final class SendScopedAccountInfoListener: AccountInfoSubscriptionAdapterHandler {
    private let wallet: MetaAccountModel
    private let scope: SendRequestScope
    private let request: UUID
    private let receive: (Result<AccountInfo?, Error>, ChainAsset) -> Void

    init(wallet: MetaAccountModel, scope: SendRequestScope, request: UUID, receive: @escaping (Result<AccountInfo?, Error>, ChainAsset) -> Void) {
        self.wallet = wallet
        self.scope = scope
        self.request = request
        self.receive = receive
    }

    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId: AccountId, chainAsset: ChainAsset) {
        guard wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId == accountId else { return }
        DispatchQueue.main.async { [self] in
            guard scope.isCurrent(request) else { return }
            receive(result, chainAsset)
        }
    }
}
