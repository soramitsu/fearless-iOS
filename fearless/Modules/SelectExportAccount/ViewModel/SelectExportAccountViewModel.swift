import Foundation

struct SelectExportAccountViewModel {
    let title: String
    let metaAccountName: String
    let metaAccountBalance: String?
    let metaAccountBalanceString: String?
    var nativeAccountCellViewModel: SelectExportAccountCellViewModel?
    var addedAccountsCellViewModels: [SelectExportAccountCellViewModel]?
}
