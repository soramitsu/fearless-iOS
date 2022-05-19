import Foundation
import SoraFoundation

final class ValidatorInfoParachainViewModelFactory {}

extension ValidatorInfoParachainViewModelFactory: ValidatorInfoViewModelFactoryProtocol {
    func buildViewModel(viewModelState _: ValidatorInfoViewModelState, priceData _: PriceData?, locale _: Locale) -> ValidatorInfoViewModel? {
        nil
    }

    func buildStakingAmountViewModels(viewModelState _: ValidatorInfoViewModelState, priceData _: PriceData?) -> [LocalizableResource<StakingAmountViewModel>]? {
        nil
    }
}
