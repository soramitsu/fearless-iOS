import Foundation
import SoraFoundation

final class StakingUnbondSetupParachainViewModelFactory: StakingUnbondSetupViewModelFactoryProtocol {
    let accountViewModelFactory: AccountViewModelFactoryProtocol

    init(accountViewModelFactory: AccountViewModelFactoryProtocol) {
        self.accountViewModelFactory = accountViewModelFactory
    }

    func buildBondingDurationViewModel(viewModelState: StakingUnbondSetupViewModelState) -> LocalizableResource<TitleWithSubtitleViewModel>? {
        guard let viewModelState = viewModelState as? StakingUnbondSetupParachainViewModelState else {
            return nil
        }

        let daysCount = viewModelState.bondingDuration.map { UInt32($0) / viewModelState.chainAsset.chain.erasPerDay }
        let viewModel: LocalizableResource<TitleWithSubtitleViewModel> = LocalizableResource { locale in
            guard let daysCount = daysCount else {
                return TitleWithSubtitleViewModel(title: "")
            }

            let title = R.string.localizable.stakingUnbondingPeriod_v190(preferredLanguages: locale.rLanguages)
            let subtitle = R.string.localizable.commonDaysFormat(
                format: Int(daysCount),
                preferredLanguages: locale.rLanguages
            )
            return TitleWithSubtitleViewModel(title: title, subtitle: subtitle)
        }
        return viewModel
    }

    func buildCollatorViewModel(viewModelState: StakingUnbondSetupViewModelState, locale: Locale) -> AccountViewModel? {
        guard let viewModelState = viewModelState as? StakingUnbondSetupParachainViewModelState else {
            return nil
        }

        return accountViewModelFactory.buildViewModel(
            title: R.string.localizable.parachainStakingCollator(preferredLanguages: locale.rLanguages),
            address: viewModelState.candidate.address,
            name: viewModelState.candidate.identity?.name,
            locale: locale
        )
    }

    func buildAccountViewModel(viewModelState: StakingUnbondSetupViewModelState, locale: Locale) -> AccountViewModel? {
        guard let viewModelState = viewModelState as? StakingUnbondSetupParachainViewModelState,
              let address = viewModelState.accountAddress else {
            return nil
        }

        return accountViewModelFactory.buildViewModel(
            title: R.string.localizable.accountInfoTitle(preferredLanguages: locale.rLanguages),
            address: address,
            name: viewModelState.wallet.fetch(for: viewModelState.chainAsset.chain.accountRequest())?.name,
            locale: locale
        )
    }

    func buildTitleViewModel() -> LocalizableResource<String> {
        LocalizableResource { locale in
            R.string.localizable.parachainStakingStakeLess(preferredLanguages: locale.rLanguages)
        }
    }

    func buildNetworkFeeViewModel(
        from balanceViewModel: LocalizableResource<BalanceViewModelProtocol>
    ) -> LocalizableResource<NetworkFeeFooterViewModelProtocol> {
        LocalizableResource { locale in
            let actionTitle = LocalizableResource { locale in
                R.string.localizable.commonContinue(preferredLanguages: locale.rLanguages)
            }
            let feeTitle = LocalizableResource { locale in
                R.string.localizable.commonNetworkFee(preferredLanguages: locale.rLanguages)
            }
            return NetworkFeeFooterViewModel(
                actionTitle: actionTitle,
                feeTitle: feeTitle,
                balanceViewModel: balanceViewModel
            )
        }
    }

    func buildHints() -> LocalizableResource<[TitleIconViewModel]> {
        LocalizableResource { locale in
            var items = [TitleIconViewModel]()

            items.append(
                TitleIconViewModel(
                    title: R.string.localizable.stakingStakeLessHint(preferredLanguages: locale.rLanguages),
                    icon: R.image.iconInfoFilled()?.tinted(with: R.color.colorStrokeGray()!)
                )
            )

            return items
        }
    }
}
