import Foundation
import SoraFoundation

final class StakingBondMoreRelaychainViewModelFactory {}

extension StakingBondMoreRelaychainViewModelFactory: StakingBondMoreViewModelFactoryProtocol {
    func buildHintViewModel(viewModelState _: StakingBondMoreViewModelState, locale: Locale) -> LocalizableResource<String>? {
        LocalizableResource { locale in
            R.string.localizable.stakingHintRewardBondMore(
                preferredLanguages: locale.rLanguages
            )
        }
    }
}
