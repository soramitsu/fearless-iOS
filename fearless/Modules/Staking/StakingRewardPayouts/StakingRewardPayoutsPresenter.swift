import Foundation
import IrohaCrypto
import SoraFoundation
import SSFModels

final class StakingRewardPayoutsPresenter {
    weak var view: StakingRewardPayoutsViewProtocol?
    var wireframe: StakingRewardPayoutsWireframeProtocol!
    var interactor: StakingRewardPayoutsInteractorInputProtocol!

    private var payoutsInfo: PayoutsInfo?
    private var priceData: PriceData?
    private var eraCountdown: EraCountdown?
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let viewModelFactory: StakingPayoutViewModelFactoryProtocol

    init(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        viewModelFactory: StakingPayoutViewModelFactoryProtocol
    ) {
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.viewModelFactory = viewModelFactory
    }

    private func updateView() {
        guard let payoutsInfo = payoutsInfo else {
            return
        }

        guard !payoutsInfo.payouts.isEmpty else {
            view?.reload(with: .emptyList)
            return
        }

        let viewModel = viewModelFactory.createPayoutsViewModel(
            payoutsInfo: payoutsInfo,
            priceData: priceData,
            eraCountdown: eraCountdown,
            erasPerDay: chainAsset.chain.erasPerDay
        )
        let viewState = StakingRewardPayoutsViewState.payoutsList(viewModel)
        view?.reload(with: viewState)
    }
}

extension StakingRewardPayoutsPresenter: StakingRewardPayoutsPresenterProtocol {
    func setup() {
        view?.reload(with: .loading(true))
        interactor.setup()
    }

    func reload() {
        view?.reload(with: .loading(true))
        interactor.reload()
    }

    func handleSelectedHistory(at index: Int) {
        guard
            let payoutsInfo = payoutsInfo,
            index >= 0,
            index < payoutsInfo.payouts.count
        else {
            return
        }
        let payoutInfo = payoutsInfo.payouts[index]
        wireframe.showRewardDetails(
            from: view,
            payoutInfo: payoutInfo,
            activeEra: payoutsInfo.activeEra,
            historyDepth: payoutsInfo.historyDepth,
            chainAsset: chainAsset,
            wallet: wallet
        )
    }

    func handlePayoutAction() {
        guard let payouts = payoutsInfo?.payouts else { return }
        wireframe.showPayoutConfirmation(
            for: payouts,
            chainAsset: chainAsset,
            wallet: wallet,
            from: view
        )
    }

    func getTimeLeftString(
        at index: Int
    ) -> LocalizableResource<NSAttributedString>? {
        guard let payoutsInfo = payoutsInfo else {
            return nil
        }
        return viewModelFactory.timeLeftString(
            at: index,
            payoutsInfo: payoutsInfo,
            eraCountdown: eraCountdown,
            erasPerDay: chainAsset.chain.erasPerDay
        )
    }
}

extension StakingRewardPayoutsPresenter: StakingRewardPayoutsInteractorOutputProtocol {
    func didReceive(result: Result<PayoutsInfo, PayoutRewardsServiceError>) {
        view?.reload(with: .loading(false))

        switch result {
        case let .success(payoutsInfo):
            self.payoutsInfo = payoutsInfo
            updateView()
        case .failure:
            payoutsInfo = nil
            let errorDescription = LocalizableResource { locale in
                R.string.localizable.commonErrorNoDataRetrieved(preferredLanguages: locale.rLanguages)
            }
            view?.reload(with: .error(errorDescription))
        }
    }

    func didReceive(priceResult: Result<PriceData?, Error>) {
        switch priceResult {
        case let .success(priceData):
            self.priceData = priceData
            updateView()
        case .failure:
            priceData = nil
            updateView()
        }
    }

    func didReceive(eraCountdownResult: Result<EraCountdown, Error>) {
        switch eraCountdownResult {
        case let .success(eraCountdown):
            self.eraCountdown = eraCountdown
            updateView()
        case .failure:
            eraCountdown = nil
            updateView()
        }
    }
}
