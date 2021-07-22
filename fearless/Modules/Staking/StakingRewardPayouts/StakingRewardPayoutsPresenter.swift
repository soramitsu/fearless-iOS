import Foundation
import IrohaCrypto
import SoraFoundation

final class StakingRewardPayoutsPresenter {
    weak var view: StakingRewardPayoutsViewProtocol?
    var wireframe: StakingRewardPayoutsWireframeProtocol!
    var interactor: StakingRewardPayoutsInteractorInputProtocol!

    private var payoutsInfo: PayoutsInfo?
    private var priceData: PriceData?
    private var eraCompletionTime: TimeInterval?
    private var timer: CountdownTimerProtocol?
    private let chain: Chain
    private let viewModelFactory: StakingPayoutViewModelFactoryProtocol

    init(chain: Chain, viewModelFactory: StakingPayoutViewModelFactoryProtocol) {
        self.chain = chain
        self.viewModelFactory = viewModelFactory
    }

    deinit {
        timer?.stop()
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
            eraCompletionTime: eraCompletionTime
        )
        let viewState = StakingRewardPayoutsViewState.payoutsList(viewModel)
        view?.reload(with: viewState)
    }

    private func startCountdownTimer(eraCompletionTime: TimeInterval) {
        timer = CountdownTimer(delegate: self)
        timer?.start(with: eraCompletionTime)
    }

    private func stopCountdownTimer() {
        timer?.stop()
        timer = nil
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
            chain: chain
        )
    }

    func handlePayoutAction() {
        guard let payouts = payoutsInfo?.payouts else { return }
        wireframe.showPayoutConfirmation(for: payouts, from: view)
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
            stopCountdownTimer()
            startCountdownTimer(eraCompletionTime: eraCountdown.eraCompletionTime)
        case .failure:
            eraCompletionTime = nil
        }
    }
}

extension StakingRewardPayoutsPresenter: CountdownTimerDelegate {
    func didStart(with remainedInterval: TimeInterval) {
        eraCompletionTime = remainedInterval
        updateView()
    }

    func didCountdown(remainedInterval: TimeInterval) {
        eraCompletionTime = remainedInterval
        updateView()
    }

    func didStop(with _: TimeInterval) {
        updateView()
    }
}
