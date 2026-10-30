import XCTest
import RobinHood
import SoraFoundation
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
@testable import fearless

final class AssetHubNetworkInfoTests: XCTestCase {
    private let hub = "68d56f15f85d3136970ec16946040bc1752654e906147f7e43e9d539d7c3de2f"
    private static let network = NetworkStakingInfo.relaychain(
        baseInfo: BaseStakingInfo(lockUpPeriod: 28, minimalBalance: 10, minStakeAmongActiveNominators: 20),
        relaychainInfo: RelaychainStakingInfo(
            stakingDuration: StakingDuration(session: 14400, era: 86400, unlocking: 2_419_200),
            totalStake: 1000,
            activeNominatorsCount: 5
        )
    )

    func testHubNetworkRequiresAccountAndConnectionWhileLegacyUsesOriginalOperation() throws {
        let registry = Registry()
        let runtime = try AssetHubRuntimeFixture(name: "polkadot")
        let base = CompoundOperationWrapper(targetOperation: ClosureOperation { Self.network })
        let account = AssetHubTestSupport.first
        let legacy = try AssetHubNetworkStakingInfo.wrapper(
            base, chainId: "legacy", accountId: nil, runtime: runtime, chainRegistry: registry, operationManager: OperationManager()
        )
        XCTAssertTrue(legacy.targetOperation === base.targetOperation)

        registry.hasConnection = false
        XCTAssertThrowsError(try AssetHubNetworkStakingInfo.wrapper(
            base, chainId: hub, accountId: account, runtime: runtime, chainRegistry: registry, operationManager: OperationManager()
        ))
        registry.hasConnection = true
        XCTAssertThrowsError(try AssetHubNetworkStakingInfo.wrapper(
            base, chainId: hub, accountId: nil, runtime: runtime, chainRegistry: registry, operationManager: OperationManager()
        ))
        let wrapper = try AssetHubNetworkStakingInfo.wrapper(
            base, chainId: hub, accountId: account, runtime: runtime, chainRegistry: registry, operationManager: OperationManager()
        )
        XCTAssertFalse(wrapper.targetOperation === base.targetOperation)
    }

    func testWalletSwitchAndReadFailureClearDisplayedHubPeriod() throws {
        let view = RecordingView()
        let presenter = makePresenter(view: view)
        presenter.didReceive(newChainAsset: AssetHubTestSupport.makeAsset(chainId: hub))
        presenter.didReceive(networkStakingInfo: Self.network)
        XCTAssertNotNil(view.networkModels.last ?? nil)
        presenter.didReceive(selectedWallet: AccountGenerator.generateMetaAccount())
        XCTAssertNil(view.networkModels.last ?? nil)
        presenter.didReceive(networkStakingInfo: Self.network)
        XCTAssertNotNil(view.networkModels.last ?? nil)
        presenter.didReceive(networkStakingInfoError: ChainRegistryError.connectionUnavailable)
        XCTAssertNil(view.networkModels.last ?? nil)
    }

    func testWalletSwitchKeepsNetworkInfoOutsideAssetHub() throws {
        let view = RecordingView()
        let presenter = makePresenter(view: view)
        presenter.didReceive(newChainAsset: AssetHubTestSupport.makeAsset(chainId: "legacy"))
        presenter.didReceive(networkStakingInfo: Self.network)
        let shown = view.networkModels.count
        presenter.didReceive(selectedWallet: AccountGenerator.generateMetaAccount())
        XCTAssertEqual(view.networkModels.count, shown)
        XCTAssertNotNil(view.networkModels.last ?? nil)
    }

    func testAccountPeriodUsesDurationAndRoundsPartialDayUpWithoutInventingZero() throws {
        let asset = AssetHubTestSupport.makeAsset(chainId: hub)
        let factory = NetworkInfoViewModelFactory()
        func rendered(_ duration: TimeInterval) -> String? {
            let info = NetworkStakingInfo.relaychain(
                baseInfo: Self.network.baseInfo,
                relaychainInfo: RelaychainStakingInfo(stakingDuration: StakingDuration(session: 1, era: 86400, unlocking: duration), totalStake: 1, activeNominatorsCount: 1)
            )
            return factory.createNetworkStakingInfoViewModel(with: info, chainAsset: asset, minNominatorBond: nil, priceData: nil, selectedMetaAccount: AccountGenerator.generateMetaAccount()).value(for: Locale(identifier: "en_US")).lockUpPeriod
        }
        XCTAssertEqual(rendered(86401), R.string.localizable.commonDaysFormat(format: 2, preferredLanguages: ["en"]))
        XCTAssertNil(rendered(0))
        XCTAssertNil(rendered(.nan))
    }

