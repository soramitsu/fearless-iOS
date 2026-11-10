import Foundation
import BigInt
import SSFModels

final class StakingRebondConfirmationPresenter {
    weak var view: StakingRebondConfirmationViewProtocol?
    let wireframe: StakingRebondConfirmationWireframeProtocol
    let interactor: StakingRebondConfirmationInteractorInputProtocol

    let confirmViewModelFactory: StakingRebondConfirmationViewModelFactoryProtocol
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    let viewModelState: StakingRebondConfirmationViewModelState
    let chainAsset: ChainAsset
    let logger: LoggerProtocol?
    private let wallet: MetaAccountModel
    private let submissionAuthorizer: SubmissionAuthorizing

    private var priceData: PriceData? {
        chainAsset.asset.getPrice(for: wallet.selectedCurrency)
    }

    init(
        interactor: StakingRebondConfirmationInteractorInputProtocol,
        wireframe: StakingRebondConfirmationWireframeProtocol,
        confirmViewModelFactory: StakingRebondConfirmationViewModelFactoryProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        chainAsset: ChainAsset,
        viewModelState: StakingRebondConfirmationViewModelState,
        wallet: MetaAccountModel,
        logger: LoggerProtocol? = nil,
        submissionAuthorizer: SubmissionAuthorizing = SubmissionAuthorizer()
    ) {
        self.submissionAuthorizer = submissionAuthorizer
        self.interactor = interactor
        self.wireframe = wireframe
        self.confirmViewModelFactory = confirmViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.chainAsset = chainAsset
        self.viewModelState = viewModelState
        self.wallet = wallet
        self.logger = logger
    }

    func refreshFeeIfNeeded() {
        interactor.estimateFee(
            builderClosure: viewModelState.builderClosure,
            reuseIdentifier: viewModelState.reuseIdentifier
        )
    }
}

extension StakingRebondConfirmationPresenter: StakingRebondConfirmationPresenterProtocol {
    func setup() {
        viewModelState.setStateListener(self)

        provideConfirmationViewModel()
        provideAssetViewModel()
        provideFeeViewModel()

        interactor.setup()

        refreshFeeIfNeeded()
    }

    func confirm() {
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current
        DataValidationRunner(validators: viewModelState.dataValidators(locale: locale)).runValidation { [weak self] in
            guard let self = self else { return }
            self.submissionAuthorizer.performAuthorized(from: self.view) { [weak self] in
                guard let strongSelf = self else {
                    return
                }

                strongSelf.view?.didStartLoading()

                strongSelf.interactor.submit(builderClosure: strongSelf.viewModelState.builderClosure)
            }
        }
    }

    func selectAccount() {
        guard let view = view, let address = viewModelState.selectableAccountAddress else { return }

        let locale = view.localizationManager?.selectedLocale ?? Locale.current
        wireframe.presentAccountOptions(from: view, address: address, chain: chainAsset.chain, locale: locale)
    }
}

extension StakingRebondConfirmationPresenter: StakingRebondConfirmationInteractorOutputProtocol {
    func didSubmitRebonding(result: Result<String, Error>) {
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
}

extension StakingRebondConfirmationPresenter: StakingRebondConfirmationModelStateListener {
    func provideFeeViewModel() {
        let viewModel = confirmViewModelFactory.createFeeViewModel(viewModelState: viewModelState, priceData: priceData)
        view?.didReceiveFee(viewModel: viewModel)
    }

    func provideAssetViewModel() {
        if let viewModel = confirmViewModelFactory.createAssetBalanceViewModel(
            viewModelState: viewModelState,
            priceData: priceData
        ) {
            view?.didReceiveAsset(viewModel: viewModel)
        }
    }

    func provideConfirmationViewModel() {
        if let viewModel = confirmViewModelFactory.createViewModel(viewModelState: viewModelState) {
            view?.didReceiveConfirmation(viewModel: viewModel)
        }
    }

    func feeParametersDidChanged() {
        interactor.estimateFee(
            builderClosure: viewModelState.builderClosure,
            reuseIdentifier: viewModelState.reuseIdentifier
        )
    }
}
