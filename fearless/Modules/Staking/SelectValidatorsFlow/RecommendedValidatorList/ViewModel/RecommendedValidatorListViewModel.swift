import Foundation
import FearlessUtils
import SoraFoundation

protocol RecommendedValidatorListViewModelProtocol {
    var itemsCountString: LocalizableResource<String> { get }
    var itemViewModels: [LocalizableResource<RecommendedValidatorViewModelProtocol>] { get }
    var title: String { get }
    var continueButtonEnabled: Bool { get }
}

protocol RecommendedValidatorViewModelProtocol {
    var icon: DrawableIcon? { get }
    var title: String { get }
    var details: String { get }
    var isSelected: Bool { get }
}

struct RecommendedValidatorListViewModel: RecommendedValidatorListViewModelProtocol {
    let itemsCountString: LocalizableResource<String>
    let itemViewModels: [LocalizableResource<RecommendedValidatorViewModelProtocol>]
    let title: String
    let continueButtonEnabled: Bool
}

struct RecommendedValidatorViewModel: RecommendedValidatorViewModelProtocol {
    let icon: DrawableIcon?
    let title: String
    let details: String
    let isSelected: Bool
}
