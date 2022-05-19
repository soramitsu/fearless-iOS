import Foundation

class CustomValidatorListParachainViewModelFactory {}

extension CustomValidatorListParachainViewModelFactory: CustomValidatorListViewModelFactoryProtocol {
    func buildViewModel(
        viewModelState _: CustomValidatorListViewModelState,
        priceData _: PriceData?,
        locale _: Locale
    ) -> CustomValidatorListViewModel? {
        nil
    }
}
