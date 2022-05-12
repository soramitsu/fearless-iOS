import Foundation
import UIKit

protocol SelectCurrencyViewModelFactoryProtocol {
    func buildViewModel(
        supportedCurrencys: [Currency],
        selectedCurrency: Currency
    ) -> [SelectCurrencyCellViewModel]
}

final class SelectCurrencyViewModelFactory: SelectCurrencyViewModelFactoryProtocol {
    func buildViewModel(
        supportedCurrencys: [Currency],
        selectedCurrency: Currency
    ) -> [SelectCurrencyCellViewModel] {
        supportedCurrencys.compactMap {
            var imageViewModel: RemoteImageViewModel?
            if let iconUrl = URL(string: $0.icon) {
                imageViewModel = RemoteImageViewModel(url: iconUrl)
            }
            return SelectCurrencyCellViewModel(
                imageViewModel: imageViewModel,
                title: $0.name,
                isSelected: $0.id == selectedCurrency.id,
                id: $0.id
            )
        }
    }
}
