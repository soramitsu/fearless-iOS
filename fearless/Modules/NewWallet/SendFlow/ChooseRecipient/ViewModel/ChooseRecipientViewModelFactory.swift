import CommonWallet
import FearlessUtils

protocol ChooseRecipientViewModelFactoryProtocol {
    func buildChooseRecipientViewModel(address: String, isValid: Bool) -> ChooseRecipientViewModel
    func buildChooseRecipientTableViewModel(searchResult: Result<[SearchData]?, Error>) -> ChooseRecipientTableViewModel
}

final class ChooseRecipientViewModelFactory: ChooseRecipientViewModelFactoryProtocol {
    private let iconGenerator: IconGenerating

    init(iconGenerator: IconGenerating) {
        self.iconGenerator = iconGenerator
    }

    func buildChooseRecipientViewModel(address: String, isValid: Bool) -> ChooseRecipientViewModel {
        ChooseRecipientViewModel(
            address: address,
            icon: try? iconGenerator.generateFromAddress(address),
            isValid: isValid
        )
    }

    func buildChooseRecipientTableViewModel(
        searchResult: Result<[SearchData]?, Error>
    ) -> ChooseRecipientTableViewModel {
        var cellModels: [SearchPeopleTableCellViewModel] = []
        if case let .success(results) = searchResult {
            cellModels = results?.compactMap { buildSearchPeopleCellViewModel(searchData: $0) } ?? []
        }
        return ChooseRecipientTableViewModel(results: cellModels)
    }

    func buildSearchPeopleCellViewModel(searchData: SearchData) -> SearchPeopleTableCellViewModel {
        SearchPeopleTableCellViewModel(
            address: searchData.firstName,
            icon: try? iconGenerator.generateFromAddress(searchData.firstName)
        )
    }
}
