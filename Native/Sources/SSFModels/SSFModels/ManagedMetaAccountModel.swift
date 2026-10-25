import Foundation
import RobinHood

public struct ManagedMetaAccountModel: Equatable, Identifiable {
    public static let noOrder: UInt32 = 0

    public let info: MetaAccountModel
    public let isSelected: Bool
    public let order: UInt32
    public var balance: String?

    public init(
        info: MetaAccountModel,
        isSelected: Bool = false,
        order: UInt32 = Self.noOrder,
        balance: String? = nil
    ) {
        self.info = info
        self.isSelected = isSelected
        self.order = order
        self.balance = balance
    }
}

public extension ManagedMetaAccountModel {
    var identifier: String { info.metaId }
}

extension ManagedMetaAccountModel {
    func replacingOrder(_ newOrder: UInt32) -> ManagedMetaAccountModel {
        ManagedMetaAccountModel(info: info, isSelected: isSelected, order: newOrder)
    }
}
