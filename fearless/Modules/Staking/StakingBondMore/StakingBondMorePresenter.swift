import SoraFoundation
import CommonWallet
import BigInt

final class StakingBondMorePresenter {
    let interactor: StakingBondMoreInteractorInputProtocol
    let wireframe: StakingBondMoreWireframeProtocol
    weak var view: StakingBondMoreViewProtocol?
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let viewModelFactory: StakingBondMoreViewModelFactoryProtocol?
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    let logger: LoggerProtocol?
    let viewModelState: StakingBondMoreViewModelState
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private var priceData: PriceData?
    private let networkFeeViewModelFactory: NetworkFeeViewModelFactoryProtocol

    init(
        interactor: StakingBondMoreInteractorInputProtocol,
        wireframe: StakingBondMoreWireframeProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        viewModelFactory: StakingBondMoreViewModelFactoryProtocol?,
        viewModelState: StakingBondMoreViewModelState,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        networkFeeViewModelFactory: NetworkFeeViewModelFactoryProtocol,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.balanceViewModelFactory = balanceViewModelFactory
        self.viewModelFactory = viewModelFactory
        self.viewModelState = viewModelState
        self.dataValidatingFactory = dataValidatingFactory
        self.networkFeeViewModelFactory = networkFeeViewModelFactory
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.logger = logger
    }

    private func estimateFee() {
        guard viewModelState.fee == nil else {
            return
        }

        interactor.estimateFee(
            reuseIdentifier: viewModelState.feeReuseIdentifier,
            builderClosure: viewModelState.builderClosure
        )
    }
}

extension StakingBondMorePresenter: StakingBondMorePresenterProtocol {
    func setup() {
        viewModelState.setStateListener(self)

        provideAmountInputViewModel()
        provideHintsViewModel()

        interactor.setup()

        estimateFee()
    }

    func handleContinueAction() {
        guard let flow = viewModelState.bondMoreConfirmationFlow else {
            return
        }

        let locale = view?.localizationManager?.selectedLocale ?? Locale.current
        DataValidationRunner(validators: viewModelState.validators(using: locale)).runValidation { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.wireframe.showConfirmation(
                from: strongSelf.view,
                flow: flow,
                chainAsset: strongSelf.chainAsset,
                wallet: strongSelf.wallet
            )
        }
    }

    func updateAmount(_ newValue: Decimal) {
        viewModelState.updateAmount(newValue)
    }

    func selectAmountPercentage(_ percentage: Float) {
        viewModelState.selectAmountPercentage(percentage)
    }
}

extension StakingBondMorePresenter: StakingBondMoreInteractorOutputProtocol {
    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData

            provideAsset()
            provideFee()
        case let .failure(error):
            logger?.error("Did receive price data error: \(error)")
        }
    }
}

extension StakingBondMorePresenter: StakingBondMoreModelStateListener {
    func didReceiveError(error: Error) {
        logger?.error("Did receive account info error: \(error)")
    }

    func feeParametersDidChanged(viewModelState: StakingBondMoreViewModelState) {
        interactor.estimateFee(
            reuseIdentifier: viewModelState.feeReuseIdentifier,
            builderClosure: viewModelState.builderClosure
        )
    }

    func provideAmountInputViewModel() {
        let viewModel = balanceViewModelFactory.createBalanceInputViewModel(viewModelState.amount)
        view?.didReceiveInput(viewModel: viewModel)
    }

    func provideFee() {
        if let fee = viewModelState.fee {
            let balanceViewModel = balanceViewModelFactory.balanceFromPrice(fee, priceData: priceData)
            let viewModel = networkFeeViewModelFactory.createViewModel(
                from: balanceViewModel
            )
            view?.didReceiveFee(viewModel: viewModel)
        } else {
            view?.didReceiveFee(viewModel: nil)
        }
    }

    func provideAsset() {
        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            viewModelState.amount,
            balance: viewModelState.balance,
            priceData: priceData
        )
        DispatchQueue.main.async {
            self.view?.didReceiveAsset(viewModel: viewModel)
        }
    }

    func didReceiveInsufficientlyFundsError() {
        if let view = view {
            wireframe.presentAmountTooHigh(
                from: view,
                locale: view.localizationManager?.selectedLocale
            )
        }
    }

    func provideAccountViewModel() {
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current

        if let viewModel = viewModelFactory?.buildAccountViewModel(viewModelState: viewModelState, locale: locale) {
            view?.didReceiveAccount(viewModel: viewModel)
        }
    }

    func provideCollatorViewModel() {
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current

        if let viewModel = viewModelFactory?.buildCollatorViewModel(
            viewModelState: viewModelState,
            locale: locale
        ) {
            view?.didReceiveCollator(viewModel: viewModel)
        }
    }

    func provideHintsViewModel() {
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current

        let viewModel = viewModelFactory?.buildHintViewModel(
            viewModelState: viewModelState,
            locale: locale
        )
        view?.didReceiveHints(viewModel: viewModel)
    }
}
