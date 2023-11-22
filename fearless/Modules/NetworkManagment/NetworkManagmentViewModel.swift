import Foundation

struct NetworkManagmentCellViewModel {
    let icon: ImageViewModelProtocol?
    let name: String
    let isSelected: Bool
    let isFavourite: Bool?
    let networkSelectType: NetworkManagmentFilter
}

struct NetworkManagmentViewModel {
    let activeFilter: NetworkManagmentFilter
    let cells: [NetworkManagmentCellViewModel]
}
