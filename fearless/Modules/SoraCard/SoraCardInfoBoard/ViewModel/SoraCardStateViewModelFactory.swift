import Foundation
import SoraFoundation

protocol SoraCardStateViewModelFactoryProtocol {
    func buildViewModel(from userStatus: SCKYCUserStatus) -> SoraCardInfoViewModel
}

final class SoraCardStateViewModelFactory: SoraCardStateViewModelFactoryProtocol {
    func buildViewModel(from userStatus: SCKYCUserStatus) -> SoraCardInfoViewModel {
        SoraCardInfoViewModel(userStatus: userStatus)
    }
}
