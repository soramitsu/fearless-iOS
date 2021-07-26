import Foundation

struct SelectValidatorsStartViewModel: Equatable {
    enum Phase {
        case setup
        case update
    }

    let phase: Phase
    let selectedCount: Int
    let totalCount: Int
}
