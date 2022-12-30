import Foundation
import SoraFoundation

final class StakingBondMoreParachainViewModelFactory {
    let accountViewModelFactory: AccountViewModelFactoryProtocol

    init(accountViewModelFactory: AccountViewModelFactoryProtocol) {
        self.accountViewModelFactory = accountViewModelFactory
    }
}

extension StakingBondMoreParachainViewModelFactory: StakingBondMoreViewModelFactoryProtocol {
    func buildHintViewModel(viewModelState _: StakingBondMoreViewModelState, locale: Locale) -> LocalizableResource<String>? {
        LocalizableResource { locale in
            R.string.localizable.parachainStakingHintRewardBondMore(
                preferredLanguages: locale.rLanguages
            )
        }
    }

    func buildCollatorViewModel(viewModelState: StakingBondMoreViewModelState, locale: Locale) -> AccountViewModel? {
        guard let viewModelState = viewModelState as? StakingBondMoreParachainViewModelState else {
            return nil
        }

        return accountViewModelFactory.buildViewModel(
            title: R.string.localizable.parachainStakingCollator(preferredLanguages: locale.rLanguages),
            address: viewModelState.candidate.address,
            name: viewModelState.candidate.identity?.name,
            locale: locale
        )
    }

    func buildAccountViewModel(viewModelState: StakingBondMoreViewModelState, locale: Locale) -> AccountViewModel? {
        guard let viewModelState = viewModelState as? StakingBondMoreParachainViewModelState,
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
