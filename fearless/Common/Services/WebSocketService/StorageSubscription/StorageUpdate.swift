import Foundation

struct StorageUpdate: Decodable {
    enum CodingKeys: String, CodingKey {
        case blockHash = "block"
        case changes
    }

    let blockHash: String?
    let changes: [[String?]]?
}

struct StorageUpdateData {
    struct StorageUpdateChangeData {
        let key: Data
        let value: Data?

        init?(change: [String?]) {
            guard change.count == 2 else {
                return nil
            }

            guard let keyString = change[0], let keyData = try? Data(hexStringSSF: keyString) else {
                return nil
            }

            key = keyData

            if let valueString = change[1], let valueData = try? Data(hexStringSSF: valueString) {
                value = valueData
            } else {
                value = nil
            }
        }
    }

    let blockHash: Data?
    let changes: [StorageUpdateChangeData]

    init(update: StorageUpdate) {
        if
            let blockHashString = update.blockHash,
            let blockHashData = try? Data(hexStringSSF: blockHashString) {
            blockHash = blockHashData
        } else {
            blockHash = nil
        }

        changes = update.changes?.compactMap { StorageUpdateChangeData(change: $0) } ?? []
    }
}
