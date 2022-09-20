import Foundation
import SoraFoundation

final class StakingUnbondSetupPoolViewModelFactory: StakingUnbondSetupViewModelFactoryProtocol {
    let accountViewModelFactory: AccountViewModelFactoryProtocol

    init(accountViewModelFactory: AccountViewModelFactoryProtocol) {
        self.accountViewModelFactory = accountViewModelFactory
    }

    func buildBondingDurationViewModel(viewModelState: StakingUnbondSetupViewModelState) -> LocalizableResource<TitleWithSubtitleViewModel>? {
        guard let viewModelState = viewModelState as? StakingUnbondSetupPoolViewModelState else {
            return nil
        }

        let viewModel: LocalizableResource<TitleWithSubtitleViewModel> = LocalizableResource { locale in
            let title = R.string.localizable.stakingUnbondingPeriod_v190(preferredLanguages: locale.rLanguages)
            let subtitle = viewModelState.stakingDuration?.unlocking.readableValue(locale: locale) ?? ""
            return TitleWithSubtitleViewModel(title: title, subtitle: subtitle)
        }

        return viewModel
    }

    func buildCollatorViewModel(viewModelState _: StakingUnbondSetupViewModelState, locale _: Locale) -> AccountViewModel? {
        nil
    }

    func buildAccountViewModel(viewModelState: StakingUnbondSetupViewModelState, locale: Locale) -> AccountViewModel? {
        guard let viewModelState = viewModelState as? StakingUnbondSetupPoolViewModelState,
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
        LocalizableResource { _ in
            []
        }
    }
}
