import XCTest
@testable import fearless
import SSFModels
import SSFStorageQueryKit
import SSFUtils
import SSFRuntimeCodingService
import BigInt

final class TonChainSelectionTests: XCTestCase {
    func testSelectedChainIdReturnsTestnetWhenEnabled() {
        let chainId = TonChainSelection.selectedChainId(isTestnetEnabled: true)

        XCTAssertEqual(chainId, "-3")
    }

    func testSelectedChainIdReturnsMainnetWhenDisabled() {
        let chainId = TonChainSelection.selectedChainId(isTestnetEnabled: false)

        XCTAssertEqual(chainId, "-239")
    }

    func testMatchesSelectedEnvironmentReturnsTrueForTestnetChainWhenEnabled() {
        let chain = makeChain(options: [.testnet])

        XCTAssertTrue(TonChainSelection.matchesSelectedEnvironment(chain: chain, isTestnetEnabled: true))
    }

    func testMatchesSelectedEnvironmentReturnsFalseForMainnetChainWhenEnabled() {
        let chain = makeChain(options: nil)

        XCTAssertFalse(TonChainSelection.matchesSelectedEnvironment(chain: chain, isTestnetEnabled: true))
    }

    private func makeChain(options: [ChainOptions]?) -> ChainModel {
        let node = ChainNodeModel(
            url: URL(string: "wss://ton.node.test")!,
            name: "TON Node",
            apikey: nil
        )

        return ChainModel(
            rank: nil,
            disabled: false,
            chainId: "ton-test-chain",
            parentId: nil,
            paraId: nil,
            name: "Ton Test",
            xcm: nil,
            nodes: Set([node]),
            addressPrefix: 0,
            types: nil,
            icon: nil,
            options: options,
            externalApi: nil,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }
}

final class TonCompatibilityTests: XCTestCase {
    func testTonCompatibilityChainDetectionByExplorerURL() {
        let chain = makeTonCompatibilityChain(
            name: "Any Name",
            chainId: "custom-chain",
            nodeURL: URL(string: "wss://node.example.com")!,
            explorerURL: URL(string: "https://tonviewer.com/address/abc")!
        )

        XCTAssertTrue(chain.isTonCompatibilityChain)
    }

    func testTonCompatibilityChainDetectionByNodeURL() {
        let chain = makeTonCompatibilityChain(
            name: "Any Name",
            chainId: "custom-chain",
            nodeURL: URL(string: "wss://rpc.ton.org")!,
            explorerURL: URL(string: "https://explorer.example.com/address/abc")!
        )

        XCTAssertTrue(chain.isTonCompatibilityChain)
    }

    func testTonCompatibilityChainDetectionReturnsFalseForNonTonChain() {
        let chain = makeTonCompatibilityChain(
            name: "Polkadot",
            chainId: "polkadot-mainnet",
            nodeURL: URL(string: "wss://rpc.polkadot.io")!,
            explorerURL: URL(string: "https://polkadot.subscan.io")!
        )

        XCTAssertFalse(chain.isTonCompatibilityChain)
    }

    func testTonAssetTypeMapsNormal() {
        let type: SubstrateAssetType? = .normal

        XCTAssertEqual(type.tonAssetType, .normal)
    }

    func testTonAssetTypeMapsJettonForNonNormalType() {
        let type: SubstrateAssetType? = .ormlAsset

        XCTAssertEqual(type.tonAssetType, .jetton)
    }

    func testTonAssetTypeMapsNoneForMissingType() {
        let type: SubstrateAssetType? = nil

        XCTAssertEqual(type.tonAssetType, .none)
    }

    func testDataTailReturnsSuffixWhenDataIsLongerThanLength() {
        let data = Data([0x01, 0x02, 0x03, 0x04])

        XCTAssertEqual(data.tail(2), Data([0x03, 0x04]))
    }

    func testDataTailReturnsOriginalDataWhenLengthExceedsCount() {
        let data = Data([0xAA, 0xBB])

        XCTAssertEqual(data.tail(8), data)
    }

    private func makeTonCompatibilityChain(
        name: String,
        chainId: String,
        nodeURL: URL,
        explorerURL: URL
    ) -> ChainModel {
        let node = ChainNodeModel(
            url: nodeURL,
            name: "Node",
            apikey: nil
        )

        let explorers = [
            ChainModel.ExternalApiExplorer(
                type: .unknown,
                types: [],
                url: explorerURL.absoluteString
            )
        ]

        let externalApi = ChainModel.ExternalApiSet(
            staking: nil,
            history: nil,
            crowdloans: nil,
            explorers: explorers,
            pricing: nil
        )

        return ChainModel(
            rank: nil,
            disabled: false,
            chainId: chainId,
            parentId: nil,
            paraId: nil,
            name: name,
            xcm: nil,
            nodes: Set([node]),
            addressPrefix: 0,
            types: nil,
            icon: nil,
            options: nil,
            externalApi: externalApi,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }
}

final class TonRemoteBalanceFetchingParsingTests: XCTestCase {
    func testParseFiatDayChangePercentStripsPercentSign() {
        let value = TonRemoteBalanceFetchingImpl.parseFiatDayChangePercent("4.25%")

        XCTAssertEqual(value, Decimal(string: "4.25"))
    }

    func testParseFiatDayChangePercentNormalizesUnicodeMinusSign() {
        let value = TonRemoteBalanceFetchingImpl.parseFiatDayChangePercent("−1.75%")

        XCTAssertEqual(value, Decimal(string: "-1.75"))
    }

    func testParseFiatDayChangePercentDefaultsToZeroForInvalidInput() {
        let value = TonRemoteBalanceFetchingImpl.parseFiatDayChangePercent("n/a")

        XCTAssertEqual(value, .zero)
    }
}

final class AccountInfoRemoteServiceTests: XCTestCase {
    func testFetchAccountInfosDelegatesTonChainToTonRemoteService() async throws {
        let chain = makeTonLikeChain()
        let wallet = AccountGenerator.generateMetaAccount()
        let ethereumFetching = AccountInfoFetchingStub()
        let tonService = AccountInfoRemoteServiceStub()
        let storagePerformer = StorageRequestPerformerStub()
        let service = AccountInfoRemoteServiceDefault(
            ethereumRemoteBalanceFetching: ethereumFetching,
            tonRemoteBalanceFetching: tonService,
            storagePerformer: storagePerformer
        )

        let result = try await service.fetchAccountInfos(for: chain, wallet: wallet)

        XCTAssertEqual(result, tonService.fetchInfosResult)
        XCTAssertEqual(tonService.fetchInfosInvocations, 1)
        XCTAssertEqual(ethereumFetching.fetchManyInvocations, 0)
        XCTAssertEqual(storagePerformer.performMixInvocations, 0)
    }

    func testFetchAccountInfosDelegatesEthereumChainToEthereumFetcher() async throws {
        let asset = AssetModel(
            id: "0x01",
            name: "Unit ETH",
            symbol: "UETH",
            precision: 18,
            isUtility: false,
            isNative: true,
            ethereumType: .normal
        )
        let chain = makeEthereumChain(with: asset)
        let wallet = AccountGenerator.generateMetaAccount()
        let ethereumFetching = AccountInfoFetchingStub()
        let tonService = AccountInfoRemoteServiceStub()
        let storagePerformer = StorageRequestPerformerStub()
        let service = AccountInfoRemoteServiceDefault(
            ethereumRemoteBalanceFetching: ethereumFetching,
            tonRemoteBalanceFetching: tonService,
            storagePerformer: storagePerformer
        )

        let expectedMap: [ChainAsset: AccountInfo?] = Dictionary(
            uniqueKeysWithValues: chain.chainAssets.map { ($0, nil) }
        )
        ethereumFetching.fetchManyResult = expectedMap

        let result = try await service.fetchAccountInfos(for: chain, wallet: wallet)

        XCTAssertEqual(result.count, expectedMap.count)
        XCTAssertEqual(ethereumFetching.fetchManyInvocations, 1)
        XCTAssertEqual(tonService.fetchInfosInvocations, 0)
        XCTAssertEqual(storagePerformer.performMixInvocations, 0)
    }

    func testFetchAccountInfosThrowsWhenTonServiceMissingForTonCompatibilityChain() async {
        let chain = makeTonLikeChain()
        let wallet = AccountGenerator.generateMetaAccount()
        let ethereumFetching = AccountInfoFetchingStub()
        let storagePerformer = StorageRequestPerformerStub()
        let service = AccountInfoRemoteServiceDefault(
            ethereumRemoteBalanceFetching: ethereumFetching,
            tonRemoteBalanceFetching: nil,
            storagePerformer: storagePerformer
        )

        do {
            _ = try await service.fetchAccountInfos(for: chain, wallet: wallet)
            XCTFail("Expected TON service missing error")
        } catch {
            XCTAssertTrue(String(describing: error).contains("TON remote fetching unavailable"))
        }

        XCTAssertEqual(ethereumFetching.fetchManyInvocations, 0)
        XCTAssertEqual(storagePerformer.performMixInvocations, 0)
    }

    func testFetchAccountInfoUsesEquilibriumRequestForGenshiroChain() async throws {
        let chain = makeGenshiroLikeChain()
        let chainAsset = try XCTUnwrap(chain.chainAssets.first)
        let wallet = AccountGenerator.generateMetaAccount()
        let ethereumFetching = AccountInfoFetchingStub()
        let tonService = AccountInfoRemoteServiceStub()
        let storagePerformer = StorageRequestPerformerStub()
        let service = AccountInfoRemoteServiceDefault(
            ethereumRemoteBalanceFetching: ethereumFetching,
            tonRemoteBalanceFetching: tonService,
            storagePerformer: storagePerformer
        )

        _ = try await service.fetchAccountInfo(for: chainAsset, wallet: wallet)

        XCTAssertEqual(storagePerformer.performMixInvocations, 1)
        let requestTypeName = String(describing: type(of: try XCTUnwrap(storagePerformer.lastMixRequests.first)))
        XCTAssertEqual(requestTypeName, String(describing: EquilibriumAccountInfotorageRequest.self))
    }

