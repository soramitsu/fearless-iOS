import UIKit

enum ProfileOptionAccessoryType {
    case arrow
    case switcher(Bool)
}

protocol ProfileOptionViewModelProtocol {
    var icon: UIImage? { get }
    var title: String { get }
    var accessoryTitle: String? { get }
    var accessoryImage: UIImage? { get }
    var accessoryType: ProfileOptionAccessoryType { get }
    var option: ProfileOption? { get }
}

struct ProfileOptionViewModel: ProfileOptionViewModelProtocol {
    let title: String
    let icon: UIImage?
    let accessoryTitle: String?
    let accessoryImage: UIImage?
    let accessoryType: ProfileOptionAccessoryType
    let option: ProfileOption?
}
