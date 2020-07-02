import Foundation

protocol ProfileUserViewModelProtocol: class {
    var name: String { get }
    var details: String { get }
}

final class ProfileUserViewModel: ProfileUserViewModelProtocol {
    var name: String
    var details: String

    init(name: String, details: String) {
        self.name = name
        self.details = details
    }
}
