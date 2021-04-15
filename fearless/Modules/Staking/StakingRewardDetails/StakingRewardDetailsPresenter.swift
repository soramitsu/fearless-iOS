import Foundation
import IrohaCrypto

final class StakingRewardDetailsPresenter {
    weak var view: StakingRewardDetailsViewProtocol?
    var wireframe: StakingRewardDetailsWireframeProtocol!
    var interactor: StakingRewardDetailsInteractorInputProtocol!

    private let chain: Chain
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let addressFactory = SS58AddressFactory()
    private let payoutInfo: PayoutInfo
    private let activeEra: EraIndex

    init(
        payoutInfo: PayoutInfo,
        activeEra: EraIndex,
        chain: Chain,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol
    ) {
        self.payoutInfo = payoutInfo
        self.activeEra = activeEra
        self.chain = chain
        self.balanceViewModelFactory = balanceViewModelFactory
    }

    private func createViewModel(payoutItem: PayoutInfo) -> StakingRewardDetailsViewModel {
        let rows: [RewardDetailsRow] = [
            .validatorInfo(.init(
                name: "Validator",
                address: addressTitle(payoutItem.validator),
                icon: R.image.iconAccount()
            )),
            .date(.init(
                titleText: R.string.localizable.stakingRewardDetailsDate(),
                valueText: "Feb 2, 2021"
            )),
            .era(.init(
                titleText: R.string.localizable.stakingRewardDetailsEra(),
                valueText: "#\(payoutItem.era.description)"
            )),
            .reward(.init(ksmAmountText: tokenAmountText(payoutItem.reward), usdAmountText: "$0"))
        ]
        return .init(rows: rows)
    }

    private func addressTitle(_ accountId: Data) -> String {
        if let address = try? addressFactory.addressFromAccountId(data: accountId, type: chain.addressType) {
            return address
        }
        return ""
    }

    private func tokenAmountText(_ value: Decimal) -> String {
        balanceViewModelFactory.amountFromValue(value).value(for: .autoupdatingCurrent)
    }
}

extension StakingRewardDetailsPresenter: StakingRewardDetailsPresenterProtocol {
    func setup() {
        let viewModel = createViewModel(payoutItem: payoutInfo)
        view?.reload(with: viewModel)
    }

    func handlePayoutAction() {
        wireframe.showPayoutConfirmation(from: view)
    }

    func handleValidatorAccountAction() {
        guard
            let view = view,
            let address = try? addressFactory.addressFromAccountId(
                data: payoutInfo.validator, type: chain.addressType
            )
        else { return }
        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chain,
            locale: .autoupdatingCurrent
        )
    }
}

extension StakingRewardDetailsPresenter: StakingRewardDetailsInteractorOutputProtocol {}
