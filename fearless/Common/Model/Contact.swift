import RobinHood

struct Contact: Identifiable, Codable, Equatable {
    var identifier: String {
        address
    }

    let name: String
    let address: String
    let chainId: String

    enum CodingKeys: String, CodingKey {
        case name
        case address
        case chainId
    }
}
