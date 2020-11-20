import Foundation

protocol ChainStorageIdFactoryProtocol {
    func createIdentifier(for key: Data) throws -> String
}

final class ChainStorageIdFactory: ChainStorageIdFactoryProtocol {
    let genesisData: Data

    init(chain: Chain) throws {
        genesisData = try Data(hexString: chain.genesisHash)
    }

    func createIdentifier(for key: Data)  throws -> String {
        try (key + genesisData).blake2b32().toHex(includePrefix: true)
    }
}
