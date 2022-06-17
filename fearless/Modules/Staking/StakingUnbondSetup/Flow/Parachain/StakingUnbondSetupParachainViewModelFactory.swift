import Foundation
import SoraFoundation

final class StakingUnbondSetupParachainViewModelFactory: StakingUnbondSetupViewModelFactoryProtocol {
    let accountViewModelFactory: AccountViewModelFactoryProtocol

    init(accountViewModelFactory: AccountViewModelFactoryProtocol) {
        self.accountViewModelFactory = accountViewModelFactory
    }

    func buildBondingDurationViewModel(viewModelState: StakingUnbondSetupViewModelState) -> LocalizableResource<String>? {
        guard let viewModelState = viewModelState as? StakingUnbondSetupParachainViewModelState else {
            return nil
        }

        let daysCount = viewModelState.bondingDuration.map { UInt32($0) / viewModelState.chainAsset.chain.erasPerDay }
        let bondingDuration: LocalizableResource<String> = LocalizableResource { locale in
            guard let daysCount = daysCount else {
                return ""
            }

            return R.string.localizable.commonDaysFormat(
                format: Int(daysCount),
                preferredLanguages: locale.rLanguages
            )
        }

        return bondingDuration
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
}