    func testFetchAccountInfosMapsBitcoinBalanceWithoutSubstrateStorage() async throws {
        let chain = makeBitcoinChain(historyBaseURL: "https://blockstream.info/api/")
        let wallet = try walletWithBitcoinAccount(chainId: chain.chainId)
        let bitcoinSync = BitcoinBalanceSyncStub(result: bitcoinBalanceResult(totalSats: 125_000))
        let mnemonicProvider = BitcoinMnemonicProviderStub(mnemonic: Self.mnemonic)
        let storagePerformer = StorageRequestPerformerStub()
        let service = makeAccountInfoRemoteService(
            bitcoinBalanceSync: bitcoinSync,
            bitcoinMnemonicProvider: mnemonicProvider,
            storagePerformer: storagePerformer
        )

        let result = try await service.fetchAccountInfos(for: chain, wallet: wallet)

        XCTAssertEqual(bitcoinSync.invocations.count, 1)
        XCTAssertEqual(bitcoinSync.invocations.first?.mnemonic, Self.mnemonic)
        XCTAssertEqual(bitcoinSync.invocations.first?.network, .mainnet)
        XCTAssertEqual(bitcoinSync.invocations.first?.baseURL, "https://blockstream.info/api/")
        XCTAssertEqual(bitcoinSync.invocations.first?.gapLimit, UniversalWalletRegistry.bitcoinMainnet.defaultGapLimit)
        XCTAssertEqual(storagePerformer.performMixInvocations, 0)

        let nativeInfo = try XCTUnwrap(result[Self.btcAsset.chainAssetId(chainId: chain.chainId)] ?? nil)
        XCTAssertEqual(nativeInfo.data.free, BigUInt(125_000))
    }

    func testFetchAccountInfoReturnsSingleBitcoinBalance() async throws {
        let chain = makeBitcoinChain()
        let chainAsset = ChainAsset(chain: chain, asset: Self.btcAsset)
        let wallet = try walletWithBitcoinAccount(chainId: chain.chainId)
        let bitcoinSync = BitcoinBalanceSyncStub(result: bitcoinBalanceResult(totalSats: 50_001))
        let service = makeAccountInfoRemoteService(
            bitcoinBalanceSync: bitcoinSync,
            bitcoinMnemonicProvider: BitcoinMnemonicProviderStub(mnemonic: Self.mnemonic)
        )

        let result = try await service.fetchAccountInfo(for: chainAsset, wallet: wallet)

        XCTAssertEqual(bitcoinSync.invocations.count, 1)
        XCTAssertEqual(result?.data.free, BigUInt(50_001))
    }

    func testFetchAccountInfosUsesBitcoinTestnetNetwork() async throws {
        let chain = makeBitcoinChain(chainId: UniversalWalletRegistry.bitcoinTestnet.chainId)
        let wallet = try walletWithBitcoinAccount(chainId: chain.chainId, network: .testnet)
        let bitcoinSync = BitcoinBalanceSyncStub(result: bitcoinBalanceResult(totalSats: 7))
        let service = makeAccountInfoRemoteService(
            bitcoinBalanceSync: bitcoinSync,
            bitcoinMnemonicProvider: BitcoinMnemonicProviderStub(mnemonic: Self.mnemonic)
        )

        _ = try await service.fetchAccountInfos(for: chain, wallet: wallet)

        XCTAssertEqual(bitcoinSync.invocations.first?.network, .testnet)
        XCTAssertEqual(bitcoinSync.invocations.first?.gapLimit, UniversalWalletRegistry.bitcoinTestnet.defaultGapLimit)
    }

    func testFetchAccountInfosFailsClosedForBitcoinWithoutMnemonicOrSubstrateStorage() async throws {
        let chain = makeBitcoinChain()
        let wallet = try walletWithBitcoinAccount(chainId: chain.chainId)
        let bitcoinSync = BitcoinBalanceSyncStub(result: bitcoinBalanceResult(totalSats: 1))
        let storagePerformer = StorageRequestPerformerStub()
        let service = makeAccountInfoRemoteService(
            bitcoinBalanceSync: bitcoinSync,
            bitcoinMnemonicProvider: BitcoinMnemonicProviderStub(mnemonic: nil),
            storagePerformer: storagePerformer
        )

        let result = try await service.fetchAccountInfos(for: chain, wallet: wallet)

        XCTAssertTrue(result.values.allSatisfy { $0 == nil })
        XCTAssertEqual(bitcoinSync.invocations.count, 0)
        XCTAssertEqual(storagePerformer.performMixInvocations, 0)
    }

    func testFetchAccountInfosFailsClosedWhenBitcoinIndexerFails() async throws {
        let chain = makeBitcoinChain()
        let wallet = try walletWithBitcoinAccount(chainId: chain.chainId)
        let bitcoinSync = BitcoinBalanceSyncStub(error: TestError.indexerUnavailable)
        let storagePerformer = StorageRequestPerformerStub()
        let service = makeAccountInfoRemoteService(
            bitcoinBalanceSync: bitcoinSync,
            bitcoinMnemonicProvider: BitcoinMnemonicProviderStub(mnemonic: Self.mnemonic),
            storagePerformer: storagePerformer
        )

        let result = try await service.fetchAccountInfos(for: chain, wallet: wallet)

        XCTAssertTrue(result.values.allSatisfy { $0 == nil })
        XCTAssertEqual(bitcoinSync.invocations.count, 1)
        XCTAssertEqual(storagePerformer.performMixInvocations, 0)
    }

    func testFetchAccountInfosRejectsMalformedBitcoinBalanceAndAssetMismatch() async throws {
        let chain = makeBitcoinChain(assets: [Self.btcPrecisionMismatchAsset, Self.usdcAsset])
        let wallet = try walletWithBitcoinAccount(chainId: chain.chainId)
        let bitcoinSync = BitcoinBalanceSyncStub(result: bitcoinBalanceResult(totalSats: -1))
        let service = makeAccountInfoRemoteService(
            bitcoinBalanceSync: bitcoinSync,
            bitcoinMnemonicProvider: BitcoinMnemonicProviderStub(mnemonic: Self.mnemonic)
        )

        let result = try await service.fetchAccountInfos(for: chain, wallet: wallet)

        XCTAssertTrue(result.values.allSatisfy { $0 == nil })
        XCTAssertEqual(bitcoinSync.invocations.count, 1)
    }

    func testFetchAccountInfosMapsSolanaNativeAndTokenBalancesWithoutSubstrateStorage() async throws {
        let chain = makeSolanaChain(historyBaseURL: "https://si.soramitsu.io/")
        let wallet = try walletWithSolanaAccount(chainId: chain.chainId)
        let solanaSync = SolanaBalanceSyncStub(result: solanaBalanceResult())
        let storagePerformer = StorageRequestPerformerStub()
        let service = makeAccountInfoRemoteService(
            solanaBalanceSync: solanaSync,
            storagePerformer: storagePerformer
        )

        let result = try await service.fetchAccountInfos(for: chain, wallet: wallet)

        XCTAssertEqual(solanaSync.invocations.count, 1)
        XCTAssertEqual(solanaSync.invocations.first?.network, UniversalWalletRegistry.solanaMainnet)
        XCTAssertEqual(solanaSync.invocations.first?.baseURL, "https://si.soramitsu.io/")
        XCTAssertEqual(solanaSync.invocations.first?.includeTokenMetadata, false)
        XCTAssertEqual(storagePerformer.performMixInvocations, 0)

        let nativeInfo = try XCTUnwrap(result[Self.solAsset.chainAssetId(chainId: chain.chainId)] ?? nil)
        let tokenInfo = try XCTUnwrap(result[Self.usdcAsset.chainAssetId(chainId: chain.chainId)] ?? nil)
        XCTAssertEqual(nativeInfo.data.free, BigUInt(1_234_567_890))
        XCTAssertEqual(tokenInfo.data.free, BigUInt(42_000_000))
    }

    func testFetchAccountInfoReturnsSingleSolanaTokenBalance() async throws {
        let chain = makeSolanaChain()
        let tokenChainAsset = ChainAsset(chain: chain, asset: Self.usdcAsset)
        let wallet = try walletWithSolanaAccount(chainId: chain.chainId)
        let solanaSync = SolanaBalanceSyncStub(result: solanaBalanceResult())
        let storagePerformer = StorageRequestPerformerStub()
        let service = makeAccountInfoRemoteService(
            solanaBalanceSync: solanaSync,
            storagePerformer: storagePerformer
        )

        let result = try await service.fetchAccountInfo(for: tokenChainAsset, wallet: wallet)

        XCTAssertEqual(solanaSync.invocations.count, 1)
        XCTAssertEqual(result?.data.free, BigUInt(42_000_000))
        XCTAssertEqual(storagePerformer.performMixInvocations, 0)
    }

