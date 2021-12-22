import Foundation
import CommonWallet
import FearlessUtils

protocol SearchPeopleViewModelFactoryProtocol {
    func buildSearchPeopleViewModel(results: [SearchData]) -> SearchPeopleViewModel
}

class SearchPeopleViewModelFactory: SearchPeopleViewModelFactoryProtocol {
    private let iconGenerator: IconGenerating

    init(iconGenerator: IconGenerating) {
        self.iconGenerator = iconGenerator
    }

    func buildSearchPeopleViewModel(results: [SearchData]) -> SearchPeopleViewModel {
        let cellModels = results.compactMap { buildSearchPeopleCellViewModel(searchData: $0) }

        return SearchPeopleViewModel(results: cellModels)
    }

    func buildSearchPeopleCellViewModel(searchData: SearchData) -> SearchPeopleTableCellViewModel {
        SearchPeopleTableCellViewModel(
            address: searchData.firstName,
            icon: try? iconGenerator.generateFromAddress(searchData.firstName)
        )
    }
}
