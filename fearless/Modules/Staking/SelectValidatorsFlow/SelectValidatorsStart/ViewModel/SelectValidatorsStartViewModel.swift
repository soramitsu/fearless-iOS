import Foundation

protocol SelectValidatorsStartViewModelProtocol {
    var selectedCount: Int { get }
    var totalCount: Int { get }
}

struct SelectValidatorsStartViewModel: SelectValidatorsStartViewModelProtocol {
    let selectedCount: Int
    let totalCount: Int
}