    func testFetchAccountInfosFailsClosedForSolanaDevnetWithoutIndexerOrSubstrateStorage() async throws {
        let chain = makeSolanaChain(chainId: UniversalWalletRegistry.solanaDevnet.chainId)
        let wallet = try walletWithSolanaAccount(chainId: chain.chainId)
        let solanaSync = SolanaBalanceSyncStub(result: solanaBalanceResult())
        let storagePerformer = StorageRequestPerformerStub()
        let service = makeAccountInfoRemoteService(
            solanaBalanceSync: solanaSync,
            storagePerformer: storagePerformer
        )

        let result = try await service.fetchAccountInfos(for: chain, wallet: wallet)

        XCTAssertTrue(result.values.allSatisfy { $0 == nil })
        XCTAssertEqual(solanaSync.invocations.count, 0)
        XCTAssertEqual(storagePerformer.performMixInvocations, 0)
    }

    func testFetchAccountInfosFailsClosedForSolanaWithoutMatchingChainAccount() async throws {
        let chain = makeSolanaChain()
        let solanaSync = SolanaBalanceSyncStub(result: solanaBalanceResult())
        let storagePerformer = StorageRequestPerformerStub()
        let service = makeAccountInfoRemoteService(
            solanaBalanceSync: solanaSync,
            storagePerformer: storagePerformer
        )

        let result = try await service.fetchAccountInfos(for: chain, wallet: AccountGenerator.generateMetaAccount())

        XCTAssertTrue(result.values.allSatisfy { $0 == nil })
        XCTAssertEqual(solanaSync.invocations.count, 0)
        XCTAssertEqual(storagePerformer.performMixInvocations, 0)
    }

    func testFetchAccountInfosFailsClosedWhenSolanaIndexerFails() async throws {
        let chain = makeSolanaChain()
        let wallet = try walletWithSolanaAccount(chainId: chain.chainId)
        let solanaSync = SolanaBalanceSyncStub(error: TestError.indexerUnavailable)
        let storagePerformer = StorageRequestPerformerStub()
        let service = makeAccountInfoRemoteService(
            solanaBalanceSync: solanaSync,
            storagePerformer: storagePerformer
        )

        let result = try await service.fetchAccountInfos(for: chain, wallet: wallet)

        XCTAssertTrue(result.values.allSatisfy { $0 == nil })
        XCTAssertEqual(solanaSync.invocations.count, 1)
        XCTAssertEqual(storagePerformer.performMixInvocations, 0)
    }

    func testFetchAccountInfosRejectsMalformedSolanaAmountsAndPrecisionMismatches() async throws {
        let chain = makeSolanaChain()
        let wallet = try walletWithSolanaAccount(chainId: chain.chainId)
        let result = solanaBalanceResult(
            nativeAmount: "-1",
            tokenAmount: "42000000",
            tokenDecimals: 5
        )
        let solanaSync = SolanaBalanceSyncStub(result: result)
        let storagePerformer = StorageRequestPerformerStub()
        let service = makeAccountInfoRemoteService(
            solanaBalanceSync: solanaSync,
            storagePerformer: storagePerformer
        )

        let accountInfos = try await service.fetchAccountInfos(for: chain, wallet: wallet)

        XCTAssertTrue(accountInfos.values.allSatisfy { $0 == nil })
        XCTAssertEqual(solanaSync.invocations.count, 1)
        XCTAssertEqual(storagePerformer.performMixInvocations, 0)
    }

    func testFetchAccountInfosMapsIrohaTairaBalancesThroughTorii() async throws {
        let chain = makeIrohaChain(
            chainId: UniversalWalletRegistry.taira.chainId,
            historyBaseURL: "https://taira.sora.org/",
            assets: [Self.irohaToriiAsset]
        )
        let wallet = try walletWithIrohaAccount(chainId: chain.chainId)
        let address = try IrohaKeyDerivation.deriveAddress(
            mnemonic: Self.mnemonic,
            chainDiscriminant: UniversalWalletRegistry.taira.chainDiscriminant
        ).i105
        let client = IrohaToriiClientStub(
            accountAssetsResponse: IrohaAccountAssetListResponse(
                items: [
                    IrohaAccountAssetListItem(
                        accountID: address,
                        asset: Self.irohaToriiAsset.id,
                        assetID: nil,
                        assetName: nil,
                        assetAlias: nil,
                        quantity: "1.5",
                        scope: "global"
                    ),
                    IrohaAccountAssetListItem(
                        accountID: address,
                        asset: Self.irohaToriiAsset.id,
                        assetID: nil,
                        assetName: nil,
                        assetAlias: nil,
                        quantity: "0.25",
                        scope: "rewards"
                    )
                ],
                hasMore: false,
                countMode: IrohaToriiCountMode.bounded.rawValue,
                total: 2
            )
        )
        let storagePerformer = StorageRequestPerformerStub()
        let service = makeAccountInfoRemoteService(
            irohaToriiClient: client,
            storagePerformer: storagePerformer
        )

        let result = try await service.fetchAccountInfos(for: chain, wallet: wallet)

        XCTAssertEqual(client.accountAssetsInvocations.count, 1)
        XCTAssertEqual(client.accountAssetsInvocations.first?.accountID, address)
        XCTAssertNil(client.accountAssetsInvocations.first?.baseURL)
        XCTAssertEqual(client.accountAssetsInvocations.first?.limit, IrohaToriiRoutes.maxLimit)
        XCTAssertEqual(client.accountAssetsInvocations.first?.countMode, .bounded)
        XCTAssertEqual(client.accountAssetsInvocations.first?.network, UniversalWalletRegistry.taira)
        XCTAssertEqual(storagePerformer.performMixInvocations, 0)

        let balance = try XCTUnwrap(result[Self.irohaToriiAsset.chainAssetId(chainId: chain.chainId)] ?? nil)
        let expectedBalance = try XCTUnwrap(BigUInt("1750000000000000000"))
        XCTAssertEqual(balance.data.free, expectedBalance)
    }

    func testFetchAccountInfoReturnsSingleIrohaBalance() async throws {
        let chain = makeIrohaChain(
            chainId: UniversalWalletRegistry.taira.chainId,
            assets: [Self.irohaToriiAsset]
        )
        let chainAsset = ChainAsset(chain: chain, asset: Self.irohaToriiAsset)
        let wallet = try walletWithIrohaAccount(chainId: chain.chainId)
        let address = try IrohaKeyDerivation.deriveAddress(
            mnemonic: Self.mnemonic,
            chainDiscriminant: UniversalWalletRegistry.taira.chainDiscriminant
        ).i105
        let client = IrohaToriiClientStub(
            accountAssetsResponse: IrohaAccountAssetListResponse(
                items: [
                    IrohaAccountAssetListItem(
                        accountID: address,
                        asset: Self.irohaToriiAsset.id,
                        assetID: nil,
                        assetName: nil,
                        assetAlias: nil,
                        quantity: "2",
                        scope: "global"
                    )
                ],
                hasMore: false,
                countMode: IrohaToriiCountMode.bounded.rawValue,
                total: 1
            )
        )
        let service = makeAccountInfoRemoteService(irohaToriiClient: client)

        let result = try await service.fetchAccountInfo(for: chainAsset, wallet: wallet)

        XCTAssertEqual(client.accountAssetsInvocations.count, 1)
        let expectedBalance = try XCTUnwrap(BigUInt("2000000000000000000"))
        XCTAssertEqual(result?.data.free, expectedBalance)
    }

    func testFetchAccountInfosFailsClosedForIrohaChainsWithoutSubstrateStorage() async throws {
        let chainIds = [
            UniversalWalletRegistry.taira.chainId,
            UniversalWalletRegistry.taira.id,
            UniversalWalletRegistry.nexus.chainId,
            UniversalWalletRegistry.nexus.id
        ]

        for chainId in chainIds {
            let chain = makeIrohaChain(chainId: chainId)
            let ethereumFetching = AccountInfoFetchingStub()
            let tonService = AccountInfoRemoteServiceStub()
            let storagePerformer = StorageRequestPerformerStub()
            let service = AccountInfoRemoteServiceDefault(
                ethereumRemoteBalanceFetching: ethereumFetching,
                tonRemoteBalanceFetching: tonService,
                storagePerformer: storagePerformer
            )

            let result = try await service.fetchAccountInfos(
                for: chain,
                wallet: AccountGenerator.generateMetaAccount()
            )

            XCTAssertTrue(result.values.allSatisfy { $0 == nil }, "Unexpected balance for \(chainId)")
            XCTAssertEqual(ethereumFetching.fetchManyInvocations, 0)
            XCTAssertEqual(tonService.fetchInfosInvocations, 0)
            XCTAssertEqual(storagePerformer.performMixInvocations, 0)
        }
    }

    func testFetchAccountInfoFailsClosedForIrohaChainAssetWithoutSubstrateStorage() async throws {
        let chain = makeIrohaChain(chainId: UniversalWalletRegistry.taira.chainId)
        let chainAsset = ChainAsset(chain: chain, asset: Self.irohaAsset)
        let storagePerformer = StorageRequestPerformerStub()
        let service = makeAccountInfoRemoteService(storagePerformer: storagePerformer)

        let result = try await service.fetchAccountInfo(
            for: chainAsset,
            wallet: AccountGenerator.generateMetaAccount()
        )

        XCTAssertNil(result)
        XCTAssertEqual(storagePerformer.performMixInvocations, 0)
    }

