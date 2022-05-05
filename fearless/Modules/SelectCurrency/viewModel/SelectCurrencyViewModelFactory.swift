import Foundation
import UIKit

protocol SelectCurrencyViewModelFactoryProtocol {
    func buildViewModel(
        supportedCurrencys: [Currency]
    ) -> [SelectCurrencyCellViewModel]
}

final class SelectCurrencyViewModelFactory: SelectCurrencyViewModelFactoryProtocol {
    func buildViewModel(
        supportedCurrencys: [Currency]
    ) -> [SelectCurrencyCellViewModel] {
        supportedCurrencys.compactMap {
            guard let iconUrl = URL(string: $0.icon) else { return nil }
            return SelectCurrencyCellViewModel(
                imageViewModel: RemoteImageViewModel(url: iconUrl),
                title: $0.name,
                isSelected: $0.isSelected ?? false,
                id: $0.id
            )
        }
    }
}
