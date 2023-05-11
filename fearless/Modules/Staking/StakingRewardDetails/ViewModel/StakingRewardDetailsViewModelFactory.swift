import Foundation
import IrohaCrypto
import SoraFoundation
import SSFUtils

protocol StakingRewardDetailsViewModelFactoryProtocol {
    func createViewModel(
        input: StakingRewardDetailsInput,
        priceData: PriceData?
    ) -> LocalizableResource<StakingRewardDetailsViewModel>
    func validatorAddress(
        from data: Data,
        addressType: SNAddressType
    ) -> AccountAddress?
    func validatorAddress(
        from data: Data,
        addressPrefix: UInt16
    ) -> AccountAddress?
}

final class StakingRewardDetailsViewModelFactory: StakingRewardDetailsViewModelFactoryProtocol {
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private lazy var addressFactory = SS58AddressFactory()
    private let iconGenerator: IconGenerating

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        iconGenerator: IconGenerating
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.iconGenerator = iconGenerator
    }

    func createViewModel(
        input: StakingRewardDetailsInput,
        priceData: PriceData?
    ) -> LocalizableResource<StakingRewardDetailsViewModel> {
        LocalizableResource { locale in
            let rows: [RewardDetailsRow] = [
                .validatorInfo(.init(
                    title: R.string.localizable.stakingRewardDetailsValidator(preferredLanguages: locale.rLanguages),
                    address: self.validatorAddress(
                        from: input.payoutInfo.validator,
                        addressPrefix: input.chain.addressPrefix
                    ) ?? "",
                    name: self.displayName(
                        payoutInfo: input.payoutInfo,
                        chain: input.chain
                    ),
                    icon: self.getValidatorIcon(validatorAccount: input.payoutInfo.validator, chain: input.chain)
                )),
                .date(.init(
                    titleText: R.string.localizable.stakingRewardDetailsDate(preferredLanguages: locale.rLanguages),
                    valueText: self.formattedDateText(
                        activeEra: input.activeEra,
                        payoutEra: input.payoutInfo.era,
                        chain: input.chain
                    )
                )),
                .era(.init(
                    titleText: R.string.localizable.stakingRewardDetailsEra(preferredLanguages: locale.rLanguages),
                    valueText: "#\(input.payoutInfo.era.description)"
                )),
                .reward(.init(
                    title: R.string.localizable
                        .stakingRewardDetailsReward(preferredLanguages: locale.rLanguages),
                    tokenAmountText: self.tokenAmountText(payoutInfo: input.payoutInfo, locale: locale),
                    usdAmountText: self.priceText(payoutInfo: input.payoutInfo, priceData: priceData, locale: locale)
                ))
            ]
            return StakingRewardDetailsViewModel(rows: rows)
        }
    }

    func validatorAddress(from data: Data, addressType: SNAddressType) -> AccountAddress? {
        try? addressFactory
            .addressFromAccountId(data: data, type: addressType)
    }

    func validatorAddress(from data: Data, addressPrefix: UInt16) -> AccountAddress? {
        try? addressFactory
            .addressFromAccountId(data: data, addressPrefix: addressPrefix)
    }

    private func displayName(payoutInfo: PayoutInfo, chain: ChainModel) -> String {
        if let displayName = payoutInfo.identity?.displayName {
            return displayName
        }

        if let address = validatorAddress(from: payoutInfo.validator, addressPrefix: chain.addressPrefix) {
            return address
        }
        return ""
    }

    private func tokenAmountText(payoutInfo: PayoutInfo, locale: Locale) -> String {
        balanceViewModelFactory.amountFromValue(payoutInfo.reward, usageCase: .detailsCrypto).value(for: locale)
    }

    private func priceText(payoutInfo: PayoutInfo, priceData: PriceData?, locale: Locale) -> String {
        guard let priceData = priceData else {
            return ""
        }

        let price = balanceViewModelFactory
            .priceFromAmount(payoutInfo.reward, priceData: priceData).value(for: locale)
        return price
    }

    private func formattedDateText(
        activeEra: EraIndex,
        payoutEra: EraIndex,
        chain: ChainModel
    ) -> String {
        let pastDays = (activeEra - payoutEra) / UInt32(chain.erasPerDay)
        guard let daysAgo = Calendar.current
            .date(byAdding: .day, value: -Int(pastDays), to: Date())
        else { return "" }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"

        return dateFormatter.string(from: daysAgo)
    }

    private func getValidatorIcon(validatorAccount: Data, chain: ChainModel) -> UIImage? {
        guard let address = validatorAddress(from: validatorAccount, addressPrefix: chain.addressPrefix)
        else { return nil }
        return try? iconGenerator.generateFromAddress(address)
            .imageWithFillColor(
                R.color.colorWhite()!,
                size: UIConstants.smallAddressIconSize,
                contentScale: UIScreen.main.scale
            )
    }
}
