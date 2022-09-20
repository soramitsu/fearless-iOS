import Foundation
import SoraFoundation

final class StakingBondMoreRelaychainViewModelFactory {
    let accountViewModelFactory: AccountViewModelFactoryProtocol

    init(accountViewModelFactory: AccountViewModelFactoryProtocol) {
        self.accountViewModelFactory = accountViewModelFactory
    }
}

extension StakingBondMoreRelaychainViewModelFactory: StakingBondMoreViewModelFactoryProtocol {
    func buildHintViewModel(viewModelState _: StakingBondMoreViewModelState, locale: Locale) -> LocalizableResource<String>? {
        LocalizableResource { locale in
            R.string.localizable.stakingHintRewardBondMore(
                preferredLanguages: locale.rLanguages
            )
        }
    }

    func buildCollatorViewModel(viewModelState _: StakingBondMoreViewModelState, locale _: Locale) -> AccountViewModel? {
        nil
    }

    func buildAccountViewModel(viewModelState _: StakingBondMoreViewModelState, locale _: Locale) -> AccountViewModel? {
        nil
    }
}
