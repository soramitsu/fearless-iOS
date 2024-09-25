import Foundation
import SoraFoundation
import SSFModels
import BigInt

protocol CrossChainSwapConfirmViewInput: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(swapAmountInfoViewModel: SwapAmountInfoViewModel)
    func didReceive(viewModel: CrossChainSwapViewModel)
    func didReceive(doubleImageViewModel: PolkaswapDoubleSymbolViewModel)
    func didReceive(feeViewModel: BalanceViewModelProtocol?)
}

protocol CrossChainSwapConfirmInteractorInput: AnyObject {
    func setup(with output: CrossChainSwapConfirmInteractorOutput)
    func confirmSwap() async throws
    func subscribeOnBalance(for chainAssets: [ChainAsset])
    func estimateFee() async throws -> BigUInt
}

final class CrossChainSwapConfirmPresenter {
    // MARK: Private properties

    private weak var view: CrossChainSwapConfirmViewInput?
    private let router: CrossChainSwapConfirmRouterInput
    private let interactor: CrossChainSwapConfirmInteractorInput
    private let viewModelFactory: CrossChainSwapConfirmViewModelFactory
    private let dataValidatingFactory: SendDataValidatingFactory

    private let swapFromChainAsset: ChainAsset
    private let swapToChainAsset: ChainAsset
    private let swap: CrossChainSwap
    private let wallet: MetaAccountModel

    private var swapFromBalance: Decimal?
    private var swapToBalance: Decimal?
    private var utilityBalance: Decimal?

    // MARK: - Constructors

    init(
        interactor: CrossChainSwapConfirmInteractorInput,
        router: CrossChainSwapConfirmRouterInput,
        localizationManager: LocalizationManagerProtocol,
        swapFromChainAsset: ChainAsset,
        swapToChainAsset: ChainAsset,
        swap: CrossChainSwap,
        viewModelFactory: CrossChainSwapConfirmViewModelFactory,
        wallet: MetaAccountModel,
        dataValidatingFactory: SendDataValidatingFactory
    ) {
        self.interactor = interactor
        self.router = router
        self.swapFromChainAsset = swapFromChainAsset
        self.swapToChainAsset = swapToChainAsset
        self.swap = swap
        self.viewModelFactory = viewModelFactory
        self.wallet = wallet
        self.dataValidatingFactory = dataValidatingFactory

        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func subscribeOnBalance() {
        let chainAssets: [ChainAsset] = [swapFromChainAsset, swapToChainAsset, swapFromChainAsset.chain.utilityChainAssets().first].compactMap { $0 }
        interactor.subscribeOnBalance(for: chainAssets)
    }

    private func provideViewModel() {
        let viewModel = viewModelFactory.buildSwapViewModel(
            swap: swap,
            sourceChainAsset: swapFromChainAsset,
            targetChainAsset: swapToChainAsset,
            wallet: wallet,
            locale: selectedLocale
        )

        view?.didReceive(viewModel: viewModel)
    }

    private func provideAmountInfoViewModel() {
        let viewModel = viewModelFactory.buildSwapAmountInfoViewModel(
            swapFromChainAsset: swapFromChainAsset,
            swapToChainAsset: swapToChainAsset,
            swap: swap,
            locale: selectedLocale
        )

        view?.didReceive(swapAmountInfoViewModel: viewModel)
    }

    private func provideImageViewModel() {
        let viewModel = viewModelFactory.buildDoubleImageViewModel(
            swapFromChainAsset: swapFromChainAsset,
            swapToChainAsset: swapToChainAsset
        )

        view?.didReceive(doubleImageViewModel: viewModel)
    }

    private func refreshFee() {
        guard let utilityChainAsset = swapFromChainAsset.chain.utilityChainAssets().first else {
            return
        }

        Task {
            let fee = try await interactor.estimateFee()
            let feeViewModel = viewModelFactory.buildFeeViewModel(utilityChainAsset: utilityChainAsset, fee: fee, locale: selectedLocale)

            guard let feeViewModel else {
                return
            }

            await MainActor.run {
                view?.didReceive(feeViewModel: feeViewModel)
            }
        }
    }
}

// MARK: - CrossChainSwapConfirmViewOutput

extension CrossChainSwapConfirmPresenter: CrossChainSwapConfirmViewOutput {
    func didLoad(view: CrossChainSwapConfirmViewInput) {
        self.view = view
        interactor.setup(with: self)

        provideViewModel()
        provideAmountInfoViewModel()
        provideImageViewModel()
        subscribeOnBalance()
        refreshFee()
    }

    func didTapConfirmButton() {
        let sendAmount = swap.fromAmount.flatMap { BigUInt(string: $0) }
        let sendAmountDecimal = sendAmount.flatMap { Decimal.fromSubstrateAmount($0, precision: Int16(swapToChainAsset.asset.precision)) }

        view?.didStartLoading()

        let precision = Int16(swapFromChainAsset.chain.utilityChainAssets().first?.asset.precision ?? swapFromChainAsset.asset.precision)
        let networkFee = swap.totalFees.flatMap { Decimal.fromSubstrateAmount($0, precision: precision) }
        let nativeFee = swapFromChainAsset.asset.isUtility ? networkFee : .zero

        DataValidationRunner(validators: [
            dataValidatingFactory.has(fee: networkFee, locale: selectedLocale, onError: {}),
            dataValidatingFactory.canPayFeeAndAmount(
                balanceType: .utility(balance: utilityBalance),
                feeAndTip: networkFee,
                sendAmount: .zero,
                locale: selectedLocale
            ),
            dataValidatingFactory.canPayFeeAndAmount(
                balanceType: .utility(balance: swapFromBalance),
                feeAndTip: nativeFee,
                sendAmount: sendAmountDecimal,
                locale: selectedLocale
            )
        ]).runValidation { [weak self] in
            guard let self else {
                return
            }

            Task {
                do {
                    try await self.interactor.confirmSwap()
                    print("Swap success")
                } catch {
                    self.router.present(error: error, from: self.view, locale: self.selectedLocale)
                }
            }
        }
    }
}

// MARK: - CrossChainSwapConfirmInteractorOutput

extension CrossChainSwapConfirmPresenter: CrossChainSwapConfirmInteractorOutput {
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset) {
        switch result {
        case let .success(accountInfo):
            if chainAsset == swapFromChainAsset.chain.utilityChainAssets().first {
                utilityBalance = accountInfo.map {
                    Decimal.fromSubstrateAmount(
                        $0.data.sendAvailable,
                        precision: Int16(chainAsset.asset.precision)
                    )
                } ?? .zero
            }
            if swapFromChainAsset == chainAsset {
                swapFromBalance = accountInfo.map {
                    Decimal.fromSubstrateAmount(
                        $0.data.sendAvailable,
                        precision: Int16(chainAsset.asset.precision)
                    )
                } ?? .zero
            }
            if swapToChainAsset == chainAsset {
                swapToBalance = accountInfo.map {
                    Decimal.fromSubstrateAmount(
                        $0.data.sendAvailable,
                        precision: Int16(chainAsset.asset.precision)
                    )
                } ?? .zero
            }
        case let .failure(error):
            router.present(error: error, from: view, locale: selectedLocale)
        }
    }
}

// MARK: - Localizable

extension CrossChainSwapConfirmPresenter: Localizable {
    func applyLocalization() {}
}

extension CrossChainSwapConfirmPresenter: CrossChainSwapConfirmModuleInput {}
