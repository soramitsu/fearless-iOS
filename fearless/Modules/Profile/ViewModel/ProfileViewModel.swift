import Foundation

protocol ProfileViewModelProtocol {
    var profileUserViewModel: WalletsManagmentCellViewModel { get }
    var profileOptionViewModel: [ProfileOptionViewModelProtocol] { get }
    var logoutViewModel: ProfileOptionViewModelProtocol { get }
}

struct ProfileViewModel: ProfileViewModelProtocol {
    let profileUserViewModel: WalletsManagmentCellViewModel
    let profileOptionViewModel: [ProfileOptionViewModelProtocol]
    let logoutViewModel: ProfileOptionViewModelProtocol
}