    func testWestendNetworkPeriodUsesHoursForTwelveHourAndFractionalDayDurations() throws {
        let asset = AssetHubTestSupport.makeAsset(chainId: "67f9723393ef76214df0118c34bbbd3dbebc8ed46a10973a8c969d48fe7598c9")
        let factory = NetworkInfoViewModelFactory()
        for (duration, hours) in [(43200.0, 12), (43201, 13), (86400, 24)] {
            let info = NetworkStakingInfo.relaychain(
                baseInfo: Self.network.baseInfo,
                relaychainInfo: RelaychainStakingInfo(stakingDuration: StakingDuration(session: 3600, era: 21600, unlocking: duration), totalStake: 1, activeNominatorsCount: 1)
            )
            let model = factory.createNetworkStakingInfoViewModel(with: info, chainAsset: asset, minNominatorBond: nil, priceData: nil, selectedMetaAccount: AccountGenerator.generateMetaAccount()).value(for: Locale(identifier: "en_US"))
            XCTAssertEqual(model.lockUpPeriod, R.string.localizable.commonHoursFormat(format: hours, preferredLanguages: ["en"]))
        }
    }

    func testWestendUnbondSetupShowsHoursAndRejectsInvalidDuration() throws {
        let runtime = try AssetHubRuntimeFixture(name: "westend")
        let state = StakingUnbondSetupRelaychainViewModelState(
            chainAsset: AssetHubTestSupport.makeAsset(chainId: runtime.chainId), wallet: AccountGenerator.generateMetaAccount(),
            dataValidatingFactory: StakingDataValidatingFactory(presentable: StakingMainWireframe()),
            callFactory: SubstrateCallFactoryDefault(runtimeService: runtime)
        )
        let factory = StakingUnbondSetupRelaychainViewModelFactory()
        for (duration, hours) in [(43200.0, 12), (43201, 13), (86400, 24)] {
            state.didReceiveUnbondingTime(result: .success(duration))
            let model = try XCTUnwrap(factory.buildBondingDurationViewModel(viewModelState: state)).value(for: Locale(identifier: "en_US"))
            XCTAssertEqual(model.subtitle, R.string.localizable.commonHoursFormat(format: hours, preferredLanguages: ["en"]))
        }
        state.didReceiveUnbondingTime(result: .success(86401))
        XCTAssertEqual(factory.buildBondingDurationViewModel(viewModelState: state)?.value(for: Locale(identifier: "en_US")).subtitle, R.string.localizable.commonDaysFormat(format: 2, preferredLanguages: ["en"]))
        for duration: TimeInterval in [0, -1, .infinity, .nan] {
            state.didReceiveUnbondingTime(result: .success(duration))
            XCTAssertEqual(factory.buildBondingDurationViewModel(viewModelState: state)?.value(for: Locale(identifier: "en_US")).title, "")
        }
    }

    func testConcurrentFixtureRequestsKeepUniqueIdentifiersAndCompleteHistory() throws {
        let fixture = try AssetHubStorageFixture()
        let identifiers = FixtureRequestIdentifiers()
        let expected = fixture.block.toHex(includePrefix: true)
        DispatchQueue.concurrentPerform(iterations: 128) { _ in
            do {
                let identifier = try fixture.callMethod(
                    RPCMethod.getFinalizedBlockHash, params: [String](),
                    options: JSONRPCOptions(resendOnReconnect: false)
                ) { (result: Result<String, Error>) in
                    XCTAssertEqual(try? result.get(), expected)
                }
                identifiers.append(identifier)
                XCTAssertLessThanOrEqual(fixture.requests.count, 128)
            } catch { XCTFail("Concurrent fixture request failed: \(error)") }
        }
        XCTAssertEqual(identifiers.values.count, 128)
        XCTAssertEqual(Set(identifiers.values).count, 128)
        XCTAssertEqual(fixture.requests.count, 128)
        XCTAssertTrue(fixture.requests.allSatisfy { $0.0 == RPCMethod.getFinalizedBlockHash })
    }

