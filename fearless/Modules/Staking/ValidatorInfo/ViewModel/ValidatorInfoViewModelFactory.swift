import Foundation
import FearlessUtils
import SoraFoundation
import CommonWallet

protocol ValidatorInfoViewModelFactoryProtocol {
    func createViewModel(
        from validatorInfo: ValidatorInfoProtocol,
        priceData: PriceData?
    )
        -> [ValidatorInfoViewModel]
    func createStakingAmountsViewModel(
        from validatorInfo: ValidatorInfoProtocol,
        priceData: PriceData?
    ) -> [LocalizableResource<StakingAmountViewModel>]
}

final class ValidatorInfoViewModelFactory {
    private let iconGenerator: IconGenerating
    private let asset: WalletAsset
    private let amountFormatterFactory: NumberFormatterFactoryProtocol
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    init(
        iconGenerator: IconGenerating,
        asset: WalletAsset,
        amountFormatterFactory: NumberFormatterFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol
    ) {
        self.iconGenerator = iconGenerator
        self.asset = asset
        self.amountFormatterFactory = amountFormatterFactory
        self.balanceViewModelFactory = balanceViewModelFactory
    }

    // MARK: - Private functions

    // MARK: Identity Rows

    private func createLegalRow(with legal: String) -> LocalizableResource<TitleWithSubtitleViewModel> {
        LocalizableResource { locale in
            let title = R.string.localizable.identityLegalNameTitle(preferredLanguages: locale.rLanguages)
            return TitleWithSubtitleViewModel(title: title, subtitle: legal)
        }
    }

    private func createEmailRow(with email: String) -> LocalizableResource<TitleWithSubtitleViewModel> {
        LocalizableResource { locale in
            let title = R.string.localizable.identityEmailTitle(preferredLanguages: locale.rLanguages)
            return TitleWithSubtitleViewModel(title: title, subtitle: email)
        }
    }

    private func createWebRow(with web: String) -> LocalizableResource<TitleWithSubtitleViewModel> {
        LocalizableResource { locale in
            let title = R.string.localizable.identityWebTitle(preferredLanguages: locale.rLanguages)
            return TitleWithSubtitleViewModel(title: title, subtitle: web)
        }
    }

    private func createTwitterRow(with twitter: String) -> LocalizableResource<TitleWithSubtitleViewModel> {
        LocalizableResource { _ in
            TitleWithSubtitleViewModel(title: "Twitter", subtitle: twitter)
        }
    }

    private func createRiotRow(with riot: String) -> LocalizableResource<TitleWithSubtitleViewModel> {
        LocalizableResource { locale in
            let title = R.string.localizable.identityRiotNameTitle(preferredLanguages: locale.rLanguages)
            return TitleWithSubtitleViewModel(title: title, subtitle: riot)
        }
    }

    // MARK: Stake Rows

