import Foundation

// MARK: - CustomCrowdloanFlow

private typealias FlowData = Codable & Equatable

enum CustomCrowdloanFlow {
    case unsupported(String)

    case karura
    case bifrost
    case moonbeam(MoonbeamFlowData)
    case astar(AstarFlowData)
    case moonbeamMemoFix(String)

    var name: String {
        switch self {
        case .karura: return "karura"
        case .bifrost: return "bifrost"
        case .moonbeam: return "moonbeam"
        case .astar: return "astar"
        case .moonbeamMemoFix: return ""

        case let .unsupported(name): return name
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
        case .moonbeam, .moonbeamMemoFix: return true
        default: return false
        }
    }

    var needsContribute: Bool {
        switch self {
        case .moonbeamMemoFix: return false
        default: return true
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
        func decodeFlowData<T: FlowData>(from decoder: Decoder, or default: T) -> T {
            guard let data = try? FlowWithData<T>(from: decoder).data else {
                return `default`
            }
            return data
        }

        let noDataFlow = try NoDataFlow(from: decoder)
        switch noDataFlow.name {
        case "astar": self = .astar(decodeFlowData(from: decoder, or: AstarFlowData.default))
        case "karura": self = .karura
        case "bifrost": self = .bifrost
        case "moonbeam": self = .moonbeam(decodeFlowData(from: decoder, or: MoonbeamFlowData.default))

        default: self = .unsupported(noDataFlow.name)
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case let .unsupported(name): try NoDataFlow(name: name).encode(to: encoder)

        case .moonbeamMemoFix: try NoDataFlow(name: name).encode(to: encoder)
        case .karura: try NoDataFlow(name: "karura").encode(to: encoder)
        case .bifrost: try NoDataFlow(name: "bifrost").encode(to: encoder)
        case let .moonbeam(data): try FlowWithData(name: "moonbeam", data: data).encode(to: encoder)
        case let .astar(data): try FlowWithData(name: "astar", data: data).encode(to: encoder)
        }
    }
}

extension CustomCrowdloanFlow: Equatable {
    static func == (lhs: CustomCrowdloanFlow, rhs: CustomCrowdloanFlow) -> Bool {
        switch (lhs, rhs) {
        case (.moonbeamMemoFix, .moonbeamMemoFix):
            return true
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
    private enum CodingKeys: String, CodingKey {
        case prodApiUrl
        case devApiUrl
        case termsUrl
        case devApiKey
        case prodApiKey
    }

    let prodApiUrl: String
    let devApiUrl: String
    let termsUrl: String
    let devApiKey: String
    let prodApiKey: String

    init(
        prodApiUrl: String,
        devApiUrl: String,
        termsUrl: String,
        devApiKey: String,
        prodApiKey: String
    ) {
        self.prodApiUrl = prodApiUrl
        self.devApiUrl = devApiUrl
        self.termsUrl = termsUrl
        self.devApiKey = devApiKey
        self.prodApiKey = prodApiKey
    }

    init(from decoder: Decoder) throws {
        let fallback = Self.default
        let container = try decoder.container(keyedBy: CodingKeys.self)

        prodApiUrl = try container.decodeIfPresent(String.self, forKey: .prodApiUrl) ?? fallback.prodApiUrl
        devApiUrl = try container.decodeIfPresent(String.self, forKey: .devApiUrl) ?? fallback.devApiUrl
        termsUrl = try container.decodeIfPresent(String.self, forKey: .termsUrl) ?? fallback.termsUrl
        devApiKey = try container.decodeIfPresent(String.self, forKey: .devApiKey) ?? fallback.devApiKey
        prodApiKey = try container.decodeIfPresent(String.self, forKey: .prodApiKey) ?? fallback.prodApiKey
    }

    static var `default`: Self {
        .init(
            prodApiUrl: "https://yy9252r9jh.api.purestake.io",
            devApiUrl: "https://wallet-test.api.purestake.xyz",
            termsUrl: "https://raw.githubusercontent.com/moonbeam-foundation/crowdloan-self-attestation/main/moonbeam/README.md",
            devApiKey: MoonbeamCrowdloanCIKeys.devApiKey,
            prodApiKey: MoonbeamCrowdloanCIKeys.prodApiKey
        )
    }
}

// MARK: - Astar

struct AstarFlowData: FlowData {
    let fearlessReferral: String?
    let bonusRate: Decimal?
    let referralRate: Decimal?

    static var `default`: Self {
        .init(
            fearlessReferral: "14Q22opa2mR3SsCZkHbDoSkN6iQpJPk6dDYwaQibufh41g3k",
            bonusRate: 0,
            referralRate: 0.01
        )
    }
}
