import Foundation
import SoraFoundation
import BigInt

final class StakingUnbondSetupPresenter {
    weak var view: StakingUnbondSetupViewProtocol?
    let wireframe: StakingUnbondSetupWireframeProtocol
    let interactor: StakingUnbondSetupInteractorInputProtocol

    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    let viewModelFactory: StakingUnbondSetupViewModelFactoryProtocol
    let viewModelState: StakingUnbondSetupViewModelState
    let logger: LoggerProtocol?
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel

    private var priceData: PriceData?

    init(
        interactor: StakingUnbondSetupInteractorInputProtocol,
        wireframe: StakingUnbondSetupWireframeProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        viewModelFactory: StakingUnbondSetupViewModelFactoryProtocol,
        viewModelState: StakingUnbondSetupViewModelState,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.balanceViewModelFactory = balanceViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.viewModelFactory = viewModelFactory
        self.viewModelState = viewModelState
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.logger = logger
    }
}

extension StakingUnbondSetupPresenter: StakingUnbondSetupPresenterProtocol {
    func didTapBackButton() {
        wireframe.dismiss(view: view)
    }

    func setup() {
        viewModelState.setStateListener(self)

        provideInputViewModel()
        provideFeeViewModel()
        provideBondingDuration()
        provideAssetViewModel()
        provideTitle()
        provideAccountViewModel()
        provideCollatorViewModel()
        provideHintsViewModel()

        interactor.setup()

        interactor.estimateFee(builderClosure: viewModelState.builderClosure)
    }

    func selectAmountPercentage(_ percentage: Float) {
        viewModelState.selectAmountPercentage(percentage)
    }

    func updateAmount(_ amount: Decimal) {
        viewModelState.updateAmount(amount)
    }

    func proceed() {
        guard let flow = viewModelState.confirmationFlow else {
            return
        }

        let locale = view?.localizationManager?.selectedLocale ?? Locale.current
        DataValidationRunner(validators: viewModelState.validators(using: locale)).runValidation { [weak self] in
            guard let strongSelf = self else {
                return
            }

            strongSelf.wireframe.proceed(
                view: strongSelf.view,
                flow: flow,
                chainAsset: strongSelf.chainAsset,
                wallet: strongSelf.wallet
            )
        }
    }

    func close() {
        wireframe.close(view: view)
    }
}

extension StakingUnbondSetupPresenter: StakingUnbondSetupInteractorOutputProtocol {
    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData
            provideAssetViewModel()
            provideFeeViewModel()
        case let .failure(error):
            logger?.error("Price data subscription error: \(error)")
        }
    }
}

extension StakingUnbondSetupPresenter: StakingUnbondSetupModelStateListener {
    func provideInputViewModel() {
        let inputView = balanceViewModelFactory.createBalanceInputViewModel(viewModelState.inputAmount)
        view?.didReceiveInput(viewModel: inputView)
    }

    func provideFeeViewModel() {
        if let fee = viewModelState.fee {
            let balanceViewModel = balanceViewModelFactory.balanceFromPrice(fee, priceData: priceData)
            let locale = view?.localizationManager?.selectedLocale ?? Locale.current
            let feeViewModel = viewModelFactory.buildNetworkFeeViewModel(from: balanceViewModel)
            view?.didReceiveFee(viewModel: feeViewModel)
        } else {
            view?.didReceiveFee(viewModel: nil)
        }
    }

    func provideAssetViewModel() {
        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            viewModelState.amount ?? 0,
            balance: viewModelState.bonded,
            priceData: priceData
        )

        view?.didReceiveAsset(viewModel: viewModel)
    }

    func provideBondingDuration() {
        guard let bondingDurationViewModel = viewModelFactory.buildBondingDurationViewModel(viewModelState: viewModelState) else {
            return
        }

        view?.didReceiveBonding(duration: bondingDurationViewModel)
    }

    func provideTitle() {
        view?.didReceiveTitle(viewModel: viewModelFactory.buildTitleViewModel())
    }

    func updateFeeIfNeeded() {
        interactor.estimateFee(builderClosure: viewModelState.builderClosure)
    }

    func didReceiveError(error: Error) {
        logger?.error("StakingUnbondSetupPresenter didReceiveError: \(error)")
    }

    func provideAccountViewModel() {
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current

        if let viewModel = viewModelFactory.buildAccountViewModel(viewModelState: viewModelState, locale: locale) {
            view?.didReceiveAccount(viewModel: viewModel)
        }
    }

    func provideCollatorViewModel() {
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current

        if let viewModel = viewModelFactory.buildCollatorViewModel(viewModelState: viewModelState, locale: locale) {
            view?.didReceiveCollator(viewModel: viewModel)
        }
    }

    func provideHintsViewModel() {
        let viewModel = viewModelFactory.buildHints()
        view?.didReceiveHints(viewModel: viewModel)
    }
}
