import Foundation

public enum ChainAssetTypeError: Error {
    case unknownType(type: String)
}

public enum EthereumAssetType: String, Codable {
    case normal
    case erc20
    case bep20
}

public enum SubstrateAssetType: String, Codable {
    case normal
    case ormlChain
    case ormlAsset
    case foreignAsset
    case stableAssetPoolToken
    case liquidCrowdloan
    case vToken
    case vsToken
    case stable
    case assets
    case equilibrium
    case soraAsset
    case assetId
    case token2
    case xcm
}

public enum AssetBaseType: String, Codable {
    case substrate
    case ethereum
}

public enum ChainAssetType: Codable, Equatable {
    case substrate(substrateType: SubstrateAssetType)
    case ethereum(ethereumType: EthereumAssetType)

    public var rawValue: String {
        switch self {
        case let .substrate(substrateType):
            return "substrate-\(substrateType.rawValue)"
        case let .ethereum(ethereumType):
            return "ethereum-\(ethereumType.rawValue)"
        }
    }

    public init?(storageValue: String) {
        let components = storageValue.components(separatedBy: "-")
        guard let baseTypeValue = components.first, let subTypeValue = components.last else {
            return nil
        }

        guard let baseType = AssetBaseType(rawValue: baseTypeValue) else {
            return nil
        }

        switch baseType {
        case .substrate:
            guard let substrateAssetType = SubstrateAssetType(rawValue: subTypeValue) else {
                return nil
            }

            self = .substrate(substrateType: substrateAssetType)
        case .ethereum:
            guard let ethereumAssetType = EthereumAssetType(rawValue: subTypeValue) else {
                return nil
            }

            self = .ethereum(ethereumType: ethereumAssetType)
        }
    }

    public var substrateAssetType: SubstrateAssetType? {
        switch self {
        case let .substrate(substrateType):
            return substrateType
        case .ethereum:
            return nil
        }
    }

    public var ethereumAssetType: EthereumAssetType? {
        switch self {
        case .substrate:
            return nil
        case let .ethereum(ethereumType):
            return ethereumType
        }
    }
}
