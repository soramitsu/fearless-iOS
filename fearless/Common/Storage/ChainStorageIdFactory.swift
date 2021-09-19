import Foundation
import FearlessUtils

protocol ChainStorageIdFactoryProtocol {
    func createIdentifier(for key: Data) -> String
}

@available(*, deprecated, message: "Use LocalStorageKeyFactory instead")
final class ChainStorageIdFactory: ChainStorageIdFactoryProtocol {
    let genesisData: Data

    init(chain: Chain) throws {
        genesisData = try Data(hexString: chain.genesisHash)
    }

    func createIdentifier(for key: Data) -> String {
        let concatData = genesisData + key
        let localKey = (try? StorageHasher.twox256.hash(data: concatData)) ?? (genesisData + key)
        return localKey.toHex()
    }
}