    private func createTotalStakeRow(with totalStake: Decimal, priceData: PriceData?) -> LocalizableResource<StakingAmountViewModel> {
        let title = LocalizableResource { locale in
            R.string.localizable
                .stakingValidatorTotalStake(preferredLanguages: locale.rLanguages)
        }

        return createStakingAmountRow(
            title: title,
            amount: totalStake,
            priceData: priceData
        )
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

    private func createYourNominatedTitle() -> LocalizableResource<String> {
        LocalizableResource { locale in
            R.string.localizable.stakingYourNominatedTitle(preferredLanguages: locale.rLanguages)
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

    private func createNominatorsRow(with stakeInfo: ValidatorStakeInfoProtocol)
        -> LocalizableResource<TitleWithSubtitleViewModel> {
        LocalizableResource { locale in
            let title = R.string.localizable
                .stakingValidatorNominators(preferredLanguages: locale.rLanguages)
            let subtitle = R.string.localizable.stakingValidatorInfoNominators(
                String(stakeInfo.nominators.count),
                String(stakeInfo.maxNominatorsRewarded)
            )
            return TitleWithSubtitleViewModel(title: title, subtitle: subtitle)
        }
    }

    private func createEstimatedRewardRow(
        with stakeReturn: Decimal
    ) -> LocalizableResource<TitleWithSubtitleViewModel> {
        LocalizableResource { locale in
            let percentageFormatter = NumberFormatter.percentAPY.localizableResource().value(for: locale)

            let title = R.string.localizable
                .stakingValidatorEstimatedReward(preferredLanguages: locale.rLanguages)

            let subtitle = percentageFormatter
                .string(from: stakeReturn as NSNumber) ?? ""

            return TitleWithSubtitleViewModel(
                title: title,
                subtitle: subtitle
            )
        }
    }

    private func createEmptyStakeRow() -> ValidatorInfoViewModel {
        .emptyStake(LocalizableResource { locale in
            EmptyStakeViewModel(
                image: R.image.iconEmptyStake()!,
                title: R.string.localizable.validatorNotElectedDescription(preferredLanguages: locale.rLanguages)
            )
        })
    }

    // MARK: Nomination Rows

    private func createNominationStateRow(with state: ValidatorMyNominationStatus)
        -> LocalizableResource<TitleWithSubtitleViewModel> {
        LocalizableResource { locale in
            let title = R.string.localizable
                .stakingRewardDetailsStatus(preferredLanguages: locale.rLanguages)

            var subtitle = ""
            switch state {
            case .active: subtitle = R.string.localizable
                .stakingNominatorStatusActive(preferredLanguages: locale.rLanguages)
            case .inactive: subtitle = R.string.localizable
                .stakingNominatorStatusInactive(preferredLanguages: locale.rLanguages)
            case .slashed: subtitle = R.string.localizable
                .stakingValidatorStatusSlashed(preferredLanguages: locale.rLanguages)
            case .waiting: subtitle = R.string.localizable
                .stakingValidatorStatusWaiting(preferredLanguages: locale.rLanguages)
            }

            return TitleWithSubtitleViewModel(title: title, subtitle: subtitle)
        }
    }

    // MARK: - View models

    private func createAccountViewModel(from validatorInfo: ValidatorInfoProtocol) -> ValidatorInfoViewModel {
        let userIcon = try? iconGenerator.generateFromAddress(validatorInfo.address)
            .imageWithFillColor(
                .white,
                size: UIConstants.normalAddressIconSize,
                contentScale: UIScreen.main.scale
            )

        let viewModel: ValidatorInfoAccountViewModelProtocol =
            ValidatorInfoAccountViewModel(
                name: validatorInfo.identity?.displayName,
                address: validatorInfo.address,
                icon: userIcon
            )

        return .account(viewModel)
    }

    private func createStakingViewModel(
        from validatorInfo: ValidatorInfoProtocol,
        priceData: PriceData?
    ) -> ValidatorInfoViewModel {
        guard let stakeInfo = validatorInfo.stakeInfo else { return createEmptyStakeRow() }

        let stakingRows: [ValidatorInfoViewModel.StakingRow] = [
            .nominators(createNominatorsRow(with: stakeInfo), stakeInfo.oversubscribed),
            .totalStake(createTotalStakeRow(with: stakeInfo.totalStake, priceData: priceData)),
            .estimatedReward(createEstimatedRewardRow(with: stakeInfo.stakeReturn))
        ]

        return .staking(stakingRows)
    }

    //    case identity([IdentityRow])
    private func createIdentityViewModel(
        from validatorInfo: ValidatorInfoProtocol
    ) -> ValidatorInfoViewModel? {
        guard let identity = validatorInfo.identity else { return nil }

        var identityRows: [ValidatorInfoViewModel.IdentityRow] = []

        if let legal = identity.legal {
            identityRows.append(.legalName(createLegalRow(with: legal)))
        }

        if let email = identity.email {
            identityRows.append(.email(createEmailRow(with: email)))
        }

        if let web = identity.web {
            identityRows.append(.web(createWebRow(with: web)))
        }

        if let twitter = identity.twitter {
            identityRows.append(.twitter(createTwitterRow(with: twitter)))
        }

        if let riot = identity.riot {
            identityRows.append(.riot(createRiotRow(with: riot)))
        }

        guard !identityRows.isEmpty else { return nil }

        return .identity(identityRows)
    }

    private func createMyNominationViewModel(
        from validatorInfo: ValidatorInfoProtocol,
        priceData: PriceData?
    ) -> ValidatorInfoViewModel? {
        guard let nomination = validatorInfo.myNomination else { return nil }

        var nominationRows: [ValidatorInfoViewModel.NominationRow] = [
            .status(createNominationStateRow(with: nomination), nomination)
        ]

        if case let .active(amount) = nomination {
            let row = createStakingAmountRow(
                title: createYourNominatedTitle(),
                amount: amount,
                priceData: priceData
            )

            nominationRows.append(.nominatedAmount(row))
        }

        return .myNomination(nominationRows)
    }
}

// MARK: - ValidatorInfoViewModelFactoryProtocol

extension ValidatorInfoViewModelFactory: ValidatorInfoViewModelFactoryProtocol {
    func createViewModel(
        from validatorInfo: ValidatorInfoProtocol,
        priceData: PriceData?
    ) -> [ValidatorInfoViewModel] {
        var model = [createAccountViewModel(from: validatorInfo)]

        if let nominationModel = createMyNominationViewModel(
            from: validatorInfo,
            priceData: priceData
        ) {
            model.append(nominationModel)
        }

        model.append(createStakingViewModel(from: validatorInfo, priceData: priceData))

        if let identityModel = createIdentityViewModel(from: validatorInfo) {
            model.append(identityModel)
        }

        return model
    }

    func createStakingAmountsViewModel(
        from validatorInfo: ValidatorInfoProtocol,
        priceData: PriceData?
    ) -> [LocalizableResource<StakingAmountViewModel>] {
        let nominatorsStake = validatorInfo.stakeInfo?.nominators
            .map(\.stake)
            .reduce(0, +) ?? 0.0

        return [createStakingAmountRow(
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
        )]
    }
}
