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

struct NodeSelectionViewModel {
    let title: String
    let autoSelectEnabled: Bool
    let viewModels: [NodeSelectionTableCellViewModel]
}
