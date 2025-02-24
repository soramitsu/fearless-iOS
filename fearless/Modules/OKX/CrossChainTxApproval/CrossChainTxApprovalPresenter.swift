import Foundation
import Web3
import SoraFoundation
import BigInt
import SSFModels

protocol CrossChainFundsPermissionViewInput: ControllerBackedProtocol {
    @MainActor
    func bind(viewModel: CrossChainFundsPermissionViewModel)
    func bind(feeViewModel: BalanceViewModelProtocol?)
    func setButtonLoadingState(isLoading: Bool)
    func didReceiveError(viewModel: ErrorViewModel?)
}

protocol CrossChainFundsPermissionInteractorInput: AnyObject {
    func setup(with output: CrossChainFundsPermissionInteractorOutput)
    func submit(mode: CrossChainFundsPermissionMode) async throws -> String
    func fetchBalance(for chainAssets: [ChainAsset]) async throws -> [ChainAssetKey: AccountInfo?]
    func estimateFee(mode: CrossChainFundsPermissionMode) async throws -> BigUInt
    func checkTransactionSucceed(txHash: String) async throws -> Bool
}

final class CrossChainFundsPermissionPresenter {
    // MARK: Private properties
    private weak var view: CrossChainFundsPermissionViewInput?
    private let router: CrossChainFundsPermissionRouterInput
    private let interactor: CrossChainFundsPermissionInteractorInput
    private let viewModelFactory: CrossChainFundsPermissionViewModelFactory
    private let mode: CrossChainFundsPermissionMode
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let swap: CrossChainSwap
    private let feeBalanceViewModelFactory: BalanceViewModelFactoryProtocol?
    private let crossChainSwapParameters: CrossChainSwapParameters
    private let dataValidatingFactory: SendDataValidatingFactory
    private let logger: LoggerProtocol?
    private var swapFromBalance: Decimal?
    private var utilityBalance: Decimal?
    private var fee: Decimal?
    private var revokeTxHash: String?
    
    // MARK: - Constructors
    init(
        interactor: CrossChainFundsPermissionInteractorInput,
        router: CrossChainFundsPermissionRouterInput,
        localizationManager: LocalizationManagerProtocol,
        viewModelFactory: CrossChainFundsPermissionViewModelFactory,
        mode: CrossChainFundsPermissionMode,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        swap: CrossChainSwap,
        feeBalanceViewModelFactory: BalanceViewModelFactoryProtocol?,
        crossChainSwapParameters: CrossChainSwapParameters,
        dataValidatingFactory: SendDataValidatingFactory,
        logger: LoggerProtocol?,
        revokeTxHash: String?
    ) {
        self.interactor = interactor
        self.router = router
        self.viewModelFactory = viewModelFactory
        self.mode = mode
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.swap = swap
        self.feeBalanceViewModelFactory = feeBalanceViewModelFactory
        self.crossChainSwapParameters = crossChainSwapParameters
        self.dataValidatingFactory = dataValidatingFactory
        self.logger = logger
        self.revokeTxHash = revokeTxHash
        
        self.localizationManager = localizationManager
    }
    
    // MARK: - Private methods
    
