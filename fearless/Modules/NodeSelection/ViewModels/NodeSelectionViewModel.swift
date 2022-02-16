import Foundation

enum NodeSelectionTableState {
    case normal
    case editing

    var reversed: NodeSelectionTableState {
        switch self {
        case .normal:
            return .editing
        case .editing:
            return .normal
        }
    }
}

struct NodeSelectionTableSection {
    let title: String
    let viewModels: [NodeSelectionTableCellViewModel]
}

struct NodeSelectionViewModel {
    let title: String
    let autoSelectEnabled: Bool
    let sections: [NodeSelectionTableSection]
}
