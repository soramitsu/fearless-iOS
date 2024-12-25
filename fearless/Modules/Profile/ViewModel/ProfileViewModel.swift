import Foundation
import SSFModels

protocol ProfileViewModelProtocol {
    var wallet: MetaAccountModel { get }
    var profileUserViewModel: WalletsManagmentCellViewModel { get }
    var profileOptionViewModel: [ProfileOptionViewModelProtocol] { get }
    var logoutViewModel: ProfileOptionViewModelProtocol { get }
}

struct ProfileViewModel: ProfileViewModelProtocol {
    let wallet: MetaAccountModel
    let profileUserViewModel: WalletsManagmentCellViewModel
    let profileOptionViewModel: [ProfileOptionViewModelProtocol]
    let logoutViewModel: ProfileOptionViewModelProtocol
}
