import Foundation
import FearlessUtils
import SoraFoundation
import CommonWallet

protocol ValidatorInfoViewModelFactoryProtocol {
    func createStakingAmountsViewModel(
        from validatorInfo: ValidatorInfoProtocol,
        priceData: PriceData?
    ) -> [LocalizableResource<StakingAmountViewModel>]

    func createViewModel(
        from validatorInfo: ValidatorInfoProtocol,
        priceData: PriceData?,
        locale: Locale
    ) -> ValidatorInfoViewModel
}

final class ValidatorInfoViewModelFactory {
    private let iconGenerator: IconGenerating
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    init(
        iconGenerator: IconGenerating,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol
    ) {
        self.iconGenerator = iconGenerator
        self.balanceViewModelFactory = balanceViewModelFactory
    }

    // MARK: - Private functions

    // MARK: Identity Rows

    private func createLegalRow(with legal: String, locale: Locale) -> ValidatorInfoViewModel.IdentityItem {
        let title = R.string.localizable.identityLegalNameTitle(preferredLanguages: locale.rLanguages)
        return .init(title: title, value: .text(legal))
    }

    private func createEmailRow(with email: String, locale: Locale) -> ValidatorInfoViewModel.IdentityItem {
        let title = R.string.localizable.identityEmailTitle(preferredLanguages: locale.rLanguages)
        return .init(title: title, value: .link(email, tag: .email))
    }

    private func createWebRow(with web: String, locale: Locale) -> ValidatorInfoViewModel.IdentityItem {
        let title = R.string.localizable.identityWebTitle(preferredLanguages: locale.rLanguages)
        return .init(title: title, value: .link(web, tag: .web))
    }

    private func createTwitterRow(with twitter: String) -> ValidatorInfoViewModel.IdentityItem {
        .init(title: "Twitter", value: .link(twitter, tag: .twitter))
    }

    private func createRiotRow(with riot: String, locale: Locale) -> ValidatorInfoViewModel.IdentityItem {
        let title = R.string.localizable.identityRiotNameTitle(preferredLanguages: locale.rLanguages)
        return .init(title: title, value: .link(riot, tag: .riot))
    }

    private func createAccountViewModel(from validatorInfo: ValidatorInfoProtocol) -> AccountInfoViewModel {
        let identityName: String = validatorInfo.identity?.displayName ?? ""

        let icon = try? iconGenerator.generateFromAddress(validatorInfo.address)
            .imageWithFillColor(
                .white,
                size: UIConstants.normalAddressIconSize,
                contentScale: UIScreen.main.scale
            )

        return AccountInfoViewModel(
            title: "",
            address: validatorInfo.address,
            name: identityName,
            icon: icon
        )
    }

    private func createExposure(
        from validatorInfo: ValidatorInfoProtocol,
        priceData: PriceData?,
        locale: Locale
    ) -> ValidatorInfoViewModel.Exposure {
        let formatter = NumberFormatter.quantity.localizableResource().value(for: locale)

        let nominatorsCount = validatorInfo.stakeInfo?.nominators.count ?? 0
        let maxNominatorsReward = validatorInfo.stakeInfo?.maxNominatorsRewarded ?? 0

        let nominators = R.string.localizable.stakingValidatorInfoNominators(
            formatter.string(from: NSNumber(value: nominatorsCount)) ?? "",
            formatter.string(from: NSNumber(value: maxNominatorsReward)) ?? ""
        )

        let myNomination: ValidatorInfoViewModel.MyNomination?

        switch validatorInfo.myNomination {
        case let .active(allocation):
            myNomination = ValidatorInfoViewModel.MyNomination(isRewarded: allocation.isRewarded)
        case .elected, .unelected, .none:
            myNomination = nil
        }

        let totalStake = balanceViewModelFactory.balanceFromPrice(
            validatorInfo.totalStake,
            priceData: priceData
        ).value(for: locale)

        let estimatedRewardDecimal = validatorInfo.stakeInfo?.stakeReturn ?? 0.0
        let estimatedReward = NumberFormatter.percentAPY.localizableResource()
            .value(for: locale).stringFromDecimal(estimatedRewardDecimal) ?? ""

        return ValidatorInfoViewModel.Exposure(
            nominators: nominators,
            myNomination: myNomination,
            totalStake: totalStake,
            estimatedReward: estimatedReward
        )
    }

