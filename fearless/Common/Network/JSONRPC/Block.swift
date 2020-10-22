import Foundation

struct Block: Decodable {
    struct Digest: Decodable {
        let logs: [String]
    }

    struct Header: Decodable {
        let digest: Digest
        let extrinsicRoot: String
        let number: String
        let stateRoot: String
        let parentHash: String
    }

    let extrinsics: [String]
    let header: Header
}
