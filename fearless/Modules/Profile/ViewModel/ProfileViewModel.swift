import Foundation

protocol ProfileViewModelProtocol {
    var profileUserViewModel: ProfileUserViewModelProtocol { get }
    var profileOptionViewModel: [ProfileOptionViewModelProtocol] { get }
    var logoutViewModel: ProfileOptionViewModelProtocol { get }
}

struct ProfileViewModel: ProfileViewModelProtocol {
    let profileUserViewModel: ProfileUserViewModelProtocol
    let profileOptionViewModel: [ProfileOptionViewModelProtocol]
    let logoutViewModel: ProfileOptionViewModelProtocol
}
