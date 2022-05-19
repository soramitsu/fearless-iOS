import Foundation

final class SelectValidatorsStartParachainViewModelFactory: SelectValidatorsStartViewModelFactoryProtocol {
    func buildViewModel(viewModelState: SelectValidatorsStartViewModelState) -> SelectValidatorsStartViewModel? {
        guard let parachainViewModelState = viewModelState as? SelectValidatorsStartParachainViewModelState else {
            return nil
        }

        return SelectValidatorsStartViewModel(
            selectedCount: parachainViewModelState.selectedCandidates?.count ?? 0,
            totalCount: parachainViewModelState.maxDelegations ?? 0
        )
    }
}
