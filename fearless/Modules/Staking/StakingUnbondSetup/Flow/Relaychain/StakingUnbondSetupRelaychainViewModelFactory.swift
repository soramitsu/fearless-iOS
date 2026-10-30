import Foundation
import SoraFoundation

final class StakingUnbondSetupRelaychainViewModelFactory: StakingUnbondSetupViewModelFactoryProtocol {
    func buildAccountViewModel(viewModelState _: StakingUnbondSetupViewModelState, locale _: Locale) -> AccountViewModel? {
        nil
    }

    func buildBondingDurationViewModel(viewModelState: StakingUnbondSetupViewModelState) -> LocalizableResource<TitleWithSubtitleViewModel>? {
        guard let viewModelState = viewModelState as? StakingUnbondSetupRelaychainViewModelState else {
            return nil
        }

        let showsHours = viewModelState.unbondingTime.map { $0 <= TimeInterval.secondsInDay } ?? false
        let unit = showsHours ? TimeInterval.secondsInHour : TimeInterval.secondsInDay
        let periodCount: UInt32?
        if let duration = viewModelState.unbondingTime {
            periodCount = duration > 0 && duration.isFinite ? UInt32(exactly: ceil(duration / unit)) : nil
        } else {
            periodCount = viewModelState.bondingDuration.map { UInt32($0) / viewModelState.chainAsset.chain.erasPerDay }
        }
        let viewModel: LocalizableResource<TitleWithSubtitleViewModel> = LocalizableResource { locale in
            guard let periodCount = periodCount else {
                return TitleWithSubtitleViewModel(title: "")
            }
            let title = R.string.localizable.stakingUnstakingPeriod(preferredLanguages: locale.rLanguages)
            let subtitle = showsHours
                ? R.string.localizable.commonHoursFormat(
                    format: Int(periodCount), preferredLanguages: locale.rLanguages
                )
                : R.string.localizable.commonDaysFormat(
                    format: Int(periodCount), preferredLanguages: locale.rLanguages
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
