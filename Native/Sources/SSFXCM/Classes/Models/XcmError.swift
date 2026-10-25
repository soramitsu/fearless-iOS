import Foundation
import SSFModels

public enum XcmError: Error {
    case invalidParachainRange
    case directionNotSupported
    case caseNotProcessed
    case missingCurrencyId
    case missingAssetLocationsResult
    case missingLocalAssetLocations
    case missingRemoteInteriors
    case missingRemoteXcmVersion
    case missingRemoteChainsResult
    case unsupportedRemoteXcmVersion
    case noFee(chainId: String)
    case missingRemoteFeeResult
    case noChainAsset(chainId: String)
    case noXcmChain(chainId: String)
    case noXcmPallet(chainId: String)
    case noWeight(chainId: String)
    case noAvailableXcmAsset(symbol: String)
    case convenience(error: String)
    case unsupportedBridgeNetwork(chainId: String)
    case invalidEvmChainId(String)
    case invalidRecipientLength(expected: Int, actual: Int)
    case missingParachainId(chainId: String)
    case unsupportedXcmVersion(XcmCallFactoryVersion)
}
