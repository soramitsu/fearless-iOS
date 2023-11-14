import Foundation

struct NetworkManagmentCellViewModel {
    let icon: ImageViewModelProtocol?
    let name: String
    let isSelected: Bool
    let isFavourite: Bool?
    let networkSelectType: NetworkManagmentSelect
}

struct NetworkManagmentViewModel {
    let activeFilter: NetworkManagmentSelect
    let cells: [NetworkManagmentCellViewModel]
}