    private func makeTonLikeChain() -> ChainModel {
        let node = ChainNodeModel(
            url: URL(string: "wss://rpc.ton.org")!,
            name: "TON",
            apikey: nil
        )

        return ChainModel(
            rank: nil,
            disabled: false,
            chainId: "unit-ton-chain",
            parentId: nil,
            paraId: nil,
            name: "Ton Unit",
            xcm: nil,
            nodes: Set([node]),
            addressPrefix: 0,
            types: nil,
            icon: nil,
            options: nil,
            externalApi: nil,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    private func makeEthereumChain(with asset: AssetModel) -> ChainModel {
        let node = ChainNodeModel(
            url: URL(string: "https://rpc.unit-eth.test")!,
            name: "Unit ETH",
            apikey: nil
        )

        return ChainModel(
            rank: nil,
            disabled: false,
            chainId: "unit-eth-chain",
            parentId: nil,
            paraId: nil,
            name: "Unit Ethereum",
            assets: Set([asset]),
            xcm: nil,
            nodes: Set([node]),
            addressPrefix: 0,
            types: nil,
            icon: nil,
            options: [.ethereum],
            externalApi: nil,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    private func makeGenshiroLikeChain() -> ChainModel {
        let node = ChainNodeModel(
            url: URL(string: "wss://node.ksm.genshiro.io")!,
            name: "Genshiro",
            apikey: nil
        )
        let asset = AssetModel(
            id: "gens-asset",
            name: "GENS",
            symbol: "GENS",
            precision: 12,
            isUtility: false,
            isNative: false,
            type: .normal
        )

        return ChainModel(
            rank: nil,
            disabled: false,
            chainId: "9de765698374eb576968c8a764168893fb277e65ad3ddafcfe2c49593fc6d663",
            parentId: nil,
            paraId: nil,
            name: "Genshiro",
            assets: Set([asset]),
            xcm: nil,
            nodes: Set([node]),
            addressPrefix: 0,
            types: nil,
            icon: nil,
            options: nil,
            externalApi: nil,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    private func makeIrohaChain(
        chainId: String,
        historyBaseURL: String? = nil,
        assets: [AssetModel] = [AccountInfoRemoteServiceTests.irohaAsset]
    ) -> ChainModel {
        let externalApi = historyBaseURL.map {
            ChainModel.ExternalApiSet(
                staking: nil,
                history: ChainModel.BlockExplorer(
                    type: "iroha",
                    url: URL(string: $0)!
                ),
                crowdloans: nil,
                explorers: nil
            )
        }

        return ChainModel(
            rank: nil,
            disabled: false,
            chainId: chainId,
            parentId: nil,
            paraId: nil,
            name: chainId.contains("nexus") || chainId.contains("sora:nexus") ? "SORA Nexus" : "Taira Testnet",
            assets: Set(assets),
            xcm: nil,
            nodes: [
                ChainNodeModel(
                    url: URL(string: "https://taira.sora.org")!,
                    name: "Taira",
                    apikey: nil
                )
            ],
            addressPrefix: 0,
            types: nil,
            icon: nil,
            options: nil,
            externalApi: externalApi,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    private func makeAccountInfoRemoteService(
        bitcoinBalanceSync: BitcoinBalanceSyncing? = nil,
        bitcoinMnemonicProvider: BitcoinMnemonicProviding = BitcoinMnemonicProviderStub(mnemonic: nil),
        solanaBalanceSync: SolanaBalanceSyncing? = nil,
        irohaToriiClient: IrohaToriiClientProtocol? = nil,
        storagePerformer: StorageRequestPerformerStub = StorageRequestPerformerStub()
    ) -> AccountInfoRemoteServiceDefault {
        AccountInfoRemoteServiceDefault(
            ethereumRemoteBalanceFetching: AccountInfoFetchingStub(),
            tonRemoteBalanceFetching: AccountInfoRemoteServiceStub(),
            bitcoinBalanceSync: bitcoinBalanceSync,
            bitcoinMnemonicProvider: bitcoinMnemonicProvider,
            solanaBalanceSync: solanaBalanceSync,
            irohaToriiClient: irohaToriiClient,
            storagePerformer: storagePerformer
        )
    }

    private func walletWithBitcoinAccount(
        chainId: String,
        network: BitcoinKeyDerivation.Network = .mainnet
    ) throws -> MetaAccountModel {
        let account = try BitcoinKeyDerivation.deriveAccount(mnemonic: Self.mnemonic, network: network)
        let chainAccount = ChainAccountModel(
            chainId: chainId,
            accountId: account.publicKey,
            publicKey: account.publicKey,
            cryptoType: CryptoType.ecdsa.rawValue,
            ethereumBased: false
        )

        return AccountGenerator.generateMetaAccount(with: [chainAccount])
    }

    private func walletWithSolanaAccount(chainId: String) throws -> MetaAccountModel {
        let account = try SolanaKeyDerivation.deriveAccount(mnemonic: Self.mnemonic)
        let chainAccount = ChainAccountModel(
            chainId: chainId,
            accountId: account.publicKey,
            publicKey: account.publicKey,
            cryptoType: CryptoType.ed25519.rawValue,
            ethereumBased: false
        )

        return AccountGenerator.generateMetaAccount(with: [chainAccount])
    }

    private func walletWithIrohaAccount(chainId: String) throws -> MetaAccountModel {
        let account = try IrohaKeyDerivation.deriveAccount(mnemonic: Self.mnemonic)
        let chainAccount = ChainAccountModel(
            chainId: chainId,
            accountId: account.publicKey,
            publicKey: account.publicKey,
            cryptoType: CryptoType.ed25519.rawValue,
            ethereumBased: false
        )

        return AccountGenerator.generateMetaAccount(with: [chainAccount])
    }

    private func makeBitcoinChain(
        chainId: String = UniversalWalletRegistry.bitcoinMainnet.chainId,
        historyBaseURL: String? = nil,
        assets: [AssetModel] = [AccountInfoRemoteServiceTests.btcAsset]
    ) -> ChainModel {
        let node = ChainNodeModel(
            url: URL(string: "https://bitcoin.node.example")!,
            name: "Bitcoin",
            apikey: nil
        )

        let externalApi = historyBaseURL.map {
            ChainModel.ExternalApiSet(
                staking: nil,
                history: ChainModel.BlockExplorer(
                    type: "subsquid",
                    url: URL(string: $0)!
                ),
                crowdloans: nil,
                explorers: nil
            )
        }

        return ChainModel(
            rank: nil,
            disabled: false,
            chainId: chainId,
            parentId: nil,
            paraId: nil,
            name: chainId == UniversalWalletRegistry.bitcoinTestnet.chainId ? "Bitcoin Testnet" : "Bitcoin",
            assets: Set(assets),
            xcm: nil,
            nodes: [node],
            addressPrefix: 0,
            types: nil,
            icon: nil,
            options: chainId == UniversalWalletRegistry.bitcoinTestnet.chainId ? [.testnet] : nil,
            externalApi: externalApi,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    private func makeSolanaChain(
        chainId: String = UniversalWalletRegistry.solanaMainnet.chainId,
        historyBaseURL: String? = nil
    ) -> ChainModel {
        let node = ChainNodeModel(
            url: URL(string: "https://api.mainnet-beta.solana.com")!,
            name: "Solana",
            apikey: nil
        )

        let externalApi = historyBaseURL.map {
            ChainModel.ExternalApiSet(
                staking: nil,
                history: ChainModel.BlockExplorer(
                    type: "subquery",
                    url: URL(string: $0)!
                ),
                explorers: nil
            )
        }

        return ChainModel(
            rank: nil,
            disabled: false,
            chainId: chainId,
            parentId: nil,
            paraId: nil,
            name: chainId == UniversalWalletRegistry.solanaDevnet.chainId ? "Solana Devnet" : "Solana",
            assets: [Self.solAsset, Self.usdcAsset],
            xcm: nil,
            nodes: [node],
            addressPrefix: 0,
            types: nil,
            icon: nil,
            options: chainId == UniversalWalletRegistry.solanaDevnet.chainId ? [.testnet] : nil,
            externalApi: externalApi,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    private func bitcoinBalanceResult(totalSats: Int64) -> BitcoinBalanceSyncResult {
        let discovered = BitcoinReceiveDiscoveredAddress(
            address: "bc1qunitbitcoinaddress000000000000000000000",
            index: 0,
            path: UniversalWalletDerivationPaths.bitcoinMainnetFirstReceive,
            confirmedSats: totalSats,
            mempoolSats: 0,
            totalSats: totalSats,
            txCount: totalSats > 0 ? 1 : 0,
            used: totalSats > 0
        )
        let discovery = BitcoinReceiveDiscoveryResult(
            addresses: [discovered],
            gapLimit: UniversalWalletRegistry.bitcoinMainnet.defaultGapLimit,
            lastUsedIndex: totalSats > 0 ? 0 : nil,
            nextReceiveAddress: "bc1qnextbitcoinaddress00000000000000000000",
            nextReceiveIndex: totalSats > 0 ? 1 : 0,
            usedAddresses: totalSats > 0 ? [discovered] : []
        )

        return BitcoinBalanceSyncResult(
            confirmedSats: totalSats,
            mempoolSats: 0,
            totalSats: totalSats,
            usedAddresses: discovery.usedAddresses,
            discovery: discovery
        )
    }

    private func solanaBalanceResult(
        nativeAmount: String = "1234567890",
        tokenAmount: String = "42000000",
        tokenDecimals: Int = 6
    ) -> SolanaBalanceSyncResult {
        let native = UniversalWalletIndexedAssetBalance(
            accountId: UniversalWalletRegistry.solanaMainnet.id,
            ecosystem: .solana,
            chainId: UniversalWalletRegistry.solanaMainnet.chainId,
            assetId: UniversalWalletRegistry.solanaMainnet.nativeAsset.id,
            amount: nativeAmount,
            decimals: UniversalWalletRegistry.solanaMainnet.nativeAsset.decimals,
            isNative: true,
            symbol: UniversalWalletRegistry.solanaMainnet.nativeAsset.symbol,
            name: UniversalWalletRegistry.solanaMainnet.name,
            uiAmountString: "1.23456789",
            syncedAtMillis: 1_715_000_000_000
        )
        let token = UniversalWalletIndexedAssetBalance(
            accountId: UniversalWalletRegistry.solanaMainnet.id,
            ecosystem: .solana,
            chainId: UniversalWalletRegistry.solanaMainnet.chainId,
            assetId: Self.usdcMint,
            amount: tokenAmount,
            decimals: tokenDecimals,
            isNative: false,
            symbol: "USDC",
            name: "USD Coin",
            uiAmountString: "42",
            tokenAccountId: "TokenAccount11111111111111111111111111111",
            contractAddress: Self.usdcMint,
            syncedAtMillis: 1_715_000_000_000
        )

        return SolanaBalanceSyncResult(
            wallet: Self.solanaWallet,
            networkId: UniversalWalletRegistry.solanaMainnet.id,
            chainId: UniversalWalletRegistry.solanaMainnet.chainId,
            syncedAtMillis: 1_715_000_000_000,
            nativeBalance: native,
            tokenBalances: [token],
            balances: [native, token]
        )
    }

    private static let mnemonic = "legal winner thank year wave sausage worth useful legal winner thank yellow"
    private static let btcAsset = AssetModel(
        id: "BTC",
        name: "Bitcoin",
        symbol: "BTC",
        precision: 8,
        isUtility: true,
        isNative: true
    )
    private static let btcPrecisionMismatchAsset = AssetModel(
        id: "BTC",
        name: "Bitcoin",
        symbol: "BTC",
        precision: 7,
        isUtility: true,
        isNative: true
    )
    private static let solanaWallet = "HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk"
    private static let usdcMint = "So11111111111111111111111111111111111111112"
    private static let solAsset = AssetModel(
        id: "SOL",
        name: "Solana",
        symbol: "SOL",
        precision: 9,
        isUtility: true,
        isNative: true
    )
    private static let usdcAsset = AssetModel(
        id: usdcMint,
        name: "USD Coin",
        symbol: "USDC",
        precision: 6,
        isUtility: false,
        isNative: false
    )
    private static let irohaAsset = AssetModel(
        id: "XOR",
        name: "SORA",
        symbol: "XOR",
        precision: 18,
        isUtility: true,
        isNative: true
    )
    private static let irohaToriiAsset = AssetModel(
        id: "xor#sora",
        name: "SORA",
        symbol: "XOR",
        precision: 18,
        isUtility: true,
        isNative: true
    )

    private enum TestError: Error {
        case indexerUnavailable
    }
}

private extension AssetModel {
    func chainAssetId(chainId: String) -> ChainAssetId {
        ChainAssetId(chainId: chainId, assetId: id)
    }
}

final class SendDependencyContainerUniversalWalletRoutingTests: XCTestCase {
    func testPrepareDependenciesDoesNotFailClosedForNativeTransferUniversalWalletChains() async {
        let chainIds = [
            UniversalWalletRegistry.bitcoinMainnet.chainId,
            UniversalWalletRegistry.bitcoinMainnet.id,
            UniversalWalletRegistry.bitcoinTestnet.chainId,
            UniversalWalletRegistry.bitcoinTestnet.id,
            UniversalWalletRegistry.solanaMainnet.chainId,
            UniversalWalletRegistry.solanaMainnet.id,
            UniversalWalletRegistry.solanaDevnet.chainId,
            UniversalWalletRegistry.solanaDevnet.id,
            UniversalWalletRegistry.taira.chainId,
            UniversalWalletRegistry.taira.id,
            UniversalWalletRegistry.nexus.chainId,
            UniversalWalletRegistry.nexus.id
        ]

        for chainId in chainIds {
            let chain = makeChain(chainId: chainId)
            let container = SendDepencyContainer(
                wallet: AccountGenerator.generateMetaAccount(),
                operationManager: fearless.OperationManagerFacade.sharedManager
            )

            do {
                _ = try await container.prepareDepencies(
                    chainAsset: ChainAsset(chain: chain, asset: Self.asset)
                )
                XCTFail("Expected missing account for \(chainId)")
            } catch let error as UniversalWalletSendRoutingError {
                XCTFail("Native transfer chain should route to a guarded service, not unsupported error: \(error)")
            } catch ChainAccountFetchingError.accountNotExists {
                continue
            } catch {
                XCTFail("Unexpected error for \(chainId): \(error)")
            }
        }
    }

    func testPrepareDependenciesFailsClosedForTonCompatibilityTransferBeforeSubstrateRouting() async throws {
        let chain = makeTonTransferChain()
        let wallet = walletWithChainAccount(chainId: chain.chainId)
        let container = SendDepencyContainer(
            wallet: wallet,
            operationManager: fearless.OperationManagerFacade.sharedManager
        )

        do {
            _ = try await container.prepareDepencies(
                chainAsset: ChainAsset(chain: chain, asset: Self.asset)
            )
            XCTFail("Expected TON transfer routing to fail closed")
        } catch {
            XCTAssertEqual((error as NSError).localizedDescription, "TON transfer not yet supported.")
        }
    }

    func testPrepareDependenciesCreatesIrohaTransferServiceForTairaAccount() async throws {
        let chain = makeIrohaChain(chainId: UniversalWalletRegistry.taira.chainId)
        let wallet = try walletWithIrohaAccount(chainId: chain.chainId)
        let container = SendDepencyContainer(
            wallet: wallet,
            operationManager: fearless.OperationManagerFacade.sharedManager
        )

        let dependencies = try await container.prepareDepencies(
            chainAsset: ChainAsset(chain: chain, asset: Self.irohaAsset)
        )

        XCTAssertTrue(dependencies.transferService is IrohaTransferService)
    }

    func testPrepareDependenciesCreatesIrohaTransferServiceForNexusAccount() async throws {
        let chain = makeIrohaChain(chainId: UniversalWalletRegistry.nexus.chainId)
        let wallet = try walletWithIrohaAccount(chainId: chain.chainId)
        let container = SendDepencyContainer(
            wallet: wallet,
            operationManager: fearless.OperationManagerFacade.sharedManager
        )

        let dependencies = try await container.prepareDepencies(
            chainAsset: ChainAsset(chain: chain, asset: Self.irohaAsset)
        )

        XCTAssertTrue(dependencies.transferService is IrohaTransferService)
    }

    func testIrohaTransferServiceBuildsSignerRequestAndSubmitsNorito() async throws {
        let chain = makeIrohaChain(
            chainId: UniversalWalletRegistry.taira.chainId,
            historyBaseURL: "https://taira.sora.org"
        )
        let wallet = try walletWithIrohaAccount(chainId: chain.chainId)
        let sourceAddress = try IrohaKeyDerivation.deriveAddress(
            mnemonic: Self.mnemonic,
            chainDiscriminant: UniversalWalletRegistry.taira.chainDiscriminant
        ).i105
        let recipientAddress = try IrohaAddressCodec.encode(
            publicKeyHex: String(repeating: "11", count: 32),
            chainDiscriminant: UniversalWalletRegistry.taira.chainDiscriminant
        )
        let toriiClient = IrohaSubmitClientStub()
        let signer = IrohaTransferSignerStub()
        let service = IrohaTransferService(
            wallet: wallet,
            chain: chain,
            toriiClient: toriiClient,
            signer: signer,
            mnemonicProvider: UniversalWalletMnemonicProviderStub(mnemonic: Self.mnemonic)
        )
        let transfer = Transfer(
            chainAsset: ChainAsset(chain: chain, asset: Self.irohaAsset),
            amount: BigUInt("1250000000000000000"),
            receiver: recipientAddress,
            tip: nil,
            appId: nil
        )

        let fee = try await service.estimateFee(for: transfer)
        let hash = try await service.submit(transfer: transfer)

        XCTAssertEqual(fee, BigUInt.zero)
        XCTAssertEqual(hash, Self.signedTransactionHash)
        XCTAssertEqual(toriiClient.lastSubmittedNorito, Self.signedTransaction)
        XCTAssertEqual(toriiClient.lastSubmitBaseURL, "https://taira.sora.org")
        XCTAssertEqual(signer.lastRequest?.amount, "1.25")
        XCTAssertEqual(signer.lastRequest?.assetDefinitionId, Self.irohaAsset.id)
        XCTAssertEqual(signer.lastRequest?.authority, sourceAddress)
        XCTAssertEqual(signer.lastRequest?.chainId, UniversalWalletRegistry.taira.chainId)
        XCTAssertEqual(signer.lastRequest?.derivationPath, UniversalWalletDerivationPaths.irohaDefault)
        XCTAssertEqual(signer.lastRequest?.destinationAccountId, recipientAddress)
        XCTAssertEqual(signer.lastRequest?.mnemonicOrSeed, Self.mnemonic)
        XCTAssertEqual(signer.lastRequest?.network, "taira")
        XCTAssertEqual(
            signer.lastRequest?.signingPublicKeyHex,
            try IrohaAddressCodec.parse(
                sourceAddress,
                expectedDiscriminant: UniversalWalletRegistry.taira.chainDiscriminant
            ).publicKeyHex
        )
        XCTAssertEqual(signer.lastRequest?.sourceAccountId, sourceAddress)
        XCTAssertEqual(signer.lastRequest?.sourceAssetId, "\(Self.irohaAsset.id)#\(sourceAddress)")
    }

    func testIrohaTransferServiceBuildsNexusSignerRequestAndSubmitsNorito() async throws {
        let chain = makeIrohaChain(
            chainId: UniversalWalletRegistry.nexus.chainId,
            historyBaseURL: "https://minamoto.sora.org"
        )
        let wallet = try walletWithIrohaAccount(chainId: chain.chainId)
        let sourceAddress = try IrohaKeyDerivation.deriveAddress(
            mnemonic: Self.mnemonic,
            chainDiscriminant: UniversalWalletRegistry.nexus.chainDiscriminant
        ).i105
        let recipientAddress = try IrohaAddressCodec.encode(
            publicKeyHex: String(repeating: "22", count: 32),
            chainDiscriminant: UniversalWalletRegistry.nexus.chainDiscriminant
        )
        let toriiClient = IrohaSubmitClientStub()
        let signer = IrohaTransferSignerStub()
        let service = IrohaTransferService(
            wallet: wallet,
            chain: chain,
            toriiClient: toriiClient,
            signer: signer,
            mnemonicProvider: UniversalWalletMnemonicProviderStub(mnemonic: Self.mnemonic)
        )
        let transfer = Transfer(
            chainAsset: ChainAsset(chain: chain, asset: Self.irohaAsset),
            amount: BigUInt("1250000000000000000"),
            receiver: recipientAddress,
            tip: nil,
            appId: nil
        )

        let fee = try await service.estimateFee(for: transfer)
        let hash = try await service.submit(transfer: transfer)

        XCTAssertEqual(fee, BigUInt.zero)
        XCTAssertEqual(hash, Self.signedTransactionHash)
        XCTAssertEqual(toriiClient.lastSubmittedNorito, Self.signedTransaction)
        XCTAssertEqual(toriiClient.lastSubmitBaseURL, "https://minamoto.sora.org")
        XCTAssertEqual(signer.lastRequest?.amount, "1.25")
        XCTAssertEqual(signer.lastRequest?.assetDefinitionId, Self.irohaAsset.id)
        XCTAssertEqual(signer.lastRequest?.authority, sourceAddress)
        XCTAssertEqual(signer.lastRequest?.chainId, UniversalWalletRegistry.nexus.chainId)
        XCTAssertEqual(signer.lastRequest?.derivationPath, UniversalWalletDerivationPaths.irohaDefault)
        XCTAssertEqual(signer.lastRequest?.destinationAccountId, recipientAddress)
        XCTAssertEqual(signer.lastRequest?.mnemonicOrSeed, Self.mnemonic)
        XCTAssertEqual(signer.lastRequest?.network, "nexus")
        XCTAssertEqual(
            signer.lastRequest?.signingPublicKeyHex,
            try IrohaAddressCodec.parse(
                sourceAddress,
                expectedDiscriminant: UniversalWalletRegistry.nexus.chainDiscriminant
            ).publicKeyHex
        )
        XCTAssertEqual(signer.lastRequest?.sourceAccountId, sourceAddress)
        XCTAssertEqual(signer.lastRequest?.sourceAssetId, "\(Self.irohaAsset.id)#\(sourceAddress)")
    }

    func testIrohaTransferServiceDefaultSignerFailsClosedAfterValidation() async throws {
        let chain = makeIrohaChain(chainId: UniversalWalletRegistry.taira.chainId)
        let wallet = try walletWithIrohaAccount(chainId: chain.chainId)
        let recipientAddress = try IrohaAddressCodec.encode(
            publicKeyHex: String(repeating: "11", count: 32),
            chainDiscriminant: UniversalWalletRegistry.taira.chainDiscriminant
        )
        let service = IrohaTransferService(
            wallet: wallet,
            chain: chain,
            toriiClient: IrohaSubmitClientStub(),
            mnemonicProvider: UniversalWalletMnemonicProviderStub(mnemonic: Self.mnemonic)
        )
        let transfer = Transfer(
            chainAsset: ChainAsset(chain: chain, asset: Self.irohaAsset),
            amount: BigUInt("1000000000000000000"),
            receiver: recipientAddress,
            tip: nil,
            appId: nil
        )

        let fee = try await service.estimateFee(for: transfer)
        XCTAssertEqual(fee, BigUInt.zero)

        do {
            _ = try await service.submit(transfer: transfer)
            XCTFail("Expected unavailable Iroha signer to fail closed")
        } catch TransferServiceError.transferFailed(let reason) {
            XCTAssertTrue(reason.contains("signing codec"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testIrohaTransferServiceRejectsMnemonicMismatchBeforeSignerOrToriiCalls() async throws {
        let chain = makeIrohaChain(chainId: UniversalWalletRegistry.taira.chainId)
        let wallet = try walletWithIrohaAccount(chainId: chain.chainId)
        let recipientAddress = try IrohaAddressCodec.encode(
            publicKeyHex: String(repeating: "11", count: 32),
            chainDiscriminant: UniversalWalletRegistry.taira.chainDiscriminant
        )
        let toriiClient = IrohaSubmitClientStub()
        let signer = IrohaTransferSignerStub()
        let service = IrohaTransferService(
            wallet: wallet,
            chain: chain,
            toriiClient: toriiClient,
            signer: signer,
            mnemonicProvider: UniversalWalletMnemonicProviderStub(mnemonic: Self.otherMnemonic)
        )
        let transfer = Transfer(
            chainAsset: ChainAsset(chain: chain, asset: Self.irohaAsset),
            amount: BigUInt("1000000000000000000"),
            receiver: recipientAddress,
            tip: nil,
            appId: nil
        )

        do {
            _ = try await service.submit(transfer: transfer)
            XCTFail("Expected Iroha transfer service to reject mismatched mnemonic material")
        } catch TransferServiceError.transferFailed(let reason) {
            XCTAssertTrue(reason.contains("does not match selected wallet"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertNil(signer.lastRequest)
        XCTAssertNil(toriiClient.lastSubmittedNorito)
    }

    private func makeChain(chainId: String) -> ChainModel {
        ChainModel(
            rank: nil,
            disabled: false,
            chainId: chainId,
            parentId: nil,
            paraId: nil,
            name: "Universal Wallet Unsupported",
            assets: [Self.asset],
            xcm: nil,
            nodes: [
                ChainNodeModel(
                    url: URL(string: "https://node.example")!,
                    name: "Node",
                    apikey: nil
                )
            ],
            addressPrefix: 0,
            types: nil,
            icon: nil,
            options: nil,
            externalApi: nil,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    private func makeTonTransferChain() -> ChainModel {
        ChainModel(
            rank: nil,
            disabled: false,
            chainId: "ton-mainnet-unit",
            parentId: nil,
            paraId: nil,
            name: "TON Mainnet",
            assets: [Self.asset],
            xcm: nil,
            nodes: [
                ChainNodeModel(
                    url: URL(string: "wss://rpc.ton.org")!,
                    name: "TON",
                    apikey: nil
                )
            ],
            addressPrefix: 0,
            types: nil,
            icon: nil,
            options: nil,
            externalApi: nil,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    private func makeIrohaChain(
        chainId: String,
        historyBaseURL: String? = nil
    ) -> ChainModel {
        let externalApi = historyBaseURL.map {
            ChainModel.ExternalApiSet(
                staking: nil,
                history: ChainModel.BlockExplorer(
                    type: "iroha",
                    url: URL(string: $0)!
                ),
                crowdloans: nil,
                explorers: nil
            )
        }

        return ChainModel(
            rank: nil,
            disabled: false,
            chainId: chainId,
            parentId: nil,
            paraId: nil,
            name: "Taira Testnet",
            assets: [Self.irohaAsset],
            xcm: nil,
            nodes: [
                ChainNodeModel(
                    url: URL(string: "https://taira.sora.org")!,
                    name: "Taira",
                    apikey: nil
                )
            ],
            addressPrefix: 0,
            types: nil,
            icon: nil,
            options: nil,
            externalApi: externalApi,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    private func walletWithIrohaAccount(chainId: String) throws -> MetaAccountModel {
        let account = try IrohaKeyDerivation.deriveAccount(mnemonic: Self.mnemonic)
        let chainAccount = ChainAccountModel(
            chainId: chainId,
            accountId: account.publicKey,
            publicKey: account.publicKey,
            cryptoType: CryptoType.ed25519.rawValue,
            ethereumBased: false
        )

        return AccountGenerator.generateMetaAccount(with: [chainAccount])
    }

    private func walletWithChainAccount(chainId: String) -> MetaAccountModel {
        let chainAccount = ChainAccountModel(
            chainId: chainId,
            accountId: Data.random(of: 32)!,
            publicKey: Data.random(of: 32)!,
            cryptoType: CryptoType.sr25519.rawValue,
            ethereumBased: false
        )

        return AccountGenerator.generateMetaAccount(with: [chainAccount])
    }

    private static let asset = AssetModel(
        id: "UNIT",
        name: "Unit",
        symbol: "UNIT",
        precision: 12,
        isUtility: true,
        isNative: true
    )

    private static let irohaAsset = AssetModel(
        id: "xor#sora",
        name: "XOR",
        symbol: "XOR",
        precision: 18,
        isUtility: true,
        isNative: true
    )
    private static let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    private static let otherMnemonic = "legal winner thank year wave sausage worth useful legal winner thank yellow"
    private static let signedTransaction = Data([1, 2, 3, 4])
    private static let signedTransactionHash = "signed-transaction-hash"
    private static let receiptTxHash = "receipt-tx-hash"
    private static let receiptEntrypointHash = "receipt-entrypoint-hash"
    private static let receiptSignedTransactionHash = "receipt-signed-transaction-hash"

    private final class IrohaTransferSignerStub: IrohaTransferSigning {
        private(set) var lastRequest: IrohaTransferSigningRequest?

        func buildAndSignTransfer(_ request: IrohaTransferSigningRequest) async throws -> IrohaSignedTransfer {
            lastRequest = request

            return IrohaSignedTransfer(
                signedTransaction: SendDependencyContainerUniversalWalletRoutingTests.signedTransaction,
                transactionHashHex: SendDependencyContainerUniversalWalletRoutingTests.signedTransactionHash
            )
        }
    }

    private final class IrohaSubmitClientStub: IrohaToriiClientProtocol {
        private(set) var lastSubmittedNorito: Data?
        private(set) var lastSubmitBaseURL: String?

        func health(baseURL _: String?) async throws -> Data {
            Data()
        }

        func accounts(
            baseURL _: String?,
            limit _: Int?,
            offset _: Int64?,
            countMode _: IrohaToriiCountMode?
        ) async throws -> IrohaAccountListResponse {
            throw AccountInfoRemoteServiceStubError.notImplemented
        }

        func account(
            accountID _: String,
            baseURL _: String?,
            network _: UniversalWalletRegistry.IrohaNetwork
        ) async throws -> IrohaAccountListItem {
            throw AccountInfoRemoteServiceStubError.notImplemented
        }

        func accountAssets(
            accountID _: String,
            baseURL _: String?,
            limit _: Int?,
            offset _: Int64?,
            countMode _: IrohaToriiCountMode?,
            asset _: String?,
            scope _: String?,
            network _: UniversalWalletRegistry.IrohaNetwork
        ) async throws -> IrohaAccountAssetListResponse {
            throw AccountInfoRemoteServiceStubError.notImplemented
        }

        func assetDefinitions(baseURL _: String?) async throws -> IrohaAssetDefinitionListResponse {
            throw AccountInfoRemoteServiceStubError.notImplemented
        }

        func submitTransaction(noritoBytes: Data, baseURL: String?) async throws -> IrohaTransactionSubmissionReceipt {
            lastSubmittedNorito = noritoBytes
            lastSubmitBaseURL = baseURL

            return IrohaTransactionSubmissionReceipt(
                payload: IrohaTransactionSubmissionPayload(
                    txHash: SendDependencyContainerUniversalWalletRoutingTests.receiptTxHash,
                    entrypointHash: SendDependencyContainerUniversalWalletRoutingTests.receiptEntrypointHash,
                    signedTransactionHash: SendDependencyContainerUniversalWalletRoutingTests.receiptSignedTransactionHash,
                    submittedAtMs: 1,
                    submittedAtHeight: 2,
                    signer: nil
                ),
                signature: nil
            )
        }

        func transactionStatus(
            hash _: String,
            baseURL _: String?,
            scope _: IrohaTransactionStatusScope
        ) async throws -> IrohaPipelineTransactionStatusResponse {
            throw AccountInfoRemoteServiceStubError.notImplemented
        }

        func mcpCapabilities(
            network _: UniversalWalletRegistry.IrohaNetwork,
            baseURL _: String?
        ) async throws -> Data {
            throw AccountInfoRemoteServiceStubError.notImplemented
        }

        func mcpJSONRPC(
            _: IrohaMcpJsonRPCRequest,
            network _: UniversalWalletRegistry.IrohaNetwork,
            baseURL _: String?
        ) async throws -> IrohaMcpJsonRPCResponse {
            throw AccountInfoRemoteServiceStubError.notImplemented
        }
    }

    private struct UniversalWalletMnemonicProviderStub: UniversalWalletMnemonicProviding {
        let mnemonic: String?

        func mnemonic(for _: MetaAccountModel, chain _: ChainModel) throws -> String? {
            mnemonic
        }
    }
}

final class ChainRegistryTonNodeSelectionTests: XCTestCase {
    func testResolveTonNodePrefersSelectedNode() {
        let primary = ChainNodeModel(
            url: URL(string: "https://ton-selected.example.com")!,
            name: "Selected",
            apikey: nil
        )
        let secondary = ChainNodeModel(
            url: URL(string: "https://ton-fallback.example.com")!,
            name: "Fallback",
            apikey: nil
        )
        let chain = makeTonChain(nodes: [primary, secondary], selectedNode: primary)

        let resolved = ChainRegistry.resolveTonNode(for: chain)

        XCTAssertEqual(resolved?.url, primary.url)
    }

    func testResolveTonNodeFallsBackDeterministicallyWhenSelectedNodeMissing() {
        let nodeB = ChainNodeModel(
            url: URL(string: "https://b-ton.example.com")!,
            name: "B",
            apikey: nil
        )
        let nodeA = ChainNodeModel(
            url: URL(string: "https://a-ton.example.com")!,
            name: "A",
            apikey: nil
        )
        let chain = makeTonChain(nodes: [nodeB, nodeA], selectedNode: nil)

        let resolved = ChainRegistry.resolveTonNode(for: chain)

        XCTAssertEqual(resolved?.url, nodeA.url)
    }

    func testResolveTonNodeReturnsNilForEmptyNodesAndNoSelection() {
        let chain = makeTonChain(nodes: [], selectedNode: nil)

        let resolved = ChainRegistry.resolveTonNode(for: chain)

        XCTAssertNil(resolved)
    }

    private func makeTonChain(nodes: [ChainNodeModel], selectedNode: ChainNodeModel?) -> ChainModel {
        ChainModel(
            rank: nil,
            disabled: false,
            chainId: "-239",
            parentId: nil,
            paraId: nil,
            name: "TON Mainnet",
            xcm: nil,
            nodes: Set(nodes),
            addressPrefix: 0,
            types: nil,
            icon: nil,
            options: nil,
            externalApi: nil,
            selectedNode: selectedNode,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }
}

final class CrossChainConfirmationViewModelFactoryTests: XCTestCase {
    func testCreateViewModelAddsOriginPreservationNoteForAssetHubChain() {
        let factory = CrossChainConfirmationViewModelFactory()
        let data = makeConfirmationData(destParaId: "1000")

        let viewModel = factory.createViewModel(with: data)

        XCTAssertEqual(viewModel.originPreservationNote, "Origin preserved via reserve transfer")
    }

    func testCreateViewModelSkipsOriginPreservationNoteForNonAssetHubChain() {
        let factory = CrossChainConfirmationViewModelFactory()
        let data = makeConfirmationData(destParaId: "2000")

        let viewModel = factory.createViewModel(with: data)

        XCTAssertNil(viewModel.originPreservationNote)
    }

    private func makeConfirmationData(destParaId: String) -> CrossChainConfirmationData {
        let wallet = AccountGenerator.generateMetaAccount()
        let originAsset = AssetModel(
            id: "origin-asset",
            name: "Origin Token",
            symbol: "ORG",
            precision: 12,
            color: "#3366FF",
            isUtility: true,
            isNative: true
        )
        let destAsset = AssetModel(
            id: "dest-asset",
            name: "Destination Token",
            symbol: "DST",
            precision: 12,
            color: "#33AA66",
            isUtility: true,
            isNative: true
        )
        let originChain = makeChain(
            chainId: "origin-chain",
            paraId: "0",
            name: "Origin Chain",
            asset: originAsset
        )
        let destChain = makeChain(
            chainId: "dest-chain",
            paraId: destParaId,
            name: "Destination Chain",
            asset: destAsset
        )

        return CrossChainConfirmationData(
            wallet: wallet,
            originChainAsset: ChainAsset(chain: originChain, asset: originAsset),
            destChainModel: destChain,
            amount: BigUInt(1_000_000),
            displayAmount: "1.00",
            originChainFee: BalanceViewModel(amount: "0.01", price: nil),
            destChainFee: BalanceViewModel(amount: "0.02", price: nil),
            destChainFeeDecimal: Decimal(string: "0.02") ?? .zero,
            recipientAddress: "recipient-address"
        )
    }

    private func makeChain(
        chainId: String,
        paraId: String,
        name: String,
        asset: AssetModel
    ) -> ChainModel {
        let node = ChainNodeModel(
            url: URL(string: "wss://\(chainId).example.org")!,
            name: "\(name) Node",
            apikey: nil
        )

        return ChainModel(
            rank: nil,
            disabled: false,
            chainId: chainId,
            parentId: nil,
            paraId: paraId,
            name: name,
            assets: Set([asset]),
            xcm: nil,
            nodes: Set([node]),
            addressPrefix: 0,
            types: nil,
            icon: URL(string: "https://\(chainId).example.org/icon.png"),
            options: nil,
            externalApi: nil,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }
}

private final class AccountInfoFetchingStub: AccountInfoFetchingProtocol {
    var fetchManyInvocations = 0
    var fetchManyResult: [ChainAsset: AccountInfo?] = [:]

    func fetch(
        for _: ChainAsset,
        accountId _: AccountId,
        completionBlock: @escaping (ChainAsset, AccountInfo?) -> Void
    ) {
        fatalError("Not used in this test")
    }

    func fetch(
        for _: [ChainAsset],
        wallet _: MetaAccountModel,
        completionBlock: @escaping ([ChainAsset: AccountInfo?]) -> Void
    ) {
        completionBlock(fetchManyResult)
    }

    func fetch(
        for chainAsset: ChainAsset,
        accountId _: AccountId
    ) async throws -> (ChainAsset, AccountInfo?) {
        (chainAsset, nil)
    }

    func fetch(
        for _: [ChainAsset],
        wallet _: MetaAccountModel
    ) async throws -> [ChainAsset: AccountInfo?] {
        fetchManyInvocations += 1
        return fetchManyResult
    }

    func fetchByUniqKey(
        for _: [ChainAsset],
        wallet _: MetaAccountModel
    ) async throws -> [ChainAssetKey: AccountInfo?] {
        [:]
    }
}

private final class AccountInfoRemoteServiceStub: AccountInfoRemoteService {
    var fetchInfosInvocations = 0
    var fetchInfosResult: [ChainAssetId: AccountInfo?] = [:]

    func fetchAccountInfos(
        for _: ChainModel,
        wallet _: MetaAccountModel
    ) async throws -> [ChainAssetId: AccountInfo?] {
        fetchInfosInvocations += 1
        return fetchInfosResult
    }

    func fetchAccountInfo(
        for _: ChainAsset,
        wallet _: MetaAccountModel
    ) async throws -> AccountInfo? {
        nil
    }
}

private final class BitcoinBalanceSyncStub: BitcoinBalanceSyncing {
    struct Invocation: Equatable {
        let mnemonic: String
        let passphrase: String
        let network: BitcoinKeyDerivation.Network
        let baseURL: String?
        let gapLimit: Int?
        let maxLookahead: Int
    }

    private let result: BitcoinBalanceSyncResult
    private let error: Error?
    private(set) var invocations: [Invocation] = []

    init(
        result: BitcoinBalanceSyncResult = BitcoinBalanceSyncResult(
            confirmedSats: 0,
            mempoolSats: 0,
            totalSats: 0,
            usedAddresses: [],
            discovery: BitcoinReceiveDiscoveryResult(
                addresses: [],
                gapLimit: UniversalWalletRegistry.bitcoinMainnet.defaultGapLimit,
                lastUsedIndex: nil,
                nextReceiveAddress: "",
                nextReceiveIndex: 0,
                usedAddresses: []
            )
        ),
        error: Error? = nil
    ) {
        self.result = result
        self.error = error
    }

    func balance(
        mnemonic: String,
        passphrase: String,
        network: BitcoinKeyDerivation.Network,
        baseURL: String?,
        gapLimit: Int?,
        maxLookahead: Int
    ) async throws -> BitcoinBalanceSyncResult {
        invocations.append(
            Invocation(
                mnemonic: mnemonic,
                passphrase: passphrase,
                network: network,
                baseURL: baseURL,
                gapLimit: gapLimit,
                maxLookahead: maxLookahead
            )
        )

        if let error {
            throw error
        }

        return result
    }
}

private struct BitcoinMnemonicProviderStub: BitcoinMnemonicProviding {
    let mnemonic: String?

    func mnemonic(for _: MetaAccountModel, chain _: ChainModel) throws -> String? {
        mnemonic
    }
}

private final class SolanaBalanceSyncStub: SolanaBalanceSyncing {
    struct Invocation: Equatable {
        let wallet: String
        let network: UniversalWalletRegistry.SolanaNetwork
        let baseURL: String?
        let includeTokenMetadata: Bool
    }

    private let result: SolanaBalanceSyncResult
    private let error: Error?
    private(set) var invocations: [Invocation] = []

    init(
        result: SolanaBalanceSyncResult = SolanaBalanceSyncResult(
            wallet: "",
            networkId: UniversalWalletRegistry.solanaMainnet.id,
            chainId: UniversalWalletRegistry.solanaMainnet.chainId,
            syncedAtMillis: 1,
            nativeBalance: UniversalWalletIndexedAssetBalance(
                accountId: UniversalWalletRegistry.solanaMainnet.id,
                ecosystem: .solana,
                chainId: UniversalWalletRegistry.solanaMainnet.chainId,
                assetId: UniversalWalletRegistry.solanaMainnet.nativeAsset.id,
                amount: "0",
                decimals: UniversalWalletRegistry.solanaMainnet.nativeAsset.decimals,
                isNative: true,
                syncedAtMillis: 1
            ),
            tokenBalances: [],
            balances: []
        ),
        error: Error? = nil
    ) {
        self.result = result
        self.error = error
    }

    func balances(
        wallet: String,
        network: UniversalWalletRegistry.SolanaNetwork,
        baseURL: String?,
        includeTokenMetadata: Bool
    ) async throws -> SolanaBalanceSyncResult {
        invocations.append(
            Invocation(
                wallet: wallet,
                network: network,
                baseURL: baseURL,
                includeTokenMetadata: includeTokenMetadata
            )
        )

        if let error {
            throw error
        }

        return result
    }
}

private final class IrohaToriiClientStub: IrohaToriiClientProtocol {
    struct AccountAssetsInvocation: Equatable {
        let accountID: String
        let baseURL: String?
        let limit: Int?
        let offset: Int64?
        let countMode: IrohaToriiCountMode?
        let asset: String?
        let scope: String?
        let network: UniversalWalletRegistry.IrohaNetwork
    }

    private let accountAssetsResponse: IrohaAccountAssetListResponse
    private let accountAssetsError: Error?
    private(set) var accountAssetsInvocations: [AccountAssetsInvocation] = []

    init(
        accountAssetsResponse: IrohaAccountAssetListResponse = IrohaAccountAssetListResponse(
            items: [],
            hasMore: false,
            countMode: IrohaToriiCountMode.bounded.rawValue,
            total: 0
        ),
        accountAssetsError: Error? = nil
    ) {
        self.accountAssetsResponse = accountAssetsResponse
        self.accountAssetsError = accountAssetsError
    }

    func health(baseURL _: String?) async throws -> Data {
        throw AccountInfoRemoteServiceStubError.notImplemented
    }

    func accounts(
        baseURL _: String?,
        limit _: Int?,
        offset _: Int64?,
        countMode _: IrohaToriiCountMode?
    ) async throws -> IrohaAccountListResponse {
        throw AccountInfoRemoteServiceStubError.notImplemented
    }

    func account(
        accountID _: String,
        baseURL _: String?,
        network _: UniversalWalletRegistry.IrohaNetwork
    ) async throws -> IrohaAccountListItem {
        throw AccountInfoRemoteServiceStubError.notImplemented
    }

    func accountAssets(
        accountID: String,
        baseURL: String?,
        limit: Int?,
        offset: Int64?,
        countMode: IrohaToriiCountMode?,
        asset: String?,
        scope: String?,
        network: UniversalWalletRegistry.IrohaNetwork
    ) async throws -> IrohaAccountAssetListResponse {
        accountAssetsInvocations.append(
            AccountAssetsInvocation(
                accountID: accountID,
                baseURL: baseURL,
                limit: limit,
                offset: offset,
                countMode: countMode,
                asset: asset,
                scope: scope,
                network: network
            )
        )

        if let accountAssetsError {
            throw accountAssetsError
        }

        return accountAssetsResponse
    }

    func assetDefinitions(baseURL _: String?) async throws -> IrohaAssetDefinitionListResponse {
        throw AccountInfoRemoteServiceStubError.notImplemented
    }

    func submitTransaction(noritoBytes _: Data, baseURL _: String?) async throws -> IrohaTransactionSubmissionReceipt {
        throw AccountInfoRemoteServiceStubError.notImplemented
    }

    func transactionStatus(
        hash _: String,
        baseURL _: String?,
        scope _: IrohaTransactionStatusScope
    ) async throws -> IrohaPipelineTransactionStatusResponse {
        throw AccountInfoRemoteServiceStubError.notImplemented
    }

    func mcpCapabilities(
        network _: UniversalWalletRegistry.IrohaNetwork,
        baseURL _: String?
    ) async throws -> Data {
        throw AccountInfoRemoteServiceStubError.notImplemented
    }

    func mcpJSONRPC(
        _: IrohaMcpJsonRPCRequest,
        network _: UniversalWalletRegistry.IrohaNetwork,
        baseURL _: String?
    ) async throws -> IrohaMcpJsonRPCResponse {
        throw AccountInfoRemoteServiceStubError.notImplemented
    }
}

private enum AccountInfoRemoteServiceStubError: Error {
    case notImplemented
}

private final class StorageRequestPerformerStub: SSFStorageQueryKit.StorageRequestPerformer {
    var performMixInvocations = 0
    var lastMixRequests: [any MixStorageRequest] = []

    func performSingle<T: Decodable>(
        _: SSFStorageQueryKit.StorageRequest,
        chain _: ChainModel
    ) async throws -> T? { nil }

    func performSingle<T: Decodable>(
        _: SSFStorageQueryKit.StorageRequest,
        withCacheOptions _: SSFStorageQueryKit.CachedStorageRequestTrigger,
        chain _: ChainModel
    ) async -> AsyncThrowingStream<SSFStorageQueryKit.CachedStorageResponse<T>, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func performMultiple<K: Decodable & Hashable, T: Decodable>(
        _: SSFStorageQueryKit.MultipleRequest,
        chain _: ChainModel
    ) async throws -> [K: T]? { nil }

    func performMultiple<K: Decodable & ScaleCodable & Hashable, T: Decodable>(
        _: SSFStorageQueryKit.MultipleRequest,
        withCacheOptions _: SSFStorageQueryKit.CachedStorageRequestTrigger,
        chain _: ChainModel
    ) async -> AsyncThrowingStream<SSFStorageQueryKit.CachedStorageResponse<[K: T]>, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func performPrefix<K: Decodable & ScaleCodable & Hashable, T: Decodable>(
        _: SSFStorageQueryKit.PrefixRequest,
        withCacheOptions _: SSFStorageQueryKit.CachedStorageRequestTrigger,
        chain _: ChainModel
    ) async -> AsyncThrowingStream<SSFStorageQueryKit.CachedStorageResponse<[K: T]>, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func performPrefix<K: Decodable & Hashable, T: Decodable>(
        _: SSFStorageQueryKit.PrefixRequest,
        chain _: ChainModel
    ) async throws -> [K: T]? { nil }

    func perform(
        _ requests: [any MixStorageRequest],
        chain _: ChainModel
    ) async throws -> [MixStorageResponse] {
        performMixInvocations += 1
        lastMixRequests = requests
        return []
    }
}
