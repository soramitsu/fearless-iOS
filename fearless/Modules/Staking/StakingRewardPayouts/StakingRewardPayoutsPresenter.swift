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
    private var payoutsInfo: PayoutsInfo?
    private var priceData: PriceData?

    init(
        chain: Chain,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol
    ) {
        self.chain = chain
        self.balanceViewModelFactory = balanceViewModelFactory
    }

    private func createCellViewModels(
        for payoutsInfo: PayoutsInfo
    ) -> [StakingRewardHistoryCellViewModel] {
        payoutsInfo.payouts.map { payout in
            let daysLeftText = daysLeftAttributedString(
                activeEra: payoutsInfo.activeEra,
                payoutEra: payout.era,
                historyDepth: payoutsInfo.historyDepth
            )

            return StakingRewardHistoryCellViewModel(
                addressOrName: self.addressTitle(payout),
                daysLeftText: daysLeftText,
                tokenAmountText: "+" + self.tokenAmountText(payout.reward),
                usdAmountText: priceText(payout.reward, priceData: priceData)
            )
        }
    }

    private func addressTitle(_ payout: PayoutInfo) -> String {
        if let displayName = payout.identity?.displayName {
            return displayName
        }

        if let address = try? addressFactory
            .addressFromAccountId(data: payout.validator, type: chain.addressType) {
            return address
        }

        return ""
    }

    private func tokenAmountText(_ value: Decimal) -> String {
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current
        return balanceViewModelFactory.amountFromValue(value).value(for: locale)
    }

    private func priceText(_ amount: Decimal, priceData: PriceData?) -> String {
        guard let priceData = priceData else {
            return "$0"
        }

        let locale = view?.localizationManager?.selectedLocale ?? Locale.current
        let price = balanceViewModelFactory
            .priceFromAmount(amount, priceData: priceData).value(for: locale)
        return price
    }

    private func daysLeftAttributedString(
        activeEra: EraIndex,
        payoutEra: EraIndex,
        historyDepth: UInt32
    ) -> NSAttributedString {
        let eraDistance = historyDepth - (activeEra - payoutEra)
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

    private func updateView() {
        guard let payoutsInfo = payoutsInfo else {
            return
        }

        guard !payoutsInfo.payouts.isEmpty else {
            view?.reload(with: .emptyList)
            return
        }

        let viewModel = StakingPayoutViewModel(
            cellViewModels: createCellViewModels(for: payoutsInfo),
            bottomButtonTitle: defineBottomButtonTitle(for: payoutsInfo.payouts)
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
        interactor.setup()
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
            chain: chain
        )
    }

    func handlePayoutAction() {
        wireframe.showPayoutConfirmation(from: view)
    }
}

extension StakingRewardPayoutsPresenter: StakingRewardPayoutsInteractorOutputProtocol {
    func didReceive(result: Result<PayoutsInfo, Error>) {
        view?.reload(with: .loading(false))

        switch result {
        case let .success(payoutsInfo):
            self.payoutsInfo = payoutsInfo
            updateView()
        case let .failure(error):
            payoutsInfo = nil
            view?.reload(with: .error(error))
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
}
