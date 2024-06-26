import Foundation
import SSFUtils

extension StorageUpdateData {
    func decodeUpdatedData<V: ScaleDecodable>(for key: String) throws -> V? {
        let keyData = try Data(hexStringSSF: key)

        guard let value = changes.first(where: { $0.key == keyData })?.value else {
            return nil
        }

        let scaleDecoder = try ScaleDecoder(data: value)

        return try V(scaleDecoder: scaleDecoder)
    }
}
