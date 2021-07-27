import Foundation
import SoraFoundation
import IrohaCrypto

final class StakingPayoutViewModelFactory: StakingPayoutViewModelFactoryProtocol {
    private let addressFactory = SS58AddressFactory()
    private let chain: Chain
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let timeFormatter: TimeFormatterProtocol
    private lazy var formatterFactory = AmountFormatterFactory()

    init(
        chain: Chain,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        timeFormatter: TimeFormatterProtocol
    ) {
        self.chain = chain
        self.balanceViewModelFactory = balanceViewModelFactory
        self.timeFormatter = timeFormatter
    }

    func createPayoutsViewModel(
        payoutsInfo: PayoutsInfo,
        priceData: PriceData?,
        eraCountdown: EraCountdown?
    ) -> LocalizableResource<StakingPayoutViewModel> {
        LocalizableResource<StakingPayoutViewModel> { locale in
            StakingPayoutViewModel(
                cellViewModels: self.createCellViewModels(
                    for: payoutsInfo,
                    priceData: priceData,
                    eraCountdown: eraCountdown,
                    locale: locale
                ),
                eraComletionTime: eraCountdown?.eraCompletionTime(),
                bottomButtonTitle: self.defineBottomButtonTitle(for: payoutsInfo.payouts, locale: locale)
            )
        }
    }

    func timeLeftString(
        at index: Int,
        payoutsInfo: PayoutsInfo,
        eraCountdown: EraCountdown?
    ) -> LocalizableResource<NSAttributedString> {
        LocalizableResource { locale in
            let payout = payoutsInfo.payouts[index]
            return self.timeLeftAttributedString(
                activeEra: payoutsInfo.activeEra,
                payoutEra: payout.era,
                historyDepth: payoutsInfo.historyDepth,
                eraCountdown: eraCountdown,
                locale: locale
            )
        }
    }

    private func createCellViewModels(
        for payoutsInfo: PayoutsInfo,
        priceData: PriceData?,
        eraCountdown: EraCountdown?,
        locale: Locale
    ) -> [StakingRewardHistoryCellViewModel] {
        payoutsInfo.payouts.map { payout in
            let daysLeftText = timeLeftAttributedString(
                activeEra: payoutsInfo.activeEra,
                payoutEra: payout.era,
                historyDepth: payoutsInfo.historyDepth,
                eraCountdown: eraCountdown,
                locale: locale
            )

            return StakingRewardHistoryCellViewModel(
                addressOrName: self.addressTitle(payout),
                daysLeftText: daysLeftText,
                tokenAmountText: "+" + self.tokenAmountText(payout.reward, locale: locale),
                usdAmountText: priceText(payout.reward, priceData: priceData, locale: locale)
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

    private func tokenAmountText(_ value: Decimal, locale: Locale) -> String {
        balanceViewModelFactory.amountFromValue(value).value(for: locale)
    }

    private func priceText(_ amount: Decimal, priceData: PriceData?, locale: Locale) -> String? {
        guard let priceData = priceData else {
            return nil
        }

        let price = balanceViewModelFactory
            .priceFromAmount(amount, priceData: priceData).value(for: locale)
        return price
    }

    private func timeLeftAttributedString(
        activeEra: EraIndex,
        payoutEra: EraIndex,
        historyDepth: UInt32,
        eraCountdown: EraCountdown?,
        locale: Locale
    ) -> NSAttributedString {
        let eraDistance = historyDepth - (activeEra - payoutEra)
        let daysLeft = Int(eraDistance) / chain.erasPerDay
        let timeLeftText: String = {
            if daysLeft == 0, let eraCountdown = eraCountdown {
                let eraCompletionTime = eraCountdown.eraCompletionTime(targetEra: activeEra + eraDistance)
                if eraCompletionTime <= .leastNormalMagnitude {
                    return R.string.localizable.stakingPayoutExpired(preferredLanguages: locale.rLanguages)
                }
                let formattedTime = (try? timeFormatter.string(from: eraCompletionTime)) ?? ""
                return R.string.localizable.commonTimeLeftFormat(formattedTime)
            }
            return R.string.localizable
                .stakingPayoutsDaysLeft(format: daysLeft, preferredLanguages: locale.rLanguages)
        }()

        let historyDepthDays = (historyDepth / 2) / UInt32(chain.erasPerDay)
        let textColor: UIColor = daysLeft < historyDepthDays ?
            R.color.colorRed()! : R.color.colorLightGray()!

        let attrubutedString = NSAttributedString(
            string: timeLeftText,
            attributes: [.foregroundColor: textColor]
        )
        return attrubutedString
    }

    private func defineBottomButtonTitle(
        for payouts: [PayoutInfo],
        locale: Locale
    ) -> String {
        let totalReward = payouts
            .reduce(into: Decimal(0)) { reward, payout in
                reward += payout.reward
            }
        let amountText = tokenAmountText(totalReward, locale: locale)
        return R.string.localizable.stakingRewardPayoutsPayoutAll(amountText, preferredLanguages: locale.rLanguages)
    }
}
