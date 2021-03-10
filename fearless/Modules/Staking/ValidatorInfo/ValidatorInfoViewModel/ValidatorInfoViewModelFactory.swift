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

    init(iconGenerator: IconGenerating,
         asset: WalletAsset,
         amountFormatterFactory: NumberFormatterFactoryProtocol) {
        self.iconGenerator = iconGenerator
        self.asset = asset
        self.amountFormatterFactory = amountFormatterFactory
    }

    func createExtrasViewModel(from validatorInfo: ValidatorInfoProtocol) -> [ValidatorInfoViewController.Section] {
        var sections: [ValidatorInfoViewController.Section] = []

        if let stakingViewModel = generateStakingViewModel(from: validatorInfo) {
            sections.append((.staking, stakingViewModel))
        }

        if let identityViewModel = generateIdentityViewModel(from: validatorInfo) {
            sections.append((.identity, identityViewModel))
        }

        return sections
    }

    func createAccountViewModel(from validatorInfo: ValidatorInfoProtocol) -> ValidatorInfoAccountViewModelProtocol {
        let userIcon = try? iconGenerator.generateFromAddress(validatorInfo.address)
            .imageWithFillColor(.white,
                                size: UIConstants.normalAddressIconSize,
                                contentScale: UIScreen.main.scale)

        let viewModel: ValidatorInfoAccountViewModelProtocol =
            ValidatorInfoAccountViewModel(name: validatorInfo.identity?.displayName,
                                          address: validatorInfo.address,
                                          icon: userIcon)

        return viewModel
    }

    // MARK: - Private functions
    private func generateStakingViewModel(
        from validatorInfo: ValidatorInfoProtocol) -> [ValidatorInfoViewController.Row]? {

        guard let stakeInfo = validatorInfo.stakeInfo else { return nil }

        var stakingViewModel: [ValidatorInfoViewController.Row] = []

        let tokenFormatter = amountFormatterFactory.createTokenFormatter(for: asset)

        let totalStakeLocalizedContent: LocalizableResource<TitleWithSubtitleViewModel> =
            LocalizableResource { locale in

                let title = R.string.localizable
                    .stakingValidatorTotalStake(preferredLanguages: locale.rLanguages)

                let subtitle = tokenFormatter.value(for: locale)
                    .string(from: stakeInfo.totalStake) ?? ""

                return TitleWithSubtitleViewModel(title: title,
                                                  subtitle: subtitle)
        }

        let nominatorsLocalizedContent: LocalizableResource<TitleWithSubtitleViewModel> =
            LocalizableResource { locale in
                let title = R.string.localizable
                    .stakingValidatorNominators(preferredLanguages: locale.rLanguages)
                return TitleWithSubtitleViewModel(title: title, subtitle: String(stakeInfo.nominators.count))
        }

        let estimatedRewardLocalizedContent: LocalizableResource<TitleWithSubtitleViewModel> =
            LocalizableResource { locale in
                let percentageFormatter = NumberFormatter.percentAPY.localizableResource().value(for: locale)

                let title = R.string.localizable
                    .stakingValidatorEstimatedReward(preferredLanguages: locale.rLanguages)

                let subtitle = percentageFormatter
                    .string(from: stakeInfo.stakeReturn as NSNumber) ?? ""

                return TitleWithSubtitleViewModel(title: title,
                                                  subtitle: subtitle)
        }

        stakingViewModel.append((rowType: .totalStake, content: totalStakeLocalizedContent))
        stakingViewModel.append((rowType: .nominators, content: nominatorsLocalizedContent))
        stakingViewModel.append((rowType: .estimatedReward, content: estimatedRewardLocalizedContent))

        guard stakingViewModel.count > 0 else { return nil }

        return stakingViewModel
    }

    private func generateIdentityViewModel(
        from validatorInfo: ValidatorInfoProtocol) -> [ValidatorInfoViewController.Row]? {
        guard let identity = validatorInfo.identity else { return nil }

        var identityViewModel: [ValidatorInfoViewController.Row] = []

        if let legal = identity.legal {
            let content: LocalizableResource<TitleWithSubtitleViewModel> = LocalizableResource { locale in
                let title = R.string.localizable.identityLegalNameTitle(preferredLanguages: locale.rLanguages)
                return TitleWithSubtitleViewModel(title: title, subtitle: legal)
            }

            identityViewModel.append((rowType: .legalName, content: content))
        }

        if let email = identity.email {
            let content: LocalizableResource<TitleWithSubtitleViewModel> =
                LocalizableResource { locale in
                    let title = R.string.localizable.identityEmailTitle(preferredLanguages: locale.rLanguages)
                    return TitleWithSubtitleViewModel(title: title, subtitle: email)
            }

            identityViewModel.append((rowType: .email, content: content))
        }

        if let web = identity.web {
            let content: LocalizableResource<TitleWithSubtitleViewModel> =
                LocalizableResource { locale in
                    let title = R.string.localizable.identityWebTitle(preferredLanguages: locale.rLanguages)
                    return TitleWithSubtitleViewModel(title: title, subtitle: web)
            }

            identityViewModel.append((rowType: .web, content: content))
        }

        if let twitter = identity.twitter {
            let content: LocalizableResource<TitleWithSubtitleViewModel> = LocalizableResource { _ in
                    return TitleWithSubtitleViewModel(title: "Twitter", subtitle: twitter)
            }
            identityViewModel.append((rowType: .twitter, content: content))
        }

        if let riot = identity.riot {
            let content: LocalizableResource<TitleWithSubtitleViewModel> =
                LocalizableResource { locale in
                    let title = R.string.localizable.identityRiotNameTitle(preferredLanguages: locale.rLanguages)
                    return TitleWithSubtitleViewModel(title: title, subtitle: riot)
            }

            identityViewModel.append((rowType: .riot, content: content))
        }

        guard identityViewModel.count > 0 else { return nil }

        return identityViewModel
    }
}
