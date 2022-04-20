import Foundation
import UIKit

enum Currency: String, CaseIterable, Codable, Equatable {
    static var defaultCurrency: Currency = .usd

    case usd
    case gbr
    case eur

    var icon: UIImage? {
        switch self {
        case .usd:
            return R.image.flagsUsd()
        case .gbr:
            return R.image.flagsGrb()
        case .eur:
            return R.image.flagsEur()
        }
    }
}

protocol SelectCurrencyViewModelFactoryProtocol {
    func buildViewModel(selected currency: Currency) -> [SelectCurrencyCellViewModel]
}

final class SelectCurrencyViewModelFactory: SelectCurrencyViewModelFactoryProtocol {
    func buildViewModel(selected currency: Currency) -> [SelectCurrencyCellViewModel] {
        Currency.allCases.map { item -> SelectCurrencyCellViewModel in
            switch item {
            case .usd:
                return SelectCurrencyCellViewModel(
                    icon: item.icon,
                    title: item.rawValue.uppercased(),
                    isSelected: item == currency
                )
            case .gbr:
                return SelectCurrencyCellViewModel(
                    icon: item.icon,
                    title: item.rawValue.uppercased(),
                    isSelected: item == currency
                )
            case .eur:
                return SelectCurrencyCellViewModel(
                    icon: item.icon,
                    title: item.rawValue.uppercased(),
                    isSelected: item == currency
                )
            }
        }
    }
}
