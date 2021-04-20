import Foundation
import SoraFoundation
import IrohaCrypto

protocol StakingPayoutViewModelFactoryProtocol {
    func createPayoutsViewModel(
        payoutsInfo: PayoutsInfo,
        priceData: PriceData?
    ) -> LocalizableResource<StakingPayoutViewModel>
}

final class StakingPayoutViewModelFactory: StakingPayoutViewModelFactoryProtocol {
    private let addressFactory = SS58AddressFactory()
    private let chain: Chain
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private lazy var formatterFactory = AmountFormatterFactory()

    init(
        chain: Chain,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol
    ) {
        self.chain = chain
        self.balanceViewModelFactory = balanceViewModelFactory
    }

    func createPayoutsViewModel(
        payoutsInfo: PayoutsInfo,
        priceData: PriceData?
    ) -> LocalizableResource<StakingPayoutViewModel> {
        LocalizableResource<StakingPayoutViewModel> { _ in
            StakingPayoutViewModel(
                cellViewModels: self.createCellViewModels(for: payoutsInfo, priceData: priceData),
                bottomButtonTitle: self.defineBottomButtonTitle(for: payoutsInfo.payouts)
            )
        }
    }

    private func createCellViewModels(
        for payoutsInfo: PayoutsInfo,
        priceData: PriceData?
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
        // let locale = view?.localizationManager?.selectedLocale ?? Locale.current
        balanceViewModelFactory.amountFromValue(value).value(for: .current)
    }

    private func priceText(_ amount: Decimal, priceData: PriceData?) -> String {
        guard let priceData = priceData else {
            return "$0"
        }

        // let locale = view?.localizationManager?.selectedLocale ?? Locale.current
        let price = balanceViewModelFactory
            .priceFromAmount(amount, priceData: priceData).value(for: .current)
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
}
