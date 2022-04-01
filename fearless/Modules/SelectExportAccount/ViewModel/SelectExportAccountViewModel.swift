import Foundation

struct SelectExportAccountViewModel {
    let title: String
    let metaAccountName: String
    let metaAccountBalanceString: String?
    let nativeAccountCellViewModel: SelectExportAccountCellViewModel?
    let addedAccountsCellViewModels: [SelectExportAccountCellViewModel]?
}
