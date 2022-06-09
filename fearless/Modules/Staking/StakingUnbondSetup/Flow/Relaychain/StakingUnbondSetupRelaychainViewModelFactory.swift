import Foundation
import SoraFoundation

final class StakingUnbondSetupRelaychainViewModelFactory: StakingUnbondSetupViewModelFactoryProtocol {
    func buildBondingDurationViewModel(viewModelState: StakingUnbondSetupViewModelState) -> LocalizableResource<String>? {
        guard let viewModelState = viewModelState as? StakingUnbondSetupRelaychainViewModelState else {
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
}
