import Foundation
import SSFModels
import RobinHood

enum BlockExplorerType: String, Codable {
    case subquery
    case subsquid
    case giantsquid
    case sora
}

class ChainModel: Codable {
    // swiftlint:disable:next type_name
    typealias Id = String

    let chainId: Id
    let parentId: Id?
    let name: String
    var assets: Set<ChainAssetModel>
    let nodes: Set<ChainNodeModel>
    let addressPrefix: UInt16
    let types: TypesSettings?
    let icon: URL?
    let options: [ChainOptions]?
    let externalApi: ExternalApiSet?
    var selectedNode: ChainNodeModel?
    let customNodes: Set<ChainNodeModel>?
    let iosMinAppVersion: String?
    let xcm: XcmChain?

    init(
        chainId: Id,
        parentId: Id? = nil,
        name: String,
        assets: Set<ChainAssetModel> = [],
        nodes: Set<ChainNodeModel>,
        addressPrefix: UInt16,
        types: TypesSettings? = nil,
        icon: URL?,
        options: [ChainOptions]? = nil,
        externalApi: ExternalApiSet? = nil,
        selectedNode: ChainNodeModel? = nil,
        customNodes: Set<ChainNodeModel>? = nil,
        iosMinAppVersion: String?,
        xcm: XcmChain?
    ) {
        self.chainId = chainId
        self.parentId = parentId
        self.name = name
        self.assets = assets
        self.nodes = nodes
        self.addressPrefix = addressPrefix
        self.types = types
        self.icon = icon
        self.options = options
        self.externalApi = externalApi
        self.selectedNode = selectedNode
        self.customNodes = customNodes
        self.iosMinAppVersion = iosMinAppVersion
        self.xcm = xcm
    }

    var isEthereumBased: Bool {
        options?.contains(.ethereumBased) ?? false
    }

    var isTestnet: Bool {
        options?.contains(.testnet) ?? false
    }

    var isTipRequired: Bool {
        options?.contains(.tipRequired) ?? false
    }

    var isPolkadot: Bool {
        name.lowercased() == "polkadot"
    }

    var isKusama: Bool {
        name.lowercased() == "kusama"
    }

    var isPolkadotOrKusama: Bool {
        isPolkadot || isKusama
    }

    var isWestend: Bool {
        name.lowercased() == "westend"
    }

    var isSora: Bool {
        name.lowercased() == "sora mainnet" || name.lowercased() == "sora test"
    }

    var isEquilibrium: Bool {
        name.lowercased() == "equilibrium"
    }

    var isUtilityFeePayment: Bool {
        isSora || isEquilibrium
    }

    var hasStakingRewardHistory: Bool {
        isPolkadotOrKusama || isWestend
    }

    var hasCrowdloans: Bool {
        options?.contains(.crowdloans) ?? false
    }

    var isSupported: Bool {
        AppVersion.stringValue?.versionLowerThan(iosMinAppVersion) == false
    }

    var hasPolkaswap: Bool {
        options.or([]).contains(.polkaswap)
    }

    func utilityAssets() -> Set<ChainAssetModel> {
        assets.filter { $0.isUtility }
    }

    var erasPerDay: UInt32 {
        let oldChainModel = Chain(rawValue: name)
        switch oldChainModel {
        case .moonbeam: return 4
        case .moonriver, .moonbaseAlpha: return 12
        case .polkadot: return 1
        case .kusama, .westend, .rococo, .soraMain, .soraTest: return 4
        default: return 1 // We have staking only for above chains
        }
    }

    var stakingSettings: ChainStakingSettings? {
        let oldChainModel = Chain(rawValue: name)
        switch oldChainModel {
        case .soraMain:
            return SoraChainStakingSettings()
        default:
            return DefaultRelaychainChainStakingSettings()
        }
    }

    var emptyURL: URL {
        URL(string: "")!
    }

    var accountIdLenght: Int {
        isEthereumBased ? EthereumConstants.accountIdLength : SubstrateConstants.accountIdLength
    }

    var chainAssets: [ChainAsset] {
        assets.map {
            ChainAsset(chain: self, asset: $0.asset)
        }
    }

    func utilityChainAssets() -> [ChainAsset] {
        assets.filter { $0.isUtility }.map {
            ChainAsset(chain: self, asset: $0.asset)
        }
    }

    func replacingSelectedNode(_ node: ChainNodeModel?) -> ChainModel {
        ChainModel(
            chainId: chainId,
            parentId: parentId,
            name: name,
            assets: assets,
            nodes: nodes,
            addressPrefix: addressPrefix,
            types: types,
            icon: icon,
            options: options,
            externalApi: externalApi,
            selectedNode: node,
            customNodes: customNodes,
            iosMinAppVersion: iosMinAppVersion,
            xcm: xcm
        )
    }

