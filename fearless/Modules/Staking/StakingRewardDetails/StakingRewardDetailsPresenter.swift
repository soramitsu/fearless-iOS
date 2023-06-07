import Foundation
import IrohaCrypto
import SSFUtils
import SSFModels

final class StakingRewardDetailsPresenter {
    weak var view: StakingRewardDetailsViewProtocol?
    var wireframe: StakingRewardDetailsWireframeProtocol!
    var interactor: StakingRewardDetailsInteractorInputProtocol!

    private let input: StakingRewardDetailsInput
    private let viewModelFactory: StakingRewardDetailsViewModelFactoryProtocol
    private var priceData: PriceData?
    private var chain: ChainModel
    private let asset: AssetModel
    private let selectedAccount: MetaAccountModel

    init(
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        chain: ChainModel,
        input: StakingRewardDetailsInput,
        viewModelFactory: StakingRewardDetailsViewModelFactoryProtocol
    ) {
        self.asset = asset
        self.selectedAccount = selectedAccount
        self.chain = chain
        self.input = input
        self.viewModelFactory = viewModelFactory
    }

    private func updateView() {
        let viewModel = viewModelFactory.createViewModel(input: input, priceData: priceData)
        view?.reload(with: viewModel)
    }
}

extension StakingRewardDetailsPresenter: StakingRewardDetailsPresenterProtocol {
    func setup() {
        updateView()
        interactor.setup()
    }

    func handlePayoutAction() {
        wireframe.showPayoutConfirmation(
            from: view,
            payoutInfo: input.payoutInfo,
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount
        )
    }

    func handleValidatorAccountAction(locale: Locale) {
        guard
            let view = view,
            let address = viewModelFactory.validatorAddress(
                from: input.payoutInfo.validator,
                addressPrefix: input.chain.addressPrefix
            )
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
