import Foundation
import HTTPTypes
import OpenAPIRuntime
import TonAPI
import XCTest
@testable import fearless
import SSFModels
import SSFStorageQueryKit
import SSFUtils
import SSFRuntimeCodingService
import BigInt

private func makeIrohaTestHistoryEndpoint(_ baseURL: String) -> ChainModel.BlockExplorer {
    guard let url = URL(string: baseURL),
          let endpoint = ChainModel.BlockExplorer(type: "sora", url: url)
    else {
        preconditionFailure("Iroha test history endpoint failed to materialize")
    }

    return endpoint
}

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

    func testTonCompatibilityChainDetectionByCanonicalIdWithoutMetadataHints() {
        let canonicalIds = [
            TonChainSelection.mainnetChainId,
            TonChainSelection.testnetChainId,
            UniversalWalletRegistry.tonMainnetRegistryEntry.id,
            UniversalWalletRegistry.tonMainnetRegistryEntry.chainId,
            "ton-testnet",
            "ton:testnet"
        ]

        for chainId in canonicalIds {
            let chain = makeTonCompatibilityChain(
                name: "Neutral Chain",
                chainId: chainId,
                nodeURL: URL(string: "wss://rpc.example.com")!,
                explorerURL: URL(string: "https://explorer.example.com/address/abc")!
            )

            XCTAssertTrue(chain.isTonCompatibilityChain, chainId)
        }
    }

    func testTonCompatibilityChainDetectionReturnsFalseForNonTonChain() {
        let nonTonChains = [
            makeTonCompatibilityChain(
                name: "Polkadot",
                chainId: "polkadot-mainnet",
                nodeURL: URL(string: "wss://rpc.polkadot.io")!,
                explorerURL: URL(string: "https://polkadot.subscan.io")!
            ),
            makeTonCompatibilityChain(
                name: "Proton Network",
                chainId: "proton-mainnet",
                nodeURL: URL(string: "wss://button.example.com")!,
                explorerURL: URL(string: "https://tonviewer.com.attacker.invalid/address/abc")!
            ),
            makeTonCompatibilityChain(
                name: "Button Chain",
                chainId: "custom-ton-like",
                nodeURL: URL(string: "wss://nottonapi.io.attacker.invalid")!,
                explorerURL: URL(string: "https://nottonviewer.example.com/address/abc")!
            )
        ]

        for chain in nonTonChains {
            XCTAssertFalse(chain.isTonCompatibilityChain, chain.chainId)
        }
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

    func testSuccessfulJettonResponseZerosKnownOmissionsWithoutTouchingReturnedMaster() {
        let chain = makeChain()
        let returned = makeJetton(id: "master-returned", chain: chain)
        let omitted = makeJetton(id: "master-omitted", chain: chain)

        let reconciled = TonRemoteBalanceFetchingImpl.reconcileKnownJettons(
            known: [returned, omitted],
            fetched: [(returned, AccountInfo(ethBalance: BigUInt(42)))]
        )
        let values = Dictionary(uniqueKeysWithValues: reconciled.map {
            ($0.0.assetKey, $0.1.data.sendAvailable)
        })

        XCTAssertEqual(values[returned.assetKey], BigUInt(42))
        XCTAssertEqual(values[omitted.assetKey], .zero)
    }

    func testJettonReconciliationDoesNotMergeSameSymbolMasters() {
        let chain = makeChain()
        let first = makeJetton(id: "master-a", chain: chain)
        let second = makeJetton(id: "master-b", chain: chain)

        let reconciled = TonRemoteBalanceFetchingImpl.reconcileKnownJettons(
            known: [first, second],
            fetched: [(first, AccountInfo(ethBalance: BigUInt(7)))]
        )

        XCTAssertEqual(Set(reconciled.map { $0.0.assetKey }), Set([first.assetKey, second.assetKey]))
        XCTAssertEqual(
            reconciled.first { $0.0.assetKey == second.assetKey }?.1.data.sendAvailable,
            .zero
        )
    }

    private func makeChain() -> ChainModel {
        ChainModel(
            rank: nil,
            disabled: false,
            chainId: "ton:mainnet",
            parentId: nil,
            paraId: nil,
            name: "TON",
            assets: [],
            xcm: nil,
            nodes: [],
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

    private func makeJetton(id: String, chain: ChainModel) -> ChainAsset {
        ChainAsset(
            chain: chain,
            asset: AssetModel(
                id: id,
                name: "Same symbol Jetton",
                symbol: "SAME",
                precision: 9,
                currencyId: id,
                isUtility: false,
                isNative: false,
                type: .xcm
            )
        )
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

    func testFetchAccountInfosUsesLimitedDirectAddressCoverageWithoutMnemonic() async throws {
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

        let nativeInfo = try XCTUnwrap(result[Self.btcAsset.chainAssetId(chainId: chain.chainId)] ?? nil)
        XCTAssertEqual(nativeInfo.data.free, BigUInt(1))
        XCTAssertEqual(bitcoinSync.invocations.count, 0)
        XCTAssertEqual(bitcoinSync.addressInvocations.count, 1)
        XCTAssertEqual(bitcoinSync.addressInvocations.first?.network, .mainnet)
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

        do {
            _ = try await service.fetchAccountInfos(for: chain, wallet: wallet)
            XCTFail("Bitcoin indexer failures must propagate for last-known balance recovery")
        } catch TestError.indexerUnavailable {
            // Expected fail-closed signal.
        } catch {
            XCTFail("Unexpected Bitcoin indexer error: \(error)")
        }
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
        XCTAssertEqual(solanaSync.invocations.first?.includeTokenMetadata, true)
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

        do {
            _ = try await service.fetchAccountInfos(for: chain, wallet: wallet)
            XCTFail("Solana indexer failures must propagate for last-known balance recovery")
        } catch TestError.indexerUnavailable {
            // Expected fail-closed signal.
        } catch {
            XCTFail("Unexpected Solana indexer error: \(error)")
        }
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
        XCTAssertEqual(client.accountAssetsInvocations.first?.baseURL, "https://taira.sora.org/")
        XCTAssertEqual(client.accountAssetsInvocations.first?.limit, IrohaToriiRoutes.maxLimit)
        XCTAssertEqual(client.accountAssetsInvocations.first?.countMode, .bounded)
        XCTAssertEqual(client.accountAssetsInvocations.first?.network, UniversalWalletRegistry.taira)
        XCTAssertEqual(storagePerformer.performMixInvocations, 0)

        let balance = try XCTUnwrap(result[Self.irohaToriiAsset.chainAssetId(chainId: chain.chainId)] ?? nil)
        let expectedBalance = try XCTUnwrap(BigUInt("1750000000000000000"))
        XCTAssertEqual(balance.data.free, expectedBalance)
    }

    func testProductionTairaCatalogMapsCanonicalXORAtLivePrecision() async throws {
        let chain = UniversalWalletRegistry.tairaChainModel
        let asset = try XCTUnwrap(chain.assets.first)
        let wallet = try walletWithIrohaAccount(chainId: chain.chainId)
        let address = try XCTUnwrap(
            UniversalWalletAccountAddressResolver.address(for: chain, wallet: wallet)
        )
        let client = IrohaToriiClientStub(
            accountAssetsResponse: IrohaAccountAssetListResponse(
                items: [
                    IrohaAccountAssetListItem(
                        accountID: address,
                        asset: UniversalWalletRegistry.tairaNativeXorAssetDefinitionId,
                        assetID: UniversalWalletRegistry.tairaNativeXorAssetDefinitionId,
                        assetName: "xor",
                        assetAlias: UniversalWalletRegistry.tairaNativeXorAlias,
                        quantity: "1.25",
                        scope: "global"
                    )
                ],
                hasMore: false,
                countMode: IrohaToriiCountMode.bounded.rawValue,
                total: 1
            )
        )
        let service = makeAccountInfoRemoteService(irohaToriiClient: client)

        let result = try await service.fetchAccountInfos(for: chain, wallet: wallet)

        let balance = try XCTUnwrap(result[asset.chainAssetId(chainId: chain.chainId)] ?? nil)
        XCTAssertEqual(asset.precision, 9)
        XCTAssertEqual(balance.data.free, BigUInt(1_250_000_000))
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

    func testFetchAccountInfosPaginatesIrohaHoldingsBeyondFiveHundredItems() async throws {
        let chain = makeIrohaChain(
            chainId: UniversalWalletRegistry.taira.chainId,
            assets: [Self.irohaToriiAsset]
        )
        let wallet = try walletWithIrohaAccount(chainId: chain.chainId)
        let address = try IrohaKeyDerivation.deriveAddress(
            mnemonic: Self.mnemonic,
            chainDiscriminant: UniversalWalletRegistry.taira.chainDiscriminant
        ).i105
        let firstPageItems = (0 ..< IrohaToriiRoutes.maxLimit).map { _ in
            IrohaAccountAssetListItem(
                accountID: address,
                asset: Self.irohaToriiAsset.id,
                assetID: nil,
                assetName: nil,
                assetAlias: nil,
                quantity: "0.001",
                scope: "global"
            )
        }
        let finalItem = IrohaAccountAssetListItem(
            accountID: address,
            asset: Self.irohaToriiAsset.id,
            assetID: nil,
            assetName: nil,
            assetAlias: nil,
            quantity: "1",
            scope: "bonus"
        )
        let client = IrohaToriiClientStub(
            accountAssetsResponses: [
                IrohaAccountAssetListResponse(
                    items: firstPageItems,
                    hasMore: true,
                    countMode: IrohaToriiCountMode.bounded.rawValue,
                    total: 501
                ),
                IrohaAccountAssetListResponse(
                    items: [finalItem],
                    hasMore: false,
                    countMode: IrohaToriiCountMode.bounded.rawValue,
                    total: 501
                )
            ]
        )
        let service = makeAccountInfoRemoteService(irohaToriiClient: client)

        let result = try await service.fetchAccountInfos(for: chain, wallet: wallet)

        XCTAssertEqual(client.accountAssetsInvocations.map(\.offset), [0, 500])
        let balance = try XCTUnwrap(result[Self.irohaToriiAsset.chainAssetId(chainId: chain.chainId)] ?? nil)
        XCTAssertEqual(balance.data.free, BigUInt("1500000000000000000"))
    }

    func testFetchAccountInfosFailsClosedForIrohaChainsWithoutSubstrateStorage() async {
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

            do {
                _ = try await service.fetchAccountInfos(
                    for: chain,
                    wallet: AccountGenerator.generateMetaAccount()
                )
                XCTFail("Expected missing Iroha account to fail for \(chainId)")
            } catch {
                XCTAssertTrue(
                    String(describing: error).contains(
                        "Iroha account address is unavailable"
                    )
                )
            }
            XCTAssertEqual(ethereumFetching.fetchManyInvocations, 0)
            XCTAssertEqual(tonService.fetchInfosInvocations, 0)
            XCTAssertEqual(storagePerformer.performMixInvocations, 0)
        }
    }

    func testFetchAccountInfoFailsClosedForIrohaChainAssetWithoutSubstrateStorage() async {
        let chain = makeIrohaChain(chainId: UniversalWalletRegistry.taira.chainId)
        let chainAsset = ChainAsset(chain: chain, asset: Self.irohaAsset)
        let storagePerformer = StorageRequestPerformerStub()
        let service = makeAccountInfoRemoteService(
            irohaToriiClient: IrohaToriiClientStub(),
            storagePerformer: storagePerformer
        )

        do {
            _ = try await service.fetchAccountInfo(
                for: chainAsset,
                wallet: AccountGenerator.generateMetaAccount()
            )
            XCTFail("Expected missing Iroha account to fail")
        } catch {
            XCTAssertTrue(
                String(describing: error).contains(
                    "Iroha account address is unavailable"
                )
            )
        }
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
                history: makeIrohaTestHistoryEndpoint($0),
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

    #if DEBUG
    func testPrepareDependenciesRoutesNativeTonMainnetToTonTransferService() async throws {
        let chain = makeTonTransferChain()
        let wallet = try walletWithTonAccount(chainId: chain.chainId)
        let remote = TonTransferRemoteStub()
        let container = SendDepencyContainer(
            wallet: wallet,
            operationManager: fearless.OperationManagerFacade.sharedManager,
            tonRemote: remote,
            tonMnemonicProvider: UniversalWalletMnemonicProviderStub(mnemonic: Self.mnemonic),
            tonSendReleasePolicy: .enabledForTests
        )

        let dependencies = try await container.prepareDepencies(
            chainAsset: ChainAsset(chain: chain, asset: Self.tonAsset)
        )

        XCTAssertTrue(dependencies.transferService is TonTransferService)
        XCTAssertEqual(remote.walletStateCallCount, 0)
        XCTAssertEqual(remote.emulateCallCount, 0)
        XCTAssertEqual(remote.broadcastCallCount, 0)
    }

    func testPrepareDependenciesCachesOneTonServiceAcrossConcurrentEstimateAndSubmit() async throws {
        let chain = makeTonTransferChain()
        let wallet = try walletWithTonAccount(chainId: chain.chainId)
        let remote = TonTransferRemoteStub()
        let container = SendDepencyContainer(
            wallet: wallet,
            operationManager: fearless.OperationManagerFacade.sharedManager,
            tonRemote: remote,
            tonMnemonicProvider: UniversalWalletMnemonicProviderStub(mnemonic: Self.mnemonic),
            tonSendReleasePolicy: .enabledForTests
        )
        let chainAsset = ChainAsset(chain: chain, asset: Self.tonAsset)
        async let first = container.prepareDepencies(chainAsset: chainAsset)
        async let second = container.prepareDepencies(chainAsset: chainAsset)
        let (firstDependencies, secondDependencies) = try await (first, second)

        XCTAssertTrue(
            (firstDependencies.transferService as AnyObject) ===
                (secondDependencies.transferService as AnyObject)
        )

        let recipient = try TonKeyDerivation.deriveAccount(
            mnemonic: Self.otherMnemonic
        ).addressBounceable
        let transfer = Transfer(
            chainAsset: chainAsset,
            amount: BigUInt(100_000_000),
            receiver: recipient,
            tip: nil,
            appId: nil
        )
        _ = try await prepareDisplayedTonFee(
            service: firstDependencies.transferService,
            transfer: transfer
        )
        let hash = try await secondDependencies.transferService.submit(transfer: transfer)
        let acknowledged = await secondDependencies.transferService.acknowledgeSubmittedTransfer(
            hash: hash,
            transfer: transfer
        )

        XCTAssertTrue(acknowledged)
        XCTAssertEqual(hash.count, 64)
        XCTAssertEqual(remote.unsignedEmulateCallCount, 1)
        XCTAssertEqual(remote.signedEmulateCallCount, 1)
        XCTAssertEqual(remote.broadcastCallCount, 1)
    }
    #endif

    func testProductionTonSendPolicyIsImmutableDisabledAndCannotBeBypassedByInjection() async throws {
        XCTAssertFalse(TonProductionSendReleasePolicy.production.isEnabled)
        let chain = makeTonTransferChain()
        let wallet = try walletWithTonAccount(chainId: chain.chainId)
        let remote = TonTransferRemoteStub()
        let container = SendDepencyContainer(
            wallet: wallet,
            operationManager: fearless.OperationManagerFacade.sharedManager,
            tonRemote: remote,
            tonMnemonicProvider: UniversalWalletMnemonicProviderStub(mnemonic: Self.mnemonic)
        )

        do {
            _ = try await container.prepareDepencies(
                chainAsset: ChainAsset(chain: chain, asset: Self.tonAsset)
            )
            XCTFail("Expected production TON send routing to remain disabled")
        } catch let error as UniversalWalletSendRoutingError {
            XCTAssertEqual(error, .tonProductionSendDisabled)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual(remote.walletStateCallCount, 0)
        XCTAssertEqual(remote.emulateCallCount, 0)
        XCTAssertEqual(remote.broadcastCallCount, 0)
    }

    func testProductionTonSendPolicyRejectsCanonicalIdWithoutTonMetadataHints() async throws {
        let chain = makeChain(chainId: TonChainSelection.mainnetChainId)
        XCTAssertTrue(chain.isTonCompatibilityChain)
        let wallet = try walletWithTonAccount(chainId: chain.chainId)
        let remote = TonTransferRemoteStub()
        let container = SendDepencyContainer(
            wallet: wallet,
            operationManager: fearless.OperationManagerFacade.sharedManager,
            tonRemote: remote,
            tonMnemonicProvider: UniversalWalletMnemonicProviderStub(mnemonic: Self.mnemonic)
        )

        do {
            _ = try await container.prepareDepencies(
                chainAsset: ChainAsset(chain: chain, asset: Self.asset)
            )
            XCTFail("Expected canonical TON identity to remain disabled without metadata hints")
        } catch let error as UniversalWalletSendRoutingError {
            XCTAssertEqual(error, .tonProductionSendDisabled)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual(remote.walletStateCallCount, 0)
        XCTAssertEqual(remote.emulateCallCount, 0)
        XCTAssertEqual(remote.broadcastCallCount, 0)
    }

    #if DEBUG
    func testPrepareDependenciesRejectsJettonBeforeAnyTonRemoteCall() async throws {
        let chain = makeTonTransferChain()
        let wallet = try walletWithTonAccount(chainId: chain.chainId)
        let remote = TonTransferRemoteStub()
        let jetton = AssetModel(
            id: "jetton-master",
            name: "Jetton",
            symbol: "JET",
            precision: 9,
            isUtility: false,
            isNative: false,
            type: .ormlAsset
        )
        let container = SendDepencyContainer(
            wallet: wallet,
            operationManager: fearless.OperationManagerFacade.sharedManager,
            tonRemote: remote,
            tonMnemonicProvider: UniversalWalletMnemonicProviderStub(mnemonic: Self.mnemonic),
            tonSendReleasePolicy: .enabledForTests
        )

        do {
            _ = try await container.prepareDepencies(
                chainAsset: ChainAsset(chain: chain, asset: jetton)
            )
            XCTFail("Expected unsupported Jetton routing to fail closed")
        } catch let error as UniversalWalletSendRoutingError {
            XCTAssertEqual(error, .unsupported(chainId: "-239/jetton-master"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual(remote.walletStateCallCount, 0)
        XCTAssertEqual(remote.emulateCallCount, 0)
        XCTAssertEqual(remote.broadcastCallCount, 0)
    }

    func testPrepareDependenciesRejectsTonTestnetBeforeAnyRemoteCall() async throws {
        let chain = makeTonTransferChain(chainId: TonChainSelection.testnetChainId)
        let wallet = try walletWithTonAccount(chainId: chain.chainId)
        let remote = TonTransferRemoteStub()
        let container = SendDepencyContainer(
            wallet: wallet,
            operationManager: fearless.OperationManagerFacade.sharedManager,
            tonRemote: remote,
            tonMnemonicProvider: UniversalWalletMnemonicProviderStub(mnemonic: Self.mnemonic),
            tonSendReleasePolicy: .enabledForTests
        )

        do {
            _ = try await container.prepareDepencies(
                chainAsset: ChainAsset(chain: chain, asset: Self.tonAsset)
            )
            XCTFail("Expected TON testnet routing to fail closed")
        } catch let error as UniversalWalletSendRoutingError {
            XCTAssertEqual(error, .unsupported(chainId: TonChainSelection.testnetChainId))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual(remote.walletStateCallCount, 0)
        XCTAssertEqual(remote.emulateCallCount, 0)
        XCTAssertEqual(remote.broadcastCallCount, 0)
    }

    func testTonTransferServiceBindsMnemonicSenderAndBroadcastsEmulatedBoc() async throws {
        let chain = makeTonTransferChain()
        let wallet = try walletWithTonAccount(chainId: chain.chainId)
        let recipient = try TonKeyDerivation.deriveAccount(
            mnemonic: Self.otherMnemonic
        ).addressBounceable
        let remote = TonTransferRemoteStub()
        let service = TonTransferService(
            wallet: wallet,
            chain: chain,
            remote: remote,
            mnemonicProvider: UniversalWalletMnemonicProviderStub(mnemonic: Self.mnemonic),
            pendingCoordinator: TonPendingIntentCoordinator(),
            clock: { 1_700_000_000 }
        )
        let transfer = Transfer(
            chainAsset: ChainAsset(chain: chain, asset: Self.tonAsset),
            amount: BigUInt(100_000_000),
            receiver: recipient,
            tip: nil,
            appId: nil
        )

        let fee = try await prepareDisplayedTonFee(service: service, transfer: transfer)
        let hash = try await service.submit(transfer: transfer)

        XCTAssertEqual(fee, BigUInt(1))
        XCTAssertEqual(hash.count, 64)
        XCTAssertEqual(remote.walletStateCallCount, 2)
        XCTAssertEqual(remote.emulateCallCount, 2)
        XCTAssertEqual(remote.broadcastCallCount, 1)
        XCTAssertEqual(remote.broadcastBocs, [try XCTUnwrap(remote.emulatedBocs.last)])
    }

    func testTonQuoteCannotSubmitUntilExactPresentationIsAcknowledged() async throws {
        let chain = makeTonTransferChain()
        let wallet = try walletWithTonAccount(chainId: chain.chainId)
        let recipient = try TonKeyDerivation.deriveAccount(
            mnemonic: Self.otherMnemonic
        ).addressBounceable
        let remote = TonTransferRemoteStub()
        let mnemonicProvider = CountingUniversalWalletMnemonicProvider(mnemonic: Self.mnemonic)
        let service = TonTransferService(
            wallet: wallet,
            chain: chain,
            remote: remote,
            mnemonicProvider: mnemonicProvider,
            pendingCoordinator: TonPendingIntentCoordinator(),
            clock: { 1_700_000_000 }
        )
        let transfer = Transfer(
            chainAsset: ChainAsset(chain: chain, asset: Self.tonAsset),
            amount: BigUInt(100_000_000),
            receiver: recipient,
            tip: nil,
            appId: nil
        )
        let received = expectation(description: "staged TON quote")
        let listener = TonFeePresentationListenerStub(expectation: received)
        service.subscribeForFee(transfer: transfer, listener: listener)
        await fulfillment(of: [received], timeout: 2)
        let walletCallsAfterQuote = remote.walletStateCallCount
        let emulationCallsAfterQuote = remote.emulateCallCount

        do {
            _ = try await service.submit(transfer: transfer)
            XCTFail("A staged but undisplayed TON quote was submitted")
        } catch TransferServiceError.transferFailed {}
        XCTAssertEqual(mnemonicProvider.callCount, 0)
        XCTAssertEqual(remote.walletStateCallCount, walletCallsAfterQuote)
        XCTAssertEqual(remote.emulateCallCount, emulationCallsAfterQuote)
        XCTAssertEqual(remote.broadcastCallCount, 0)

        let presentationAccepted = await service.confirmFeePresentation(
            id: try XCTUnwrap(listener.presentationID),
            fee: try XCTUnwrap(listener.fee)
        )
        XCTAssertTrue(presentationAccepted)
        _ = try await service.submit(transfer: transfer)
        XCTAssertEqual(mnemonicProvider.callCount, 1)
        XCTAssertEqual(remote.signedEmulateCallCount, 1)
        XCTAssertEqual(remote.broadcastCallCount, 1)
    }

    func testTonDirectEstimateNeverAuthorizesSubmission() async throws {
        let chain = makeTonTransferChain()
        let wallet = try walletWithTonAccount(chainId: chain.chainId)
        let recipient = try TonKeyDerivation.deriveAccount(
            mnemonic: Self.otherMnemonic
        ).addressBounceable
        let remote = TonTransferRemoteStub()
        let mnemonicProvider = CountingUniversalWalletMnemonicProvider(mnemonic: Self.mnemonic)
        let service = TonTransferService(
            wallet: wallet,
            chain: chain,
            remote: remote,
            mnemonicProvider: mnemonicProvider,
            pendingCoordinator: TonPendingIntentCoordinator(),
            clock: { 1_700_000_000 }
        )
        let transfer = Transfer(
            chainAsset: ChainAsset(chain: chain, asset: Self.tonAsset),
            amount: BigUInt(100_000_000),
            receiver: recipient,
            tip: nil,
            appId: nil
        )

        _ = try await service.estimateFee(for: transfer)
        do {
            _ = try await service.submit(transfer: transfer)
            XCTFail("A fee calculated without an opaque presentation ID authorized submission")
        } catch TransferServiceError.transferFailed {}

        XCTAssertEqual(mnemonicProvider.callCount, 0)
        XCTAssertEqual(remote.signedEmulateCallCount, 0)
        XCTAssertEqual(remote.broadcastCallCount, 0)
    }

    func testTonUnsubscribeSynchronouslyRevokesQuoteBeforeImmediateSubmit() async throws {
        let chain = makeTonTransferChain()
        let wallet = try walletWithTonAccount(chainId: chain.chainId)
        let recipient = try TonKeyDerivation.deriveAccount(
            mnemonic: Self.otherMnemonic
        ).addressBounceable
        let remote = TonTransferRemoteStub()
        let mnemonicProvider = CountingUniversalWalletMnemonicProvider(mnemonic: Self.mnemonic)
        let service = TonTransferService(
            wallet: wallet,
            chain: chain,
            remote: remote,
            mnemonicProvider: mnemonicProvider,
            pendingCoordinator: TonPendingIntentCoordinator(),
            clock: { 1_700_000_000 }
        )
        let transfer = Transfer(
            chainAsset: ChainAsset(chain: chain, asset: Self.tonAsset),
            amount: BigUInt(100_000_000),
            receiver: recipient,
            tip: nil,
            appId: nil
        )
        _ = try await prepareDisplayedTonFee(service: service, transfer: transfer)
        let walletCallsAfterQuote = remote.walletStateCallCount
        let emulationCallsAfterQuote = remote.emulateCallCount

        service.unsubscribe()
        do {
            _ = try await service.submit(transfer: transfer)
            XCTFail("An unsubscribed TON quote was submitted")
        } catch TransferServiceError.transferFailed {}

        XCTAssertEqual(mnemonicProvider.callCount, 0)
        XCTAssertEqual(remote.walletStateCallCount, walletCallsAfterQuote)
        XCTAssertEqual(remote.emulateCallCount, emulationCallsAfterQuote)
        XCTAssertEqual(remote.broadcastCallCount, 0)
    }

    func testTonRestartRecoverySucceedsWithoutMnemonicAndWithoutNewBearer() async throws {
        let chain = makeTonTransferChain()
        let wallet = try walletWithTonAccount(chainId: chain.chainId)
        let recipient = try TonKeyDerivation.deriveAccount(
            mnemonic: Self.otherMnemonic
        ).addressBounceable
        let transfer = Transfer(
            chainAsset: ChainAsset(chain: chain, asset: Self.tonAsset),
            amount: BigUInt(100_000_000),
            receiver: recipient,
            tip: nil,
            appId: nil
        )
        let journal = TonInMemoryPendingIntentJournal()
        let firstRemote = TonTransferRemoteStub()
        firstRemote.reconciliationResult = .notFound
        let firstService = TonTransferService(
            wallet: wallet,
            chain: chain,
            remote: firstRemote,
            mnemonicProvider: UniversalWalletMnemonicProviderStub(mnemonic: Self.mnemonic),
            pendingCoordinator: TonPendingIntentCoordinator(journal: journal),
            clock: { 1_700_000_000 }
        )
        _ = try await prepareDisplayedTonFee(service: firstService, transfer: transfer)
        let oldHash: String
        do {
            _ = try await firstService.submit(transfer: transfer)
            return XCTFail("Expected first outcome to remain unknown")
        } catch let TransferServiceError.tonBroadcastOutcomeUnknown(messageHashHex) {
            oldHash = messageHashHex
        }

        let missingMnemonic = CountingUniversalWalletMnemonicProvider(mnemonic: nil)
        let recoveryRemote = TonTransferRemoteStub()
        recoveryRemote.reconciliationResult = .confirmed
        let recoveryService = TonTransferService(
            wallet: wallet,
            chain: chain,
            remote: recoveryRemote,
            mnemonicProvider: missingMnemonic,
            pendingCoordinator: TonPendingIntentCoordinator(journal: journal),
            clock: { 1_700_000_000 }
        )
        let recoveredHash = try await recoveryService.submit(transfer: transfer)

        XCTAssertEqual(recoveredHash, oldHash)
        XCTAssertEqual(missingMnemonic.callCount, 0)
        XCTAssertEqual(recoveryRemote.reconcileCallCount, 1)
        XCTAssertEqual(recoveryRemote.walletStateCallCount, 0)
        XCTAssertEqual(recoveryRemote.emulateCallCount, 0)
        XCTAssertEqual(recoveryRemote.broadcastCallCount, 0)
    }

    func testTonDifferentIntentRecoveryNeverReturnsThePriorHashAsNewSuccess() async throws {
        let chain = makeTonTransferChain()
        let wallet = try walletWithTonAccount(chainId: chain.chainId)
        let recipient = try TonKeyDerivation.deriveAccount(
            mnemonic: Self.otherMnemonic
        ).addressBounceable
        let chainAsset = ChainAsset(chain: chain, asset: Self.tonAsset)
        let priorTransfer = Transfer(
            chainAsset: chainAsset,
            amount: BigUInt(100_000_000),
            receiver: recipient,
            tip: nil,
            appId: nil
        )
        let newTransfer = Transfer(
            chainAsset: chainAsset,
            amount: BigUInt(100_000_001),
            receiver: recipient,
            tip: nil,
            appId: nil
        )
        let journal = TonInMemoryPendingIntentJournal()
        let firstRemote = TonTransferRemoteStub()
        firstRemote.reconciliationResult = .notFound
        let firstService = TonTransferService(
            wallet: wallet,
            chain: chain,
            remote: firstRemote,
            mnemonicProvider: UniversalWalletMnemonicProviderStub(mnemonic: Self.mnemonic),
            pendingCoordinator: TonPendingIntentCoordinator(journal: journal),
            clock: { 1_700_000_000 }
        )
        _ = try await prepareDisplayedTonFee(service: firstService, transfer: priorTransfer)
        let priorHash: String
        do {
            _ = try await firstService.submit(transfer: priorTransfer)
            return XCTFail("Expected the prior transfer outcome to remain unknown")
        } catch let TransferServiceError.tonBroadcastOutcomeUnknown(messageHashHex) {
            priorHash = messageHashHex
        }

        let mnemonicProvider = CountingUniversalWalletMnemonicProvider(mnemonic: nil)
        let recoveryRemote = TonTransferRemoteStub()
        recoveryRemote.reconciliationResult = .confirmed
        let recoveryService = TonTransferService(
            wallet: wallet,
            chain: chain,
            remote: recoveryRemote,
            mnemonicProvider: mnemonicProvider,
            pendingCoordinator: TonPendingIntentCoordinator(journal: journal),
            clock: { 1_700_000_000 }
        )
        let recoveredIdentity: TonTransferIntentIdentity
        do {
            _ = try await recoveryService.submit(transfer: newTransfer)
            return XCTFail("The prior transfer hash was reported as the new transfer's success")
        } catch let TransferServiceError.tonPriorTransferConfirmed(identity, messageHashHex) {
            recoveredIdentity = identity
            XCTAssertEqual(messageHashHex, priorHash)
            XCTAssertEqual(identity.amountNanotons, priorTransfer.amount.description)
        }

        XCTAssertEqual(mnemonicProvider.callCount, 0)
        XCTAssertEqual(recoveryRemote.reconcileCallCount, 1)
        XCTAssertEqual(recoveryRemote.walletStateCallCount, 0)
        XCTAssertEqual(recoveryRemote.emulateCallCount, 0)
        XCTAssertEqual(recoveryRemote.broadcastCallCount, 0)
        let acknowledged = await recoveryService.acknowledgeRecoveredTransfer(
            hash: priorHash,
            identity: recoveredIdentity
        )
        XCTAssertTrue(acknowledged)
    }
    #endif

    func testTonFeeEstimateNeverRequestsMnemonicOrProducesSignedEmulation() async throws {
        let chain = makeTonTransferChain()
        let wallet = try walletWithTonAccount(chainId: chain.chainId)
        let recipient = try TonKeyDerivation.deriveAccount(
            mnemonic: Self.otherMnemonic
        ).addressBounceable
        let remote = TonTransferRemoteStub()
        let mnemonicProvider = CountingUniversalWalletMnemonicProvider(
            mnemonic: Self.mnemonic
        )
        let service = TonTransferService(
            wallet: wallet,
            chain: chain,
            remote: remote,
            mnemonicProvider: mnemonicProvider,
            clock: { 1_700_000_000 }
        )
        let transfer = Transfer(
            chainAsset: ChainAsset(chain: chain, asset: Self.tonAsset),
            amount: BigUInt(100_000_000),
            receiver: recipient,
            tip: nil,
            appId: nil
        )

        let estimatedFee = try await service.estimateFee(for: transfer)

        XCTAssertEqual(estimatedFee, BigUInt(1))
        XCTAssertEqual(mnemonicProvider.callCount, 0)
        XCTAssertEqual(remote.unsignedEmulateCallCount, 1)
        XCTAssertEqual(remote.signedEmulateCallCount, 0)
        XCTAssertEqual(remote.broadcastCallCount, 0)
    }

    func testTonFeePaymentAssetIgnoresAdditionalUnorderedUtilityAssets() {
        let hostileUtility = AssetModel(
            id: "hostile-utility",
            name: "Hostile Utility",
            symbol: "HST",
            precision: 2,
            isUtility: true,
            isNative: false,
            type: .ormlAsset
        )
        let chain = makeTonTransferChain(assets: [hostileUtility, Self.tonAsset])
        let selectedTon = ChainAsset(chain: chain, asset: Self.tonAsset)

        let feeAsset = WalletSendConfirmInteractor.resolveFeePaymentChainAsset(
            for: selectedTon
        )

        XCTAssertEqual(feeAsset?.asset.id, Self.tonAsset.id)
        XCTAssertEqual(feeAsset?.asset.symbol, "TON")
        XCTAssertEqual(feeAsset?.asset.precision, 9)
    }

    #if !DEBUG
    func testReleaseTonTransferSubmitFailsBeforeMnemonicOrRemoteWork() async {
        let chain = makeChain(chainId: TonChainSelection.mainnetChainId)
        let mnemonicProvider = CountingUniversalWalletMnemonicProvider(
            mnemonic: Self.mnemonic
        )
        let remote = TonTransferRemoteStub()
        let service = TonTransferService(
            wallet: AccountGenerator.generateMetaAccount(),
            chain: chain,
            remote: remote,
            mnemonicProvider: mnemonicProvider,
            clock: { 1_700_000_000 }
        )
        let invalidTransfer = Transfer(
            chainAsset: ChainAsset(chain: chain, asset: Self.asset),
            amount: 0,
            receiver: "intentionally invalid",
            tip: nil,
            appId: nil
        )

        do {
            _ = try await service.submit(transfer: invalidTransfer)
            XCTFail("Expected Release TON submit to remain disabled")
        } catch TransferServiceError.tonProductionSendDisabled {
            // Expected before transfer resolution, mnemonic lookup, or remote work.
        } catch {
            XCTFail("Unexpected Release TON submit error: \(error)")
        }

        XCTAssertEqual(mnemonicProvider.callCount, 0)
        XCTAssertEqual(remote.walletStateCallCount, 0)
        XCTAssertEqual(remote.emulateCallCount, 0)
        XCTAssertEqual(remote.broadcastCallCount, 0)
    }
    #endif

    #if DEBUG
    func testTonTransferServicePreservesExactUnknownOutcomeHash() async throws {
        let chain = makeTonTransferChain()
        let wallet = try walletWithTonAccount(chainId: chain.chainId)
        let recipient = try TonKeyDerivation.deriveAccount(
            mnemonic: Self.otherMnemonic
        ).addressBounceable
        let remote = TonTransferRemoteStub()
        remote.reconciliationResult = .notFound
        let service = TonTransferService(
            wallet: wallet,
            chain: chain,
            remote: remote,
            mnemonicProvider: UniversalWalletMnemonicProviderStub(mnemonic: Self.mnemonic),
            pendingCoordinator: TonPendingIntentCoordinator(),
            clock: { 1_700_000_000 }
        )
        let transfer = Transfer(
            chainAsset: ChainAsset(chain: chain, asset: Self.tonAsset),
            amount: BigUInt(100_000_000),
            receiver: recipient,
            tip: nil,
            appId: nil
        )

        _ = try await prepareDisplayedTonFee(service: service, transfer: transfer)
        do {
            _ = try await service.submit(transfer: transfer)
            XCTFail("Expected an explicitly unknown broadcast outcome")
        } catch let TransferServiceError.tonBroadcastOutcomeUnknown(messageHashHex) {
            XCTAssertEqual(messageHashHex, remote.broadcastMessageHashes.first)
            XCTAssertEqual(messageHashHex.count, 64)
        } catch {
            XCTFail("Unexpected TON submit error: \(error)")
        }
        XCTAssertEqual(remote.broadcastCallCount, 1)
    }

    func testTonTransferServiceRejectsMnemonicMismatchBeforeRemoteCalls() async throws {
        let chain = makeTonTransferChain()
        let wallet = try walletWithTonAccount(chainId: chain.chainId)
        let recipient = try TonKeyDerivation.deriveAccount(
            mnemonic: Self.otherMnemonic
        ).addressBounceable
        let remote = TonTransferRemoteStub()
        let service = TonTransferService(
            wallet: wallet,
            chain: chain,
            remote: remote,
            mnemonicProvider: UniversalWalletMnemonicProviderStub(mnemonic: Self.otherMnemonic),
            pendingCoordinator: TonPendingIntentCoordinator(),
            clock: { 1_700_000_000 }
        )
        let transfer = Transfer(
            chainAsset: ChainAsset(chain: chain, asset: Self.tonAsset),
            amount: BigUInt(100_000_000),
            receiver: recipient,
            tip: nil,
            appId: nil
        )

        _ = try await prepareDisplayedTonFee(service: service, transfer: transfer)
        let walletCallsBeforeSubmit = remote.walletStateCallCount
        let emulationCallsBeforeSubmit = remote.emulateCallCount
        do {
            _ = try await service.submit(transfer: transfer)
            XCTFail("Expected mismatched TON mnemonic to fail closed")
        } catch TransferServiceError.transferFailed {}

        XCTAssertEqual(remote.walletStateCallCount, walletCallsBeforeSubmit)
        XCTAssertEqual(remote.emulateCallCount, emulationCallsBeforeSubmit)
        XCTAssertEqual(remote.unsignedEmulateCallCount, 1)
        XCTAssertEqual(remote.signedEmulateCallCount, 0)
        XCTAssertEqual(remote.broadcastCallCount, 0)
    }
    #endif

    #if DEBUG
    func testTonTransferServiceRejectsUnsupportedTipAndAppIdBeforeRemoteCalls() async throws {
        let chain = makeTonTransferChain()
        let wallet = try walletWithTonAccount(chainId: chain.chainId)
        let recipient = try TonKeyDerivation.deriveAccount(
            mnemonic: Self.otherMnemonic
        ).addressBounceable

        let unsupportedFields: [(tip: BigUInt?, appId: BigUInt?)] = [
            (BigUInt(1), nil),
            (nil, BigUInt(1)),
            (BigUInt(1), BigUInt(1))
        ]
        for (tip, appId) in unsupportedFields {
            let remote = TonTransferRemoteStub()
            let service = TonTransferService(
                wallet: wallet,
                chain: chain,
                remote: remote,
                mnemonicProvider: UniversalWalletMnemonicProviderStub(mnemonic: Self.mnemonic),
                pendingCoordinator: TonPendingIntentCoordinator(),
                clock: { 1_700_000_000 }
            )
            let transfer = Transfer(
                chainAsset: ChainAsset(chain: chain, asset: Self.tonAsset),
                amount: BigUInt(100_000_000),
                receiver: recipient,
                tip: tip,
                appId: appId
            )

            do {
                _ = try await service.submit(transfer: transfer)
                XCTFail("Expected unsupported TON fields to fail closed")
            } catch TransferServiceError.transferFailed {}

            XCTAssertEqual(remote.walletStateCallCount, 0)
            XCTAssertEqual(remote.emulateCallCount, 0)
            XCTAssertEqual(remote.broadcastCallCount, 0)
        }
    }
    #endif

    func testProductionSendDependenciesRejectIrohaBeforeServiceConstruction() async throws {
        for chainId in [
            UniversalWalletRegistry.taira.chainId,
            UniversalWalletRegistry.nexus.chainId
        ] {
            let chain = makeIrohaChain(chainId: chainId)
            let wallet = AccountGenerator.generateMetaAccount()
            let container = SendDepencyContainer(
                wallet: wallet,
                operationManager: fearless.OperationManagerFacade.sharedManager
            )

            do {
                _ = try await container.prepareDepencies(
                    chainAsset: ChainAsset(chain: chain, asset: Self.irohaAsset)
                )
                XCTFail("Expected Iroha send routing to remain disabled for \(chainId)")
            } catch let error as UniversalWalletSendRoutingError {
                XCTAssertEqual(error, .irohaProductionSendDisabled)
            } catch {
                XCTFail("Unexpected Iroha send-routing error: \(error)")
            }
        }
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
        XCTAssertEqual(signer.lastRequest?.metadata, IrohaTransactionMetadata.none)
        XCTAssertEqual(signer.lastRequest?.metadata.values, [:])
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
        XCTAssertEqual(signer.lastRequest?.metadata, IrohaTransactionMetadata.none)
        XCTAssertEqual(signer.lastRequest?.metadata.values, [:])
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

    func testIrohaNexusWalletSmokeEvidenceThreadsExactImmutableMetadataToSigner() async throws {
        let chain = makeIrohaChain(
            chainId: UniversalWalletRegistry.nexus.chainId,
            historyBaseURL: "https://minamoto.sora.org"
        )
        let wallet = try walletWithIrohaAccount(chainId: chain.chainId)
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
            amount: BigUInt("1000000000000000000"),
            receiver: recipientAddress,
            tip: nil,
            appId: nil
        )
        var operatorInput = Self.validIrohaWalletSmokeMetadata
        let expectedSnapshot = operatorInput

        let hash = try await service.submitNexusWalletSmokeEvidence(
            transfer: transfer,
            untrustedMetadata: operatorInput
        )
        operatorInput[IrohaWalletSmokeTransactionMetadata.walletCommitKey] = String(repeating: "b", count: 40)

        XCTAssertEqual(hash, Self.signedTransactionHash)
        XCTAssertEqual(signer.lastRequest?.network, "nexus")
        XCTAssertEqual(signer.lastRequest?.metadata.values, expectedSnapshot)
        XCTAssertEqual(signer.lastRequest?.metadata.values.count, 4)
        XCTAssertEqual(toriiClient.lastSubmittedNorito, Self.signedTransaction)
        XCTAssertEqual(toriiClient.lastSubmitBaseURL, "https://minamoto.sora.org")
    }

    func testIrohaWalletSmokeMetadataSnapshotDoesNotAliasInputOrReturnedValues() throws {
        var operatorInput = Self.validIrohaWalletSmokeMetadata
        let expectedSnapshot = operatorInput
        let metadata = try IrohaWalletSmokeTransactionMetadata.validatedSnapshot(of: operatorInput)

        operatorInput[IrohaWalletSmokeTransactionMetadata.walletCommitKey] = String(repeating: "b", count: 40)
        var returnedValues = metadata.values
        returnedValues[IrohaWalletSmokeTransactionMetadata.evidenceRoleKey] = "route-canary"

        XCTAssertEqual(metadata.values, expectedSnapshot)
        XCTAssertNotEqual(metadata.values, operatorInput)
        XCTAssertNotEqual(metadata.values, returnedValues)
    }

    func testIrohaNexusWalletSmokeEvidenceRejectsMalformedMetadataBeforeSignerOrTorii() async throws {
        let chain = makeIrohaChain(
            chainId: UniversalWalletRegistry.nexus.chainId,
            historyBaseURL: "https://minamoto.sora.org"
        )
        let wallet = try walletWithIrohaAccount(chainId: chain.chainId)
        let recipientAddress = try IrohaAddressCodec.encode(
            publicKeyHex: String(repeating: "22", count: 32),
            chainDiscriminant: UniversalWalletRegistry.nexus.chainDiscriminant
        )
        let transfer = Transfer(
            chainAsset: ChainAsset(chain: chain, asset: Self.irohaAsset),
            amount: BigUInt("1000000000000000000"),
            receiver: recipientAddress,
            tip: nil,
            appId: nil
        )
        let roleKey = IrohaWalletSmokeTransactionMetadata.evidenceRoleKey
        let routeHashKey = IrohaWalletSmokeTransactionMetadata.routeGovernanceActionHashKey
        let platformKey = IrohaWalletSmokeTransactionMetadata.walletPlatformKey
        let commitKey = IrohaWalletSmokeTransactionMetadata.walletCommitKey
        var cases: [(String, [String: String], IrohaWalletSmokeMetadataError)] = []

        func mutated(
            _ label: String,
            key: String,
            value: String?,
            expected: IrohaWalletSmokeMetadataError
        ) {
            var metadata = Self.validIrohaWalletSmokeMetadata
            metadata[key] = value
            cases.append((label, metadata, expected))
        }

        mutated("missing field", key: roleKey, value: nil, expected: .invalidFieldSet)
        mutated("wrong role", key: roleKey, value: "route-canary", expected: .invalidEvidenceRole)
        mutated("wrong role case", key: roleKey, value: "Wallet-Smoke", expected: .invalidEvidenceRole)
        mutated("wrong platform", key: platformKey, value: "android", expected: .invalidWalletPlatform)
        mutated("wrong platform case", key: platformKey, value: "IOS", expected: .invalidWalletPlatform)
        mutated("hash prefix", key: routeHashKey, value: String(repeating: "1", count: 64), expected: .invalidRouteGovernanceActionHash)
        mutated("short hash", key: routeHashKey, value: "sha256:" + String(repeating: "1", count: 63), expected: .invalidRouteGovernanceActionHash)
        mutated("uppercase hash", key: routeHashKey, value: "sha256:" + String(repeating: "A", count: 64), expected: .invalidRouteGovernanceActionHash)
        mutated("zero hash", key: routeHashKey, value: "sha256:" + String(repeating: "0", count: 64), expected: .invalidRouteGovernanceActionHash)
        mutated("hash control", key: routeHashKey, value: Self.irohaRouteActionHash + "\n", expected: .invalidRouteGovernanceActionHash)
        mutated("hash unicode", key: routeHashKey, value: "sha256:" + String(repeating: "１", count: 64), expected: .invalidRouteGovernanceActionHash)
        mutated("short commit", key: commitKey, value: String(repeating: "a", count: 39), expected: .invalidWalletCommit)
        mutated("uppercase commit", key: commitKey, value: String(repeating: "A", count: 40), expected: .invalidWalletCommit)
        mutated("zero commit", key: commitKey, value: String(repeating: "0", count: 40), expected: .invalidWalletCommit)
        mutated("commit control", key: commitKey, value: Self.irohaWalletCommit + "\u{0000}", expected: .invalidWalletCommit)
        mutated("commit unicode", key: commitKey, value: String(repeating: "ａ", count: 40), expected: .invalidWalletCommit)

        var extra = Self.validIrohaWalletSmokeMetadata
        extra["unexpected"] = "field"
        cases.append(("extra field", extra, .invalidFieldSet))

        var wrongKeyCase = Self.validIrohaWalletSmokeMetadata
        wrongKeyCase[platformKey] = nil
        wrongKeyCase["wallet_Platform"] = "ios"
        cases.append(("wrong key case", wrongKeyCase, .invalidFieldSet))

        var controlKey = Self.validIrohaWalletSmokeMetadata
        controlKey[commitKey] = nil
        controlKey[commitKey + "\n"] = Self.irohaWalletCommit
        cases.append(("control in key", controlKey, .invalidFieldSet))

        var unicodeKey = Self.validIrohaWalletSmokeMetadata
        unicodeKey[commitKey] = nil
        unicodeKey["wallet_commіt"] = Self.irohaWalletCommit
        cases.append(("unicode confusable key", unicodeKey, .invalidFieldSet))

        for (label, metadata, expectedError) in cases {
            let toriiClient = IrohaSubmitClientStub()
            let signer = IrohaTransferSignerStub()
            let mnemonicProvider = CountingUniversalWalletMnemonicProvider(mnemonic: Self.mnemonic)
            let service = IrohaTransferService(
                wallet: wallet,
                chain: chain,
                toriiClient: toriiClient,
                signer: signer,
                mnemonicProvider: mnemonicProvider
            )

            do {
                _ = try await service.submitNexusWalletSmokeEvidence(
                    transfer: transfer,
                    untrustedMetadata: metadata
                )
                XCTFail("Malformed metadata unexpectedly reached the signer: \(label)")
            } catch let error as IrohaWalletSmokeMetadataError {
                XCTAssertEqual(error, expectedError, label)
            } catch {
                XCTFail("Unexpected metadata error for \(label): \(error)")
            }
            XCTAssertEqual(mnemonicProvider.callCount, 0, label)
            XCTAssertNil(signer.lastRequest, label)
            XCTAssertNil(toriiClient.lastSubmittedNorito, label)
        }
        XCTAssertEqual(cases.count, 20)
    }

    func testIrohaWalletSmokeEvidenceRejectsTairaAndNoncanonicalNexusBeforeSignerOrTorii() async throws {
        let configurations: [(
            label: String,
            chainId: String,
            historyBaseURL: String,
            expectedReason: String
        )] = [
            (
                "Taira route",
                UniversalWalletRegistry.taira.chainId,
                "https://taira.sora.org",
                "exact canonical Nexus chain identity"
            ),
            (
                "uppercase Nexus chain-id drift",
                UniversalWalletRegistry.nexus.chainId.uppercased(),
                "https://minamoto.sora.org",
                "exact canonical Nexus chain identity"
            ),
            (
                "Nexus registry-id alias",
                UniversalWalletRegistry.nexus.id,
                "https://minamoto.sora.org",
                "exact canonical Nexus chain identity"
            ),
            (
                "unrelated HTTPS host",
                UniversalWalletRegistry.nexus.chainId,
                "https://nexus-proxy.example",
                "canonical Nexus Torii"
            ),
            (
                "HTTP downgrade",
                UniversalWalletRegistry.nexus.chainId,
                "http://minamoto.sora.org",
                "canonical Nexus Torii"
            ),
            (
                "suffix-confusion host",
                UniversalWalletRegistry.nexus.chainId,
                "https://minamoto.sora.org.attacker.invalid",
                "canonical Nexus Torii"
            ),
            (
                "userinfo host confusion",
                UniversalWalletRegistry.nexus.chainId,
                "https://minamoto.sora.org@attacker.invalid",
                "canonical Nexus Torii"
            ),
            (
                "noncanonical port",
                UniversalWalletRegistry.nexus.chainId,
                "https://minamoto.sora.org:444",
                "canonical Nexus Torii"
            ),
            (
                "path-bearing endpoint",
                UniversalWalletRegistry.nexus.chainId,
                "https://minamoto.sora.org/v1/mcp",
                "canonical Nexus Torii"
            ),
            (
                "query-bearing endpoint",
                UniversalWalletRegistry.nexus.chainId,
                "https://minamoto.sora.org?redirect=https://attacker.invalid",
                "canonical Nexus Torii"
            ),
            (
                "fragment-bearing endpoint",
                UniversalWalletRegistry.nexus.chainId,
                "https://minamoto.sora.org#@attacker.invalid",
                "canonical Nexus Torii"
            ),
            (
                "trailing-slash drift",
                UniversalWalletRegistry.nexus.chainId,
                "https://minamoto.sora.org/",
                "canonical Nexus Torii"
            )
        ]

        XCTAssertEqual(configurations.count, 12)

        for configuration in configurations {
            let chain = makeIrohaChain(
                chainId: configuration.chainId,
                historyBaseURL: configuration.historyBaseURL
            )
            XCTAssertEqual(
                chain.externalApi?.history?.url.absoluteString,
                configuration.historyBaseURL,
                configuration.label
            )
            let wallet = try walletWithIrohaAccount(chainId: chain.chainId)
            let network = configuration.chainId == UniversalWalletRegistry.taira.chainId
                ? UniversalWalletRegistry.taira
                : UniversalWalletRegistry.nexus
            let recipientAddress = try IrohaAddressCodec.encode(
                publicKeyHex: String(repeating: "22", count: 32),
                chainDiscriminant: network.chainDiscriminant
            )
            let toriiClient = IrohaSubmitClientStub()
            let signer = IrohaTransferSignerStub()
            let mnemonicProvider = CountingUniversalWalletMnemonicProvider(mnemonic: Self.mnemonic)
            let service = IrohaTransferService(
                wallet: wallet,
                chain: chain,
                toriiClient: toriiClient,
                signer: signer,
                mnemonicProvider: mnemonicProvider
            )
            let transfer = Transfer(
                chainAsset: ChainAsset(chain: chain, asset: Self.irohaAsset),
                amount: BigUInt("1000000000000000000"),
                receiver: recipientAddress,
                tip: nil,
                appId: nil
            )

            do {
                _ = try await service.submitNexusWalletSmokeEvidence(
                    transfer: transfer,
                    untrustedMetadata: Self.validIrohaWalletSmokeMetadata
                )
                XCTFail("Untrusted evidence route unexpectedly reached signing: \(configuration.label)")
            } catch TransferServiceError.transferFailed(let reason) {
                XCTAssertTrue(
                    reason.contains(configuration.expectedReason),
                    "\(configuration.label): \(reason)"
                )
            } catch {
                XCTFail("Unexpected evidence route error for \(configuration.label): \(error)")
            }
            XCTAssertEqual(mnemonicProvider.callCount, 0, configuration.label)
            XCTAssertNil(signer.lastRequest, configuration.label)
            XCTAssertNil(toriiClient.lastSubmittedNorito, configuration.label)
        }
    }

    func testIrohaWalletSmokeEvidenceRemainsFailClosedWithUnavailableSigner() async throws {
        let chain = makeIrohaChain(
            chainId: UniversalWalletRegistry.nexus.chainId,
            historyBaseURL: "https://minamoto.sora.org"
        )
        let wallet = try walletWithIrohaAccount(chainId: chain.chainId)
        let recipientAddress = try IrohaAddressCodec.encode(
            publicKeyHex: String(repeating: "22", count: 32),
            chainDiscriminant: UniversalWalletRegistry.nexus.chainDiscriminant
        )
        let toriiClient = IrohaSubmitClientStub()
        let service = IrohaTransferService(
            wallet: wallet,
            chain: chain,
            toriiClient: toriiClient,
            mnemonicProvider: UniversalWalletMnemonicProviderStub(mnemonic: Self.mnemonic)
        )
        let transfer = Transfer(
            chainAsset: ChainAsset(chain: chain, asset: Self.irohaAsset),
            amount: BigUInt("1000000000000000000"),
            receiver: recipientAddress,
            tip: nil,
            appId: nil
        )

        do {
            _ = try await service.submitNexusWalletSmokeEvidence(
                transfer: transfer,
                untrustedMetadata: Self.validIrohaWalletSmokeMetadata
            )
            XCTFail("Wallet-smoke metadata unexpectedly enabled production signing")
        } catch TransferServiceError.transferFailed(let reason) {
            XCTAssertTrue(reason.contains("signing codec"), reason)
        } catch {
            XCTFail("Unexpected unavailable-signer error: \(error)")
        }
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

    private func makeTonTransferChain(
        chainId: String = TonChainSelection.mainnetChainId,
        assets: Set<AssetModel>? = nil
    ) -> ChainModel {
        ChainModel(
            rank: nil,
            disabled: false,
            chainId: chainId,
            parentId: nil,
            paraId: nil,
            name: "TON Mainnet",
            assets: assets ?? [Self.tonAsset],
            xcm: nil,
            nodes: [
                ChainNodeModel(
                    url: URL(string: "https://tonapi.io")!,
                    name: "TON",
                    apikey: nil
                )
            ],
            addressPrefix: 0,
            types: nil,
            icon: nil,
            options: chainId == TonChainSelection.testnetChainId ? [.testnet] : nil,
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
                history: makeIrohaTestHistoryEndpoint($0),
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

    private func prepareDisplayedTonFee(
        service: TransferServiceProtocol,
        transfer: Transfer
    ) async throws -> BigUInt {
        let received = expectation(description: "displayed TON fee")
        let listener = TonFeePresentationListenerStub(expectation: received)
        service.subscribeForFee(transfer: transfer, listener: listener)
        await fulfillment(of: [received], timeout: 2)
        let fee = try XCTUnwrap(listener.fee)
        let presentationID = try XCTUnwrap(listener.presentationID)
        let accepted = await service.confirmFeePresentation(
            id: presentationID,
            fee: fee
        )
        XCTAssertTrue(accepted)
        return fee
    }

    private func walletWithTonAccount(chainId: String) throws -> MetaAccountModel {
        let account = try TonKeyDerivation.deriveAccount(mnemonic: Self.mnemonic)
        let chainAccount = ChainAccountModel(
            chainId: chainId,
            accountId: account.accountHash,
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
    private static let tonAsset = AssetModel(
        id: UniversalWalletRegistry.tonNativeAssetId,
        name: "Toncoin",
        symbol: "TON",
        precision: 9,
        isUtility: true,
        isNative: true,
        type: .normal
    )
    private static let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    private static let otherMnemonic = "legal winner thank year wave sausage worth useful legal winner thank yellow"
    private static let signedTransaction = Data([1, 2, 3, 4])
    private static let signedTransactionHash = "signed-transaction-hash"
    private static let irohaRouteActionHash = "sha256:" + String(repeating: "1", count: 64)
    private static let irohaWalletCommit = String(repeating: "a", count: 40)
    private static var validIrohaWalletSmokeMetadata: [String: String] {
        [
            IrohaWalletSmokeTransactionMetadata.evidenceRoleKey: "wallet-smoke",
            IrohaWalletSmokeTransactionMetadata.routeGovernanceActionHashKey: irohaRouteActionHash,
            IrohaWalletSmokeTransactionMetadata.walletPlatformKey: "ios",
            IrohaWalletSmokeTransactionMetadata.walletCommitKey: irohaWalletCommit
        ]
    }
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

    private final class TonFeePresentationListenerStub: TonTransferFeePresentationListener {
        private let expectation: XCTestExpectation
        private(set) var fee: BigUInt?
        private(set) var presentationID: String?

        init(expectation: XCTestExpectation) {
            self.expectation = expectation
        }

        func didReceiveTonFee(fee: BigUInt, presentationID: String) {
            self.fee = fee
            self.presentationID = presentationID
            expectation.fulfill()
        }

        func didReceiveFee(fee _: BigUInt) {
            XCTFail("TON quote lost its presentation identifier")
            expectation.fulfill()
        }

        func didReceiveFeeError(feeError: Error) {
            XCTFail("Unexpected TON quote error: \(feeError)")
            expectation.fulfill()
        }
    }

    private final class TonTransferRemoteStub: TonTransferRemoteProtocol, @unchecked Sendable {
        let reviewedSignedOperationOrigin: String? = TonAPIClientFactory.canonicalAuthenticatedOrigin.absoluteString

        private(set) var walletStateCallCount = 0
        private(set) var emulateCallCount = 0
        private(set) var unsignedEmulateCallCount = 0
        private(set) var signedEmulateCallCount = 0
        private(set) var broadcastCallCount = 0
        private(set) var reconcileCallCount = 0
        private(set) var emulatedBocs: [String] = []
        private(set) var broadcastBocs: [String] = []
        private(set) var broadcastMessageHashes: [String] = []
        var reconciliationResult: TonReconciliationResult = .confirmed

        func walletState(address _: String) async throws -> TonWalletRemoteState {
            walletStateCallCount += 1
            return TonWalletRemoteState(sequenceNumber: 1, isInitialized: true)
        }

        func recipientRequiresMemo(address _: String) async throws -> Bool {
            false
        }

        func emulateUnsigned(
            message: TonUnsignedEmulationMessage,
            intent _: TonEmulationIntent
        ) async throws -> TonEmulationResult {
            emulateCallCount += 1
            unsignedEmulateCallCount += 1
            emulatedBocs.append(message.bocBase64)
            return TonEmulationResult(accepted: true, totalFeeNanotons: 1)
        }

        func emulateSigned(
            message: TonSignedExternalMessage,
            intent _: TonEmulationIntent
        ) async throws -> TonEmulationResult {
            emulateCallCount += 1
            signedEmulateCallCount += 1
            emulatedBocs.append(message.bocBase64)
            return TonEmulationResult(accepted: true, totalFeeNanotons: 1)
        }

        func broadcast(message: TonSignedExternalMessage) async throws {
            broadcastCallCount += 1
            broadcastBocs.append(message.bocBase64)
            broadcastMessageHashes.append(message.messageHashHex)
        }

        func reconcile(
            message _: TonSignedExternalMessage,
            intent _: TonEmulationIntent
        ) async throws -> TonReconciliationResult {
            reconcileCallCount += 1
            return reconciliationResult
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

    private final class CountingUniversalWalletMnemonicProvider: UniversalWalletMnemonicProviding {
        let mnemonic: String?
        private(set) var callCount = 0

        init(mnemonic: String?) {
            self.mnemonic = mnemonic
        }

        func mnemonic(for _: MetaAccountModel, chain _: ChainModel) throws -> String? {
            callCount += 1
            return mnemonic
        }
    }
}

final class ChainRegistryTonNodeSelectionTests: XCTestCase {
    func testResolveTonNodePrefersSelectedNode() throws {
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
        XCTAssertEqual(try ChainRegistry.tonAPIBaseURL(for: chain), primary.url)
    }

    func testResolveTonNodeFallsBackDeterministicallyWhenSelectedNodeMissing() throws {
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
        XCTAssertEqual(try ChainRegistry.tonAPIBaseURL(for: chain), nodeA.url)
    }

    func testResolveTonNodeReturnsNilForEmptyNodesAndNoSelection() {
        let chain = makeTonChain(nodes: [], selectedNode: nil)

        let resolved = ChainRegistry.resolveTonNode(for: chain)

        XCTAssertNil(resolved)
        XCTAssertThrowsError(try ChainRegistry.tonAPIBaseURL(for: chain))
    }

    func testTonApiBaseURLRejectsInsecureCrossNetworkEndpoint() {
        let node = ChainNodeModel(
            url: URL(string: "http://testnet.ton.example.com")!,
            name: "Insecure testnet",
            apikey: nil
        )
        let chain = makeTonChain(nodes: [node], selectedNode: node)

        XCTAssertThrowsError(try ChainRegistry.tonAPIBaseURL(for: chain))
    }

    func testTonApiBaseURLRejectsAuthorityAndURLComponentConfusion() {
        let invalidURLs = [
            "https://user:secret@tonapi.io",
            "https://tonapi.io/v2",
            "https://tonapi.io?redirect=https://attacker.example",
            "https://tonapi.io#attacker"
        ]

        for rawURL in invalidURLs {
            let node = ChainNodeModel(
                url: URL(string: rawURL)!,
                name: "Untrusted",
                apikey: nil
            )
            let chain = makeTonChain(nodes: [node], selectedNode: node)

            XCTAssertThrowsError(try ChainRegistry.tonAPIBaseURL(for: chain), rawURL)
        }
    }

    func testTonApiAuthorizationIsRestrictedToExactCanonicalOrigin() {
        let canonical = TonAPIClientFactory(
            tonAPIURL: URL(string: "https://tonapi.io")!,
            token: "top-secret"
        )
        XCTAssertTrue(canonical.usesAuthorization)

        let untrustedURLs = [
            "https://evil.example",
            "https://tonapi.io.evil.example",
            "https://tonapi.io:444",
            "https://user@tonapi.io",
            "https://tonapi.io/v2",
            "https://tonapi.io?next=evil",
            "https://tonapi.io#evil"
        ]
        for rawURL in untrustedURLs {
            let factory = TonAPIClientFactory(
                tonAPIURL: URL(string: rawURL)!,
                token: "top-secret"
            )
            XCTAssertFalse(factory.usesAuthorization, rawURL)
            XCTAssertFalse(
                TonAPIClientFactory.canAttachAuthorization(to: factory.serverURL),
                rawURL
            )
        }
    }

    func testCanonicalTonApiOriginStillRejectsMissingOrMalformedCredentialsForSignedOperations() async {
        let configuration = mockConfiguration()
        TonAPIMockURLProtocol.install { protocolInstance, request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            protocolInstance.client?.urlProtocol(
                protocolInstance,
                didReceive: response,
                cacheStoragePolicy: .notAllowed
            )
            protocolInstance.client?.urlProtocolDidFinishLoading(protocolInstance)
        }
        defer { TonAPIMockURLProtocol.reset() }
        let signedMessage = TonSignedExternalMessage(
            boc: Data([0]),
            bocBase64: "AA==",
            messageHashHex: String(repeating: "00", count: 32),
            signingPayloadHashHex: String(repeating: "00", count: 32),
            publicKey: Data(repeating: 1, count: 32),
            walletAddress: "0:" + String(repeating: "0", count: 64),
            sequenceNumber: 0,
            validUntil: UInt64.max,
            includesStateInit: false
        )
        let rejectedTokens = [
            "",
            " ",
            " leading-space",
            "trailing-space ",
            "line\nbreak",
            "tab\tseparated",
            "non-ascii-é",
            String(repeating: "a", count: 4097)
        ]

        for token in rejectedTokens {
            let factory = TonAPIClientFactory(
                tonAPIURL: URL(string: "https://tonapi.io")!,
                token: token
            )
            XCTAssertFalse(factory.usesAuthorization, token.debugDescription)
            XCTAssertFalse(factory.hasReviewedProductionSendCredential, token.debugDescription)
            let remote = TonAPIRemoteClient(factory: factory, configuration: configuration)
            XCTAssertNil(remote.reviewedSignedOperationOrigin, token.debugDescription)
            do {
                try await remote.broadcast(message: signedMessage)
                XCTFail("Malformed credential enabled signed operation: \(token.debugDescription)")
            } catch let error as TonTransferRemoteError {
                XCTAssertEqual(error, .untrustedSignedOperationEndpoint)
            } catch {
                XCTFail("Unexpected malformed-credential error: \(error)")
            }
        }
        XCTAssertEqual(TonAPIMockURLProtocol.requestCount, 0)
    }

    func testTonProductionSendEndpointAllowlistPinsExactBinaryOwnedOrigin() throws {
        XCTAssertEqual(
            TonAPIClientFactory.reviewedProductionSendOrigins,
            [URL(string: "https://tonapi.io")!]
        )
        XCTAssertTrue(
            TonAPIClientFactory.isReviewedProductionSendServerURL(
                URL(string: "https://tonapi.io")!
            )
        )
        XCTAssertTrue(
            TonAPIClientFactory.isReviewedProductionSendServerURL(
                URL(string: "https://tonapi.io/")!
            )
        )

        let rejectedURLs = [
            "https://evil.example",
            "https://tonapi.io.evil.example",
            "https://tonapi.io:443",
            "https://tonapi.io:444",
            "https://user@tonapi.io",
            "https://tonapi.io/v2",
            "https://tonapi.io?next=evil",
            "https://tonapi.io#evil",
            "http://tonapi.io"
        ]
        for rawURL in rejectedURLs {
            XCTAssertFalse(
                TonAPIClientFactory.isReviewedProductionSendServerURL(
                    try XCTUnwrap(URL(string: rawURL))
                ),
                rawURL
            )
        }
    }

    func testTonReadOnlyNodeResolutionDoesNotExpandProductionSendAllowlist() throws {
        let unreviewed = ChainNodeModel(
            url: URL(string: "https://read-only-ton.example.com")!,
            name: "Read only",
            apikey: nil
        )
        let chain = makeTonChain(nodes: [unreviewed], selectedNode: unreviewed)

        XCTAssertEqual(try ChainRegistry.tonAPIBaseURL(for: chain), unreviewed.url)
        XCTAssertFalse(
            TonAPIClientFactory.isReviewedProductionSendServerURL(
                try ChainRegistry.tonAPIBaseURL(for: chain)
            )
        )
    }

    func testTonApiTransportNeverFollowsRedirectAndUsesFiniteBounds() {
        let redirected = URLRequest(url: URL(string: "https://attacker.example/capture")!)

        XCTAssertNil(TonAPINoRedirectDelegate.redirectedRequest(redirected))
        XCTAssertFalse(TonAPITransportPolicy.followsRedirects)
        XCTAssertGreaterThan(TonAPITransportPolicy.requestTimeout, 0)
        XCTAssertGreaterThan(TonAPITransportPolicy.resourceTimeout, 0)
        XCTAssertLessThanOrEqual(TonAPITransportPolicy.requestTimeout, 30)
        XCTAssertLessThanOrEqual(TonAPITransportPolicy.resourceTimeout, 60)
        XCTAssertEqual(TonAPITransportPolicy.maximumResponseBytes, 2 * 1_024 * 1_024)
        XCTAssertEqual(TonAPITransportPolicy.maximumRequestBodyBytes, 1 * 1_024 * 1_024)
    }

    func testTonApiTransportCancelsOversizedStreamingResponse() async throws {
        let configuration = mockConfiguration()
        TonAPIMockURLProtocol.install { protocolInstance, request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            protocolInstance.client?.urlProtocol(
                protocolInstance,
                didReceive: response,
                cacheStoragePolicy: .notAllowed
            )
            let chunk = Data(repeating: 0x41, count: 512 * 1_024)
            for _ in 0 ..< 5 {
                protocolInstance.client?.urlProtocol(protocolInstance, didLoad: chunk)
            }
            protocolInstance.client?.urlProtocolDidFinishLoading(protocolInstance)
        }
        defer { TonAPIMockURLProtocol.reset() }

        let transport = TonAPIURLSessionTransport(configuration: configuration)
        do {
            _ = try await transport.send(
                HTTPRequest(
                    method: .get,
                    scheme: nil,
                    authority: nil,
                    path: "/v2/test"
                ),
                body: nil,
                baseURL: URL(string: "https://tonapi.io")!,
                operationID: "oversized-response"
            )
            XCTFail("Expected bounded transport to reject oversized response")
        } catch let error as TonAPITransportError {
            guard case let .responseTooLarge(actualBytes, maximumBytes) = error else {
                return XCTFail("Unexpected transport error: \(error)")
            }
            XCTAssertGreaterThan(actualBytes, maximumBytes)
            XCTAssertEqual(maximumBytes, TonAPITransportPolicy.maximumResponseBytes)
        }
        XCTAssertEqual(TonAPIMockURLProtocol.requestCount, 1)
    }

    func testTonApiTransportRejectsOversizedRequestBeforeNetwork() async throws {
        let configuration = mockConfiguration()
        TonAPIMockURLProtocol.install { protocolInstance, request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            protocolInstance.client?.urlProtocol(
                protocolInstance,
                didReceive: response,
                cacheStoragePolicy: .notAllowed
            )
            protocolInstance.client?.urlProtocolDidFinishLoading(protocolInstance)
        }
        defer { TonAPIMockURLProtocol.reset() }

        let transport = TonAPIURLSessionTransport(configuration: configuration)
        let body = HTTPBody(
            Data(repeating: 0x42, count: TonAPITransportPolicy.maximumRequestBodyBytes + 1)
        )
        do {
            _ = try await transport.send(
                HTTPRequest(
                    method: .post,
                    scheme: nil,
                    authority: nil,
                    path: "/v2/test"
                ),
                body: body,
                baseURL: URL(string: "https://tonapi.io")!,
                operationID: "oversized-request"
            )
            XCTFail("Expected oversized request body to fail")
        } catch {
            XCTAssertEqual(TonAPIMockURLProtocol.requestCount, 0)
        }
    }

    func testCancellingTonApiTransportCancelsSessionTaskAndClearsState() async {
        let configuration = mockConfiguration()
        let started = expectation(description: "request started")
        let stopped = expectation(description: "URL loading stopped")
        TonAPIMockURLProtocol.install(
            { protocolInstance, request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                protocolInstance.client?.urlProtocol(
                    protocolInstance,
                    didReceive: response,
                    cacheStoragePolicy: .notAllowed
                )
                started.fulfill()
                // Intentionally never finish: caller cancellation must stop this request.
            },
            onStop: { stopped.fulfill() }
        )
        defer { TonAPIMockURLProtocol.reset() }

        let transport = TonAPIURLSessionTransport(configuration: configuration)
        let requestTask = Task {
            try await transport.send(
                HTTPRequest(
                    method: .get,
                    scheme: nil,
                    authority: nil,
                    path: "/v2/never-finishes"
                ),
                body: nil,
                baseURL: URL(string: "https://tonapi.io")!,
                operationID: "cancelled-request"
            )
        }

        await fulfillment(of: [started], timeout: 1)
        XCTAssertEqual(transport.inFlightRequestCount, 1)
        requestTask.cancel()
        do {
            _ = try await requestTask.value
            XCTFail("Expected caller cancellation to propagate")
        } catch is CancellationError {
            // Expected exact cancellation rather than a transport timeout.
        } catch {
            XCTFail("Unexpected cancellation error: \(error)")
        }
        await fulfillment(of: [stopped], timeout: 1)
        XCTAssertEqual(transport.inFlightRequestCount, 0)
        XCTAssertEqual(TonAPIMockURLProtocol.requestCount, 1)
    }

    func testTonApiRedirectNeverIssuesHostileRequestOrForwardsAuthorization() async throws {
        let configuration = mockConfiguration()
        TonAPIMockURLProtocol.install { protocolInstance, request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 302,
                httpVersion: nil,
                headerFields: ["Location": "https://attacker.example/capture"]
            )!
            protocolInstance.client?.urlProtocol(
                protocolInstance,
                didReceive: response,
                cacheStoragePolicy: .notAllowed
            )
            protocolInstance.client?.urlProtocolDidFinishLoading(protocolInstance)
        }
        defer { TonAPIMockURLProtocol.reset() }

        let factory = TonAPIClientFactory(
            tonAPIURL: URL(string: "https://tonapi.io")!,
            token: "top-secret"
        )
        do {
            _ = try await factory.tonAPIClient(configuration: configuration).sendBlockchainMessage(
                .init(body: .json(.init(boc: "te6ccgEBAQEAAgAAAA==")))
            )
            XCTFail("Expected the generated client to reject a bodyless redirect response")
        } catch {}

        XCTAssertEqual(TonAPIMockURLProtocol.requestCount, 1)
        XCTAssertEqual(TonAPIMockURLProtocol.requests.first?.url?.host, "tonapi.io")
        XCTAssertEqual(
            TonAPIMockURLProtocol.requests.first?.value(forHTTPHeaderField: "Authorization"),
            "Bearer top-secret"
        )
        XCTAssertFalse(TonAPIMockURLProtocol.requests.contains { $0.url?.host == "attacker.example" })

        let trailingSlashFactory = TonAPIClientFactory(
            tonAPIURL: URL(string: "https://tonapi.io/")!,
            token: "top-secret"
        )
        do {
            _ = try await trailingSlashFactory
                .tonAPIClient(configuration: configuration)
                .sendBlockchainMessage(
                    .init(body: .json(.init(boc: "te6ccgEBAQEAAgAAAA==")))
                )
            XCTFail("Expected the generated client to reject a bodyless redirect response")
        } catch {}

        XCTAssertEqual(TonAPIMockURLProtocol.requestCount, 2)
        let trailingSlashRequest = try XCTUnwrap(TonAPIMockURLProtocol.requests.last)
        XCTAssertEqual(
            trailingSlashRequest.url?.absoluteString,
            "https://tonapi.io/v2/blockchain/message"
        )
        XCTAssertEqual(
            trailingSlashRequest.value(forHTTPHeaderField: "Authorization"),
            "Bearer top-secret"
        )
    }

    func testHostileTonApiOriginCannotReceiveSignedOperations() async throws {
        let configuration = mockConfiguration()
        TonAPIMockURLProtocol.install { protocolInstance, request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            protocolInstance.client?.urlProtocol(
                protocolInstance,
                didReceive: response,
                cacheStoragePolicy: .notAllowed
            )
            protocolInstance.client?.urlProtocolDidFinishLoading(protocolInstance)
        }
        defer { TonAPIMockURLProtocol.reset() }

        let factory = TonAPIClientFactory(
            tonAPIURL: URL(string: "https://attacker.example")!,
            token: "top-secret"
        )
        let remote = TonAPIRemoteClient(factory: factory, configuration: configuration)
        let signedMessage = TonSignedExternalMessage(
            boc: Data([0]),
            bocBase64: "AA==",
            messageHashHex: String(repeating: "00", count: 32),
            signingPayloadHashHex: String(repeating: "00", count: 32),
            publicKey: Data(repeating: 1, count: 32),
            walletAddress: "0:" + String(repeating: "0", count: 64),
            sequenceNumber: 0,
            validUntil: UInt64.max,
            includesStateInit: false
        )

        do {
            try await remote.broadcast(message: signedMessage)
            XCTFail("Expected an unreviewed origin to reject signed operations")
        } catch let error as TonTransferRemoteError {
            XCTAssertEqual(error, .untrustedSignedOperationEndpoint)
        }

        XCTAssertEqual(TonAPIMockURLProtocol.requestCount, 0)
    }

    func testCanonicalTonApiFactoryIsRequiredForSignedOperations() async throws {
        let configuration = mockConfiguration()
        TonAPIMockURLProtocol.install { protocolInstance, request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            protocolInstance.client?.urlProtocol(
                protocolInstance,
                didReceive: response,
                cacheStoragePolicy: .notAllowed
            )
            protocolInstance.client?.urlProtocolDidFinishLoading(protocolInstance)
        }
        defer { TonAPIMockURLProtocol.reset() }

        let factory = TonAPIClientFactory(
            tonAPIURL: URL(string: "https://tonapi.io")!,
            token: "top-secret"
        )
        let signedMessage = TonSignedExternalMessage(
            boc: Data([0]),
            bocBase64: "AA==",
            messageHashHex: String(repeating: "00", count: 32),
            signingPayloadHashHex: String(repeating: "00", count: 32),
            publicKey: Data(repeating: 1, count: 32),
            walletAddress: "0:" + String(repeating: "0", count: 64),
            sequenceNumber: 0,
            validUntil: UInt64.max,
            includesStateInit: false
        )

        let factoryRemote = TonAPIRemoteClient(
            factory: factory,
            configuration: configuration
        )
        try await factoryRemote.broadcast(message: signedMessage)
        XCTAssertEqual(TonAPIMockURLProtocol.requestCount, 1)
        XCTAssertEqual(
            TonAPIMockURLProtocol.requests.first?.url?.absoluteString,
            "https://tonapi.io/v2/blockchain/message"
        )
        XCTAssertEqual(
            TonAPIMockURLProtocol.requests.first?.value(forHTTPHeaderField: "Authorization"),
            "Bearer top-secret"
        )

        let directRemote = TonAPIRemoteClient(
            client: factory.tonAPIClient(configuration: configuration)
        )
        do {
            try await directRemote.broadcast(message: signedMessage)
            XCTFail("Expected direct generated-client injection to fail closed")
        } catch let error as TonTransferRemoteError {
            XCTAssertEqual(error, .untrustedSignedOperationEndpoint)
        }
        XCTAssertEqual(TonAPIMockURLProtocol.requestCount, 1)
    }

    private func mockConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TonAPIMockURLProtocol.self]
        return configuration
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

private final class TonAPIMockURLProtocol: URLProtocol {
    typealias Handler = (TonAPIMockURLProtocol, URLRequest) -> Void

    private static let lock = NSLock()
    private static var handler: Handler?
    private static var onStop: (() -> Void)?
    private static var capturedRequests: [URLRequest] = []

    static var requests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return capturedRequests
    }

    static var requestCount: Int { requests.count }

    static func install(
        _ handler: @escaping Handler,
        onStop: (() -> Void)? = nil
    ) {
        lock.lock()
        self.handler = handler
        self.onStop = onStop
        capturedRequests = []
        lock.unlock()
    }

    static func reset() {
        lock.lock()
        handler = nil
        onStop = nil
        capturedRequests = []
        lock.unlock()
    }

    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self.capturedRequests.append(request)
        let handler = Self.handler
        Self.lock.unlock()

        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        handler(self, request)
    }

    override func stopLoading() {
        Self.lock.lock()
        let onStop = Self.onStop
        Self.lock.unlock()
        onStop?()
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
            recipientAddress: "recipient-address",
            reviewedRoute: ReviewedCrossChainRouteContext(
                definition: ReviewedXcmRouteRegistry.routes[0],
                providerId: "polkaswap-sora-substrate"
            )
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

    struct AddressInvocation: Equatable {
        let address: String
        let network: BitcoinKeyDerivation.Network
        let baseURL: String?
    }

    private let result: BitcoinBalanceSyncResult
    private let addressResult: BitcoinAddressBalanceResult
    private let error: Error?
    private(set) var invocations: [Invocation] = []
    private(set) var addressInvocations: [AddressInvocation] = []

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
        addressResult: BitcoinAddressBalanceResult? = nil,
        error: Error? = nil
    ) {
        self.result = result
        self.addressResult = addressResult ?? BitcoinAddressBalanceResult(
            confirmedSats: result.confirmedSats,
            mempoolSats: result.mempoolSats,
            totalSats: result.totalSats
        )
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

    func balance(
        address: String,
        network: BitcoinKeyDerivation.Network,
        baseURL: String?
    ) async throws -> BitcoinAddressBalanceResult {
        addressInvocations.append(
            AddressInvocation(address: address, network: network, baseURL: baseURL)
        )
        if let error { throw error }
        return addressResult
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

    private var accountAssetsResponses: [IrohaAccountAssetListResponse]
    private let accountAssetsError: Error?
    private(set) var accountAssetsInvocations: [AccountAssetsInvocation] = []

    init(
        accountAssetsResponse: IrohaAccountAssetListResponse = IrohaAccountAssetListResponse(
            items: [],
            hasMore: false,
            countMode: IrohaToriiCountMode.bounded.rawValue,
            total: 0
        ),
        accountAssetsResponses: [IrohaAccountAssetListResponse]? = nil,
        accountAssetsError: Error? = nil
    ) {
        self.accountAssetsResponses = accountAssetsResponses ?? [accountAssetsResponse]
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

        guard accountAssetsResponses.isNotEmpty else {
            throw AccountInfoRemoteServiceStubError.notImplemented
        }
        return accountAssetsResponses.removeFirst()
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
