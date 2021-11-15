import Foundation

// MARK: - CustomCrowdloanFlow

private typealias FlowData = Codable & Equatable

enum CustomCrowdloanFlow {
    case unsupported(String)

    case karura
    case bifrost
    case moonbeam(MoonbeamFlowData)
    case acala(AcalaFlowData)
    case astar(AstarFlowData)
    case moonbeamMemoFix(String)

    var name: String {
        switch self {
        case .karura: return "karura"
        case .bifrost: return "bifrost"
        case .moonbeam: return "moonbeam"
        case .astar: return "astar"
        case .acala: return "acala"
        case .moonbeamMemoFix: return ""

        case let .unsupported(name): return name
        }
    }

    var hasReferralBonus: Bool {
        switch self {
        case .karura, .bifrost, .astar, .acala: return true
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
        case "acala": self = .acala(decodeFlowData(from: decoder, or: AcalaFlowData.default))
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
        case let .acala(data): try FlowWithData(name: "acala", data: data).encode(to: encoder)
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
        case let (.acala(lhsData), .acala(rhsData)):
            return rhsData == lhsData
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

    static var `default`: Self {
        .init(
            prodApiUrl: "https://yy9252r9jh.api.purestake.io",
            devApiUrl: "https://wallet-test.api.purestake.xyz",
            termsUrl: "https://raw.githubusercontent.com/moonbeam-foundation/crowdloan-self-attestation/main/moonbeam/README.md",
            devApiKey: "JbykAAZTUa8MTggXlb4k03yAW9Ur2DFU1T0rm2Th",
            prodApiKey: "oueZPaKtwAEAooqpdafr33i6yqPgU804E06CqeGb"
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

// MARK: - Acala

struct AcalaFlowData: FlowData {
    let prodApiUrl: String
    let devApiUrl: String
    let prodApiKey: String
    let devApiKey: String
    let bonusUrl: String?
    let termsUrl: String?
    let crowdloanInfoUrl: String?
    let fearlessReferral: String?

    static var `default`: Self {
        .init(
            prodApiUrl: "https://crowdloan.aca-api.network",
            devApiUrl: "https://crowdloan.aca-dev.network",
            prodApiKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1lIjoiZmVhcmVsZXNzd2FsbGV0IiwiaWF0IjoxNjM0Nzg2MDc3fQ.zwz3BSD68AKjo1BySkzrh7SfzO8yF-8YBhgiKZyE5lQ",
            devApiKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1lIjoiZmVhcmVsZXNzd2FsbGV0IiwiaWF0IjoxNjM0MDg1OTg0fQ.3joSiklSRDNrCtVMQc6ReRnEgtp65QOzRt8IPA4bMtw",
            bonusUrl: "https://wiki.acala.network/acala/acala-crowdloan/crowdloan-rewards",
            termsUrl: "https://acala.network/acala/terms",
            crowdloanInfoUrl: "https://wiki.acala.network/acala/acala-crowdloan",
            fearlessReferral: "0x9642d0db9f3b301b44df74b63b0b930011e3f52154c5ca24b4dc67b3c7322f15"
        )
    }
}
