import Foundation
import FearlessUtils

protocol ProfileUserViewModelProtocol {
    var name: String { get }
    var details: String { get }
    var icon: DrawableIcon? { get }
}

struct ProfileUserViewModel: ProfileUserViewModelProtocol {
    let name: String
    let details: String
    let icon: DrawableIcon?
}
