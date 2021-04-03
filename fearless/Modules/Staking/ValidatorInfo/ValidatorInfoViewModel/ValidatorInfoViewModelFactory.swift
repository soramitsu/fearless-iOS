import Foundation
import FearlessUtils
import SoraFoundation
import CommonWallet

protocol ValidatorInfoViewModelFactoryProtocol {
    func createExtrasViewModel(
        from validatorInfo: ValidatorInfoProtocol) -> [ValidatorInfoViewController.Section]
    func createAccountViewModel(
        from validatorInfo: ValidatorInfoProtocol) -> ValidatorInfoAccountViewModelProtocol
}

final class ValidatorInfoViewModelFactory: ValidatorInfoViewModelFactoryProtocol {
    private let iconGenerator: IconGenerating
    private let asset: WalletAsset
    private let amountFormatterFactory: NumberFormatterFactoryProtocol

    init(
        iconGenerator: IconGenerating,
        asset: WalletAsset,
        amountFormatterFactory: NumberFormatterFactoryProtocol
    ) {
        self.iconGenerator = iconGenerator
        self.asset = asset
        self.amountFormatterFactory = amountFormatterFactory
    }

    func createExtrasViewModel(from validatorInfo: ValidatorInfoProtocol) -> [ValidatorInfoViewController.Section] {
        var sections: [ValidatorInfoViewController.Section] = []

        if let stakingViewModel = createStakingViewModel(from: validatorInfo) {
            sections.append((.staking, stakingViewModel))
        }

        if let identityViewModel = createIdentityViewModel(from: validatorInfo) {
            sections.append((.identity, identityViewModel))
        }

        return sections
    }

    func createAccountViewModel(from validatorInfo: ValidatorInfoProtocol) -> ValidatorInfoAccountViewModelProtocol {
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

        return viewModel
    }

    // MARK: - Private functions

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

    private func createTotalStakeRow(with totalStake: Decimal) -> LocalizableResource<TitleWithSubtitleViewModel> {
        let tokenFormatter = amountFormatterFactory.createTokenFormatter(for: asset)

        return LocalizableResource { locale in

            let title = R.string.localizable
                .stakingValidatorTotalStake(preferredLanguages: locale.rLanguages)

            let subtitle = tokenFormatter.value(for: locale)
                .string(from: totalStake) ?? ""

            return TitleWithSubtitleViewModel(
                title: title,
                subtitle: subtitle
            )
        }
    }

    private func createNominatorsRow(with nominators: [Any]) -> LocalizableResource<TitleWithSubtitleViewModel> {
        LocalizableResource { locale in
            let title = R.string.localizable
                .stakingValidatorNominators(preferredLanguages: locale.rLanguages)
            return TitleWithSubtitleViewModel(title: title, subtitle: String(nominators.count))
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

    private func createIdentityViewModel(
        from validatorInfo: ValidatorInfoProtocol
    ) -> [ValidatorInfoViewController.Row]? {
        guard let identity = validatorInfo.identity else { return nil }

        var identityViewModel: [ValidatorInfoViewController.Row] = []

        if let legal = identity.legal {
            identityViewModel.append((
                rowType: .legalName,
                content: createLegalRow(with: legal)
            ))
        }

        if let email = identity.email {
            identityViewModel.append((
                rowType: .email,
                content: createEmailRow(with: email)
            ))
        }

        if let web = identity.web {
            identityViewModel.append((
                rowType: .web,
                content: createWebRow(with: web)
            ))
        }

        if let twitter = identity.twitter {
            identityViewModel.append((
                rowType: .twitter,
                content: createTwitterRow(with: twitter)
            ))
        }

        if let riot = identity.riot {
            identityViewModel.append((
                rowType: .riot,
                content: createRiotRow(with: riot)
            ))
        }

        guard !identityViewModel.isEmpty else { return nil }

        return identityViewModel
    }

    private func createStakingViewModel(
        from validatorInfo: ValidatorInfoProtocol
    ) -> [ValidatorInfoViewController.Row]? {
        guard let stakeInfo = validatorInfo.stakeInfo else { return nil }

        var stakingViewModel: [ValidatorInfoViewController.Row] = []

        stakingViewModel.append((
            rowType: .totalStake,
            content: createTotalStakeRow(with: stakeInfo.totalStake)
        ))

        stakingViewModel.append((
            rowType: .nominators,
            content:
            createNominatorsRow(with: stakeInfo.nominators)
        ))

        stakingViewModel.append((
            rowType: .estimatedReward,
            createEstimatedRewardRow(with: stakeInfo.stakeReturn)
        ))

        guard !stakingViewModel.isEmpty else { return nil }

        return stakingViewModel
    }
}
