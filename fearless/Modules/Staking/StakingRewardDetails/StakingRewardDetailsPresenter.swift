import Foundation
import IrohaCrypto
import FearlessUtils

final class StakingRewardDetailsPresenter {
    weak var view: StakingRewardDetailsViewProtocol?
    var wireframe: StakingRewardDetailsWireframeProtocol!
    var interactor: StakingRewardDetailsInteractorInputProtocol!

    private let payoutInfo: PayoutInfo
    private let chain: Chain
    private let viewModelFactory: StakingRewardDetailsViewModelFactoryProtocol
    private var priceData: PriceData?

    init(
        payoutInfo: PayoutInfo,
        chain: Chain,
        viewModelFactory: StakingRewardDetailsViewModelFactoryProtocol
    ) {
        self.payoutInfo = payoutInfo
        self.chain = chain
        self.viewModelFactory = viewModelFactory
    }

    private func updateView() {
        let viewModel = viewModelFactory.createViewModel(priceData: priceData)
        view?.reload(with: viewModel)
    }
}

extension StakingRewardDetailsPresenter: StakingRewardDetailsPresenterProtocol {
    func setup() {
        updateView()
        interactor.setup()
    }

    func handlePayoutAction() {
        wireframe.showPayoutConfirmation(from: view, payoutInfo: payoutInfo)
    }

    func handleValidatorAccountAction(locale: Locale) {
        guard
            let view = view,
            let address = viewModelFactory.validatorAddress
        else { return }
        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chain,
            locale: locale
        )
    }
}

extension StakingRewardDetailsPresenter: StakingRewardDetailsInteractorOutputProtocol {
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
}
