import Foundation
import FearlessUtils

protocol SelectedValidatorViewModelProtocol {
    var icon: DrawableIcon { get }
    var title: String { get }
    var details: String { get }
}

struct SelectedValidatorViewModel: SelectedValidatorViewModelProtocol  {
    let icon: DrawableIcon
    let title: String
    let details: String
}
