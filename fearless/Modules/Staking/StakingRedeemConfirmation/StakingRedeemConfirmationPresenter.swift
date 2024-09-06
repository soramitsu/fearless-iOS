import Foundation
import BigInt
import SSFModels

final class StakingRedeemConfirmationPresenter {
    weak var view: StakingRedeemConfirmationViewProtocol?
    let wireframe: StakingRedeemConfirmationWireframeProtocol
    let interactor: StakingRedeemConfirmationInteractorInputProtocol

    let confirmViewModelFactory: StakingRedeemConfirmationViewModelFactoryProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let viewModelState: StakingRedeemConfirmationViewModelState
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
    let logger: LoggerProtocol?

    var priceData: PriceData? {
        chainAsset.asset.getPrice(for: wallet.selectedCurrency)
    }

    init(
        interactor: StakingRedeemConfirmationInteractorInputProtocol,
        wireframe: StakingRedeemConfirmationWireframeProtocol,
        confirmViewModelFactory: StakingRedeemConfirmationViewModelFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        viewModelState: StakingRedeemConfirmationViewModelState,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.confirmViewModelFactory = confirmViewModelFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.viewModelState = viewModelState
        self.dataValidatingFactory = dataValidatingFactory
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.logger = logger
    }
}

extension StakingRedeemConfirmationPresenter: StakingRedeemConfirmationPresenterProtocol {
    func setup() {
        viewModelState.setStateListener(self)

        provideConfirmationViewModel()
        provideAssetViewModel()
        provideFeeViewModel()
        provideHintsViewModel()

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
        guard let view = view, let address = viewModelState.address else { return }

        let locale = view.localizationManager?.selectedLocale ?? Locale.current
        wireframe.presentAccountOptions(from: view, address: address, chain: chainAsset.chain, locale: locale)
    }

    func didTapBackButton() {
        wireframe.dismiss(view: view)
    }
}

extension StakingRedeemConfirmationPresenter: StakingRedeemConfirmationInteractorOutputProtocol {
    func didSubmitRedeeming(result: Result<String, Error>) {
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

extension StakingRedeemConfirmationPresenter: StakingRedeemConfirmationModelStateListener {
    func didReceiveError(error: Error) {
        logger?.error("StakingRedeemConfirmationPresenter didReceiveError: \(error)")
    }

    func provideFeeViewModel() {
        if let fee = viewModelState.fee {
            let feeViewModel = balanceViewModelFactory.balanceFromPrice(fee, priceData: priceData, usageCase: .detailsCrypto)
            view?.didReceiveFee(viewModel: feeViewModel)
        } else {
            view?.didReceiveFee(viewModel: nil)
        }
    }

    func provideAssetViewModel() {
        guard let viewModel = confirmViewModelFactory.buildAssetViewModel(
            viewModelState: viewModelState,
            priceData: priceData
        ) else {
            return
        }

        view?.didReceiveAsset(viewModel: viewModel)
    }

    func provideConfirmationViewModel() {
        guard let viewModel = confirmViewModelFactory.buildViewModel(viewModelState: viewModelState) else {
            return
        }

        view?.didReceiveConfirmation(viewModel: viewModel)
    }

    func provideHintsViewModel() {
        let viewModel = confirmViewModelFactory.buildHints()
        view?.didReceiveHints(viewModel: viewModel)
    }

    func refreshFeeIfNeeded() {
        interactor.estimateFee(
            builderClosure: viewModelState.builderClosure,
            reuseIdentifier: viewModelState.reuseIdentifier
        )
    }
}