    private func checkRevokeTransactionSucceed(revokeTxHash: String) {
        Task {
            do {
                let isSucceed = try await interactor.checkTransactionSucceed(txHash: revokeTxHash)
                if isSucceed {
                    self.revokeTxHash = nil
                    
                    try await Task.sleep(nanoseconds: 1000000000)
                    try await refreshFee()
                }
            } catch {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    self?.checkRevokeTransactionSucceed(revokeTxHash: revokeTxHash)
                }
            }
        }
    }
    
    @MainActor private func provideViewModel() {
        let viewModel = viewModelFactory.buildViewModel(
            mode: mode,
            chainAsset: chainAsset,
            wallet: wallet,
            swap: swap,
            locale: selectedLocale
        )
        
        view?.bind(viewModel: viewModel)
    }
    
    private func refreshFee() async throws {
        await MainActor.run {
            view?.bind(feeViewModel: nil)
            view?.setButtonLoadingState(isLoading: true)
        }
        
        if let revokeTxHash {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.checkRevokeTransactionSucceed(revokeTxHash: revokeTxHash)
            }
            return
        }
        
        guard let utilityChainAsset = chainAsset.chain.utilityChainAssets().first else {
            return
        }
        
        do {
            let fee = try await interactor.estimateFee(mode: mode)
            let feeDecimal = Decimal.fromSubstrateAmount(fee, precision: Int16(utilityChainAsset.asset.precision))
            let feeViewModel = feeDecimal.flatMap { feeBalanceViewModelFactory?.balanceFromPrice($0, priceData: utilityChainAsset.asset.getPrice(for: wallet.selectedCurrency), usageCase: .detailsCrypto) }
            
            self.fee = Decimal.fromSubstrateAmount(fee, precision: Int16(utilityChainAsset.asset.precision))
            
            await MainActor.run {
                view?.bind(feeViewModel: feeViewModel?.value(for: selectedLocale))
                view?.setButtonLoadingState(isLoading: false)

            }
        } catch {
            logger?.customError(error)
            
            if let rpcError = error as? RPCResponse<EthereumQuantity>.Error {
                await MainActor.run {
                    self.showDefaultError(
                        title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: self.selectedLocale.rLanguages),
                        message: rpcError.message
                    )
                }
            }
        }
    }
    
    private func subscribeOnBalance() {
        let chainAssets = [chainAsset, chainAsset.chain.utilityChainAssets().first].compactMap { $0 }

        Task {
            do {
                let accountInfos = try await interactor.fetchBalance(for: chainAssets)
                accountInfos.forEach {
                    handle(accountInfo: $0.value, for: $0.key)
                }
            } catch {
                logger?.customError(error)
            }
        }
    }
    
    private func handle(accountInfo: AccountInfo?, for chainAssetKey: ChainAssetKey) {
        if let utilityChainAsset = chainAsset.chain.utilityChainAssets().first, chainAssetKey == utilityChainAsset.uniqueKey(for: wallet) {
            utilityBalance = accountInfo.map {
                Decimal.fromSubstrateAmount(
                    $0.data.sendAvailable,
                    precision: Int16(utilityChainAsset.asset.precision)
                )
            } ?? .zero
        }

        if chainAsset.uniqueKey(for: wallet) == chainAssetKey {
            swapFromBalance = accountInfo.map {
                Decimal.fromSubstrateAmount(
                    $0.data.sendAvailable,
                    precision: Int16(chainAsset.asset.precision)
                )
            } ?? .zero
        }
    }
    
    private func sendRequest() async throws {
        await MainActor.run {
            view?.setButtonLoadingState(isLoading: true)
        }

        do {
            let hash = try await interactor.submit(mode: mode)
            await proceed(txHash: hash)
        } catch {
            await MainActor.run {
                view?.setButtonLoadingState(isLoading: false)
                router.present(error: error, from: view, locale: selectedLocale)
            }
        }
    }
    
    @MainActor private func proceed(txHash: String) {
        view?.setButtonLoadingState(isLoading: false)
        
        switch mode {
        case .approve:
            router.presentConfirm(
                crossChainSwapParameters: crossChainSwapParameters,
                approveTxHash: txHash,
                from: view
            )
        case let .revoke(dexTokenApproveAddress):
            router.presentFundsPermission(
                mode: .approve(dexTokenApproveAddress: dexTokenApproveAddress),
                crossChainSwapParameters: crossChainSwapParameters,
                revokeTxHash: txHash,
                from: view
            )
        case .none:
            break
        }
        
    }
    
    private func showDefaultError(title: String, message: String) {
        let errorViewModel = ErrorViewModel(
            title: title,
            message: message,
            actionTitle: nil,
            actionHandler: nil
        )
        view?.didReceiveError(viewModel: errorViewModel)
    }
}

// MARK: - CrossChainFundsPermissionViewOutput
extension CrossChainFundsPermissionPresenter: CrossChainFundsPermissionViewOutput {
    func didLoad(view: CrossChainFundsPermissionViewInput) {
        self.view = view
        interactor.setup(with: self)
        subscribeOnBalance()
        
        Task {
            await provideViewModel()
            try await refreshFee()
        }
    }
    
    func didTapConfirmButton() {
        let balance: BalanceType = chainAsset.asset.isUtility ? .utility(balance: swapFromBalance) : .orml(balance: swapFromBalance, utilityBalance: utilityBalance)
        let amount = BigUInt(string: crossChainSwapParameters.amount)
        let amountDecimal = amount.flatMap { Decimal.fromSubstrateAmount($0, precision: Int16(chainAsset.asset.precision)) }
        DataValidationRunner(validators: [
            dataValidatingFactory.has(fee: fee, locale: selectedLocale, onError: {}),
            dataValidatingFactory.canPayFeeAndAmount(
                balanceType: balance,
                feeAndTip: fee,
                sendAmount: amountDecimal,
                locale: selectedLocale
            )
        ]).runValidation { [weak self] in
            guard let self else {
                return
            }
            
            Task {
                try await self.sendRequest()
            }
        }
    }
    
    func didTapBackButton() {
        router.dismiss(view: view)
    }
}

// MARK: - CrossChainFundsPermissionInteractorOutput
extension CrossChainFundsPermissionPresenter: CrossChainFundsPermissionInteractorOutput {}

// MARK: - Localizable
extension CrossChainFundsPermissionPresenter: Localizable {
    func applyLocalization() {}
}

extension CrossChainFundsPermissionPresenter: CrossChainFundsPermissionModuleInput {}
