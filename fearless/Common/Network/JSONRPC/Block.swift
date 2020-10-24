import Foundation

struct SignedBlock: Decodable {
    let block: Block
    let justification: Data?
}

struct Block: Decodable {
    struct Digest: Decodable {
        let logs: [String]
    }

    struct Header: Decodable {
        let digest: Digest
        let extrinsicsRoot: String
        let number: String
        let stateRoot: String
        let parentHash: String
    }

    let extrinsics: [String]
    let header: Header
}
