import Foundation
import SSFUtils

protocol ProfileUserViewModelProtocol {
    var name: String { get }
    var details: String { get }
    var icon: DrawableIcon? { get }
}
