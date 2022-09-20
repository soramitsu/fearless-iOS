import Foundation
import BigInt

final class StakingUnbondConfirmPresenter {
    weak var view: StakingUnbondConfirmViewProtocol?
    let wireframe: StakingUnbondConfirmWireframeProtocol
    let interactor: StakingUnbondConfirmInteractorInputProtocol

    let confirmViewModelFactory: StakingUnbondConfirmViewModelFactoryProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    let viewModelState: StakingUnbondConfirmViewModelState
    let chainAsset: ChainAsset
    let logger: LoggerProtocol?

    private var priceData: PriceData?

    init(
        interactor: StakingUnbondConfirmInteractorInputProtocol,
        wireframe: StakingUnbondConfirmWireframeProtocol,
        confirmViewModelFactory: StakingUnbondConfirmViewModelFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        viewModelState: StakingUnbondConfirmViewModelState,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        chainAsset: ChainAsset,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.confirmViewModelFactory = confirmViewModelFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.viewModelState = viewModelState
        self.dataValidatingFactory = dataValidatingFactory
        self.chainAsset = chainAsset
        self.logger = logger
    }
}

extension StakingUnbondConfirmPresenter: StakingUnbondConfirmPresenterProtocol {
    func didTapBackButton() {
        wireframe.dismiss(view: view)
    }

    func setup() {
        viewModelState.setStateListener(self)

        provideConfirmationViewModel()
        provideAssetViewModel()
        provideFeeViewModel()
        provideBondingDuration()

        interactor.setup()

        refreshFeeIfNeeded()
    }

    func confirm() {
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current
        DataValidationRunner(validators: viewModelState.validators(using: locale)).runValidation { [weak self] in
            guard let strongSelf = self else {
                return
            }

            strongSelf.view?.didStartLoading()

            strongSelf.interactor.submit(builderClosure: strongSelf.viewModelState.builderClosure)
        }
    }

    func selectAccount() {
        guard let view = view, let address = viewModelState.accountAddress else { return }

        let locale = view.localizationManager?.selectedLocale ?? Locale.current
        wireframe.presentAccountOptions(from: view, address: address, chain: chainAsset.chain, locale: locale)
    }
}

extension StakingUnbondConfirmPresenter: StakingUnbondConfirmInteractorOutputProtocol {
    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData

            provideAssetViewModel()
            provideFeeViewModel()
            provideConfirmationViewModel()
        case let .failure(error):
            logger?.error("Price data subscription error: \(error)")
        }
    }
}

extension StakingUnbondConfirmPresenter: StakingUnbondConfirmModelStateListener {
    func didReceiveError(error: Error) {
        logger?.error("StakingUnbondConfirmPresenter didReceiveError: \(error)")
    }

    func didSubmitUnbonding(result: Result<String, Error>) {
        view?.didStopLoading()

        guard let view = view else {
            return
        }

        switch result {
        case .success:
            wireframe.complete(from: view)
        case .failure:
            wireframe.presentExtrinsicFailed(from: view, locale: view.localizationManager?.selectedLocale)
        }
    }

    func provideFeeViewModel() {
        if let fee = viewModelState.fee {
            let feeViewModel = balanceViewModelFactory.balanceFromPrice(fee, priceData: priceData)
            view?.didReceiveFee(viewModel: feeViewModel)
        } else {
            view?.didReceiveFee(viewModel: nil)
        }
    }

    func provideBondingDuration() {
        guard let bondingDurationViewModel = confirmViewModelFactory
            .buildBondingDurationViewModel(viewModelState: viewModelState) else {
            return
        }

        view?.didReceiveBonding(duration: bondingDurationViewModel)
    }

    func provideAssetViewModel() {
        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            viewModelState.inputAmount,
            balance: viewModelState.bonded,
            priceData: priceData
        )

        view?.didReceiveAsset(viewModel: viewModel)
    }

    func provideConfirmationViewModel() {
        guard let viewModel = confirmViewModelFactory.buildViewModel(viewModelState: viewModelState) else {
            return
        }

        view?.didReceiveConfirmation(viewModel: viewModel)
    }

    func refreshFeeIfNeeded() {
        interactor.estimateFee(
            builderClosure: viewModelState.builderClosure,
            reuseIdentifier: viewModelState.reuseIdentifier
        )
    }
}
