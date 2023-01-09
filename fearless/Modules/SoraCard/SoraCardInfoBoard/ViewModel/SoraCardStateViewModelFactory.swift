import Foundation
import SoraFoundation

protocol SoraCardStateViewModelFactoryProtocol {
    func buildViewModel(from kycStatus: SCKYCStatusResponse) -> LocalizableResource<SoraCardInfoViewModel>
    func buildEmptyViewModel() -> LocalizableResource<SoraCardInfoViewModel>
}

final class SoraCardStateViewModelFactory: SoraCardStateViewModelFactoryProtocol {
    private func buildState(from _: SCKYCStatusResponse) -> SoraCardState {
        .none
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