    func replacingCustomNodes(_ newCustomNodes: [ChainNodeModel]) -> ChainModel {
        ChainModel(
            chainId: chainId,
            parentId: parentId,
            name: name,
            assets: assets,
            nodes: nodes,
            addressPrefix: addressPrefix,
            types: types,
            icon: icon,
            options: options,
            externalApi: externalApi,
            selectedNode: selectedNode,
            customNodes: Set(newCustomNodes),
            iosMinAppVersion: iosMinAppVersion,
            xcm: xcm
        )
    }

    // MARK: - ChainModelProtocol

    var assetsModels: [any ChainAssetModelProtocol] {
        Array(assets)
    }

    var isRelaychain: Bool {
        parentId == nil
    }

    public lazy var nodesUrls: [URL] = {
        nodes.map { $0.url }
    }()

    public lazy var selectedNodeUrl: URL? = {
        selectedNode?.url
    }()
}

extension ChainModel: Hashable {
    static func == (lhs: ChainModel, rhs: ChainModel) -> Bool {
        lhs.chainId == rhs.chainId
            && lhs.externalApi == rhs.externalApi
            && lhs.assets == rhs.assets
            && lhs.options == rhs.options
            && lhs.types == rhs.types
            && lhs.icon == rhs.icon
            && lhs.name == rhs.name
            && lhs.addressPrefix == rhs.addressPrefix
            && lhs.nodes == rhs.nodes
            && lhs.iosMinAppVersion == rhs.iosMinAppVersion
            && lhs.selectedNode == rhs.selectedNode
            && lhs.xcm == rhs.xcm
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(chainId)
    }
}

extension ChainModel: Identifiable {
    var identifier: String { chainId }
}

enum ChainOptions: String, Codable {
    case ethereumBased
    case testnet
    case crowdloans
    case orml
    case tipRequired
    case poolStaking
    case polkaswap

    case unsupported

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        if let options = ChainOptions(rawValue: rawValue) {
            self = options
        } else {
            self = .unsupported
        }
    }
}

extension ChainModel {
    struct TypesSettings: Codable, Hashable {
        let url: URL
        let overridesCommon: Bool
    }

    struct ExternalResource: Codable, Hashable {
        let type: String
        let url: URL

        static func == (lhs: ExternalResource, rhs: ExternalResource) -> Bool {
            lhs.type == rhs.type && lhs.url == rhs.url
        }
    }

    struct BlockExplorer: Codable, Hashable {
        let type: BlockExplorerType
        let url: URL

        init?(type: String, url: URL) {
            guard let externalApiType = BlockExplorerType(rawValue: type) else {
                return nil
            }

            self.type = externalApiType
            self.url = url
        }

        static func == (lhs: BlockExplorer, rhs: BlockExplorer) -> Bool {
            lhs.type == rhs.type && lhs.url == rhs.url
        }
    }

    enum SubscanType: String, Codable, Hashable {
        case extrinsic
        case account
        case event
        case unknown

        public init(from decoder: Decoder) throws {
            self = try SubscanType(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .unknown
        }
    }

    enum ExternalApiExplorerType: String, Codable {
        case subscan
        case polkascan
        case unknown

        public init(from decoder: Decoder) throws {
            self = try ExternalApiExplorerType(
                rawValue: decoder.singleValueContainer().decode(RawValue.self)
            ) ?? .unknown
        }
    }

    struct ExternalApiExplorer: Codable, Hashable {
        let type: ExternalApiExplorerType
        let types: [SubscanType]
        let url: String
    }

    struct ExternalApiSet: Codable, Hashable {
        let staking: BlockExplorer?
        let history: BlockExplorer?
        let crowdloans: ExternalResource?
        let explorers: [ExternalApiExplorer]?

        static func == (lhs: ExternalApiSet, rhs: ExternalApiSet) -> Bool {
            lhs.staking == rhs.staking && lhs.history == rhs.history && lhs.crowdloans == rhs.crowdloans && lhs.explorers == rhs.explorers
        }
    }

    func polkascanAddressURL(_ address: String) -> URL? {
        guard let explorer = externalApi?.explorers?.first(where: { $0.type == .polkascan }) else {
            return nil
        }

        return explorer.explorerUrl(for: address, type: .account)
    }

    func subscanAddressURL(_ address: String) -> URL? {
        URL(string: "https://\(name.lowercased()).subscan.io/account/\(address)")
    }

    func subscanExtrinsicUrl(_ extrinsicHash: String) -> URL? {
        URL(string: "https://\(name.lowercased()).subscan.io/extrinsic/\(extrinsicHash)")
    }
}

extension ChainModel.ExternalApiExplorer {
    func explorerUrl(for value: String, type: ChainModel.SubscanType) -> URL? {
        let replaceType = url.replacingOccurrences(of: "{type}", with: type.rawValue)
        let replaceValue = replaceType.replacingOccurrences(of: "{value}", with: value)
        return URL(string: replaceValue)
    }
}
