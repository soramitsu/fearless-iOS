import Foundation
import SoraFoundation
import IrohaCrypto

final class StakingPayoutViewModelFactory: StakingPayoutViewModelFactoryProtocol {
    private let addressFactory = SS58AddressFactory()
    private let chain: ChainModel
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let timeFormatter: TimeFormatterProtocol

    init(
        chain: ChainModel,
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
        eraCountdown: EraCountdown?,
        erasPerDay: UInt32
    ) -> LocalizableResource<StakingPayoutViewModel> {
        let timerCompletion: TimeInterval?

        if let eraCountdown = eraCountdown,
           let maxPayout = payoutsInfo.payouts.max(by: { $0.era < $1.era }) {
            timerCompletion = eraCountdown.timeIntervalTillSet(
                targetEra: maxPayout.era + payoutsInfo.historyDepth + 1
            )
        } else {
            timerCompletion = nil
        }

        return LocalizableResource<StakingPayoutViewModel> { locale in
            StakingPayoutViewModel(
                cellViewModels: self.createCellViewModels(
                    for: payoutsInfo,
                    priceData: priceData,
                    eraCountdown: eraCountdown,
                    locale: locale,
                    erasPerDay: erasPerDay
                ),
                eraComletionTime: timerCompletion,
                bottomButtonTitle: self.defineBottomButtonTitle(for: payoutsInfo.payouts, locale: locale)
            )
        }
    }

    func timeLeftString(
        at index: Int,
        payoutsInfo: PayoutsInfo,
        eraCountdown: EraCountdown?,
        erasPerDay: UInt32
    ) -> LocalizableResource<NSAttributedString> {
        LocalizableResource { locale in
            let payout = payoutsInfo.payouts[index]
            return self.timeLeftAttributedString(
                payoutEra: payout.era,
                historyDepth: payoutsInfo.historyDepth,
                eraCountdown: eraCountdown,
                locale: locale, erasPerDay: erasPerDay
            )
        }
    }

    private func createCellViewModels(
        for payoutsInfo: PayoutsInfo,
        priceData: PriceData?,
        eraCountdown: EraCountdown?,
        locale: Locale,
        erasPerDay: UInt32
    ) -> [StakingRewardHistoryCellViewModel] {
        payoutsInfo.payouts.map { payout in
            let daysLeftText = timeLeftAttributedString(
                payoutEra: payout.era,
                historyDepth: payoutsInfo.historyDepth,
                eraCountdown: eraCountdown,
                locale: locale,
                erasPerDay: erasPerDay
            )

            return StakingRewardHistoryCellViewModel(
                addressOrName: self.addressTitle(payout),
                daysLeftText: daysLeftText,
                tokenAmountText: "+" + self.tokenAmountText(payout.reward, locale: locale),
                usdAmountText: priceText(payout.reward, priceData: priceData, locale: locale),
                timeInterval: nil,
                locale: locale
            )
        }
    }

    private func addressTitle(_ payout: PayoutInfo) -> String {
        if let displayName = payout.identity?.displayName {
            return displayName
        }

        if let address = try? addressFactory
            .addressFromAccountId(data: payout.validator, addressPrefix: chain.addressPrefix) {
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
        payoutEra: EraIndex,
        historyDepth: UInt32,
        eraCountdown: EraCountdown?,
        locale: Locale,
        erasPerDay: UInt32
    ) -> NSAttributedString {
        guard let eraCountdown = eraCountdown else { return .init(string: "") }

        let eraCompletionTime = eraCountdown.timeIntervalTillSet(targetEra: payoutEra + historyDepth + 1)
        let daysLeft = eraCompletionTime.daysFromSeconds

        let timeLeftText: String = {
            if eraCompletionTime <= .leastNormalMagnitude {
                return R.string.localizable.stakingPayoutExpired(preferredLanguages: locale.rLanguages)
            }
            if daysLeft == 0 {
                let formattedTime = (try? timeFormatter.string(from: eraCompletionTime)) ?? ""
                return R.string.localizable.commonTimeLeftFormat(
                    formattedTime,
                    preferredLanguages: locale.rLanguages
                )
            } else {
                return R.string.localizable
                    .commonDaysLeftFormat(format: daysLeft, preferredLanguages: locale.rLanguages)
            }
        }()

        let historyDepthDays = (historyDepth / 2) / erasPerDay
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
