import Foundation

public struct SignedBlock: Decodable {
    public let block: Block
    public let justification: Data?
}

public struct Block: Decodable {
    public struct Digest: Decodable {
        public let logs: [String]
    }

    public struct Header: Decodable {
        public let digest: Digest
        public let extrinsicsRoot: String
        public let number: String
        public let stateRoot: String
        public let parentHash: String
    }

    public let extrinsics: [String]
    public let header: Header
}
