import Foundation
import FearlessUtils
import SoraFoundation

protocol SelectedValidatorsViewModelProtocol {
    var itemsCountString: LocalizableResource<String> { get }
    var itemViewModels: [LocalizableResource<SelectedValidatorViewModelProtocol>] { get }
}

protocol SelectedValidatorViewModelProtocol {
    var icon: DrawableIcon { get }
    var title: String { get }
    var details: String { get }
}

struct SelectedValidatorsViewModel: SelectedValidatorsViewModelProtocol {
    let itemsCountString: LocalizableResource<String>
    let itemViewModels: [LocalizableResource<SelectedValidatorViewModelProtocol>]
}

struct SelectedValidatorViewModel: SelectedValidatorViewModelProtocol {
    let icon: DrawableIcon
    let title: String
    let details: String
}
