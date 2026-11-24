import XCTest
import RobinHood
import SSFModels
@testable import fearless

/// Muting a network's issue saves its ChainSettings and re-sends the issues. The wallet list and the asset networks
/// screen hide muted issues only with those settings, but both interactors had a getChainSettings() nothing called,
/// so a muted network kept its warning there.
final class MutedNetworkIssuesTests: XCTestCase {
    func testAssetNetworksReadsTheMutedNetworksOnSetupAndAfterAMute() throws {
        let wallet = CovJSelFixture.substrateWallet()
        let chain = CovJSelFixture.chain(name: "Muted", assets: [])
        let source = ChainAsset(chain: chain, asset: CovJSelFixture.asset("src"))
        let repository = MutableChainSettingsRepository()
        let interactor = AssetNetworksInteractor(
            chainAsset: source,
            wallet: wallet,
            chainAssetFetching: CovJSelChainAssetFetchingStub(result: .success([source])),
            accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter(
                walletLocalSubscriptionFactory: CovJSelWalletSubscriptionFactoryStub(),
                selectedMetaAccount: wallet
            ),
            chainsIssuesCenter: ChainsIssuesCenter(
                wallet: wallet,
                networkIssuesCenter: CovJSelNetworkIssuesCenterStub(),
                eventCenter: EventCenter(),
                missingAccountHelper: CovJSelNoMissingAccounts(),
                accountInfoFetcher: CovJSelNoAccountInfo()
            ),
            chainSettingsRepository: AsyncAnyRepository(repository),
            catalog: CanonicalTokenGroupCatalog(data: nil, testnets: .bundled)
        )
        let output = CovJSelInteractorOutputSpy()

        interactor.setup(with: output)
        XCTAssertTrue(CovJWait.until(timeout: 5) { output.settings.count == 1 }, "the stored settings arrive with the screen")
        XCTAssertEqual(output.settings.last, [])

        // What NetworkIssuesNotification does on mute: store the setting, then re-send the issues.
        var muted = ChainSettings.defaultSettings(for: chain.chainId)
        muted.setIssueMuted(true)
        repository.settings = [muted]
        interactor.handleChainsIssues([.network(chains: [chain])])

        XCTAssertTrue(CovJWait.until(timeout: 5) { output.settings.count == 2 })
        XCTAssertEqual(output.settings.last, [muted])
        XCTAssertEqual(output.issues.last?.count, 1)
    }

    func testWalletListReadsTheMutedNetworksOnSetupAndWithEveryIssueUpdate() {
        let harness = CovHAssetListInteractorHarness()
        harness.interactor.setup(with: harness.output)
        CovHAssetListFixture.spin(timeout: 5) { harness.output.events.contains("chainSettings") }
        XCTAssertEqual(harness.output.events.filter { $0 == "chainSettings" }.count, 1)

        harness.interactor.handleChainsIssues([.network(chains: [CovHAssetListFixture.chain(name: "Muted")])])
        CovHAssetListFixture.spin(timeout: 5) { harness.output.events.filter { $0 == "chainSettings" }.count == 2 }

        XCTAssertEqual(harness.output.events.filter { $0 == "chainSettings" }.count, 2)
    }
}

private final class MutableChainSettingsRepository: AsyncCoreDataRepository {
    typealias Model = ChainSettings

    private let lock = NSLock()
    private var stored: [ChainSettings] = []

    var settings: [ChainSettings] {
        get { lock.lock(); defer { lock.unlock() }; return stored }
        set { lock.lock(); stored = newValue; lock.unlock() }
    }

    func fetch(by ids: [String], options _: RepositoryFetchOptions) async throws -> [ChainSettings] {
        settings.filter { ids.contains($0.chainId) }
    }

    func fetch(by id: String, options _: RepositoryFetchOptions) async throws -> ChainSettings? {
        settings.first { $0.chainId == id }
    }

    func fetchAll(with _: RepositoryFetchOptions) async throws -> [ChainSettings] {
        settings
    }

    func save(models: [ChainSettings], deleteIds _: [String]) async {
        settings += models
    }
}
