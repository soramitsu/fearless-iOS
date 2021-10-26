import Foundation

// MARK: - CustomCrowdloanFlow

enum CustomCrowdloanFlow: Codable {
    private struct NoDataFlow: Codable {
        let name: String
    }

    private struct FlowWithData<T: Codable>: Codable {
        let name: String
        let data: T
    }

    case karura
    case bifrost
    case moonbeam(MoonbeamFlowData)

    init(from decoder: Decoder) throws {
        let noDataFlow = try NoDataFlow(from: decoder)
        switch noDataFlow.name {
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
        case .karura: try NoDataFlow(name: "karura").encode(to: encoder)
        case .bifrost: try NoDataFlow(name: "bifrost").encode(to: encoder)
        case let .moonbeam(data): try FlowWithData(name: "moonbeam", data: data).encode(to: encoder)
        }
    }
}

// MARK: - Moonbeam

struct MoonbeamFlowData: Codable {
    let prodApiUrl: String
    let devApiUrl: String
}
