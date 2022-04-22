import Foundation
import UIKit

enum Currency: String, CaseIterable, Codable, Equatable {
    static var defaultCurrency: Currency = .usd

    case usd
    case gbp
    case eur

    var icon: UIImage? {
        switch self {
        case .usd:
            return R.image.flagsUsd()
        case .gbp:
            return R.image.flagsGrb()
        case .eur:
            return R.image.flagsEur()
        }
    }

    var symbol: String {
        switch self {
        case .usd:
            return "$"
        case .gbp:
            return "£"
        case .eur:
            return "€"
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
            case .gbp:
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
