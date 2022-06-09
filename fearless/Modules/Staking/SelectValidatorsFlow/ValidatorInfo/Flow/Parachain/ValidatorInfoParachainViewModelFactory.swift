import Foundation
import SoraFoundation
import FearlessUtils
import BigInt

final class ValidatorInfoParachainViewModelFactory {
    private let iconGenerator: IconGenerating
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let chainAsset: ChainAsset

    init(
        iconGenerator: IconGenerating,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        chainAsset: ChainAsset
    ) {
        self.iconGenerator = iconGenerator
        self.balanceViewModelFactory = balanceViewModelFactory
        self.chainAsset = chainAsset
    }

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

    private func createAccountViewModel(from collatorInfo: ParachainStakingCandidateInfo) -> AccountInfoViewModel {
        let identityName: String = collatorInfo.identity?.displayName ?? ""

        let icon = try? iconGenerator.generateFromAddress(collatorInfo.address)
            .imageWithFillColor(
                .white,
                size: UIConstants.normalAddressIconSize,
                contentScale: UIScreen.main.scale
            )

        return AccountInfoViewModel(
            title: "",
            address: collatorInfo.address,
            name: identityName,
            icon: icon
        )
    }

    private func createExposure(
        from collatorInfo: ParachainStakingCandidateInfo,
        priceData: PriceData?,
        locale: Locale
    ) -> ValidatorInfoViewModel.ParachainExposure {
        let formatter = NumberFormatter.quantity.localizableResource().value(for: locale)

        let delegationsCountString = collatorInfo.metadata?.delegationCount ?? ""

        let myNomination: ValidatorInfoViewModel.MyNomination?

        switch collatorInfo.metadata?.status {
        case let .active:
            myNomination = ValidatorInfoViewModel.MyNomination(isRewarded: true)
        case .idle, .leaving, .none:
            myNomination = nil
        }

        let totalStakeAmount = Decimal.fromSubstrateAmount(
            collatorInfo.metadata?.totalCounted ?? BigUInt.zero,
            precision: Int16(chainAsset.asset.precision)
        ) ?? Decimal.zero
        let totalStake = balanceViewModelFactory.balanceFromPrice(
            totalStakeAmount,
            priceData: priceData
        ).value(for: locale)

        // TODO: Stake return real value
        let estimatedRewardDecimal = Decimal.zero
        let estimatedReward = NumberFormatter.percentAPY.localizableResource()
            .value(for: locale).stringFromDecimal(estimatedRewardDecimal) ?? ""

        let minimumBond = Decimal.fromSubstrateAmount(collatorInfo.metadata?.lowestTopDelegationAmount ?? BigUInt.zero, precision: Int16(chainAsset.asset.precision)) ?? 0

        let selfBonded = Decimal.fromSubstrateAmount(collatorInfo.metadata?.bond ?? BigUInt.zero, precision: Int16(chainAsset.asset.precision)) ?? 0

        let effectiveAmountBonded = Decimal.fromSubstrateAmount(collatorInfo.metadata?.bond ?? BigUInt.zero, precision: Int16(chainAsset.asset.precision)) ?? 0

        let minimumBondString = balanceViewModelFactory.balanceFromPrice(
            minimumBond,
            priceData: priceData
        ).value(for: locale).amount

        let selfBondedString = balanceViewModelFactory.balanceFromPrice(
            selfBonded,
            priceData: priceData
        ).value(for: locale).amount

        let effectiveAmountBondedString = balanceViewModelFactory.balanceFromPrice(
            effectiveAmountBonded,
            priceData: priceData
        ).value(for: locale).amount

        // TODO: Oversubscribed real value
        return ValidatorInfoViewModel.ParachainExposure(
            delegations: delegationsCountString,
            totalStake: totalStake,
            estimatedReward: estimatedReward,
            minimumBond: minimumBondString,
            selfBonded: selfBondedString,
            effectiveAmountBonded: effectiveAmountBondedString
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

extension ValidatorInfoParachainViewModelFactory: ValidatorInfoViewModelFactoryProtocol {
    func buildViewModel(viewModelState: ValidatorInfoViewModelState, priceData: PriceData?, locale: Locale) -> ValidatorInfoViewModel? {
        guard let parachainViewModelState = viewModelState as? ValidatorInfoParachainViewModelState else {
            return nil
        }

        let accountViewModel = createAccountViewModel(from: parachainViewModelState.collatorInfo)

        let status: ValidatorInfoViewModel.StakingStatus

        if parachainViewModelState.collatorInfo.metadata != nil {
            let exposure = createExposure(from: parachainViewModelState.collatorInfo, priceData: priceData, locale: locale)
            status = .electedParachain(exposure: exposure)
        } else {
            status = .unelected
        }

        // TODO: Has slashes real value
        let staking = ValidatorInfoViewModel.Staking(
            status: status,
            slashed: false
        )

        let identityItems = parachainViewModelState.collatorInfo.identity.map { identity in
            createIdentityViewModel(from: identity, locale: locale)
        }

        return ValidatorInfoViewModel(
            account: accountViewModel,
            staking: staking,
            identity: identityItems
        )
    }

    func buildStakingAmountViewModels(viewModelState _: ValidatorInfoViewModelState, priceData _: PriceData?) -> [LocalizableResource<StakingAmountViewModel>]? {
        nil
    }
}
