import Foundation
import FearlessUtils
import SoraFoundation

protocol SelectedValidatorsViewModelProtocol {
    var maxTargets: Int { get }
    var itemViewModels: [LocalizableResource<SelectedValidatorViewModelProtocol>] { get }
}

protocol SelectedValidatorViewModelProtocol {
    var icon: DrawableIcon { get }
    var title: String { get }
    var details: String { get }
}

struct SelectedValidatorsViewModel: SelectedValidatorsViewModelProtocol {
    var maxTargets: Int
    var itemViewModels: [LocalizableResource<SelectedValidatorViewModelProtocol>]
}

struct SelectedValidatorViewModel: SelectedValidatorViewModelProtocol {
    let icon: DrawableIcon
    let title: String
    let details: String
}
