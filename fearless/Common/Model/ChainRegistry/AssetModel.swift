import Foundation
import RobinHood

struct AssetModel: Equatable, Codable, Hashable {
    // swiftlint:disable:next type_name
    typealias Id = String
    typealias PriceId = String

    let id: String
    let chainId: String
    let precision: UInt16
    let icon: URL?
    let priceId: PriceId?
    let price: Decimal?

    var name: String {
        id.uppercased()
    }

    func sortKey(accountId: AccountId) -> String {
        id + chainId + accountId.toHex()
    }

    static func == (lhs: AssetModel, rhs: AssetModel) -> Bool {
        lhs.id == rhs.id &&
            lhs.chainId == rhs.chainId &&
            lhs.precision == rhs.precision &&
            lhs.icon == rhs.icon &&
            lhs.priceId == rhs.priceId
    }

    func replacingPrice(_ newPrice: Decimal?) -> AssetModel {
        AssetModel(
            id: id,
            chainId: chainId,
            precision: precision,
            icon: icon,
            priceId: priceId,
            price: newPrice
        )
    }
}

extension AssetModel: Identifiable {
    var identifier: String { id }
}
