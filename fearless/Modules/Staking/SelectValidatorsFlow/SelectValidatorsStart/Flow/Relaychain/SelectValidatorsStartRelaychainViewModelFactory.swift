import Foundation

final class SelectValidatorsStartRelaychainViewModelFactory: SelectValidatorsStartViewModelFactoryProtocol {
    func buildViewModel(viewModelState: SelectValidatorsStartViewModelState) -> SelectValidatorsStartViewModel? {
        guard let relaychainViewModelState = viewModelState as? SelectValidatorsStartRelaychainViewModelState else {
            return nil
        }

        return SelectValidatorsStartViewModel(
            selectedCount: relaychainViewModelState.electedValidators?.count ?? 0,
            totalCount: relaychainViewModelState.maxNominations ?? 0
        )
    }
}
