import UIKit

protocol ProfileOptionViewModelProtocol {
    var icon: UIImage { get }
    var title: String { get }
    var accessoryTitle: String? { get }
}

struct ProfileOptionViewModel: ProfileOptionViewModelProtocol {
    let title: String
    let icon: UIImage
    let accessoryTitle: String?
}
