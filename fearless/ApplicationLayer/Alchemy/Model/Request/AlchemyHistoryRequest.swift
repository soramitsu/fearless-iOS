import Foundation

enum AlchemyHistoryBlockFilter: Encodable {
    case hex(value: String)
    case int(value: UInt64)
    case latest
    case indexed

    var value: String {
        switch self {
        case let .hex(value):
            return value
        case let .int(value):
            return "\(value)"
        case .latest:
            return "latest"
        case .indexed:
            return "indexed"
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case let .hex(value):
            try container.encode(value)
        case let .int(value):
            try container.encode(value)
        case .latest:
            try container.encode(value)
        case .indexed:
            try container.encode(value)
        }
    }
}

struct AlchemyHistoryRequest: Encodable {
    let fromBlock: AlchemyHistoryBlockFilter?
    let toBlock: AlchemyHistoryBlockFilter?
    let category: [AlchemyTokenCategory]
    let withMetadata: Bool?
    let excludeZeroValue: Bool?
    let maxCount: String?
    let fromAddress: String?
    let toAddress: String?
    let order: AlchemySortOrder?

    init(fromAddress: String, category: [AlchemyTokenCategory]) {
        self.init(category: category, fromAddress: fromAddress, toAddress: nil)
    }

    init(toAddress: String, category: [AlchemyTokenCategory]) {
        self.init(category: category, fromAddress: nil, toAddress: toAddress)
    }

    init(
        fromBlock: AlchemyHistoryBlockFilter? = .hex(value: "0x0"),
        toBlock: AlchemyHistoryBlockFilter? = .latest,
        category: [AlchemyTokenCategory],
        withMetadata: Bool = true,
        excludeZeroValue: Bool = true,
        maxCount: String? = nil,
        fromAddress: String?,
        toAddress: String?,
        order: AlchemySortOrder = .desc
    ) {
        self.fromBlock = fromBlock
        self.toBlock = toBlock
        self.category = category
        self.withMetadata = withMetadata
        self.excludeZeroValue = excludeZeroValue
        self.maxCount = maxCount
        self.fromAddress = fromAddress
        self.toAddress = toAddress
        self.order = order
    }
}
