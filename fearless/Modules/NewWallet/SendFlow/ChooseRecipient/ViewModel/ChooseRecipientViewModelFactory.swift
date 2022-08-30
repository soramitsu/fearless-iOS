import CommonWallet
import FearlessUtils

protocol ChooseRecipientViewModelFactoryProtocol {
    func buildChooseRecipientViewModel(results: [SearchData]) -> ChooseRecipientViewModel
}

final class ChooseRecipientViewModelFactory: ChooseRecipientViewModelFactoryProtocol {
    private let iconGenerator: IconGenerating

    init(iconGenerator: IconGenerating) {
        self.iconGenerator = iconGenerator
    }

    func buildChooseRecipientViewModel(results: [SearchData]) -> ChooseRecipientViewModel {
        let cellModels = results.compactMap { buildSearchPeopleCellViewModel(searchData: $0) }

        return ChooseRecipientViewModel(results: cellModels)
    }

    func buildSearchPeopleCellViewModel(searchData: SearchData) -> SearchPeopleTableCellViewModel {
        SearchPeopleTableCellViewModel(
            address: searchData.firstName,
            icon: try? iconGenerator.generateFromAddress(searchData.firstName)
        )
    }
}
