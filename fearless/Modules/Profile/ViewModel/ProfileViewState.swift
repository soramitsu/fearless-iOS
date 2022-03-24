import Foundation

enum ProfileViewState {
    case loading
    case loaded(ProfileViewModelProtocol)
}