    func testNativeAccountDurationsReplaceOnlyNetworkLockupAndPropagateReadFailure() async throws {
        let fixture = try AssetHubStorageFixture()
        fixture.allowsUnpinnedReads = true
        let first = Data(repeating: 1, count: 32), second = Data(repeating: 2, count: 32)
        _ = try fixture.put(.activeEra, json: "{\"index\":\"100\",\"start\":null}")
        _ = try fixture.put(.areNominatorsSlashable, json: "false")
        _ = try fixture.put(.lastValidatorEra, json: "\"99\"", account: first)
        let factory = AssetHubUnbondingOperationFactory(storage: StorageRequestFactory(remoteFactory: StorageKeyFactory(), operationManager: OperationManager()), duration: Duration())
        for (account, periods) in [(first, UInt32(28)), (second, UInt32(2))] {
            let base = CompoundOperationWrapper(targetOperation: ClosureOperation { Self.network })
            let wrapper = factory.applying(duration: factory.create(accountId: account, runtime: fixture.runtime, connection: fixture), to: base)
            let info = try await run(wrapper)
            XCTAssertEqual(info.baseInfo.lockUpPeriod, periods)
            XCTAssertEqual(info.relaychainInfo?.stakingDuration.unlocking, Double(periods) * 86400)
            XCTAssertEqual(info.baseInfo.minimalBalance, Self.network.baseInfo.minimalBalance)
            XCTAssertEqual(info.relaychainInfo?.totalStake, Self.network.relaychainInfo?.totalStake)
        }
        fixture.error = ChainRegistryError.connectionUnavailable
        let base = CompoundOperationWrapper(targetOperation: ClosureOperation { Self.network })
        do {
            _ = try await run(factory.applying(duration: factory.create(accountId: second, runtime: fixture.runtime, connection: fixture), to: base))
            XCTFail("Failed account reads must not publish a zero or generic lockup")
        } catch {}
    }

    func testInvalidEraDurationCannotPublishZeroAccountLockup() async throws {
        let factory = AssetHubUnbondingOperationFactory(storage: StorageRequestFactory(remoteFactory: StorageKeyFactory(), operationManager: OperationManager()), duration: Duration())
        for era: TimeInterval in [.infinity, .nan, 0, -1] {
            let base = CompoundOperationWrapper(targetOperation: ClosureOperation { Self.network })
            let duration = CompoundOperationWrapper(targetOperation: ClosureOperation { StakingDuration(session: 1, era: era, unlocking: 100) })
            do {
                _ = try await run(factory.applying(duration: duration, to: base))
                XCTFail("Invalid era duration must not publish account timing")
            } catch {}
        }
    }

    private func makePresenter(view: RecordingView) -> StakingMainPresenter {
        let wallet = AccountGenerator.generateMetaAccount()
        let stateFactory = StakingStateViewModelFactory(
            analyticsRewardsViewModelFactoryBuilder: { chainAsset, balanceViewModelFactory in
                AnalyticsRewardsViewModelFactory(
                    assetInfo: chainAsset.assetDisplayInfo,
                    balanceViewModelFactory: balanceViewModelFactory,
                    calendar: Calendar(identifier: .gregorian)
                )
            },
            logger: nil,
            selectedMetaAccount: wallet,
            eventCenter: EventCenter()
        )
        let presenter = StakingMainPresenter(
            stateViewModelFactory: stateFactory,
            networkInfoViewModelFactory: NetworkInfoViewModelFactory(),
            viewModelFacade: StakingViewModelFacade(selectedMetaAccount: wallet),
            dataValidatingFactory: StakingDataValidatingFactory(presentable: StakingMainWireframe()),
            logger: nil,
            selectedMetaAccount: wallet,
            moduleOutput: nil
        )
        presenter.view = view
        presenter.wireframe = StakingMainWireframeProtocolStub()
        return presenter
    }

    private func run(_ wrapper: CompoundOperationWrapper<NetworkStakingInfo>) async throws -> NetworkStakingInfo {
        let done = expectation(description: "network period")
        wrapper.targetOperation.completionBlock = { done.fulfill() }
        OperationManager().enqueue(operations: wrapper.allOperations, in: .transient)
        await fulfillment(of: [done], timeout: 5)
        return try XCTUnwrap(wrapper.targetOperation.result).get()
    }

    private final class RecordingView: StakingMainViewProtocolStub, @unchecked Sendable {
        private(set) var networkModels: [LocalizableResource<NetworkStakingInfoViewModelProtocol>?] = []

        override func didRecieveNetworkStakingInfo(viewModel: LocalizableResource<NetworkStakingInfoViewModelProtocol>?) {
            networkModels.append(viewModel)
        }
    }

    private final class Registry: ChainRegistryProtocolStub, @unchecked Sendable {
        var hasConnection = true

        override func getConnection(for _: ChainModel.Id) -> ChainConnection? {
            hasConnection ? MockConnection() : nil
        }
    }

    private final class FixtureRequestIdentifiers {
        private let lock = NSLock()
        private var stored: [UInt16] = []
        var values: [UInt16] { lock.lock(); defer { lock.unlock() }; return stored }
        func append(_ identifier: UInt16) {
            lock.lock(); defer { lock.unlock() }
            stored.append(identifier)
        }
    }

    private struct Duration: StakingDurationOperationFactoryProtocol {
        func createDurationOperation(from _: SSFRuntimeCodingService.RuntimeCodingServiceProtocol) -> CompoundOperationWrapper<StakingDuration> {
            CompoundOperationWrapper(targetOperation: ClosureOperation { StakingDuration(session: 14400, era: 86400, unlocking: 2_419_200) })
        }
    }
}
