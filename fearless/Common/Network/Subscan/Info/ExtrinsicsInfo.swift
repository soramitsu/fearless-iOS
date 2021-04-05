import Foundation

struct ExtrinsicsInfo {
    let row: Int
    let page: Int
    let address: String?
    let moduleName: String?
    let callName: String?
}

extension ExtrinsicsInfo: Encodable {
    private enum CodingKeys: String, CodingKey {
        case row
        case page
        case address
        case moduleName = "module"
        case callName = "call"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(row, forKey: .row)
        try container.encode(page, forKey: .page)
        try container.encodeIfPresent(address, forKey: .address)
        try container.encodeIfPresent(callName, forKey: .callName)
    }
}
