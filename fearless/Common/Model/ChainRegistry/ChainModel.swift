import Foundation
import RobinHood

class ChainModel: Codable {
    // swiftlint:disable:next type_name
    typealias Id = String

    struct TypesSettings: Codable, Hashable {
        let url: URL
        let overridesCommon: Bool
    }

    struct ExternalApi: Codable, Hashable {
        let type: String
        let url: URL
    }

    struct ExternalApiSet: Codable, Hashable {
        let staking: ExternalApi?
        let history: ExternalApi?
        let crowdloans: ExternalApi?

        // For some reason, when ExternalApi fails to unwrap, even though it's optional, whole ChainModel fails, provide required inits

        init(staking: ExternalApi?, history: ExternalApi?, crowdloans: ExternalApi?) {
            self.staking = staking
            self.history = history
            self.crowdloans = crowdloans
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: ExternalApiSet.CodingKeys.self)
            staking = try? container.decode(ExternalApi.self, forKey: .staking)
            history = try? container.decode(ExternalApi.self, forKey: .history)
            crowdloans = try? container.decode(ExternalApi.self, forKey: .crowdloans)
        }
    }

    enum TypesUsage {
        case onlyCommon
        case both
        case onlyOwn
    }

    let chainId: Id
    let parentId: Id?
    let name: String
    var assets: Set<ChainAssetModel>
    let nodes: Set<ChainNodeModel>
    let addressPrefix: UInt16
    let types: TypesSettings?
    let icon: URL?
    let options: [ChainOptions]
    let externalApi: ExternalApiSet?
    let selectedNode: ChainNodeModel?
    let customNodes: Set<ChainNodeModel>
    let iosMinAppVersion: String?

    enum DecodingError: Error {
        case missingAssets
        case missingNodes
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Rules for app stable work
        // 1. Optional unwrap with "try?"
        // 2. Strict fields unwrap with "try"
        // 3. Sets/URLs unwrap with decodeOptionalArray with empty set
        // 4. Throw error if something is wrong with "DecodingError", so ignore chain in app

        chainId = try container.decode(Id.self, forKey: .chainId)
        parentId = try? container.decode(Id.self, forKey: .parentId)
        name = try container.decode(String.self, forKey: .name)
        assets = container.decodeOptionalArray([ChainAssetModel].self, forKey: .assets).toSet()
        nodes = container.decodeOptionalArray([ChainNodeModel].self, forKey: .nodes).toSet()
        addressPrefix = try container.decode(UInt16.self, forKey: .addressPrefix)
        types = try? container.decode(TypesSettings.self, forKey: .types)
        icon = try? container.decode(URL.self, forKey: .icon)
        options = container.decodeOptionalArray([ChainOptions].self, forKey: .options)
        externalApi = try? container.decode(ExternalApiSet.self, forKey: .externalApi)
        selectedNode = try? container.decode(ChainNodeModel.self, forKey: .selectedNode)
        customNodes = container.decodeOptionalArray([ChainNodeModel].self, forKey: .customNodes).toSet()
        iosMinAppVersion = try? container.decode(String.self, forKey: .iosMinAppVersion)

        if assets.isEmpty {
            throw DecodingError.missingAssets
        }

        if nodes.isEmpty {
            throw DecodingError.missingNodes
        }
    }

    init(
        chainId: Id,
        parentId: Id? = nil,
        name: String,
        assets: Set<ChainAssetModel> = [],
        nodes: Set<ChainNodeModel>,
        addressPrefix: UInt16,
        types: TypesSettings? = nil,
        icon: URL?,
        options: [ChainOptions] = [],
        externalApi: ExternalApiSet? = nil,
        selectedNode: ChainNodeModel? = nil,
        customNodes: Set<ChainNodeModel> = [],
        iosMinAppVersion: String?
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
    }

    var isEthereumBased: Bool {
        options.contains(.ethereumBased)
    }

    var isTestnet: Bool {
        options.contains(.testnet)
    }

    var isOrml: Bool {
        options.contains(.orml)
    }

    var isTipRequired: Bool {
        options.contains(.tipRequired)
    }

    var isPolkadotOrKusama: Bool {
        name.lowercased() == "polkadot" || name.lowercased() == "kusama"
    }

    var isWestend: Bool {
        name.lowercased() == "westend"
    }

    var hasStakingRewardHistory: Bool {
        isPolkadotOrKusama || isWestend
    }

    var hasCrowdloans: Bool {
        options.contains(.crowdloans)
    }

    var isSupported: Bool {
        AppVersion.stringValue?.versionLowerThan(iosMinAppVersion) == false
    }

    func utilityAssets() -> Set<ChainAssetModel> {
        assets.filter { $0.isUtility }
    }

    var typesUsage: TypesUsage {
        if let types = types {
            return types.overridesCommon ? .onlyOwn : .both
        } else {
            return .onlyCommon
        }
    }

    var tokenSymbol: TokenSymbol? {
        guard isOrml else {
            return nil
        }

        guard let assetName = assets.first?.assetId else {
            return nil
        }

        return TokenSymbol(rawValue: assetName)
    }

    var currencyId: CurrencyId? {
        CurrencyId.token(symbol: tokenSymbol)
    }

    var erasPerDay: UInt32 {
        let oldChainModel = Chain(rawValue: name)
        switch oldChainModel {
        case .polkadot: return 1
        case .kusama, .westend, .rococo: return 4
        default: return 1 // We have staking only for above chains
        }
    }

    var emptyURL: URL {
        URL(string: "")!
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
            iosMinAppVersion: iosMinAppVersion
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
            iosMinAppVersion: iosMinAppVersion
        )
    }
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
            && lhs.selectedNode == rhs.selectedNode
            && lhs.nodes == rhs.nodes
            && lhs.iosMinAppVersion == rhs.iosMinAppVersion
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
}

extension ChainModel {
    func polkascanAddressURL(_ address: String) -> URL? {
        URL(string: "https://polkascan.io/\(name)/account/\(address)")
    }

    func subscanAddressURL(_ address: String) -> URL? {
        URL(string: "https://\(name).subscan.io/account/\(address)")
    }

    func subscanExtrinsicUrl(_ extrinsicHash: String) -> URL? {
        URL(string: "https://\(name).subscan.io/extrinsic/\(extrinsicHash)")
    }
}
