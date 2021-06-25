import Foundation
import FearlessUtils

protocol SelectedValidatorsViewModelProtocol {
    var maxTargets: Int { get }
    var itemViewModels: [SelectedValidatorViewModelProtocol] { get }
}

protocol SelectedValidatorViewModelProtocol {
    var icon: DrawableIcon { get }
    var title: String { get }
    var details: String { get }
}

struct SelectedValidatorsViewModel: SelectedValidatorsViewModelProtocol {
    var maxTargets: Int
    var itemViewModels: [SelectedValidatorViewModelProtocol]
}

struct SelectedValidatorViewModel: SelectedValidatorViewModelProtocol {
    let icon: DrawableIcon
    let title: String
    let details: String
}
