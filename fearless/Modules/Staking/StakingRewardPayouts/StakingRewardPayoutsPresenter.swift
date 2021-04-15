import Foundation
import IrohaCrypto
import SoraFoundation

final class StakingRewardPayoutsPresenter {
    weak var view: StakingRewardPayoutsViewProtocol?
    var wireframe: StakingRewardPayoutsWireframeProtocol!
    var interactor: StakingRewardPayoutsInteractorInputProtocol!

    private let addressFactory = SS58AddressFactory()
    private let chain: Chain
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private lazy var formatterFactory = AmountFormatterFactory()
    private var payoutItems: [PayoutInfo] = []

    init(
        chain: Chain,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol
    ) {
        self.chain = chain
        self.balanceViewModelFactory = balanceViewModelFactory
    }
}

extension StakingRewardPayoutsPresenter: StakingRewardPayoutsPresenterProtocol {
    func setup() {
        view?.hideEmptyView()
        view?.startLoading()
        interactor.setup()
    }

    func handleSelectedHistory(at index: Int) {
        guard index >= 0, index < payoutItems.count else {
            return
        }
        let payoutItem = payoutItems[index]
        wireframe.showRewardDetails(from: view, payoutItem: payoutItem, chain: chain)
    }

    func handlePayoutAction() {
        wireframe.showPayoutConfirmation(from: view)
    }

    private func createCellViewModels(
        for payoutsInfo: PayoutsInfo
    ) -> [StakingRewardHistoryCellViewModel] {
        payoutsInfo.payouts.map { payout in
            let daysLeftText = daysLeftAttributedString(
                activeEra: payoutsInfo.activeEra,
                payoutEra: payout.era,
                historyDepth: 84
            )
            return StakingRewardHistoryCellViewModel(
                addressOrName: addressTitle(payout.validator),
                daysLeftText: daysLeftText,
                tokenAmountText: tokenAmountText(payout.reward),
                usdAmountText: "$0"
            )
        }
    }

    private func addressTitle(_ accountId: Data) -> String {
        if let address = try? addressFactory.addressFromAccountId(data: accountId, type: chain.addressType) {
            return address
        }
        return ""
    }

    private func tokenAmountText(_ value: Decimal) -> String {
        "+" + balanceViewModelFactory.amountFromValue(value).value(for: .autoupdatingCurrent)
    }

    private func daysLeftAttributedString(
        activeEra: EraIndex,
        payoutEra: EraIndex,
        historyDepth: UInt32
    ) -> NSAttributedString {
        let eraDistance = (activeEra - payoutEra)
        let daysLeft = eraDistance / UInt32(chain.erasPerDay)
        let daysLeftText = daysLeft == 1 ? " day left" : " days left"

        let historyDepthDays = (historyDepth / 2) / UInt32(chain.erasPerDay)
        let textColor: UIColor = daysLeft < historyDepthDays ?
            R.color.colorRed()! : R.color.colorLightGray()!

        let attrubutedString = NSAttributedString(
            string: daysLeft.description + daysLeftText,
            attributes: [.foregroundColor: textColor]
        )
        return attrubutedString
    }

    private func defineBottomButtonTitle(
        for payouts: [PayoutInfo]
    ) -> String {
        let totalReward = payouts
            .reduce(into: Decimal(0)) { reward, payout in
                reward += payout.reward
            }
        let amountText = tokenAmountText(totalReward)
        return "Payout all (\(amountText))"
    }
}

extension StakingRewardPayoutsPresenter: StakingRewardPayoutsInteractorOutputProtocol {
    func didReceive(result: Result<PayoutsInfo, Error>) {
        view?.stopLoading()

        switch result {
        case let .success(payoutInfo):
            payoutItems = payoutInfo.payouts

            if payoutInfo.payouts.isEmpty {
                view?.showEmptyView()
            } else {
                let viewModel = StakingPayoutViewModel(
                    cellViewModels: createCellViewModels(for: payoutInfo),
                    bottomButtonTitle: defineBottomButtonTitle(for: payoutInfo.payouts)
                )
                view?.reload(with: viewModel)
            }
        case .failure:
            payoutItems = []
            let emptyViewModel = StakingPayoutViewModel(
                cellViewModels: [],
                bottomButtonTitle: ""
            )
            view?.reload(with: emptyViewModel)

            view?.showRetryState()
        }
    }
}
