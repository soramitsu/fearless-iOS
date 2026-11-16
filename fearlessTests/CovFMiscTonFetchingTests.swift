import RobinHood
import SSFModels
import XCTest
@testable import fearless

/// The TON fetcher's network calls need a node URL. These chains have none, so every request fails before a
/// client is created and no host is ever contacted.
final class CovFMiscTonFetchingTests: XCTestCase {
    func testAssetWithoutTonTypeReadsNothingAndReturnsNil() async throws {
        let chain = covFMiscTonChain(types: [nil])
        let repository = CovFRepository<AccountInfoStorageWrapper>()
        let fetcher = makeFetcher(repository: repository)
        let wallet = AccountGenerator.generateMetaAccount()
        let asset = try XCTUnwrap(chain.chainAssets.first)
        let info = try await fetcher.fetchAccountInfo(for: asset, wallet: wallet)
        XCTAssertNil(info)
        let accountId = try XCTUnwrap(wallet.fetch(for: chain.accountRequest())?.accountId)
        let key = try LocalStorageKeyFactory().createFromStoragePath(asset.storagePath, chainAssetKey: asset.uniqueKey(accountId: accountId))
        try covFMiscEventually { repository.items.count == 1 }
        XCTAssertEqual(repository.items.first?.identifier, key)
    }

    func testNativeAndJettonReadsFailWithoutNodeBeforeAnyRequest() async throws {
        let chain = covFMiscTonChain(types: [.normal, .xcm])
        let fetcher = makeFetcher()
        let wallet = AccountGenerator.generateMetaAccount()
        for asset in chain.chainAssets {
            do {
                _ = try await fetcher.fetchAccountInfo(for: asset, wallet: wallet)
                XCTFail("Expected missing node for \(asset.asset.id)")
            } catch {
                XCTAssertTrue(covFMiscIsConnectionUnavailable(error), "\(error)")
            }
        }
    }

    func testChainScanNeedsNativeTonAssetAndANode() async throws {
        let fetcher = makeFetcher()
        let wallet = AccountGenerator.generateMetaAccount()
        do {
            _ = try await fetcher.fetchAccountInfos(for: covFMiscTonChain(types: [.xcm]), wallet: wallet)
            XCTFail("Expected missing native asset")
        } catch {
            XCTAssertEqual(error as? TonRemoteBalanceFetchingError, .utilityNotFound)
        }
        do {
            _ = try await fetcher.fetchAccountInfos(for: covFMiscTonChain(types: [.normal, .xcm]), wallet: wallet)
            XCTFail("Expected missing node")
        } catch {
            XCTAssertTrue(covFMiscIsConnectionUnavailable(error), "\(error)")
        }
    }

    func testAssetListScanNeedsNativeTonAssetAndANode() async throws {
        let fetcher = makeFetcher()
        let wallet = AccountGenerator.generateMetaAccount()
        do {
            _ = try await fetcher.fetchAccountInfos(for: covFMiscTonChain(types: [.xcm]).chainAssets, wallet: wallet)
            XCTFail("Expected missing native asset")
        } catch {
            XCTAssertEqual(error as? TonRemoteBalanceFetchingError, .utilityNotFound)
        }
        do {
            _ = try await fetcher.fetchAccountInfos(for: covFMiscTonChain(types: [.normal]).chainAssets, wallet: wallet)
            XCTFail("Expected missing node")
        } catch {
            XCTAssertTrue(covFMiscIsConnectionUnavailable(error), "\(error)")
        }
    }

    /// An in-memory repository: the cache write is asynchronous and must not reach Core Data after the test ends.
    private func makeFetcher(repository: CovFRepository<AccountInfoStorageWrapper> = CovFRepository()) -> TonRemoteBalanceFetchingImpl {
        TonRemoteBalanceFetchingImpl(
            chainRegistry: CovFRegistry(),
            repositoryWrapper: BalanceRepositoryCacheWrapper(
                logger: CovFBalLogger(), repository: AnyDataProviderRepository(repository), operationManager: OperationManager()
            ),
            jettonInjector: CovFMiscJettonInjector()
        )
    }
}

func covFMiscIsConnectionUnavailable(_ error: Error) -> Bool {
    if case .connectionUnavailable? = error as? ChainRegistryError { return true }
    return false
}

func covFMiscTonChain(types: [SubstrateAssetType?]) -> ChainModel {
    let assets = types.enumerated().map { index, type in
        AssetModel(id: "ton-\(index)", name: "TON \(index)", symbol: "T\(index)", precision: 9, currencyId: nil,
                   isUtility: type == .normal, isNative: type == .normal, type: type)
    }
    return ChainModel(
        rank: nil, disabled: false, chainId: "covf-ton", parentId: nil, paraId: nil, name: "TON",
        assets: Set(assets), xcm: nil, nodes: [], addressPrefix: 0, icon: nil, options: nil, iosMinAppVersion: nil, identityChain: nil
    )
}

final class CovFMiscJettonInjector: TonJettonInjector {
    func inject(jettonItems _: [TonJettonBalance]) async {}
    func inject(tonPriceData _: [PriceData]) async {}
}
