import Foundation
import FearlessUtils
import SoraFoundation

protocol RecommendedValidatorListViewModelProtocol {
    var itemsCountString: LocalizableResource<String> { get }
    var itemViewModels: [LocalizableResource<RecommendedValidatorViewModelProtocol>] { get }
}

protocol RecommendedValidatorViewModelProtocol {
    var icon: DrawableIcon { get }
    var title: String { get }
    var details: String { get }
}

struct RecommendedValidatorListViewModel: RecommendedValidatorListViewModelProtocol {
    let itemsCountString: LocalizableResource<String>
    let itemViewModels: [LocalizableResource<RecommendedValidatorViewModelProtocol>]
}

struct RecommendedValidatorViewModel: RecommendedValidatorViewModelProtocol {
    let icon: DrawableIcon
    let title: String
    let details: String
}
