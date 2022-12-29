import Foundation

protocol SoraCardStateViewModelFactoryProtocol {
    func buildState(from kycStatus: SCKYCStatusResponse) -> SoraCardState
}

final class SoraCardStateViewModelFactory: SoraCardStateViewModelFactoryProtocol {
    func buildState(from _: SCKYCStatusResponse) -> SoraCardState {
        .none
    }
}
