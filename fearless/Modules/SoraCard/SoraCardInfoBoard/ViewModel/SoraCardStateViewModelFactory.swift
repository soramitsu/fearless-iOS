import Foundation
import SoraFoundation

protocol SoraCardStateViewModelFactoryProtocol {
    func buildViewModel(from kycStatus: SCKYCStatusResponse) -> LocalizableResource<SoraCardInfoViewModel>
    func buildEmptyViewModel() -> LocalizableResource<SoraCardInfoViewModel>
}

final class SoraCardStateViewModelFactory: SoraCardStateViewModelFactoryProtocol {
    private func buildState(from kycStatus: SCKYCStatusResponse) -> SoraCardState {
        var state: SoraCardState = .none
        switch kycStatus.verificationStatus {
        case .none, .accepted, .pending, .rejected:
            state = .none
        }

        return state
    }

    func buildEmptyViewModel() -> LocalizableResource<SoraCardInfoViewModel> {
        let state: SoraCardState = .none

        return LocalizableResource { locale in
            SoraCardInfoViewModel(state: state, title: state.title(for: locale))
        }
    }

    func buildViewModel(from kycStatus: SCKYCStatusResponse) -> LocalizableResource<SoraCardInfoViewModel> {
        let state = buildState(from: kycStatus)

        return LocalizableResource { locale in
            SoraCardInfoViewModel(state: state, title: state.title(for: locale))
        }
    }
}
