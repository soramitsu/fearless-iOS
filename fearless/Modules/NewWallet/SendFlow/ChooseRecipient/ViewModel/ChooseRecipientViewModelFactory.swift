import CommonWallet
import FearlessUtils

protocol ChooseRecipientViewModelFactoryProtocol {
    func buildChooseRecipientViewModel(address: String, isValid: Bool) -> ChooseRecipientViewModel
    func buildChooseRecipientTableViewModel(results: [SearchData]) -> ChooseRecipientTableViewModel
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

    func buildChooseRecipientTableViewModel(results: [SearchData]) -> ChooseRecipientTableViewModel {
        let cellModels = results.compactMap { buildSearchPeopleCellViewModel(searchData: $0) }

        return ChooseRecipientTableViewModel(results: cellModels)
    }

    func buildSearchPeopleCellViewModel(searchData: SearchData) -> SearchPeopleTableCellViewModel {
        SearchPeopleTableCellViewModel(
            address: searchData.firstName,
            icon: try? iconGenerator.generateFromAddress(searchData.firstName)
        )
    }
}
