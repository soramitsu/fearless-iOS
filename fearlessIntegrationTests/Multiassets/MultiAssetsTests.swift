import XCTest
@testable import fearless
import RobinHood
import SoraKeystore
import SoraFoundation
import IrohaCrypto

class MultiAssetsTests: XCTestCase {
    struct ChainInfo {
        let address: String
        let chain: Chain
    }

    let chainInfoList: [ChainInfo] =
        [
            /*ChainInfo(
                address: "5FCj3BzHo5274Jwd6PFdsGzSgDtQ724k7o7GRYTzAf7n37vk",
                chain: .westend
            ),
            ChainInfo(
                address: "HPB4rpxcMYxfqXWRDCcq57e6aw8ij8VNwfrnE1RgNGx19v3",
                chain: .kusama
            ),
            ChainInfo(
                address: "148fP7zCq1JErXCy92PkNam4KZNcroG9zbbiPwMB1qehgeT4",
                chain: .polkadot
            ),
            ChainInfo(
                address: "ofG2H56gunvmxD1tkPXVEkd7m5h77bD6kDVRpSUg89jh3UP",
                chain: .karura
            ),
            ChainInfo(
                address: "0x6477c1006ab85e6d94e8e7371f23b782fe95ca6b",
                chain: .moonriver
            ),
            ChainInfo(
                address: "2tC69agE7nYBA3VnQkP9N26zcxeRzXuADF9U1tAwpTakb6UL",
                chain: .darwinia
            ),
            ChainInfo(
                address: "2cNPNdHYZuFZdKsWt2avT5YerutN347b2oBXVp3cQ4Brf5VK",
                chain: .kulupu
            ),
            ChainInfo(
                address: "cnTYVPiZahYwoc4nF9PuzQNERbZeADFYvwSMsTg72iT6ZFqFS",
                chain: .sora
            ),
             ChainInfo(
                 address: "iB4rFe3BU9aD4TKDd3TbRnex2cUxTMQy7rrr5LGZDykjsDB",
                 chain: .edgeware
             ),
            ChainInfo(
                address: "3sqo18YiLP8BzNGbAoAbCqJgcAhJvL56t7z9zs7pqEMKyRnx",
                chain: .subsocial
            ),
            ChainInfo(
                address: "5SjzpaPkVvrZZXuKV2nBnjMUFwVS1CNopx31Eh9LfcJyKwTN",
                chain: .chainX
            ),
            ChainInfo(
                address: "0x5AacB4Cb1BF3fb344a0e93529A8f17A3ed6EB8B6",
                chain: .moonBaseAlpha
            ),
            ChainInfo(
                address: "Z9jV9NBr7iUwwdRDbVK1FxKVcx5CN2Lr9ZZyLN8NDBN1uFF",
                chain: .plasm
            ),
            ChainInfo(
                address: "4cwfB8jUPs2pWVEJdXQBvYKyxUoNTRGWLA5ePULPssxRh5CW",
                chain: .centrifuge
            )*/
            ChainInfo(
                address: "586U6e2jTGbbmAVMRorGdUYTUWC8XvN3Kyw3mNkYeYBVSTtz",
                chain: .statemine
            )
        ]

    func testKnowSubstrateNetworks() throws {
        let services: [WebSocketServiceProtocol] = try chainInfoList.enumerated().map { (index, chainInfo) in
            return try setupNetworkConnection(for: chainInfo, serviceId: String(index))
        }

        services.forEach { $0.setup() }

        wait(for: [XCTestExpectation()], timeout: 3600)
    }

    private func setupNetworkConnection(for chainInfo: ChainInfo, serviceId: String) throws
    -> WebSocketServiceProtocol {
        var settings = InMemorySettingsManager()
        let storageFacade = SubstrateStorageTestFacade()

        let accountItem = AccountItem(
            address: chainInfo.address,
            cryptoType: .ecdsa,
            username: "Account \(serviceId)",
            publicKeyData: Data()
        )

        settings.selectedAccount = accountItem
        settings.selectedConnection = ConnectionItem.supportedConnections.first {
            $0.type == chainInfo.chain.addressType
        }!

        let operationManager = OperationManagerFacade.sharedManager

        let runtimeService = try createRuntimeService(from: storageFacade,
                                                      operationManager: operationManager,
                                                      chain: chainInfo.chain)

        runtimeService.setup()

        let webSocketService = createWebSocketService(
            for: serviceId,
            storageFacade: storageFacade,
            runtimeService: runtimeService,
            operationManager: operationManager,
            settings: settings
        )

        return webSocketService
    }

    private func createRuntimeService(from storageFacade: StorageFacadeProtocol,
                                      operationManager: OperationManagerProtocol,
                                      chain: Chain,
                                      logger: LoggerProtocol? = nil) throws
    -> RuntimeRegistryService {
        let providerFactory = SubstrateDataProviderFactory(facade: storageFacade,
                                                           operationManager: operationManager,
                                                           logger: logger)

        let topDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ??
            FileManager.default.temporaryDirectory
        let runtimeDirectory = topDirectory.appendingPathComponent("runtime").path
        let filesRepository = RuntimeFilesOperationFacade(repository: FileRepository(),
                                                          directoryPath: runtimeDirectory)

        return RuntimeRegistryService(chain: chain,
                                      metadataProviderFactory: providerFactory,
                                      dataOperationFactory: DataOperationFactory(),
                                      filesOperationFacade: filesRepository,
                                      operationManager: operationManager,
                                      eventCenter: EventCenter.shared,
                                      logger: logger)
    }

    private func createWebSocketService(for identifier: String,
                                        storageFacade: StorageFacadeProtocol,
                                        runtimeService: RuntimeCodingServiceProtocol,
                                        operationManager: OperationManagerProtocol,
                                        settings: SettingsManagerProtocol
    ) -> WebSocketServiceProtocol {
        let connectionItem = settings.selectedConnection
        let address = settings.selectedAccount?.address

        let settings = WebSocketServiceSettings(url: connectionItem.url,
                                                addressType: connectionItem.type,
                                                address: address)

        let factory = MultiAssetMockSubscriptionFactory(
            serviceId: identifier,
            storageFacade: storageFacade,
            runtimeService: runtimeService,
            operationManager: operationManager,
            eventCenter: EventCenter.shared
        )

        return WebSocketService(settings: settings,
                                connectionFactory: WebSocketEngineFactory(),
                                subscriptionsFactory: factory,
                                applicationHandler: ApplicationHandler())
    }
}
