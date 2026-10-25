import Foundation

public struct XcmChain: Codable, Equatable {
    public let xcmVersion: XcmCallFactoryVersion?
    public let destWeightIsPrimitive: Bool?
    public let availableAssets: [XcmAvailableAsset]
    public let availableDestinations: [XcmAvailableDestination]

    public init(
        xcmVersion: XcmCallFactoryVersion?,
        destWeightIsPrimitive: Bool?,
        availableAssets: [XcmAvailableAsset],
        availableDestinations: [XcmAvailableDestination]
    ) {
        self.xcmVersion = xcmVersion
        self.destWeightIsPrimitive = destWeightIsPrimitive
        self.availableAssets = availableAssets
        self.availableDestinations = availableDestinations
    }

    public static func == (lhs: XcmChain, rhs: XcmChain) -> Bool {
        lhs.xcmVersion == rhs.xcmVersion &&
            lhs.availableAssets == rhs.availableAssets &&
            Set(lhs.availableDestinations) == Set(rhs.availableDestinations) &&
            lhs.destWeightIsPrimitive ?? false == rhs.destWeightIsPrimitive ?? false
    }
}

public struct XcmAvailableDestination: Codable, Hashable {
    public let chainId: ChainModel.Id
    public let bridgeParachainId: String?
    public let assets: [XcmAvailableAsset]

    public init(
        chainId: ChainModel.Id,
        bridgeParachainId: String?,
        assets: [XcmAvailableAsset]
    ) {
        self.chainId = chainId
        self.bridgeParachainId = bridgeParachainId
        self.assets = assets
    }
}

public struct XcmAvailableAsset: Codable, Hashable {
    public let id: String
    public let symbol: String

    public init(id: String, symbol: String) {
        self.id = id
        self.symbol = symbol
    }
}