    private func createIdentityViewModel(
        from identity: AccountIdentity,
        locale: Locale
    ) -> [ValidatorInfoViewModel.IdentityItem] {
        var identityItems: [ValidatorInfoViewModel.IdentityItem] = []

        if let legal = identity.legal {
            identityItems.append(createLegalRow(with: legal, locale: locale))
        }

        if let email = identity.email {
            identityItems.append(createEmailRow(with: email, locale: locale))
        }

        if let web = identity.web {
            identityItems.append(createWebRow(with: web, locale: locale))
        }

        if let twitter = identity.twitter {
            identityItems.append(createTwitterRow(with: twitter))
        }

        if let riot = identity.riot {
            identityItems.append(createRiotRow(with: riot, locale: locale))
        }

        return identityItems
    }

    private func createOwnStakeTitle() -> LocalizableResource<String> {
        LocalizableResource { locale in
            R.string.localizable.stakingValidatorOwnStake(preferredLanguages: locale.rLanguages)
        }
    }

    private func createNominatorsStakeTitle() -> LocalizableResource<String> {
        LocalizableResource { locale in
            R.string.localizable.stakingValidatorNominators(preferredLanguages: locale.rLanguages)
        }
    }

    private func createTotalTitle() -> LocalizableResource<String> {
        LocalizableResource { locale in
            R.string.localizable.walletTransferTotalTitle(preferredLanguages: locale.rLanguages)
        }
    }

    private func createStakingAmountRow(
        title: LocalizableResource<String>,
        amount: Decimal,
        priceData: PriceData?
    ) -> LocalizableResource<StakingAmountViewModel> {
        let balance = balanceViewModelFactory.balanceFromPrice(amount, priceData: priceData)

        return LocalizableResource { locale in

            let title = title.value(for: locale)

            return StakingAmountViewModel(
                title: title,
                balance: balance.value(for: locale)
            )
        }
    }
}

// MARK: - ValidatorInfoViewModelFactoryProtocol

extension ValidatorInfoViewModelFactory: ValidatorInfoViewModelFactoryProtocol {
    func createViewModel(
        from validatorInfo: ValidatorInfoProtocol,
        priceData: PriceData?,
        locale: Locale
    ) -> ValidatorInfoViewModel {
        let accountViewModel = createAccountViewModel(from: validatorInfo)

        let status: ValidatorInfoViewModel.StakingStatus

        switch validatorInfo.myNomination {
        case .active, .elected:
            let exposure = createExposure(from: validatorInfo, priceData: priceData, locale: locale)
            status = .elected(exposure: exposure)
        case .unelected, .none:
            status = .unelected
        }

        let staking = ValidatorInfoViewModel.Staking(
            status: status,
            slashed: validatorInfo.hasSlashes
        )

        let identityItems = validatorInfo.identity.map { identity in
            createIdentityViewModel(from: identity, locale: locale)
        }

        return ValidatorInfoViewModel(
            account: accountViewModel,
            staking: staking,
            identity: identityItems
        )
    }

    func createStakingAmountsViewModel(
        from validatorInfo: ValidatorInfoProtocol,
        priceData: PriceData?
    ) -> [LocalizableResource<StakingAmountViewModel>] {
        let nominatorsStake = validatorInfo.stakeInfo?.nominators
            .map(\.stake)
            .reduce(0, +) ?? 0.0

        return [
            createStakingAmountRow(
                title: createOwnStakeTitle(),
                amount: (validatorInfo.stakeInfo?.totalStake ?? 0.0) - nominatorsStake,
                priceData: priceData
            ),
            createStakingAmountRow(
                title: createNominatorsStakeTitle(),
                amount: nominatorsStake,
                priceData: priceData
            ),
            createStakingAmountRow(
                title: createTotalTitle(),
                amount: validatorInfo.stakeInfo?.totalStake ?? 0.0,
                priceData: priceData
            )
        ]
    }
}
