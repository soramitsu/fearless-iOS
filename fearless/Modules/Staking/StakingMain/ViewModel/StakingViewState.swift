import Foundation
import SoraFoundation

enum StakingViewState {
    case undefined
    case nominator(viewModel: LocalizableResource<NominationViewModelProtocol>)
    case validator
    case bonded(viewModel: LocalizableResource<StakingEstimationViewModelProtocol>)
    case noStash(viewModel: LocalizableResource<StakingEstimationViewModelProtocol>)
}
