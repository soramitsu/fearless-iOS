import Foundation
import RobinHood
import SSFChainConnection
import SSFChainRegistry
import SSFExtrinsicKit
import SSFModels
import SSFNetwork
import SSFRuntimeCodingService
import SSFStorageQueryKit
import SSFUtils

struct XcmExtrinsicServices {
    let extrinsic: XcmExtrinsicServiceProtocol
    let destinationFeeFetcher: XcmDestinationFeeFetching
    let availableDestionationFetching: XcmChainsConfigFetching
}

/// The only way into the XCM services is `createReadOnlyServices`: discovery and fee quotation.
///
/// This assembly must never take, hold or forward signing material, and it must never build a
/// service around a signer that works. Sending a cross-chain transfer is the wallet's job, through
/// its own reviewed and authorized path. `scripts/test-xcm-read-only-boundary.py` fails the build
/// when a mutation-capable entry point shows up here again.
public enum XcmAssembly {
    /// Discovery and fee quotation need public account identity, never a wallet
    /// secret. Fee operations retain their existing dummy-signature path.
    public static func createReadOnlyServices(
        chainId: String,
        cryptoType: CryptoType,
        chainMetadata: RuntimeMetadataItemProtocol?,
        accountId: AccountId,
        chainType: ChainBaseType,
        sourceConfig: XcmConfigProtocol?,
        chainRegistry: ChainRegistryProtocol?
    ) -> XcmReadOnlyServices {
        // The dependency container uses this value only for chain, runtime, account and
        // crypto-type selection. There is no signing material in it.
        let context = FromChainData(
            chainId: chainId, cryptoType: cryptoType, chainMetadata: chainMetadata,
            accountId: accountId, chainType: chainType
        )
        let services = makeServices(
            fromChainData: context, sourceConfig: sourceConfig, chainRegistry: chainRegistry
        )
        return XcmReadOnlyServices(
            extrinsic: XcmReadOnlyFeeEstimator(service: services.extrinsic),
            destinationFeeFetcher: services.destinationFeeFetcher,
            availableDestionationFetching: services.availableDestionationFetching
        )
    }

    private static func makeServices(
        fromChainData: FromChainData,
        sourceConfig: XcmConfigProtocol?,
        chainRegistry: ChainRegistryProtocol?
    ) -> XcmExtrinsicServices {
        let callFactory = XcmCallFactory(
            tokenLocationsSourceUrl: sourceConfig?.tokenLocationsSourceUrl ?? XcmConfig.shared
                .tokenLocationsSourceUrl
        )
        let extrinsicBuilder = XcmExtrinsicBuilder(callFactory: callFactory)
        let chainRegistry = chainRegistry ?? Self.createInternalChainRegistry(sourceConfig: sourceConfig)

        let xcmChainsConfigFetcher = XcmChainsConfigFetcher(chainRegistry: chainRegistry)
        let depsContainer = XcmDependencyContainer(
            chainRegistry: chainRegistry,
            fromChainData: fromChainData
        )

        let callPathDeterminer = CallPathDeterminerImpl(
            chainRegistry: chainRegistry,
            fromChainData: fromChainData
        )

        let destinationFeeFetcher = XcmDestinationFeeFetcher(
            sourceUrl: sourceConfig?.destinationFeeSourceUrl ?? XcmConfig.shared
                .destinationFeeSourceUrl,
            networkOperationFactory: NetworkOperationFactory(),
            operationQueue: OperationQueue()
        )

        let extrinsic = XcmExtrinsicService(
            signingWrapper: XcmReadOnlySigner(),
            extrinsicBuilder: extrinsicBuilder,
            xcmVersionFetcher: xcmChainsConfigFetcher,
            chainRegistry: chainRegistry,
            depsContainer: depsContainer,
            callPathDeterminer: callPathDeterminer
        )

        return XcmExtrinsicServices(
            extrinsic: extrinsic,
            destinationFeeFetcher: destinationFeeFetcher,
            availableDestionationFetching: xcmChainsConfigFetcher
        )
    }
    
    private static func createInternalChainRegistry(
        sourceConfig: XcmConfigProtocol?
    ) -> ChainRegistryProtocol {
        // Background retries of the remote files stop after a few attempts; a later request
        // loads them again.
        let retryStrategy = ExponentialReconnection(maxAttempts: 5)

        let chainSyncService = ChainSyncService(
            chainsUrl: sourceConfig?.chainsSourceUrl ?? XcmConfig.shared.chainsSourceUrl,
            operationQueue: OperationQueue(),
            dataFetchFactory: NetworkOperationFactory(),
            retryStrategy: retryStrategy
        )

        let chainsTypesSyncService = ChainsTypesSyncService(
            url: sourceConfig?.chainTypesSourceUrl ?? XcmConfig.shared.chainTypesSourceUrl,
            dataOperationFactory: NetworkOperationFactory(),
            operationQueue: OperationQueue(),
            retryStrategy: retryStrategy
        )

        let runtimeSyncService = RuntimeSyncService(
            dataOperationFactory: NetworkOperationFactory(),
            retryStrategy: retryStrategy
        )

        let chainRegistry = ChainRegistry(
            runtimeProviderPool: RuntimeProviderPool(),
            connectionPool: ConnectionPool(),
            chainSyncService: chainSyncService,
            chainsTypesSyncService: chainsTypesSyncService,
            runtimeSyncService: runtimeSyncService
        )
        return chainRegistry
    }
}

public extension XcmAssembly {
    /// Public identity of the account the services act for.
    struct FromChainData {
        public let chainId: String
        public let cryptoType: CryptoType
        public let chainMetadata: RuntimeMetadataItemProtocol?
        public let accountId: AccountId
        public let chainType: ChainBaseType

        public init(
            chainId: String,
            cryptoType: CryptoType,
            chainMetadata: RuntimeMetadataItemProtocol?,
            accountId: AccountId,
            chainType: ChainBaseType
        ) {
            self.chainId = chainId
            self.cryptoType = cryptoType
            self.chainMetadata = chainMetadata
            self.accountId = accountId
            self.chainType = chainType
        }
    }
}
