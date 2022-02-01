import Foundation
import RobinHood

struct ManagedMetaAccountModel: Equatable {
    static let noOrder: UInt32 = 0

    let info: MetaAccountModel
    let isSelected: Bool
    let order: UInt32

    init(info: MetaAccountModel, isSelected: Bool = false, order: UInt32 = Self.noOrder) {
        self.info = info
        self.isSelected = isSelected
        self.order = order
    }
}

extension ManagedMetaAccountModel: Identifiable {
    var identifier: String { info.metaId }
}

extension ManagedMetaAccountModel {
    func replacingOrder(_ newOrder: UInt32) -> ManagedMetaAccountModel {
        ManagedMetaAccountModel(info: info, isSelected: isSelected, order: newOrder)
    }
}
