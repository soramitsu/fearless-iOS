import Foundation
import FearlessUtils
import SoraFoundation

protocol RecommendedValidatorListViewModelProtocol {
    var itemsCountString: LocalizableResource<String> { get }
    var rewardColumnTitle: String { get }
    var itemViewModels: [LocalizableResource<RecommendedValidatorViewModelProtocol>] { get }
    var title: String { get }
    var continueButtonEnabled: Bool { get }
    var continueButtonTitle: String { get }
}

protocol RecommendedValidatorViewModelProtocol {
    var icon: DrawableIcon? { get }
    var title: String { get }
    var detailsAttributedString: NSAttributedString? { get }
    var detailsAux: String? { get }
    var isSelected: Bool { get }
}

struct RecommendedValidatorListViewModel: RecommendedValidatorListViewModelProtocol {
    let itemsCountString: LocalizableResource<String>
    let itemViewModels: [LocalizableResource<RecommendedValidatorViewModelProtocol>]
    let title: String
    let continueButtonEnabled: Bool
    let rewardColumnTitle: String
    let continueButtonTitle: String
}

struct RecommendedValidatorViewModel: RecommendedValidatorViewModelProtocol {
    let icon: DrawableIcon?
    let title: String
    let detailsAttributedString: NSAttributedString?
    let detailsAux: String?
    let isSelected: Bool
}
