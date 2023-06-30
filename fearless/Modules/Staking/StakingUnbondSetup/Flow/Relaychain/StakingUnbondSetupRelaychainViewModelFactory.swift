import Foundation
import SoraFoundation

final class StakingUnbondSetupRelaychainViewModelFactory: StakingUnbondSetupViewModelFactoryProtocol {
    func buildCollatorViewModel(viewModelState _: StakingUnbondSetupViewModelState, locale _: Locale) -> AccountViewModel? {
        nil
    }

    func buildAccountViewModel(viewModelState _: StakingUnbondSetupViewModelState, locale _: Locale) -> AccountViewModel? {
        nil
    }

    func buildBondingDurationViewModel(viewModelState: StakingUnbondSetupViewModelState) -> LocalizableResource<TitleWithSubtitleViewModel>? {
        guard let viewModelState = viewModelState as? StakingUnbondSetupRelaychainViewModelState else {
            return nil
        }

        let daysCount = viewModelState.bondingDuration.map { UInt32($0) / viewModelState.chainAsset.chain.erasPerDay }
        let viewModel: LocalizableResource<TitleWithSubtitleViewModel> = LocalizableResource { locale in
            guard let daysCount = daysCount else {
                return TitleWithSubtitleViewModel(title: "")
            }
            let title = R.string.localizable.stakingUnstakingPeriod(preferredLanguages: locale.rLanguages)
            let subtitle = R.string.localizable.commonDaysFormat(
                format: Int(daysCount),
                preferredLanguages: locale.rLanguages
            )
            return TitleWithSubtitleViewModel(title: title, subtitle: subtitle)
        }

        return viewModel
    }

    func buildTitleViewModel() -> LocalizableResource<String> {
        LocalizableResource { locale in
            R.string.localizable.stakingUnbond_v190(preferredLanguages: locale.rLanguages)
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
        LocalizableResource { _ in
            [TitleIconViewModel]()
        }
    }
}
