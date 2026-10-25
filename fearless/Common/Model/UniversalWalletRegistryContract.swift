import Foundation

struct UniversalWalletChainRegistry: Codable, Equatable {
    static let schemaVersionValue = 1

    let schemaVersion: Int
    let chains: [UniversalWalletChainRegistryEntry]

    init(schemaVersion: Int = UniversalWalletChainRegistry.schemaVersionValue, chains: [UniversalWalletChainRegistryEntry]) {
        self.schemaVersion = schemaVersion
        self.chains = chains
    }

    func validationErrors() -> Set<UniversalWalletRegistryValidationError> {
        var errors = Set<UniversalWalletRegistryValidationError>()

        if schemaVersion != Self.schemaVersionValue {
            errors.insert(.invalidSchemaVersion)
        }
        if chains.isEmpty {
            errors.insert(.chainsRequired)
        }

        var ids = Set<String>()
        var chainIds = Set<String>()
        chains.forEach { chain in
            errors.formUnion(chain.validationErrors())
            if !ids.insert(chain.id).inserted {
                errors.insert(.duplicateChainId)
            }
            if !chainIds.insert(chain.chainId).inserted {
                errors.insert(.duplicateChainId)
            }
        }

        return errors
    }
}

struct UniversalWalletChainRegistryEntry: Codable, Equatable {
    let id: String
    let ecosystem: String
    let chainId: String
    let displayName: String
    let enabledByDefault: Bool
    let nativeAsset: UniversalWalletRegistryAsset?
    let derivationPath: String?
    let slip44CoinType: Int?
    let features: [String]
    let endpoints: [UniversalWalletRegistryEndpoint]

    init(
        id: String,
        ecosystem: String,
        chainId: String,
        displayName: String,
        enabledByDefault: Bool,
        nativeAsset: UniversalWalletRegistryAsset? = nil,
        derivationPath: String? = nil,
        slip44CoinType: Int? = nil,
        features: [String] = [],
        endpoints: [UniversalWalletRegistryEndpoint] = []
    ) {
        self.id = id
        self.ecosystem = ecosystem
        self.chainId = chainId
        self.displayName = displayName
        self.enabledByDefault = enabledByDefault
        self.nativeAsset = nativeAsset
        self.derivationPath = derivationPath
        self.slip44CoinType = slip44CoinType
        self.features = features
        self.endpoints = endpoints
    }

    init(
        id: String,
        ecosystem: UniversalWalletEcosystem,
        chainId: String,
        displayName: String,
        enabledByDefault: Bool,
        nativeAsset: UniversalWalletRegistryAsset? = nil,
        derivationPath: String? = nil,
        slip44CoinType: Int? = nil,
        features: [String] = [],
        endpoints: [UniversalWalletRegistryEndpoint] = []
    ) {
        self.init(
            id: id,
            ecosystem: ecosystem.rawValue,
            chainId: chainId,
            displayName: displayName,
            enabledByDefault: enabledByDefault,
            nativeAsset: nativeAsset,
            derivationPath: derivationPath,
            slip44CoinType: slip44CoinType,
            features: features,
            endpoints: endpoints
        )
    }

    func validationErrors() -> Set<UniversalWalletRegistryValidationError> {
        var errors = Set<UniversalWalletRegistryValidationError>()

        if !UniversalWalletRegistryContractValidator.matches(id, #"^[a-z0-9][a-z0-9._:-]{1,63}$"#) {
            errors.insert(.invalidId)
        }
        if UniversalWalletEcosystem(rawValue: ecosystem) == nil {
            errors.insert(.invalidEcosystem)
        }
        if !UniversalWalletRegistryContractValidator.matches(chainId, #"^[A-Za-z0-9._:-]{2,128}$"#) {
            errors.insert(.invalidChainId)
        }
        if !UniversalWalletRegistryContractValidator.isHumanText(displayName, maxLength: 80) {
            errors.insert(.invalidDisplayName)
        }
        if enabledByDefault, endpoints.isEmpty {
            errors.insert(.endpointRequired)
        }
        if let nativeAsset {
            errors.formUnion(nativeAsset.validationErrors())
        }
        if let derivationPath,
           !derivationPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !UniversalWalletRegistryContractValidator.matches(derivationPath, #"^m(?:/[0-9]+'?)*$"#) {
            errors.insert(.invalidDerivationPath)
        }
        if let slip44CoinType, slip44CoinType < 0 {
            errors.insert(.invalidSlip44CoinType)
        }

        var featureIds = Set<String>()
        features.forEach { feature in
            if !UniversalWalletRegistryContractValidator.featureIds.contains(feature) {
                errors.insert(.invalidFeatureId)
            }
            if !featureIds.insert(feature).inserted {
                errors.insert(.duplicateFeatureId)
            }
        }

        var endpointIds = Set<String>()
        endpoints.forEach { endpoint in
            errors.formUnion(endpoint.validationErrors())
            if !endpointIds.insert(endpoint.id).inserted {
                errors.insert(.duplicateEndpointId)
            }
        }

        return errors
    }
}

