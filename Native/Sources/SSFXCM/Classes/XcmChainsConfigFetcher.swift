import Foundation
import RobinHood
import SSFChainRegistry
import SSFModels
import SSFNetwork
import SSFUtils

public protocol XcmChainsConfigFetching {
    func getAvailableOriginalChains(
        assetSymbol: String?,
        destinationChainId: ChainModel.Id?
    ) async throws -> [ChainModel.Id]

    func getAvailableAssets(
        originalChainId: ChainModel.Id?,
        destinationChainId: ChainModel.Id?
    ) async throws -> [String]

    func getAvailableDestinationChains(
        originalChainId: ChainModel.Id?,
        assetSymbol: String?
    ) async throws -> [ChainModel.Id]
}
// sourcery: AutoMockable
protocol XcmVersionFetching {
    func getVersion(for chainId: String) async throws -> XcmCallFactoryVersion
}

final class XcmChainsConfigFetcher: XcmChainsConfigFetching, XcmVersionFetching {
    private let chainRegistry: ChainRegistryProtocol

    init(chainRegistry: ChainRegistryProtocol) {
        self.chainRegistry = chainRegistry
    }

    // MARK: - XcmRemoteChainsFetching

    func getAvailableOriginalChains(
        assetSymbol: String?,
        destinationChainId: ChainModel.Id?
    ) async throws -> [ChainModel.Id] {
        var chains = try await chainRegistry
            .getChains()
            .filter { $0.xcm != nil }

        if let assetSymbol = assetSymbol {
            chains = chains.filter { chainModel in
                chainModel.xcm?.availableDestinations.contains(where: { destChain in
                    if destChain.assets.map({ $0.symbol.lowercased() })
                        .contains(assetSymbol.lowercased())
                    {
                        return true
                    } else if assetSymbol.lowercased().hasPrefix("xc") {
                        let modifySymbol = String(assetSymbol.dropFirst(2)).lowercased()
                        return destChain.assets.map { $0.symbol.lowercased() }
                            .contains(modifySymbol)
                    }
                    return false
                }) == true
            }
        }
        if let destinationChainId = destinationChainId {
            chains = chains.filter { chainModel in
                chainModel.xcm?.availableDestinations.contains(where: { destChain in
                    destChain.chainId == destinationChainId
                }) == true
            }
        }
        return chains.map { $0.chainId }
    }

    func getAvailableAssets(
        originalChainId: ChainModel.Id?,
        destinationChainId: ChainModel.Id?
    ) async throws -> [String] {
        let chains = try await chainRegistry
            .getChains()
            .filter { $0.xcm != nil }
        var originAssets: [String] = []
        var destAssets: [String] = []

        if let originalChainId = originalChainId {
            originAssets = chains.first { $0.chainId == originalChainId }?
                .xcm?
                .availableDestinations
                .map { $0.assets.map { $0.symbol }}
                .reduce([], +) ?? []
            if destinationChainId == nil {
                return Array(Set(originAssets))
            }
        }
        if let destinationChainId = destinationChainId {
            destAssets = chains.first { $0.chainId == destinationChainId }?
                .xcm?
                .availableAssets
                .map { $0.symbol } ?? []
            if originalChainId == nil {
                return Array(Set(destAssets))
            }
        }

        if originalChainId == nil, destinationChainId == nil {
            for chainModel in chains {
                chainModel.xcm?.availableDestinations.forEach { availableDestination in
                    originAssets += availableDestination.assets.map { $0.symbol }
                }
                destAssets += chainModel.xcm?.availableAssets.map { $0.symbol } ?? []
            }
        }

        return Array(Set(originAssets).intersection(Set(destAssets)))
    }

    func getAvailableDestinationChains(
        originalChainId: ChainModel.Id?,
        assetSymbol: String?
    ) async throws -> [ChainModel.Id] {
        var chains = try await chainRegistry
            .getChains()
            .filter { $0.xcm != nil }

        var destChainIds: [ChainModel.Id] = []
        if let originalChainId = originalChainId {
            chains = chains.filter { $0.chainId == originalChainId }
            let destinations = chains.map { $0.xcm?.availableDestinations ?? [] }.reduce([], +)
            destChainIds = destinations.map { $0.chainId }
        }
        if let assetSymbol = assetSymbol {
            let destinations = chains.map { $0.xcm?.availableDestinations ?? [] }.reduce([], +)
            destChainIds = destinations
                .filter {
                    if $0.assets.map({ $0.symbol.lowercased() })
                        .contains(assetSymbol.lowercased())
                    {
                        return true
                    } else if assetSymbol.hasPrefix("xc") {
                        let modifySymbol = String(assetSymbol.dropFirst(2)).lowercased()
                        return $0.assets.map { $0.symbol.lowercased() }.contains(modifySymbol)
                    }
                    return false
                }
                .map { $0.chainId }
        }
        if originalChainId == nil, assetSymbol == nil {
            let destinations = chains.map { $0.xcm?.availableDestinations ?? [] }.reduce([], +)
            destChainIds += destinations.map { $0.chainId }
        }
        return Array(Set(destChainIds))
    }

    // MARK: - XcmRemoteChainsVersionFetching

    func getVersion(for chainId: String) async throws -> XcmCallFactoryVersion {
        let chains = try await chainRegistry
            .getChains()
            .filter { $0.xcm != nil }

        guard let version = chains.first(where: {
            $0.chainId == chainId
        })?.xcm?.xcmVersion else {
            throw XcmError.missingRemoteXcmVersion
        }
        return version
    }
}
