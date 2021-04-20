import Foundation
import IrohaCrypto
import SoraFoundation
import FearlessUtils

protocol StakingRewardDetailsViewModelFactoryProtocol {
    func createViewModel() -> LocalizableResource<StakingRewardDetailsViewModel>
    var validatorAddress: AccountAddress? { get }
}

final class StakingRewardDetailsViewModelFactory: StakingRewardDetailsViewModelFactoryProtocol {
    let payoutInfo: PayoutInfo
    let chain: Chain
    let activeEra: EraIndex
    let historyDepth: UInt32

    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let addressFactory = SS58AddressFactory()
    private let iconGenerator: IconGenerating

    var validatorAddress: AccountAddress? {
        try? addressFactory.addressFromAccountId(
            data: payoutInfo.validator,
            type: chain.addressType
        )
    }

    init(
        input: StakingRewardDetailsInput,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        iconGenerator: IconGenerating
    ) {
        payoutInfo = input.payoutInfo
        chain = input.chain
        activeEra = input.activeEra
        historyDepth = input.historyDepth
        self.balanceViewModelFactory = balanceViewModelFactory
        self.iconGenerator = iconGenerator
    }

    func createViewModel() -> LocalizableResource<StakingRewardDetailsViewModel> {
        LocalizableResource { locale in
            let rows: [RewardDetailsRow] = [
                .validatorInfo(.init(
                    name: R.string.localizable.stakingRewardDetailsValidator(preferredLanguages: locale.rLanguages),
                    address: self.addressTitle(),
                    icon: self.getValidatorIcon()
                )),
                .date(.init(
                    titleText: R.string.localizable.stakingRewardDetailsDate(preferredLanguages: locale.rLanguages),
                    valueText: self.formattedDateText()
                )),
                .era(.init(
                    titleText: R.string.localizable.stakingRewardDetailsEra(preferredLanguages: locale.rLanguages),
                    valueText: "#\(self.payoutInfo.era.description)"
                )),
                .reward(.init(
                    ksmAmountText: self.tokenAmountText(locale: locale),
                    usdAmountText: "$0"
                ))
            ]
            return StakingRewardDetailsViewModel(rows: rows)
        }
    }

    private func addressTitle() -> String {
        if let displayName = payoutInfo.identity?.displayName {
            return displayName
        }

        if let address = try? addressFactory
            .addressFromAccountId(data: payoutInfo.validator, type: chain.addressType) {
            return address
        }
        return ""
    }

    private func tokenAmountText(locale: Locale) -> String {
        balanceViewModelFactory.amountFromValue(payoutInfo.reward).value(for: locale)
    }

    private func priceText(_ amount: Decimal, priceData: PriceData?, locale: Locale) -> String {
        guard let priceData = priceData else {
            return ""
        }

        let price = balanceViewModelFactory
            .priceFromAmount(amount, priceData: priceData).value(for: locale)
        return price
    }

    private func formattedDateText() -> String {
        let pastDays = (activeEra - payoutInfo.era) / UInt32(chain.erasPerDay)
        guard let daysAgo = Calendar.current
            .date(byAdding: .day, value: -Int(pastDays), to: Date())
        else { return "" }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"

        return dateFormatter.string(from: daysAgo)
    }

    private func getValidatorIcon() -> UIImage? {
        guard let address = validatorAddress else { return nil }
        return try? iconGenerator.generateFromAddress(address)
            .imageWithFillColor(
                .white,
                size: UIConstants.smallAddressIconSize,
                contentScale: UIScreen.main.scale
            )
    }
}
