import Foundation
import Web3
import SSFModels

final class StakingBondMoreConfirmationPresenter {
    weak var view: StakingBondMoreConfirmationViewProtocol?
    let wireframe: StakingBondMoreConfirmationWireframeProtocol
    let interactor: StakingBondMoreConfirmationInteractorInputProtocol

    let confirmViewModelFactory: StakingBondMoreConfirmViewModelFactoryProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let viewModelState: StakingBondMoreConfirmationViewModelState
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    let chainAsset: ChainAsset
    let logger: LoggerProtocol?
    let wallet: MetaAccountModel

    private var priceData: PriceData?

    init(
        interactor: StakingBondMoreConfirmationInteractorInputProtocol,
        wireframe: StakingBondMoreConfirmationWireframeProtocol,
        confirmViewModelFactory: StakingBondMoreConfirmViewModelFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        viewModelState: StakingBondMoreConfirmationViewModelState,
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

extension StakingBondMoreConfirmationPresenter: StakingBondMoreConfirmationPresenterProtocol {
    func didTapBackButton() {
        wireframe.dismiss(view: view)
    }

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
        DataValidationRunner(validators: viewModelState.validators(using: locale)).runValidation { [weak self] in
            guard let strongSelf = self, let builderClosure = strongSelf.viewModelState.builderClosure else {
                return
            }

            strongSelf.view?.didStartLoading()

            strongSelf.interactor.submit(builderClosure: builderClosure)
        }
    }

    func selectAccount() {
        guard let view = view, let address = viewModelState.accountAddress else { return }

        let locale = view.localizationManager?.selectedLocale ?? Locale.current
        wireframe.presentAccountOptions(from: view, address: address, chain: chainAsset.chain, locale: locale)
    }
}

extension StakingBondMoreConfirmationPresenter: StakingBondMoreConfirmationOutputProtocol {
    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData

            provideAssetViewModel()
            provideFeeViewModel()
            provideConfirmationViewModel()
        case let .failure(error):
            logger?.error("Did receive price data error: \(error)")
        }
    }

    func didSubmitBonding(result: Result<String, Error>) {
        view?.didStopLoading()

        guard let view = view else {
            return
        }

        switch result {
        case let .success(hash):
            wireframe.complete(from: view, chainAsset: chainAsset, extrinsicHash: hash)
        case .failure:
            wireframe.presentExtrinsicFailed(from: view, locale: view.localizationManager?.selectedLocale)
        }
    }
}

extension StakingBondMoreConfirmationPresenter: StakingBondMoreConfirmationModelStateListener {
    func didReceiveError(error: Error) {
        logger?.error("StakingBondMoreConfirmationPresenter didReceiveError: \(error)")
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
        let assetViewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            viewModelState.amount,
            balance: viewModelState.balance,
            priceData: priceData
        )

        view?.didReceiveAsset(viewModel: assetViewModel)
    }

    func provideConfirmationViewModel() {
        let locale = view?.selectedLocale ?? Locale.current

        do {
            guard let viewModel = try confirmViewModelFactory.createViewModel(
                account: wallet,
                amount: viewModelState.amount,
                state: viewModelState,
                locale: locale,
                priceData: priceData
            ) else {
                return
            }

            DispatchQueue.main.async {
                self.view?.didReceiveConfirmation(viewModel: viewModel)
            }
        } catch {
            logger?.error("Did receive view model factory error: \(error)")
        }
    }

    func refreshFeeIfNeeded() {
        guard viewModelState.fee == nil else {
            return
        }

        interactor.estimateFee(
            builderClosure: viewModelState.builderClosure,
            reuseIdentifier: viewModelState.feeReuseIdentifier
        )
    }
}