struct UniversalWalletRegistryAsset: Codable, Equatable {
    let id: String
    let symbol: String
    let decimals: Int
    let name: String?

    func validationErrors() -> Set<UniversalWalletRegistryValidationError> {
        var errors = Set<UniversalWalletRegistryValidationError>()

        if !UniversalWalletRegistryContractValidator.matches(id, #"^[A-Za-z0-9._:-]{1,128}$"#) {
            errors.insert(.invalidAssetId)
        }
        if !UniversalWalletRegistryContractValidator.matches(symbol, #"^[A-Z0-9]{2,16}$"#) {
            errors.insert(.invalidAssetSymbol)
        }
        if !(0 ... 255).contains(decimals) {
            errors.insert(.invalidAssetDecimals)
        }
        if let name, !UniversalWalletRegistryContractValidator.isHumanText(name, maxLength: 80) {
            errors.insert(.invalidAssetName)
        }

        return errors
    }
}

struct UniversalWalletRegistryEndpoint: Codable, Equatable {
    let id: String
    let kind: UniversalWalletRegistryEndpointKind
    let url: String
    let readOnly: Bool
    let priority: Int

    init(id: String, kind: UniversalWalletRegistryEndpointKind, url: String, readOnly: Bool, priority: Int = 0) {
        self.id = id
        self.kind = kind
        self.url = url
        self.readOnly = readOnly
        self.priority = priority
    }

    func validationErrors() -> Set<UniversalWalletRegistryValidationError> {
        var errors = Set<UniversalWalletRegistryValidationError>()

        if !UniversalWalletRegistryContractValidator.matches(id, #"^[a-z0-9][a-z0-9._:-]{1,63}$"#) {
            errors.insert(.invalidEndpointId)
        }
        if !UniversalWalletRegistryContractValidator.isPublicOrLocalURL(url) {
            errors.insert(.invalidEndpointUrl)
        }
        if priority < 0 {
            errors.insert(.invalidEndpointPriority)
        }
        if !readOnly, kind == .indexer {
            errors.insert(.publicWriteIndexer)
        }

        return errors
    }
}

enum UniversalWalletRegistryEndpointKind: String, Codable {
    case indexer
    case rpc
    case toriiMcp = "torii-mcp"
    case explorer
}

enum UniversalWalletRegistryValidationError: String, Error, CaseIterable {
    case invalidSchemaVersion
    case chainsRequired
    case duplicateChainId
    case invalidId
    case invalidEcosystem
    case invalidChainId
    case invalidDisplayName
    case endpointRequired
    case invalidDerivationPath
    case invalidSlip44CoinType
    case invalidAssetId
    case invalidAssetSymbol
    case invalidAssetDecimals
    case invalidAssetName
    case duplicateEndpointId
    case invalidEndpointId
    case invalidEndpointUrl
    case invalidEndpointPriority
    case duplicateFeatureId
    case invalidFeatureId
    case publicWriteIndexer
}

enum UniversalWalletRegistryContractValidator {
    static let featureIds: Set<String> = ["receive", "transfer", "offline-cash", "sccp", "governance"]

    static func isPublicOrLocalURL(_ value: String) -> Bool {
        matches(value, #"^(https://[^\s]+|http://(?:localhost|127\.0\.0\.1)(?::[0-9]+)?(?:/[^\s]*)?)$"#)
    }

    static func isHumanText(_ value: String, maxLength: Int) -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return !normalized.isEmpty &&
            normalized.count <= maxLength &&
            normalized.rangeOfCharacter(from: .controlCharacters) == nil
    }

    static func matches(_ value: String, _ pattern: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) != nil
    }
}
