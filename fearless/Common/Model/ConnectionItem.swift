import Foundation
import IrohaCrypto

struct ConnectionItem: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case title
        case url
        case type
    }

    let title: String
    let url: URL
    let type: SNAddressType
}

extension ConnectionItem {
    init(managedConnectionItem: ManagedConnectionItem) {
        title = managedConnectionItem.title
        url = managedConnectionItem.url
        type = managedConnectionItem.type
    }

    func replacingTitle(_ newTitle: String) -> ConnectionItem {
        ConnectionItem(title: newTitle,
                       url: url,
                       type: type)
    }
}
