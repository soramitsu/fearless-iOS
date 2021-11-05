import Foundation

// MARK: - CustomCrowdloanFlow

private typealias FlowData = Codable & Equatable

enum CustomCrowdloanFlow {
    case karura
    case bifrost
    case moonbeam(MoonbeamFlowData)
    case astar(AstarFlowData?)

    var name: String {
        switch self {
        case .karura: return "karura"
        case .bifrost: return "bifrost"
        case .moonbeam: return "moonbeam"
        case .astar: return "astar"
        }
    }

    var hasReferralBonus: Bool {
        switch self {
        case .karura, .bifrost, .astar: return true
        default: return false
        }
    }

    var hasEthereumReferral: Bool {
        switch self {
        case .moonbeam: return true
        default: return false
        }
    }
}

extension CustomCrowdloanFlow: Codable {
    private struct NoDataFlow: Codable {
        let name: String
    }

    private struct FlowWithData<T: FlowData>: Codable {
        let name: String
        let data: T
    }

    init(from decoder: Decoder) throws {
        let noDataFlow = try NoDataFlow(from: decoder)
        switch noDataFlow.name {
        case "astar": self = .astar(try? FlowWithData<AstarFlowData>(from: decoder).data)
        case "karura": self = .karura
        case "bifrost": self = .bifrost
        case "moonbeam": self = .moonbeam(try FlowWithData<MoonbeamFlowData>(from: decoder).data)
        default:
            let errorContext = DecodingError.Context(
                codingPath: [], debugDescription: "Unknown flow with name: \(noDataFlow.name)", underlyingError: nil
            )
            throw DecodingError.dataCorrupted(errorContext)
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case let .astar(data): try FlowWithData(name: "astar", data: data).encode(to: encoder)
        case .karura: try NoDataFlow(name: "karura").encode(to: encoder)
        case .bifrost: try NoDataFlow(name: "bifrost").encode(to: encoder)
        case let .moonbeam(data): try FlowWithData(name: "moonbeam", data: data).encode(to: encoder)
        }
    }
}

extension CustomCrowdloanFlow: Equatable {
    static func == (lhs: CustomCrowdloanFlow, rhs: CustomCrowdloanFlow) -> Bool {
        switch (lhs, rhs) {
        case let (.astar(lhsData), .astar(rhsData)):
            return lhsData == rhsData
        case (.karura, .karura):
            return true
        case (.bifrost, .bifrost):
            return true
        case let (.moonbeam(lhsData), .moonbeam(rhsData)):
            return lhsData == rhsData
        default:
            return false
        }
    }
}

// MARK: - Moonbeam

struct MoonbeamFlowData: FlowData {
    let prodApiUrl: String
    let devApiUrl: String
    let termsUrl: String
    let devApiKey: String
    let prodApiKey: String
}

struct AstarFlowData: FlowData {
    let fearlessReferral: String
}
