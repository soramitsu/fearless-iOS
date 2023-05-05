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
                R.color.colorWhite()!,
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
        let delegationsCountString = "\(collatorInfo.metadata?.delegationCount ?? 0)"

        let totalStakeDecimal = Decimal.fromSubstrateAmount(
            collatorInfo.metadata?.totalCounted ?? BigUInt.zero,
            precision: Int16(chainAsset.asset.precision)
        ) ?? 0.0
        let ownStakeDecimal = Decimal.fromSubstrateAmount(
            collatorInfo.metadata?.bond ?? BigUInt.zero,
            precision: Int16(chainAsset.asset.precision)
        ) ?? 0.0

        let totalStake = balanceViewModelFactory.balanceFromPrice(
            totalStakeDecimal,
            priceData: priceData,
            usageCase: .listCrypto
        ).value(for: locale)

        let estimatedReward = collatorInfo.subqueryData?.apr ?? 0.0
        let estimatedRewardDecimal = Decimal(estimatedReward)
        let estimatedRewardString = NumberFormatter.percentPlainAPR.localizableResource()
            .value(for: locale).stringFromDecimal(estimatedRewardDecimal) ?? ""

        let minimumBond = Decimal.fromSubstrateAmount(
            collatorInfo.metadata?.lowestTopDelegationAmount ?? BigUInt.zero,
            precision: Int16(chainAsset.asset.precision)
        ) ?? 0

        let effectiveAmountBondedDecimal = totalStakeDecimal - ownStakeDecimal

        let minimumBondString = balanceViewModelFactory.balanceFromPrice(
            minimumBond,
            priceData: priceData,
            usageCase: .listCrypto
        ).value(for: locale).amount

        let selfBondedString = balanceViewModelFactory.balanceFromPrice(
            ownStakeDecimal,
            priceData: priceData,
            usageCase: .listCrypto
        ).value(for: locale).amount

        let effectiveAmountBondedString = balanceViewModelFactory.balanceFromPrice(
            effectiveAmountBondedDecimal,
            priceData: priceData,
            usageCase: .listCrypto
        ).value(for: locale).amount

        return ValidatorInfoViewModel.ParachainExposure(
            delegations: delegationsCountString,
            totalStake: totalStake,
            estimatedReward: estimatedRewardString,
            minimumBond: minimumBondString,
            selfBonded: selfBondedString,
            effectiveAmountBonded: effectiveAmountBondedString,
            oversubscribed: collatorInfo.oversubscribed
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
            R.string.localizable.parachainStakingDelegatorsTitle(preferredLanguages: locale.rLanguages)
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
        let balance = balanceViewModelFactory.balanceFromPrice(amount, priceData: priceData, usageCase: .listCrypto)

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
            let exposure = createExposure(
                from: parachainViewModelState.collatorInfo,
                priceData: priceData,
                locale: locale
            )
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
            identity: identityItems,
            title: R.string.localizable.stakingCollatorInfoTitle(preferredLanguages: locale.rLanguages)
        )
    }

    func buildStakingAmountViewModels(
        viewModelState: ValidatorInfoViewModelState,
        priceData: PriceData?
    ) -> [LocalizableResource<StakingAmountViewModel>]? {
        guard let parachainViewModelState = viewModelState as? ValidatorInfoParachainViewModelState else {
            return nil
        }

        let collator = parachainViewModelState.collatorInfo

        let totalStake = Decimal.fromSubstrateAmount(
            collator.metadata?.totalCounted ?? BigUInt.zero,
            precision: Int16(chainAsset.asset.precision)
        ) ?? 0.0
        let ownStake = Decimal.fromSubstrateAmount(
            collator.metadata?.bond ?? BigUInt.zero,
            precision: Int16(chainAsset.asset.precision)
        ) ?? 0.0

        return [
            createStakingAmountRow(
                title: createOwnStakeTitle(),
                amount: ownStake,
                priceData: priceData
            ),
            createStakingAmountRow(
                title: createNominatorsStakeTitle(),
                amount: totalStake - ownStake,
                priceData: priceData
            ),
            createStakingAmountRow(
                title: createTotalTitle(),
                amount: totalStake,
                priceData: priceData
            )
        ]
    }
}
