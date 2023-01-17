import Foundation
import SoraFoundation

protocol SoraCardStateViewModelFactoryProtocol {
    func buildViewModel(from kycStatus: SCKYCStatusResponse?) -> LocalizableResource<SoraCardInfoViewModel>
    func buildEmptyViewModel() -> LocalizableResource<SoraCardInfoViewModel>
}

final class SoraCardStateViewModelFactory: SoraCardStateViewModelFactoryProtocol {
    private func buildState(from verificationStatus: SCVerificationStatus) -> SoraCardState {
        switch verificationStatus {
        case .none:
            return .none
        case .pending:
            return .verification
        case .accepted:
            return .onway
        case .rejected:
            return .verificationFailed
        }
    }

    private func buildState(from kycStatus: SCKYCStatusResponse?) -> SoraCardState {
        guard let kycStatus = kycStatus else {
            return .none
        }

        switch kycStatus.kycStatus {
        case .started:
            return .kycStarted
        case .rejected, .failed:
            return .rejected
        case .completed, .successful:
            return buildState(from: kycStatus.verificationStatus)
        }
    }

    func buildEmptyViewModel() -> LocalizableResource<SoraCardInfoViewModel> {
        let state: SoraCardState = .none

        return LocalizableResource { locale in
            SoraCardInfoViewModel(state: state, title: state.title(for: locale))
        }
    }

    func buildViewModel(from kycStatus: SCKYCStatusResponse?) -> LocalizableResource<SoraCardInfoViewModel> {
        let state = buildState(from: kycStatus)

        return LocalizableResource { locale in
            SoraCardInfoViewModel(state: state, title: state.title(for: locale))
        }
    }
}
