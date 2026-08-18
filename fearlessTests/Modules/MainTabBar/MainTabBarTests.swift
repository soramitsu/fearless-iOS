import CryptoKit
import BigInt
import RobinHood
import SoraFoundation
import SoraKeystore
import SSFModels
import SSFPools
import SSFUtils
import UIKit
import XCTest

@testable import fearless

final class MainTabBarTests: XCTestCase {
    private let expectedItemCount = 5

    func testRemoteFlagEnablesOnlyReviewedLiquidityPoolSubmissionBoundary() {
        MultiChainFeaturePolicy.update(
            FeatureToggleConfig(
                pendulumCaseEnabled: false,
                nftEnabled: true,
                polkaswapMutationsEnabled: true
            )
        )
        defer { MultiChainFeaturePolicy.update(.defaultConfig) }

        XCTAssertTrue(MultiChainFeaturePolicy.current.polkaswapMutationsEnabled)
        XCTAssertTrue(
            ReviewedLiquidityPoolExecutionAuthority.allowsSubmission(
                remoteEnabled: MultiChainFeaturePolicy.current.polkaswapMutationsEnabled
            )
        )
    }

    func testLiquidityPoolKillSwitchDisablesActionsWithoutRemovingAuthority() {
        XCTAssertTrue(ReviewedLiquidityPoolExecutionAuthority.isAvailable)
        XCTAssertFalse(
            ReviewedLiquidityPoolExecutionAuthority.allowsSubmission(remoteEnabled: false)
        )
    }

    func testLiquidityPoolRuntimeCapabilityNegotiatesCurrentCallNames() {
        let capabilities = ReviewedPoolRuntimeCapabilities(
            tradingPair: ReviewedPoolRuntimeModule(
                name: "TradingPair",
                calls: ["register"]
            ),
            poolXYK: ReviewedPoolRuntimeModule(
                name: "PoolXYK",
                calls: ["initialize_pool", "deposit_liquidity", "withdraw_liquidity"]
            )
        )

        XCTAssertTrue(capabilities.canCreateAndDeposit)
        XCTAssertTrue(capabilities.canDepositExisting)
        XCTAssertTrue(capabilities.canWithdraw)
        XCTAssertEqual(capabilities.poolXYK?.resolvedCall("depositLiquidity"), "deposit_liquidity")
    }

    func testLiquidityPoolCallPayloadPreservesExactAssetsAndLargeIntegerStrings() throws {
        let baseAssetId = "0x0200000000000000000000000000000000000000000000000000000000000000"
        let targetAssetId = "0x0200040000000000000000000000000000000000000000000000000000000000"
        let amount = "900719925474099312345678901234567890"
        let data = try JSONEncoder().encode(
            ReviewedPoolDepositCall(
                dexId: "0",
                assetA: SoraAssetId(wrappedValue: baseAssetId),
                assetB: SoraAssetId(wrappedValue: targetAssetId),
                desiredA: amount,
                desiredB: "2",
                minA: "1",
                minB: "1"
            )
        )
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(payload["dexId"] as? String, "0")
        XCTAssertEqual(encodedSoraAssetId(payload["inputAssetA"]), baseAssetId)
        XCTAssertEqual(encodedSoraAssetId(payload["inputAssetB"]), targetAssetId)
        XCTAssertEqual(payload["inputADesired"] as? String, amount)
    }

    func testDemeterRemoteKillSwitchCanEnableReviewedSubmissionBoundary() {
        MultiChainFeaturePolicy.update(
            FeatureToggleConfig(
                pendulumCaseEnabled: false,
                nftEnabled: true,
                demeterMutationsEnabled: true
            )
        )
        defer { MultiChainFeaturePolicy.update(.defaultConfig) }

        XCTAssertTrue(MultiChainFeaturePolicy.current.demeterMutationsEnabled)
    }

    func testDemeterDepositBoundaryUsesExactPoolAssetAndFreshXORFee() throws {
        let pool = makeDemeterPool()
        let snapshot = makeDemeterSnapshot(pool: pool, pooledTokens: "200", rewards: "1")
        let balances = makeDemeterBalances(pool: pool, poolSpendable: 150, feeSpendable: 10)

        XCTAssertNoThrow(
            try DemeterMutationBoundaryValidator.validate(
                .deposit(pool: pool, amount: "100"),
                snapshot: snapshot,
                balances: balances,
                requiredFee: 5
            )
        )
        XCTAssertThrowsError(
            try DemeterMutationBoundaryValidator.validate(
                .deposit(pool: pool, amount: "151"),
                snapshot: snapshot,
                balances: balances,
                requiredFee: 5
            )
        ) { error in
            XCTAssertEqual(error as? DemeterSubmissionError, .insufficientAsset)
        }

        let wrongAsset = DemeterAuthoritativeBalances(
            poolAssetKey: AssetKey(
                ecosystem: "substrate",
                chainId: PolkamarktConstants.soraChainId,
                assetId: "0xnot-the-runtime-pool-asset"
            ),
            feeAssetKey: balances.feeAssetKey,
            poolAssetSpendable: 1_000,
            feeSpendable: 1_000
        )
        XCTAssertThrowsError(
            try DemeterMutationBoundaryValidator.validate(
                .deposit(pool: pool, amount: "100"),
                snapshot: snapshot,
                balances: wrongAsset,
                requiredFee: 5
            )
        ) { error in
            XCTAssertEqual(error as? DemeterSubmissionError, .balanceUnavailable)
        }
    }

    func testDemeterWithdrawBoundaryUsesAuthoritativeExactPosition() throws {
        let pool = makeDemeterPool()
        let snapshot = makeDemeterSnapshot(pool: pool, pooledTokens: "100", rewards: "1")
        let balances = makeDemeterBalances(pool: pool, poolSpendable: 0, feeSpendable: 10)

        XCTAssertNoThrow(
            try DemeterMutationBoundaryValidator.validate(
                .withdraw(pool: pool, amount: "100"),
                snapshot: snapshot,
                balances: balances,
                requiredFee: 5
            )
        )
        XCTAssertThrowsError(
            try DemeterMutationBoundaryValidator.validate(
                .withdraw(pool: pool, amount: "101"),
                snapshot: snapshot,
                balances: balances,
                requiredFee: 5
            )
        ) { error in
            XCTAssertEqual(error as? DemeterSubmissionError, .insufficientPosition)
        }
    }

    func testDemeterClaimBoundaryRequiresCurrentExactPositionReward() throws {
        let pool = makeDemeterPool()
        let balances = makeDemeterBalances(pool: pool, poolSpendable: 0, feeSpendable: 10)
        XCTAssertNoThrow(
            try DemeterMutationBoundaryValidator.validate(
                .claim(pool: pool),
                snapshot: makeDemeterSnapshot(pool: pool, pooledTokens: "0", rewards: "1"),
                balances: balances,
                requiredFee: 5
            )
        )
        XCTAssertThrowsError(
            try DemeterMutationBoundaryValidator.validate(
                .claim(pool: pool),
                snapshot: makeDemeterSnapshot(pool: pool, pooledTokens: "100", rewards: "0"),
                balances: balances,
                requiredFee: 5
            )
        ) { error in
            XCTAssertEqual(error as? DemeterSubmissionError, .claimUnavailable)
        }
    }

    func testDemeterCallPayloadsPreserveRuntimeIdentitiesAndLargeIntegerStrings() throws {
        let pool = makeDemeterPool()
        let amount = "900719925474099312345678901234567890"
        let data = try JSONEncoder().encode(
            DemeterDepositCall(
                baseAsset: SoraAssetId(wrappedValue: pool.identity.baseAssetId),
                poolAsset: SoraAssetId(wrappedValue: pool.identity.poolAssetId),
                rewardAsset: SoraAssetId(wrappedValue: pool.identity.rewardAssetId),
                isFarm: pool.identity.isFarm,
                pooledTokens: amount
            )
        )
        let payload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        XCTAssertEqual(encodedSoraAssetId(payload["base_asset"]), pool.identity.baseAssetId)
        XCTAssertEqual(
            encodedSoraAssetId(payload["pool_asset"]),
            pool.identity.poolAssetId,
            String(data: data, encoding: .utf8) ?? "Invalid JSON"
        )
        XCTAssertEqual(encodedSoraAssetId(payload["reward_asset"]), pool.identity.rewardAssetId)
        XCTAssertEqual(payload["pooled_tokens"] as? String, amount)
        XCTAssertEqual(payload["is_farm"] as? Bool, pool.identity.isFarm)
    }

    private func encodedSoraAssetId(_ value: Any?) -> String? {
        guard let object = value as? [String: Any],
              let encodedBytes = object["code"] as? [String],
              encodedBytes.count == 32 else {
            return nil
        }

        let bytes = encodedBytes.compactMap { UInt8($0, radix: 10) }
        guard bytes.count == encodedBytes.count else {
            return nil
        }

        return bytes.reduce(into: "0x") { result, byte in
            result += String(format: "%02x", Int(byte))
        }
    }

    func testStakingPositionFactorySurfacesOnlyPositiveAuthoritativeLocks() {
        let chain = makePositionChain()
        let asset = ChainAsset(chain: chain, asset: chain.utilityChainAssets()[0].asset)
        let positive = DeFiPositionRowFactory.staking(
            StakingLocks(
                staked: Decimal(string: "12.5")!,
                unstaking: Decimal(string: "1.25")!,
                redeemable: .zero,
                claimable: Decimal(string: "0.5")!
            ),
            chainAsset: asset,
            feature: .staking
        )
        let empty = DeFiPositionRowFactory.staking(
            StakingLocks(staked: .zero, unstaking: .zero, redeemable: .zero, claimable: .zero),
            chainAsset: asset,
            feature: .staking
        )

        XCTAssertEqual(positive.count, 1)
        XCTAssertEqual(positive.first?.feature, .staking)
        XCTAssertTrue(positive.first?.subtitle.contains("12.5 UNIT staked") == true)
        XCTAssertTrue(empty.isEmpty)
    }

    func testSoraLiquidityPositionFactoryUsesCanonicalAssetKeysWithoutSymbolAggregation() throws {
        let fixture = makeSoraLiquidityPositionFixture()
        let positions = [
            AccountPool(
                poolId: "\(fixture.baseAssetId)-\(fixture.targetAssetIds[0])",
                accountId: "0xaccount",
                chainId: fixture.chain.chainId,
                baseAssetId: fixture.baseAssetId,
                targetAssetId: fixture.targetAssetIds[0],
                baseAssetPooled: Decimal(string: "12.5"),
                targetAssetPooled: Decimal(string: "25"),
                accountPoolShare: Decimal(string: "0.75")
            ),
            AccountPool(
                poolId: "\(fixture.baseAssetId)-\(fixture.targetAssetIds[1])",
                accountId: "0xaccount",
                chainId: fixture.chain.chainId,
                baseAssetId: fixture.baseAssetId,
                targetAssetId: fixture.targetAssetIds[1],
                baseAssetPooled: Decimal(string: "2"),
                targetAssetPooled: Decimal(string: "4"),
                accountPoolShare: Decimal(string: "0.1")
            )
        ]

        let rows = try DeFiPositionRowFactory.liquidityPools(positions, chain: fixture.chain)

        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(Set(rows.map(\.id)).count, 2)
        XCTAssertTrue(rows.allSatisfy { $0.feature == .liquidityPools && $0.kind == .position })
        XCTAssertTrue(rows.allSatisfy { $0.title == "XOR / USD liquidity" })
        XCTAssertTrue(rows.allSatisfy { !$0.id.contains("USD") })
        XCTAssertEqual(
            Set(rows.compactMap { $0.assetKeys.first?.assetId }),
            Set([fixture.baseAssetId])
        )
        XCTAssertEqual(
            Set(rows.compactMap { $0.assetKeys.last?.assetId }),
            Set(fixture.targetAssetIds)
        )
        XCTAssertTrue(rows.allSatisfy { $0.subtitle.contains("SORA") })
    }

    func testSoraLiquidityPositionFactoryDistinguishesZeroFromUnavailableBalance() throws {
        let fixture = makeSoraLiquidityPositionFixture()
        let poolId = "\(fixture.baseAssetId)-\(fixture.targetAssetIds[0])"
        let zero = AccountPool(
            poolId: poolId,
            accountId: "0xaccount",
            chainId: fixture.chain.chainId,
            baseAssetId: fixture.baseAssetId,
            targetAssetId: fixture.targetAssetIds[0],
            baseAssetPooled: .zero,
            targetAssetPooled: .zero,
            accountPoolShare: .zero
        )
        let missingBalance = AccountPool(
            poolId: poolId,
            accountId: "0xaccount",
            chainId: fixture.chain.chainId,
            baseAssetId: fixture.baseAssetId,
            targetAssetId: fixture.targetAssetIds[0],
            baseAssetPooled: Decimal(1),
            targetAssetPooled: nil,
            accountPoolShare: Decimal(string: "0.1")
        )

        XCTAssertTrue(
            try DeFiPositionRowFactory.liquidityPools([zero], chain: fixture.chain).isEmpty
        )
        XCTAssertThrowsError(
            try DeFiPositionRowFactory.liquidityPools([missingBalance], chain: fixture.chain)
        ) { error in
            XCTAssertEqual(
                error as? SoraLiquidityPoolPositionError,
                .balanceUnavailable(poolId: poolId)
            )
        }
    }

    func testSoraLiquidityPositionSourceHasHonestLoadingZeroAndErrorStates() async {
        let fixture = makeSoraLiquidityPositionFixture()
        let accountId = Data([0x01, 0x02])
        let zero = AccountPool(
            poolId: "\(fixture.baseAssetId)-\(fixture.targetAssetIds[0])",
            accountId: accountId.toHex(),
            chainId: fixture.chain.chainId,
            baseAssetId: fixture.baseAssetId,
            targetAssetId: fixture.targetAssetIds[0],
            baseAssetPooled: .zero,
            targetAssetPooled: .zero,
            accountPoolShare: .zero
        )
        let zeroSource = SoraLiquidityPoolDeFiPositionSource(
            chain: fixture.chain,
            accountId: accountId,
            loader: SoraLiquidityPoolPositionLoaderStub(result: .success([zero]))
        )
        let zeroSnapshot = await DeFiPositionsAggregator(
            sources: [zeroSource],
            explicitlyUnavailableRows: []
        ).load()

        XCTAssertEqual(DeFiHubPositionRow.loadingPositions.kind, .loading)
        XCTAssertFalse(zeroSnapshot.hasPositivePositions)
        XCTAssertFalse(zeroSnapshot.hasPartialFailure)
        XCTAssertEqual(zeroSnapshot.rows.map(\.kind), [.empty])

        let failedSource = SoraLiquidityPoolDeFiPositionSource(
            chain: fixture.chain,
            accountId: accountId,
            loader: SoraLiquidityPoolPositionLoaderStub(result: .failure(.offline))
        )
        let failedSnapshot = await DeFiPositionsAggregator(
            sources: [failedSource],
            explicitlyUnavailableRows: []
        ).load()

        XCTAssertFalse(failedSnapshot.hasPositivePositions)
        XCTAssertTrue(failedSnapshot.hasPartialFailure)
        XCTAssertTrue(failedSnapshot.rows.contains { $0.kind == .empty })
        XCTAssertTrue(failedSnapshot.rows.contains {
            $0.kind == .status &&
                $0.feature == .liquidityPools &&
                $0.title == "Liquidity pools positions unavailable" &&
                $0.subtitle == "Source offline"
        })
    }

    func testRepeatedAppearancePreservesControllerManagedTabBar() {
        let (viewController, presenter) = makeViewController()

        viewController.loadViewIfNeeded()
        let controllerManagedTabBar = viewController.tabBar

        performAppearanceTransition(on: viewController, appearing: true)
        assertStableTabBar(viewController, expectedTabBar: controllerManagedTabBar)

        performAppearanceTransition(on: viewController, appearing: false)
        performAppearanceTransition(on: viewController, appearing: true)
        viewController.view.layoutIfNeeded()
        viewController.tabBar.layoutIfNeeded()

        assertStableTabBar(viewController, expectedTabBar: controllerManagedTabBar)
        XCTAssertEqual(presenter.didLoadCallCount, 1)

        let middleButton = controls(in: viewController.tabBar)
            .compactMap { $0 as? TabBarMiddleButton }
            .first

        middleButton?.sendActions(for: .touchUpInside)
        XCTAssertEqual(viewController.selectedIndex, MainTabBarDestination.polkaswap.rawValue)

        performAppearanceTransition(on: viewController, appearing: false)
    }

    func testApplicationDoesNotForcePreIOS26DesignCompatibility() {
        XCTAssertNil(
            Bundle.main.object(forInfoDictionaryKey: "UIDesignRequiresCompatibility")
        )
    }

    private func makePositionChain() -> ChainModel {
        let asset = AssetModel(
            id: "UNIT",
            name: "Unit",
            symbol: "UNIT",
            precision: 12,
            isUtility: true,
            isNative: true
        )
        return ChainModel(
            rank: 1,
            disabled: false,
            chainId: "unit-staking",
            parentId: nil,
            paraId: nil,
            name: "Unit Network",
            assets: [asset],
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

    func testTabBarRendersEveryItemControlInWindow() {
        let (viewController, _) = makeViewController()
        viewController.loadViewIfNeeded()
        let controllerManagedTabBar = viewController.tabBar
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))

        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()
        viewController.tabBar.layoutIfNeeded()

        assertStableTabBar(viewController, expectedTabBar: controllerManagedTabBar)
        assertRenderedItemControls(viewController, in: window)
    }

    func testReselectingRaisedPolkaswapDestinationReturnsItsStackToRoot() {
        let presenter = MainTabBarPresenterStub()
        let viewControllers = MainTabBarDestination.allCases.map { destination -> UIViewController in
            let root = UIViewController()
            root.tabBarItem = UITabBarItem(
                title: destination.title,
                image: UIImage(systemName: "circle"),
                tag: destination.rawValue
            )
            return UINavigationController(rootViewController: root)
        }
        let viewController = MainTabBarViewController(
            viewControllers: viewControllers,
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )
        viewController.loadViewIfNeeded()
        viewController.select(destination: .polkaswap)

        let polkaswapNavigation = viewControllers[MainTabBarDestination.polkaswap.rawValue]
            as? UINavigationController
        polkaswapNavigation?.pushViewController(UIViewController(), animated: false)
        XCTAssertEqual(polkaswapNavigation?.viewControllers.count, 2)

        viewController.select(destination: .polkaswap)

        XCTAssertEqual(polkaswapNavigation?.viewControllers.count, 1)
        XCTAssertEqual(viewController.selectedIndex, MainTabBarDestination.polkaswap.rawValue)
    }

    func testUnavailablePolkaswapRootCanBeRecoveredAfterServicesStart() {
        let presenter = MainTabBarPresenterStub()
        var viewControllers = MainTabBarDestination.allCases.map { _ -> UIViewController in
            UINavigationController(rootViewController: UIViewController())
        }
        viewControllers[MainTabBarDestination.polkaswap.rawValue] = UINavigationController(
            rootViewController: FeatureUnavailableViewController(
                title: "Polkaswap",
                message: "Services are starting",
                icon: nil
            )
        )
        let viewController = MainTabBarViewController(
            viewControllers: viewControllers,
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        XCTAssertTrue(viewController.isPolkaswapUnavailable)

        let availableController = UINavigationController(rootViewController: UIViewController())
        viewController.didReplaceView(
            for: availableController,
            for: MainTabBarDestination.polkaswap.rawValue
        )

        XCTAssertFalse(viewController.isPolkaswapUnavailable)
        XCTAssertTrue(
            viewController.viewControllers?[MainTabBarDestination.polkaswap.rawValue] === availableController
        )
    }

    func testChainSetupEventRetriesPolkaswapAfterInitialAssemblyAttempt() {
        let serviceCoordinator = MainTabBarServiceCoordinatorSpy()
        let output = MainTabBarInteractorOutputSpy()
        let interactor = MainTabBarInteractor(
            eventCenter: EventCenterProtocolStub(),
            serviceCoordinator: serviceCoordinator,
            keystoreImportService: MainTabBarKeystoreImportServiceStub()
        )

        interactor.setup(with: output)

        XCTAssertEqual(serviceCoordinator.setupCallCount, 1)
        XCTAssertEqual(output.didPrepareChainsCallCount, 1)

        let retried = expectation(description: "Polkaswap assembly retried after chain setup")
        output.onDidPrepareChains = {
            retried.fulfill()
        }
        interactor.processChainsSetupCompleted()

        wait(for: [retried], timeout: 1)
        XCTAssertEqual(output.didPrepareChainsCallCount, 2)
    }

    func testBundledPolkaswapSettingsSupportOfflineCleanStartup() throws {
        let settings = try XCTUnwrap(PolkaswapSettingsFactory.bundledSettings())
        let dexIds = settings.availableDexIds.map(\.code)

        XCTAssertFalse(dexIds.isEmpty)
        XCTAssertEqual(Set(dexIds).count, dexIds.count)
        XCTAssertTrue(dexIds.contains(0))
        XCTAssertFalse(settings.xstusdId.isEmpty)
        XCTAssertTrue(
            settings.availableDexIds.contains { $0.assetId == settings.xstusdId }
        )
    }

    func testPolkaswapSettingsSyncPublishesOnlyAfterCleanInstallPersistence() throws {
        let settings = try XCTUnwrap(PolkaswapSettingsFactory.bundledSettings())
        let repository = PolkaswapSettingsRepositoryProbe(localSettings: [])
        let published = expectation(description: "persisted Polkaswap settings published")
        let eventCenter = PolkaswapSettingsEventCenterProbe(
            repository: repository,
            expectation: published
        )
        let service = PolkaswapSettingsSyncService(
            settingsUrl: URL(string: "https://example.invalid/polkaswapSettings.json"),
            dataFetchFactory: StaticPolkaswapSettingsDataFactory(
                data: try JSONEncoder().encode(settings)
            ),
            repository: AnyDataProviderRepository(repository),
            operationQueue: OperationQueue(),
            eventCenter: eventCenter
        )

        service.syncUp()

        wait(for: [published], timeout: 1)
        XCTAssertEqual(repository.savedSettings, [settings])
        XCTAssertTrue(eventCenter.observedPersistedSettings)
        XCTAssertFalse(service.isSyncing)
    }

    func testPolkaswapSettingsSyncCompletesWhenRemoteVersionIsUnchanged() throws {
        let settings = try XCTUnwrap(PolkaswapSettingsFactory.bundledSettings())
        let repository = PolkaswapSettingsRepositoryProbe(localSettings: [settings])
        let published = expectation(description: "unchanged Polkaswap settings published")
        let eventCenter = PolkaswapSettingsEventCenterProbe(
            repository: repository,
            expectation: published
        )
        let service = PolkaswapSettingsSyncService(
            settingsUrl: URL(string: "https://example.invalid/polkaswapSettings.json"),
            dataFetchFactory: StaticPolkaswapSettingsDataFactory(
                data: try JSONEncoder().encode(settings)
            ),
            repository: AnyDataProviderRepository(repository),
            operationQueue: OperationQueue(),
            eventCenter: eventCenter
        )

        service.syncUp()

        wait(for: [published], timeout: 1)
        XCTAssertEqual(repository.saveCallCount, 0)
        XCTAssertFalse(service.isSyncing)
    }

    func testPolkaswapFeeCoverageRequiresInputAndFeeWhenSpendingXor() {
        let amounts = PolkaswapSwapResolvedAmounts(
            desired: 100,
            slip: 120,
            requiredInput: 120
        )

        for variant in [SwapVariant.desiredInput, .desiredOutput] {
            XCTAssertTrue(
                PolkaswapFeeCoverage.isSufficient(
                    inputIsXor: true,
                    outputIsXor: false,
                    swapVariant: variant,
                    amounts: amounts,
                    xorBalance: 125,
                    fee: 5
                )
            )
            XCTAssertFalse(
                PolkaswapFeeCoverage.isSufficient(
                    inputIsXor: true,
                    outputIsXor: false,
                    swapVariant: variant,
                    amounts: amounts,
                    xorBalance: 124,
                    fee: 5
                )
            )
        }
    }

    func testPolkaswapFeeCoverageUsesBoundedXorOutputForPostponedFee() {
        let amounts = PolkaswapSwapResolvedAmounts(
            desired: 7,
            slip: 5,
            requiredInput: 100
        )
        let cases: [(SwapVariant, BigUInt)] = [
            (.desiredInput, amounts.slip),
            (.desiredOutput, amounts.desired)
        ]

        for (variant, boundedOutput) in cases {
            XCTAssertTrue(
                PolkaswapFeeCoverage.isSufficient(
                    inputIsXor: false,
                    outputIsXor: true,
                    swapVariant: variant,
                    amounts: amounts,
                    xorBalance: 2,
                    fee: boundedOutput + 2
                )
            )
            XCTAssertFalse(
                PolkaswapFeeCoverage.isSufficient(
                    inputIsXor: false,
                    outputIsXor: true,
                    swapVariant: variant,
                    amounts: amounts,
                    xorBalance: 1,
                    fee: boundedOutput + 2
                )
            )
        }
    }

    func testPolkaswapFeeCoverageRequiresExistingXorForNonXorOutput() {
        let amounts = PolkaswapSwapResolvedAmounts(
            desired: 100,
            slip: 120,
            requiredInput: 120
        )

        for variant in [SwapVariant.desiredInput, .desiredOutput] {
            XCTAssertTrue(
                PolkaswapFeeCoverage.isSufficient(
                    inputIsXor: false,
                    outputIsXor: false,
                    swapVariant: variant,
                    amounts: amounts,
                    xorBalance: 5,
                    fee: 5
                )
            )
            XCTAssertFalse(
                PolkaswapFeeCoverage.isSufficient(
                    inputIsXor: false,
                    outputIsXor: false,
                    swapVariant: variant,
                    amounts: amounts,
                    xorBalance: 4,
                    fee: 5
                )
            )
        }
    }

    func testPolkaswapOperationBatchCompletesWhenAnOperationIsCancelled() {
        let batch = PolkaswapOperationBatch<Int>(expectedCount: 2)
        let notified = expectation(description: "cancelled operation still completes batch")

        batch.notify(on: .main) { values, errors in
            XCTAssertEqual(values, [7])
            XCTAssertEqual(errors.count, 1)
            XCTAssertTrue(errors.first is BaseOperationError)
            notified.fulfill()
        }

        DispatchQueue.global().async {
            batch.complete(.success(7))
        }
        DispatchQueue.global().async {
            batch.complete(nil)
        }

        wait(for: [notified], timeout: 1)
    }

    func testConcurrentPolkaswapOperationBatchesNeverMixResults() {
        let resultCount = 500
        let firstBatch = PolkaswapOperationBatch<Int>(expectedCount: resultCount)
        let secondBatch = PolkaswapOperationBatch<Int>(expectedCount: resultCount)
        let firstNotified = expectation(description: "first quote batch")
        let secondNotified = expectation(description: "second quote batch")

        firstBatch.notify(on: .main) { values, errors in
            XCTAssertEqual(values.count, resultCount)
            XCTAssertTrue(values.allSatisfy { (0 ..< resultCount).contains($0) })
            XCTAssertTrue(errors.isEmpty)
            firstNotified.fulfill()
        }
        secondBatch.notify(on: .main) { values, errors in
            XCTAssertEqual(values.count, resultCount)
            XCTAssertTrue(values.allSatisfy { (resultCount ..< 2 * resultCount).contains($0) })
            XCTAssertTrue(errors.isEmpty)
            secondNotified.fulfill()
        }

        DispatchQueue.global().async {
            DispatchQueue.concurrentPerform(iterations: resultCount) { index in
                firstBatch.complete(.success(index))
                secondBatch.complete(.success(index + resultCount))
            }
        }

        wait(for: [firstNotified, secondNotified], timeout: 2)
    }

    func testPolkaswapQuoteResponsePolicyRejectsOlderEquivalentRequest() {
        let older = PolkaswapQuoteParams(
            requestId: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            fromAssetId: "xor",
            toAssetId: "val",
            amount: "1",
            swapVariant: .desiredInput,
            liquiditySources: ["XYKPool"],
            filterMode: .allowSelected
        )
        let latest = PolkaswapQuoteParams(
            requestId: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            fromAssetId: older.fromAssetId,
            toAssetId: older.toAssetId,
            amount: older.amount,
            swapVariant: older.swapVariant,
            liquiditySources: older.liquiditySources,
            filterMode: older.filterMode
        )

        XCTAssertFalse(
            PolkaswapQuoteResponsePolicy.shouldAccept(
                response: older,
                latest: latest,
                currentFromAssetId: latest.fromAssetId,
                currentToAssetId: latest.toAssetId
            )
        )
        XCTAssertTrue(
            PolkaswapQuoteResponsePolicy.shouldAccept(
                response: latest,
                latest: latest,
                currentFromAssetId: latest.fromAssetId,
                currentToAssetId: latest.toAssetId
            )
        )
        XCTAssertFalse(
            PolkaswapQuoteResponsePolicy.shouldAccept(
                response: latest,
                latest: latest,
                currentFromAssetId: latest.fromAssetId,
                currentToAssetId: "different"
            )
        )
    }

    func testReviewedXcmRegistryAcceptsExactRuntimeRouteAndRejectsDestinationDrift() throws {
        let definition = try XCTUnwrap(
            ReviewedXcmRouteRegistry.routes.first { $0.originSymbol == "DOT" }
        )
        let destinationId = try XCTUnwrap(definition.destinationChainIds.first)
        let runtimeAsset = XcmAvailableAsset(
            id: definition.xcmAssetId,
            symbol: definition.originSymbol
        )
        let exactDestination = XcmAvailableDestination(
            chainId: destinationId,
            bridgeParachainId: nil,
            assets: [runtimeAsset]
        )
        let destination = makeChain(id: destinationId, name: "Polkadot")
        let exactOrigin = makeChain(
            id: definition.originChainId,
            name: "SORA",
            xcm: XcmChain(
                xcmVersion: .V3,
                destWeightIsPrimitive: nil,
                availableAssets: [runtimeAsset],
                availableDestinations: [exactDestination]
            ),
            asset: makeAsset(
                id: definition.originAssetId,
                symbol: definition.originSymbol,
                precision: definition.originPrecision,
                currencyId: reviewedRuntimeCurrencyId(definition)
            )
        )

        XCTAssertNotNil(
            ReviewedXcmRouteRegistry.validatedOrigin(
                for: definition,
                chainsById: [exactOrigin.chainId: exactOrigin, destination.chainId: destination]
            )
        )

        let unknownDestinationId = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
        let driftedOrigin = makeChain(
            id: definition.originChainId,
            name: "SORA",
            xcm: XcmChain(
                xcmVersion: .V3,
                destWeightIsPrimitive: nil,
                availableAssets: [runtimeAsset],
                availableDestinations: [
                    exactDestination,
                    XcmAvailableDestination(
                        chainId: unknownDestinationId,
                        bridgeParachainId: nil,
                        assets: [runtimeAsset]
                    )
                ]
            ),
            asset: makeAsset(
                id: definition.originAssetId,
                symbol: definition.originSymbol,
                precision: definition.originPrecision,
                currencyId: reviewedRuntimeCurrencyId(definition)
            )
        )
        let unknownDestination = makeChain(id: unknownDestinationId, name: "Unknown")

        XCTAssertNil(
            ReviewedXcmRouteRegistry.validatedOrigin(
                for: definition,
                chainsById: [
                    driftedOrigin.chainId: driftedOrigin,
                    destination.chainId: destination,
                    unknownDestination.chainId: unknownDestination
                ]
            )
        )
    }

    func testCrossChainProviderRegistrySeparatesExactBurnAdaptersAndKeepsUnsupportedProviderVisible() {
        XCTAssertEqual(
            CrossChainProviderRegistry.defaultProviders.map(\.identifier),
            [
                "wallet-xcm",
                "polkaswap-sora-substrate",
                "sora-liberland-xcm",
                "polkaswap-sora-evm"
            ]
        )
        XCTAssertEqual(
            CrossChainProviderRegistry.defaultProviders.map(\.displayName),
            [
                "Wallet XCM",
                "Polkaswap SORA ↔ Substrate",
                "SORA ↔ Liberland",
                "Polkaswap SORA ↔ EVM"
            ]
        )
        XCTAssertTrue(ReviewedXcmRouteRegistry.soraSubstrateRoutes.allSatisfy {
            $0.originChainId != ReviewedXcmRouteRegistry.liberlandChainId &&
                !$0.destinationChainIds.contains(ReviewedXcmRouteRegistry.liberlandChainId)
        })
        XCTAssertTrue(ReviewedXcmRouteRegistry.liberlandRoutes.allSatisfy {
            $0.originChainId == ReviewedXcmRouteRegistry.liberlandChainId ||
                $0.destinationChainIds.contains(ReviewedXcmRouteRegistry.liberlandChainId)
        })
        XCTAssertEqual(
            ReviewedXcmRouteRegistry.soraSubstrateRoutes.count + ReviewedXcmRouteRegistry.liberlandRoutes.count,
            ReviewedXcmRouteRegistry.routes.count
        )

        let provider = PolkaswapEvmBridgeRouteProvider()
        let routes = provider.origins(wallet: AccountGenerator.generateMetaAccount(), chains: [])
        let capability = provider.capability(for: routes)
        XCTAssertTrue(routes.isEmpty)
        XCTAssertFalse(capability.isAvailable)
        XCTAssertEqual(capability.identifier, "polkaswap-sora-evm")
        XCTAssertTrue(capability.reason?.contains("no reviewed executable") == true)

        let wallet = AccountGenerator.generateMetaAccount()
        let walletXcmRoutes = WalletXcmRouteProvider().origins(wallet: wallet, chains: [])
        let soraSubstrateRoutes = SoraSubstrateBridgeRouteProvider().origins(wallet: wallet, chains: [])
        let liberlandRoutes = LiberlandXcmRouteProvider().origins(wallet: wallet, chains: [])
        XCTAssertTrue(walletXcmRoutes.isEmpty)
        XCTAssertTrue(soraSubstrateRoutes.isEmpty)
        XCTAssertTrue(liberlandRoutes.isEmpty)
        XCTAssertTrue(ReviewedXcmExecutionAuthority.isAvailable)
        XCTAssertTrue(ReviewedXcmRouteRegistry.soraSubstrateRoutes.allSatisfy {
            $0.execution.runtimeCall == .soraBridgeProxyBurn
        })
        XCTAssertTrue(ReviewedXcmRouteRegistry.liberlandRoutes.allSatisfy {
            $0.execution.runtimeCall == .soraBridgeProxyBurn ||
                $0.execution.runtimeCall == .liberlandSoraBridgeAppBurn
        })
        XCTAssertEqual(
            Set(ReviewedXcmRouteRegistry.routes.map { $0.execution.fingerprint }).count,
            ReviewedXcmRouteRegistry.routes.count
        )
        XCTAssertTrue(
            WalletXcmRouteProvider().capability(for: walletXcmRoutes).reason?
                .contains("SSFXCM") == true
        )
        XCTAssertTrue(
            SoraSubstrateBridgeRouteProvider().capability(for: soraSubstrateRoutes).reason?
                .contains("bridgeProxy.burn") == true
        )
    }

    func testUnavailableCrossChainInventoryIsExactVisibleAndCannotExecute() {
        let walletRoutes = ReviewedWalletXcmRouteCatalog.routes
        XCTAssertEqual(walletRoutes.count, 15)
        XCTAssertTrue(walletRoutes.allSatisfy { $0.providerId == "wallet-xcm" })
        XCTAssertTrue(walletRoutes.allSatisfy { $0.protocolName == "Polkadot XCM v3" })
        XCTAssertTrue(walletRoutes.allSatisfy { $0.minimumAmount == nil })
        XCTAssertTrue(walletRoutes.allSatisfy { !$0.isExecutable })
        XCTAssertTrue(walletRoutes.allSatisfy { !$0.warnings.isEmpty })
        XCTAssertTrue(walletRoutes.allSatisfy {
            $0.unavailableReason.contains("adjacent final submission guard")
        })
        XCTAssertEqual(Set(walletRoutes.map(\.id)).count, walletRoutes.count)
        XCTAssertEqual(
            Set(walletRoutes.map(\.symbol)),
            Set(["DOT", "KSM"])
        )
        XCTAssertEqual(
            Set(walletRoutes.map { $0.originRouteAssetId }),
            Set([
                "99e66d4f-00cd-4d73-bd1b-3adadcacffb2",
                "0ceffe96-8090-404e-815c-91118ee5dd65"
            ])
        )
        XCTAssertTrue(walletRoutes.contains {
            $0.originNetworkName == "Moonbeam" &&
                $0.destinationNetworkName == "Polkadot" &&
                $0.originCatalogAssetId == "7e4e064e-2b23-4eb5-96db-e6491c4031e5" &&
                $0.assetKey == AssetKey(
                    ecosystem: "evm",
                    chainId: "fe58ea77779b7abda7da4ec526d14db9b1e9cd40a217c34892af80a9b332b76d",
                    assetId: "42259045809535163221576417993425387648"
                )
        })
        XCTAssertTrue(walletRoutes.contains {
            $0.originNetworkName == "Parallel" &&
                $0.destinationNetworkName == "Polkadot" &&
                $0.originCatalogAssetId == "769ffb89-fd2f-4add-94a1-d2f9f716c143" &&
                $0.originCanonicalAssetId == "101"
        })

        let evmRoutes = ReviewedSoraEvmRouteCatalog.routes
        XCTAssertEqual(evmRoutes.count, 2)
        XCTAssertTrue(evmRoutes.allSatisfy { $0.providerId == "polkaswap-sora-evm" })
        XCTAssertTrue(evmRoutes.allSatisfy { !$0.isExecutable })
        XCTAssertTrue(evmRoutes.allSatisfy { $0.symbol == "ETH" && $0.precision == 18 })
        XCTAssertEqual(
            Set(evmRoutes.map { "\($0.originChainId)->\($0.destinationChainId)" }),
            Set([
                "\(ReviewedXcmRouteRegistry.soraChainId)->1",
                "1->\(ReviewedXcmRouteRegistry.soraChainId)"
            ])
        )
        let soraToEthereum = evmRoutes.first {
            $0.originChainId == ReviewedXcmRouteRegistry.soraChainId
        }
        XCTAssertEqual(
            soraToEthereum?.originCanonicalAssetId,
            "0x0200070000000000000000000000000000000000000000000000000000000000"
        )
        XCTAssertEqual(
            soraToEthereum?.destinationCatalogAssetId,
            "c2a6c062-d511-4bde-9ce6-ea775d2a302c"
        )
        let ethereumToSora = evmRoutes.first { $0.originChainId == "1" }
        XCTAssertEqual(ethereumToSora?.originCatalogAssetId, "c2a6c062-d511-4bde-9ce6-ea775d2a302c")
        XCTAssertEqual(ethereumToSora?.destinationCatalogAssetId, "82f45df3-b6d8-43e7-a440-c0e73ab59785")

        let inventory = ReviewedUnavailableCrossChainRouteCatalog.routes
        XCTAssertEqual(inventory.count, 17)
        XCTAssertEqual(Set(inventory.map(\.id)).count, inventory.count)
        XCTAssertTrue(inventory.allSatisfy { !$0.isExecutable })

        let wallet = AccountGenerator.generateMetaAccount()
        let walletProvider = WalletXcmRouteProvider()
        let evmProvider = PolkaswapEvmBridgeRouteProvider()
        XCTAssertEqual(walletProvider.reviewedUnavailableRoutes, walletRoutes)
        XCTAssertEqual(evmProvider.reviewedUnavailableRoutes, evmRoutes)
        XCTAssertTrue(walletProvider.origins(wallet: wallet, chains: []).isEmpty)
        XCTAssertTrue(evmProvider.origins(wallet: wallet, chains: []).isEmpty)

        let viewController = CrossChainRootViewController(
            wallet: wallet,
            providers: [],
            unavailableRouteInventory: inventory
        )
        viewController.loadViewIfNeeded()
        XCTAssertEqual(
            viewController.tableView(UITableView(), numberOfRowsInSection: 0),
            inventory.count
        )
    }

    func testLiberlandLldRoutesKeepCatalogAndXcmIdentitiesSeparate() throws {
        let soraLld = try XCTUnwrap(
            ReviewedXcmRouteRegistry.routes.first {
                $0.originChainId == ReviewedXcmRouteRegistry.soraChainId &&
                    $0.originSymbol == "LLD"
            }
        )
        XCTAssertEqual(soraLld.originAssetId, "1c3b4fcb-5a5f-4319-9dce-d178006eb9bf")
        XCTAssertEqual(soraLld.xcmAssetId, "a6b83d39-a488-4b34-8352-280705a792ea")
        XCTAssertNotEqual(soraLld.originAssetId, soraLld.xcmAssetId)
        XCTAssertEqual(soraLld.originPrecision, 18)
        XCTAssertEqual(soraLld.minimumDisplay, "1.1 LLD")
        XCTAssertEqual(soraLld.execution.minimumAmount, "1100000000000000000")
        XCTAssertEqual(
            soraLld.execution.asset,
            .soraAsset(
                currencyId: "0x00513be65493a7fc3e2128d4230061a530acf40478a4affa20bbba27a310673e"
            )
        )
        XCTAssertTrue(soraLld.warnings.contains { $0.contains("both must match independently") })

        let liberlandLld = try XCTUnwrap(
            ReviewedXcmRouteRegistry.routes.first {
                $0.originChainId == ReviewedXcmRouteRegistry.liberlandChainId &&
                    $0.originSymbol == "LLD"
            }
        )
        XCTAssertEqual(liberlandLld.originAssetId, "a6b83d39-a488-4b34-8352-280705a792ea")
        XCTAssertEqual(liberlandLld.xcmAssetId, "a6b83d39-a488-4b34-8352-280705a792e")
        XCTAssertNotEqual(liberlandLld.originAssetId, liberlandLld.xcmAssetId)
        XCTAssertEqual(liberlandLld.originPrecision, 12)
        XCTAssertEqual(liberlandLld.minimumDisplay, "1.1 LLD")
        XCTAssertEqual(liberlandLld.execution.minimumAmount, "1100000000000")
        XCTAssertEqual(liberlandLld.execution.asset, .liberlandNativeLLD)
        XCTAssertTrue(liberlandLld.warnings.contains { $0.contains("does not equal") })

        let liberlandLlm = try XCTUnwrap(
            ReviewedXcmRouteRegistry.routes.first {
                $0.originChainId == ReviewedXcmRouteRegistry.liberlandChainId &&
                    $0.originSymbol == "LLM"
            }
        )
        let liberlandXor = try XCTUnwrap(
            ReviewedXcmRouteRegistry.routes.first {
                $0.originChainId == ReviewedXcmRouteRegistry.liberlandChainId &&
                    $0.originSymbol == "XOR"
            }
        )
        XCTAssertEqual(liberlandLlm.originPrecision, 12)
        XCTAssertEqual(liberlandLlm.execution.asset, .liberlandAsset(currencyId: "1"))
        XCTAssertEqual(liberlandXor.originPrecision, 12)
        XCTAssertEqual(liberlandXor.execution.asset, .liberlandAsset(currencyId: "774441749"))

        for definition in [soraLld, liberlandLld] {
            let minimum = try XCTUnwrap(
                definition.execution.minimumAmount.flatMap { BigUInt($0, radix: 10) }
            )
            let balances = ReviewedCrossChainAuthoritativeBalances(
                originAssetKey: reviewedOriginAssetKey(definition),
                feeAssetKey: AssetKey(
                    ecosystem: "substrate",
                    chainId: definition.originChainId,
                    assetId: "reviewed-fee-asset"
                ),
                originSpendable: minimum + 100,
                feeSpendable: 100
            )
            XCTAssertNoThrow(
                try ReviewedCrossChainSubmissionBoundaryValidator.validate(
                    definition: definition,
                    requestedAmount: minimum,
                    burnAmount: minimum,
                    balances: balances,
                    originFee: 1
                )
            )
            XCTAssertThrowsError(
                try ReviewedCrossChainSubmissionBoundaryValidator.validate(
                    definition: definition,
                    requestedAmount: minimum - 1,
                    burnAmount: minimum,
                    balances: balances,
                    originFee: 1
                )
            ) { error in
                XCTAssertEqual(error as? ReviewedCrossChainSubmissionError, .belowMinimum)
            }
        }
    }

    func testSoraToAcalaUsesReviewedOnePointOneAcaMinimum() throws {
        let aca = try XCTUnwrap(
            ReviewedXcmRouteRegistry.routes.first {
                $0.originChainId == ReviewedXcmRouteRegistry.soraChainId &&
                    $0.originSymbol == "ACA"
            }
        )

        XCTAssertEqual(aca.minimumDisplay, "1.1 ACA")
        XCTAssertEqual(aca.execution.minimumAmount, "1100000000000000000")
    }

    func testLiberlandNativeLldRequiresOneCatalogAndOneReviewedXcmIdentityMatch() throws {
        let definition = try XCTUnwrap(
            ReviewedXcmRouteRegistry.routes.first {
                $0.originChainId == ReviewedXcmRouteRegistry.liberlandChainId &&
                    $0.originSymbol == "LLD"
            }
        )
        let destinationId = try XCTUnwrap(definition.destinationChainIds.first)
        let reviewedXcmAsset = XcmAvailableAsset(
            id: definition.xcmAssetId,
            symbol: definition.originSymbol
        )
        let destination = makeChain(id: destinationId, name: "SORA")
        let nativeLld = makeAsset(
            id: definition.originAssetId,
            symbol: definition.originSymbol,
            precision: definition.originPrecision
        )

        func origin(availableAssets: [XcmAvailableAsset]) -> ChainModel {
            makeChain(
                id: definition.originChainId,
                name: "Liberland",
                xcm: XcmChain(
                    xcmVersion: .V3,
                    destWeightIsPrimitive: nil,
                    availableAssets: availableAssets,
                    availableDestinations: [
                        XcmAvailableDestination(
                            chainId: destinationId,
                            bridgeParachainId: nil,
                            assets: [reviewedXcmAsset]
                        )
                    ]
                ),
                asset: nativeLld
            )
        }

        let exactOrigin = origin(availableAssets: [reviewedXcmAsset])
        XCTAssertNotNil(
            ReviewedXcmRouteRegistry.validatedOrigin(
                for: definition,
                chainsById: [
                    exactOrigin.chainId: exactOrigin,
                    destination.chainId: destination
                ]
            )
        )

        let catalogIdInXcm = XcmAvailableAsset(
            id: definition.originAssetId,
            symbol: definition.originSymbol
        )
        let wrongIdentityOrigin = origin(availableAssets: [catalogIdInXcm])
        XCTAssertNil(
            ReviewedXcmRouteRegistry.validatedOrigin(
                for: definition,
                chainsById: [
                    wrongIdentityOrigin.chainId: wrongIdentityOrigin,
                    destination.chainId: destination
                ]
            )
        )

        let duplicateIdentityOrigin = origin(
            availableAssets: [reviewedXcmAsset, reviewedXcmAsset]
        )
        XCTAssertNil(
            ReviewedXcmRouteRegistry.validatedOrigin(
                for: definition,
                chainsById: [
                    duplicateIdentityOrigin.chainId: duplicateIdentityOrigin,
                    destination.chainId: destination
                ]
            )
        )
    }

    func testCrossChainSubmissionAcceptsExactDescriptorAndRejectsIdentityDrift() throws {
        let definition = try XCTUnwrap(
            ReviewedXcmRouteRegistry.routes.first { $0.originSymbol == "DOT" }
        )
        let destinationId = try XCTUnwrap(definition.destinationChainIds.first)
        let runtimeAsset = XcmAvailableAsset(
            id: definition.xcmAssetId,
            symbol: definition.originSymbol
        )
        let originAsset = makeAsset(
            id: definition.originAssetId,
            symbol: definition.originSymbol,
            precision: definition.originPrecision,
            currencyId: reviewedRuntimeCurrencyId(definition)
        )
        let origin = makeChain(
            id: definition.originChainId,
            name: "SORA",
            xcm: XcmChain(
                xcmVersion: .V3,
                destWeightIsPrimitive: nil,
                availableAssets: [runtimeAsset],
                availableDestinations: [
                    XcmAvailableDestination(
                        chainId: destinationId,
                        bridgeParachainId: nil,
                        assets: [runtimeAsset]
                    )
                ]
            ),
            asset: originAsset
        )
        let destination = makeChain(id: destinationId, name: "Polkadot")
        let context = ReviewedCrossChainRouteContext(
            definition: definition,
            providerId: "polkaswap-sora-substrate"
        )
        let exactOrigin = ChainAsset(chain: origin, asset: originAsset)

        XCTAssertNotNil(
            CrossChainAssembly.configureModule(
                with: exactOrigin,
                wallet: AccountGenerator.generateMetaAccount(),
                reviewedRoute: context
            )
        )

        XCTAssertThrowsError(
            try ReviewedCrossChainSubmissionValidator.validate(
                origin: exactOrigin,
                destination: destination,
                reviewedRoute: context,
                mutationsEnabled: false
            )
        ) { error in
            XCTAssertEqual(error as? ReviewedCrossChainSubmissionError, .actionsPaused)
        }
        XCTAssertNoThrow(
            try ReviewedCrossChainSubmissionValidator.validate(
                origin: exactOrigin,
                destination: destination,
                reviewedRoute: context,
                mutationsEnabled: true
            )
        )
        XCTAssertThrowsError(
            try ReviewedCrossChainSubmissionValidator.validate(
                origin: exactOrigin,
                destination: destination,
                reviewedRoute: context,
                mutationsEnabled: true,
                executionAdapterAvailable: false
            )
        ) { error in
            XCTAssertEqual(error as? ReviewedCrossChainSubmissionError, .executionAdapterUnavailable)
        }
        XCTAssertNoThrow(
            try ReviewedCrossChainSubmissionValidator.validate(
                origin: exactOrigin,
                destination: destination,
                reviewedRoute: context,
                mutationsEnabled: true,
                executionAdapterAvailable: true
            )
        )

        let sameSymbolDifferentIdentity = makeAsset(
            id: "same-symbol-but-unreviewed-contract",
            symbol: definition.originSymbol,
            precision: definition.originPrecision,
            currencyId: reviewedRuntimeCurrencyId(definition)
        )
        XCTAssertThrowsError(
            try ReviewedCrossChainSubmissionValidator.validate(
                origin: ChainAsset(chain: origin, asset: sameSymbolDifferentIdentity),
                destination: destination,
                reviewedRoute: context,
                mutationsEnabled: true,
                executionAdapterAvailable: true
            )
        ) { error in
            XCTAssertEqual(error as? ReviewedCrossChainSubmissionError, .unreviewedRoute)
        }

        let originWithoutRuntimeRoute = makeChain(
            id: definition.originChainId,
            name: "SORA",
            asset: originAsset
        )
        XCTAssertThrowsError(
            try ReviewedCrossChainSubmissionValidator.validate(
                origin: ChainAsset(chain: originWithoutRuntimeRoute, asset: originAsset),
                destination: destination,
                reviewedRoute: context,
                mutationsEnabled: true,
                executionAdapterAvailable: true
            )
        ) { error in
            XCTAssertEqual(error as? ReviewedCrossChainSubmissionError, .unreviewedRoute)
        }

        let ambiguousSymbolOrigin = makeChain(
            id: definition.originChainId,
            name: "SORA",
            xcm: XcmChain(
                xcmVersion: .V3,
                destWeightIsPrimitive: nil,
                availableAssets: [
                    runtimeAsset,
                    XcmAvailableAsset(id: "different-id", symbol: definition.originSymbol)
                ],
                availableDestinations: [
                    XcmAvailableDestination(
                        chainId: destinationId,
                        bridgeParachainId: nil,
                        assets: [runtimeAsset]
                    )
                ]
            ),
            asset: originAsset
        )
        XCTAssertNoThrow(
            try ReviewedCrossChainSubmissionValidator.validate(
                origin: ChainAsset(chain: ambiguousSymbolOrigin, asset: originAsset),
                destination: destination,
                reviewedRoute: context,
                mutationsEnabled: true,
                executionAdapterAvailable: true
            )
        )
    }

    func testCrossChainBoundaryUsesExactAssetIdentityMinimumAndFreshFees() throws {
        let definition = try XCTUnwrap(
            ReviewedXcmRouteRegistry.routes.first { $0.originSymbol == "DOT" }
        )
        let minimum = try XCTUnwrap(
            definition.execution.minimumAmount.flatMap { BigUInt($0, radix: 10) }
        )
        let originKey = AssetKey(
            ecosystem: "substrate",
            chainId: definition.originChainId,
            assetId: definition.execution.asset.canonicalAssetId(
                originCatalogId: definition.originAssetId
            )
        )
        let feeKey = AssetKey(
            ecosystem: "substrate",
            chainId: definition.originChainId,
            assetId: PolkamarktConstants.feeAssetId
        )
        let balances = ReviewedCrossChainAuthoritativeBalances(
            originAssetKey: originKey,
            feeAssetKey: feeKey,
            originSpendable: minimum + 100,
            feeSpendable: 100
        )

        XCTAssertNoThrow(
            try ReviewedCrossChainSubmissionBoundaryValidator.validate(
                definition: definition,
                requestedAmount: minimum,
                burnAmount: minimum + 10,
                balances: balances,
                originFee: 10
            )
        )
        XCTAssertThrowsError(
            try ReviewedCrossChainSubmissionBoundaryValidator.validate(
                definition: definition,
                requestedAmount: minimum - 1,
                burnAmount: minimum,
                balances: balances,
                originFee: 10
            )
        ) { error in
            XCTAssertEqual(error as? ReviewedCrossChainSubmissionError, .belowMinimum)
        }
        let wrongIdentity = ReviewedCrossChainAuthoritativeBalances(
            originAssetKey: AssetKey(
                ecosystem: "substrate",
                chainId: definition.originChainId,
                assetId: "same-symbol-different-runtime-asset"
            ),
            feeAssetKey: feeKey,
            originSpendable: minimum + 100,
            feeSpendable: 100
        )
        XCTAssertThrowsError(
            try ReviewedCrossChainSubmissionBoundaryValidator.validate(
                definition: definition,
                requestedAmount: minimum,
                burnAmount: minimum + 10,
                balances: wrongIdentity,
                originFee: 10
            )
        ) { error in
            XCTAssertEqual(error as? ReviewedCrossChainSubmissionError, .balanceUnavailable)
        }
    }

    func testCrossChainFinalGuardIsAdjacentAndPreventsSubmission() {
        let executor = ReviewedCrossChainExecutorSpy()
        let authorizer = ReviewedCrossChainAuthorizerStub(
            submission: ReviewedCrossChainAuthorizedSubmission(
                builder: { $0 },
                executor: executor,
                finalGuard: { throw ReviewedCrossChainSubmissionError.selectedWalletChanged }
            )
        )
        let output = ReviewedCrossChainConfirmationOutputSpy(
            expectation: expectation(description: "Final guard rejected")
        )
        let interactor = CrossChainConfirmationInteractor(
            teleportData: makeCrossChainConfirmationDataForBoundaryTest(),
            submissionAuthorizer: authorizer,
            operationQueue: OperationQueue(),
            logger: Logger.shared,
            mutationsEnabled: { true }
        )
        interactor.setup(with: output)

        interactor.submit()
        wait(for: [output.expectation], timeout: 1)

        XCTAssertEqual(output.error as? ReviewedCrossChainSubmissionError, .selectedWalletChanged)
        XCTAssertEqual(executor.submitCount, 0)
    }

    func testHeldIrohaAssetInjectionPreservesMissingMetadataTrust() async throws {
        let unique = UUID().uuidString.lowercased()
        let assetId = "missing_definition_\(unique)#missing_domain"
        let chain = makeChain(id: "iroha:missing-metadata-\(unique)", name: "Iroha")
        let heldAsset = makeAsset(
            id: assetId,
            symbol: "Unknown Iroha asset",
            precision: 18,
            currencyId: assetId
        )
        let chainAsset = ChainAsset(chain: chain, asset: heldAsset)
        AssetTrustResolver.markMissing(chainAsset)
        XCTAssertEqual(AssetTrustResolver.metadataTrust(for: chainAsset).trust, .missing)

        let repository = InMemoryChainModelRepository(models: [chain])
        let injector = DynamicAssetCatalogInjectorImpl(
            chainModelRepository: AsyncAnyRepository(repository),
            eventCenter: EventCenterProtocolStub(),
            logger: Logger.shared
        )

        await injector.inject(assetModels: [heldAsset], into: chain)

        let fetchedChain = try await repository.fetch(
            by: chain.chainId,
            options: RepositoryFetchOptions()
        )
        let savedChain = try XCTUnwrap(fetchedChain)
        let savedAsset = try XCTUnwrap(savedChain.assets.first { $0.id == assetId })
        let savedChainAsset = ChainAsset(chain: savedChain, asset: savedAsset)
        let trust = AssetTrustResolver.metadataTrust(for: savedChainAsset)
        XCTAssertEqual(trust.trust, .missing)
        XCTAssertEqual(trust.provenance, .chain)
    }

    func testPolkamarktAccountCapabilityFailsClosedForAccountAssetsAndBalances() {
        let canonicalKUSD = AssetKey(
            ecosystem: "substrate",
            chainId: PolkamarktConstants.soraChainId,
            assetId: PolkamarktConstants.collateralAssetId
        )
        let canonicalXOR = AssetKey(
            ecosystem: "substrate",
            chainId: PolkamarktConstants.soraChainId,
            assetId: PolkamarktConstants.feeAssetId
        )

        XCTAssertEqual(
            PolkamarktAccountCapability(
                hasSoraAccount: false,
                collateralAssetKey: nil,
                feeAssetKey: nil,
                collateralSpendable: nil,
                feeSpendable: nil
            ).failureReason(),
            "Add a SORA account to use Polkamarkt."
        )
        XCTAssertEqual(
            PolkamarktAccountCapability(
                hasSoraAccount: true,
                collateralAssetKey: canonicalKUSD,
                feeAssetKey: canonicalXOR,
                collateralSpendable: BigUInt(100),
                feeSpendable: .zero
            ).failureReason(),
            "Fund XOR to pay SORA network fees."
        )
        XCTAssertEqual(
            PolkamarktAccountCapability(
                hasSoraAccount: true,
                collateralAssetKey: canonicalKUSD,
                feeAssetKey: canonicalXOR,
                collateralSpendable: BigUInt(100),
                feeSpendable: BigUInt(1)
            ).failureReason(requiredCollateral: BigUInt(101)),
            "Insufficient KUSD collateral for this buy."
        )
        XCTAssertEqual(
            PolkamarktAccountCapability(
                hasSoraAccount: true,
                collateralAssetKey: canonicalKUSD,
                feeAssetKey: canonicalXOR,
                collateralSpendable: BigUInt(100),
                feeSpendable: BigUInt(1)
            ).failureReason(requiredFee: BigUInt(2)),
            "Insufficient XOR to pay the current SORA network fee."
        )
        XCTAssertNil(
            PolkamarktAccountCapability(
                hasSoraAccount: true,
                collateralAssetKey: canonicalKUSD,
                feeAssetKey: canonicalXOR,
                collateralSpendable: BigUInt(100),
                feeSpendable: BigUInt(1)
            ).failureReason(requiredCollateral: BigUInt(100))
        )
    }

    func testDeFiPositionsAggregatorReturnsPositiveProtocolRows() async {
        let position = DeFiHubPositionRow(
            id: "demeter:position",
            feature: .farming,
            kind: .position,
            title: "Farm XOR",
            subtitle: "Deposited 10 · Rewards 1 PSWAP"
        )
        let aggregator = DeFiPositionsAggregator(
            sources: [
                DeFiPositionSourceStub(
                    feature: .farming,
                    title: "Demeter",
                    results: [.success([position])]
                )
            ],
            explicitlyUnavailableRows: []
        )

        let snapshot = await aggregator.load()

        XCTAssertTrue(snapshot.hasPositivePositions)
        XCTAssertFalse(snapshot.hasPartialFailure)
        XCTAssertEqual(snapshot.rows, [position])
    }

    func testDeFiPositionsAggregatorShowsHonestEmptyState() async {
        let aggregator = DeFiPositionsAggregator(
            sources: [
                DeFiPositionSourceStub(
                    feature: .polkamarkt,
                    title: "Polkamarkt",
                    results: [.success([])]
                )
            ],
            explicitlyUnavailableRows: []
        )

        let snapshot = await aggregator.load()

        XCTAssertFalse(snapshot.hasPositivePositions)
        XCTAssertFalse(snapshot.hasPartialFailure)
        XCTAssertEqual(snapshot.rows.first?.kind, .empty)
        XCTAssertEqual(snapshot.rows.first?.title, "No active DeFi positions")
    }

    func testDeFiPositionsAggregatorSurfacesPartialFailureAndRetainsStaleRows() async {
        let demeter = DeFiHubPositionRow(
            id: "demeter:position",
            feature: .farming,
            kind: .position,
            title: "Farm XOR",
            subtitle: "Deposited 10"
        )
        let demeterSource = DeFiPositionSourceStub(
            feature: .farming,
            title: "Demeter",
            results: [.success([demeter]), .failure(.offline)]
        )
        let polkamarktSource = DeFiPositionSourceStub(
            feature: .polkamarkt,
            title: "Polkamarkt",
            results: [.failure(.offline), .success([])]
        )
        let aggregator = DeFiPositionsAggregator(
            sources: [demeterSource, polkamarktSource],
            explicitlyUnavailableRows: []
        )

        let partial = await aggregator.load()
        XCTAssertTrue(partial.hasPositivePositions)
        XCTAssertTrue(partial.hasPartialFailure)
        XCTAssertTrue(partial.rows.contains(demeter))
        XCTAssertTrue(partial.rows.contains { $0.title == "Polkamarkt positions unavailable" })

        let stale = await aggregator.load()
        XCTAssertTrue(stale.hasPartialFailure)
        XCTAssertTrue(stale.rows.contains(demeter))
        XCTAssertTrue(stale.rows.contains { $0.title == "Demeter positions are stale" })
    }

    func testPolkamarktSharedContractPreservesCanonicalNetworkCatalogAndRawIntegers() throws {
        let data = try polkamarktFixtureData()
        let digest = Data(SHA256.hash(data: data)).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(digest, "e0eb0fba87e580ecd15c8722ce0876c5e10a994cc3c497d95b16bcc34ee021b4")

        let root = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        XCTAssertEqual(root["contract"] as? String, "fearless-polkamarkt-v1")

        let network = try XCTUnwrap(root["network"] as? [String: Any])
        let collateral = try XCTUnwrap(network["collateral"] as? [String: Any])
        let feeAsset = try XCTUnwrap(network["feeAsset"] as? [String: Any])
        XCTAssertEqual(network["chainId"] as? String, PolkamarktConstants.soraChainId)
        XCTAssertEqual(collateral["assetId"] as? String, PolkamarktConstants.collateralAssetId)
        XCTAssertEqual(collateral["symbol"] as? String, PolkamarktConstants.collateralSymbol)
        XCTAssertEqual(collateral["precision"] as? Int, Int(PolkamarktConstants.precision))
        XCTAssertEqual(feeAsset["assetId"] as? String, PolkamarktConstants.feeAssetId)
        XCTAssertEqual(feeAsset["symbol"] as? String, PolkamarktConstants.feeSymbol)

        let catalog = try XCTUnwrap(root["catalog"] as? [String: Any])
        let currentBlock = try XCTUnwrap(catalog["currentBlock"] as? String)
        let legacy = try XCTUnwrap(catalog["legacyQueryResponse"] as? [String: Any])
        let legacyData = try JSONSerialization.data(withJSONObject: legacy)
        let response = try JSONDecoder().decode(PolkamarktFixtureMarketResponse.self, from: legacyData)
        let indexed = response.data.markets.edges.compactMap { $0.node?.market }

        let runtimeEntriesData = try JSONSerialization.data(
            withJSONObject: try XCTUnwrap(catalog["runtimeEntries"])
        )
        let runtimeEntries = try JSONDecoder().decode(
            [PolkamarktRuntimeMarketEntry].self,
            from: runtimeEntriesData
        )
        let runtime = try XCTUnwrap(root["runtime"] as? [String: Any])
        let stateData = try JSONSerialization.data(
            withJSONObject: try XCTUnwrap(runtime["marketState"])
        )
        let state = try JSONDecoder().decode(PolkamarktMarketState.self, from: stateData)
        let merged = PolkamarktCatalog.merge(
            indexed: indexed,
            runtime: runtimeEntries,
            states: [state.marketId: state],
            currentBlock: currentBlock
        )

        XCTAssertEqual(
            merged.map(\.marketId),
            catalog["expectedSortedMarketIds"] as? [String]
        )
        let expectedStatus = try XCTUnwrap(catalog["expectedDisplayStatus"] as? [String: String])
        XCTAssertEqual(
            Dictionary(uniqueKeysWithValues: merged.map {
                ($0.marketId, $0.displayStatus(currentBlock: currentBlock).rawValue)
            }),
            expectedStatus
        )
        let noActive = try XCTUnwrap(catalog["noActiveMarketCase"] as? [String: Any])
        let finalizedBlock = try XCTUnwrap(noActive["currentBlock"] as? String)
        XCTAssertEqual(PolkamarktCatalog.activeMarkets(merged, currentBlock: finalizedBlock).map(\.marketId), [])
        XCTAssertEqual(
            Set(merged.map(\.marketId)),
            Set(try XCTUnwrap(noActive["expectedVisibleFinalizedMarketIds"] as? [String]))
        )

        let quotes = try XCTUnwrap(root["quotes"] as? [[String: Any]])
        let buy = try XCTUnwrap(quotes.first { $0["name"] as? String == "buyAboveSafeInteger" })
        let buyParams = try XCTUnwrap(buy["domainParams"] as? [String: String])
        XCTAssertEqual(
            try PolkamarktRPCRequestBuilder.parametersJSON([
                .unsignedInteger(try XCTUnwrap(buyParams["marketId"])),
                .text(try XCTUnwrap(buyParams["outcome"])),
                .unsignedInteger(try XCTUnwrap(buyParams["collateralIn"]))
            ]),
            buy["wireParamsJson"] as? String
        )
        let buyResponse = try JSONDecoder().decode(
            PolkamarktBuyQuote.self,
            from: JSONSerialization.data(withJSONObject: try XCTUnwrap(buy["response"]))
        )
        XCTAssertEqual(buyResponse.collateralIn, "1000000000000000001")
        XCTAssertEqual(buyResponse.sharesOut, "1800000000000000002")

        let sell = try XCTUnwrap(quotes.first { $0["name"] as? String == "sellAboveSafeInteger" })
        let sellParams = try XCTUnwrap(sell["domainParams"] as? [String: String])
        XCTAssertEqual(
            try PolkamarktRPCRequestBuilder.parametersJSON([
                .unsignedInteger(try XCTUnwrap(sellParams["marketId"])),
                .text(try XCTUnwrap(sellParams["outcome"])),
                .unsignedInteger(try XCTUnwrap(sellParams["sharesIn"]))
            ]),
            sell["wireParamsJson"] as? String
        )
    }

    func testPolkamarktSharedContractNegotiatesCapabilityDriftAndClaimFallback() throws {
        let root = try polkamarktFixtureObject()
        let runtime = try XCTUnwrap(root["runtime"] as? [String: Any])
        let complete = try XCTUnwrap(runtime["completeCapabilities"] as? [String: Any])
        let capabilities = PolkamarktRuntimeCapabilities(
            palletAvailable: (complete["pallet"] as? String) == "polkamarkt",
            storage: Set(try XCTUnwrap(complete["storage"] as? [String])),
            rpc: Set(try XCTUnwrap(complete["rpc"] as? [String])),
            calls: Set(try XCTUnwrap(complete["calls"] as? [String])),
            claimablePayoutFieldAvailable: true
        )
        XCTAssertTrue(capabilities.canBrowseRuntime)
        XCTAssertTrue(capabilities.canTrade)
        XCTAssertTrue(capabilities.canClaimTrader)
        XCTAssertTrue(capabilities.canClaimCreator)

        let noState = PolkamarktRuntimeCapabilities(
            palletAvailable: true,
            storage: capabilities.storage,
            rpc: Set(capabilities.rpc.filter { $0 != "marketState" }),
            calls: capabilities.calls,
            claimablePayoutFieldAvailable: true
        )
        XCTAssertTrue(noState.canBrowseRuntime)
        XCTAssertFalse(noState.canTrade)
        XCTAssertEqual(
            noState.tradingUnavailableReason,
            "Market state RPC is unavailable; browse and history remain available."
        )

        let noCreator = PolkamarktRuntimeCapabilities(
            palletAvailable: true,
            storage: capabilities.storage,
            rpc: capabilities.rpc,
            calls: Set(capabilities.calls.filter { $0 != "claimCreatorFees" }),
            claimablePayoutFieldAvailable: false
        )
        XCTAssertTrue(noCreator.canClaimTrader)
        XCTAssertFalse(noCreator.canClaimCreator)

        let activity = try XCTUnwrap(root["accountActivity"] as? [String: Any])
        let indexedActivity = try JSONDecoder().decode(
            PolkamarktIndexedAccountActivity.self,
            from: JSONSerialization.data(
                withJSONObject: try XCTUnwrap(activity["indexerResponse"])
            )
        )
        XCTAssertEqual(indexedActivity.positions.first?.shares, "1800000000000000002")
        XCTAssertEqual(indexedActivity.trades.first?.collateral, "1000000000000000001")
        XCTAssertEqual(indexedActivity.trades.first?.sharesOut, "1800000000000000002")
        XCTAssertEqual(indexedActivity.trades.first?.fee, "1000000000000000")
        XCTAssertEqual(indexedActivity.trades.first?.blockNumber, "90")
        var claim = try XCTUnwrap(activity["runtimeClaimable"] as? [String: Any])
        claim.removeValue(forKey: "claimablePayout")
        let claimable = try JSONDecoder().decode(
            PolkamarktClaimable.self,
            from: JSONSerialization.data(withJSONObject: claim)
        )
        XCTAssertEqual(claimable.effectiveTraderPayout, "2200000000000000000")

        XCTAssertEqual(
            root["deferredActions"] as? [String],
            ["createMarket", "reportEarlyResolution"]
        )
    }

    func testPolkamarktFinalQuoteBindingIncludesExactMarketFee() throws {
        let root = try polkamarktFixtureObject()
        let quotes = try XCTUnwrap(root["quotes"] as? [[String: Any]])
        let buyFixture = try XCTUnwrap(
            quotes.first { $0["name"] as? String == "buyAboveSafeInteger" }
        )
        let buyParams = try XCTUnwrap(buyFixture["domainParams"] as? [String: String])
        let buyQuote = try JSONDecoder().decode(
            PolkamarktBuyQuote.self,
            from: JSONSerialization.data(withJSONObject: try XCTUnwrap(buyFixture["response"]))
        )
        let buyMinimum = try XCTUnwrap(BigUInt(buyQuote.sharesOut, radix: 10)) * 99 / 100
        XCTAssertNoThrow(
            try PolkamarktMutationQuoteValidator.validateBuy(
                marketId: try XCTUnwrap(buyParams["marketId"]),
                outcome: .yes,
                collateralIn: try XCTUnwrap(buyParams["collateralIn"]),
                minSharesOut: String(buyMinimum),
                quote: buyQuote
            )
        )
        let invalidFeeQuote = PolkamarktBuyQuote(
            marketId: buyQuote.marketId,
            outcome: buyQuote.outcome,
            collateralIn: buyQuote.collateralIn,
            feeAmount: "2",
            pricingCollateral: buyQuote.pricingCollateral,
            sharesOut: buyQuote.sharesOut
        )
        XCTAssertThrowsError(
            try PolkamarktMutationQuoteValidator.validateBuy(
                marketId: try XCTUnwrap(buyParams["marketId"]),
                outcome: .yes,
                collateralIn: try XCTUnwrap(buyParams["collateralIn"]),
                minSharesOut: String(buyMinimum),
                quote: invalidFeeQuote
            )
        ) { error in
            XCTAssertEqual(error as? PolkamarktSubmissionError, .collateralFeeMismatch)
        }

        let sellFixture = try XCTUnwrap(
            quotes.first { $0["name"] as? String == "sellAboveSafeInteger" }
        )
        let sellParams = try XCTUnwrap(sellFixture["domainParams"] as? [String: String])
        let sellQuote = try JSONDecoder().decode(
            PolkamarktSellQuote.self,
            from: JSONSerialization.data(withJSONObject: try XCTUnwrap(sellFixture["response"]))
        )
        let sellMinimum = try XCTUnwrap(BigUInt(sellQuote.collateralOut, radix: 10)) * 99 / 100
        XCTAssertNoThrow(
            try PolkamarktMutationQuoteValidator.validateSell(
                marketId: try XCTUnwrap(sellParams["marketId"]),
                outcome: .no,
                sharesIn: try XCTUnwrap(sellParams["sharesIn"]),
                minCollateralOut: String(sellMinimum),
                quote: sellQuote
            )
        )
    }

    func testDemeterMutationServiceRejectsEveryActionWhenFinalAuthorizationFails() async {
        let pool = makeDemeterPool()
        let mutations: [DemeterMutation] = [
            .deposit(pool: pool, amount: "100"),
            .withdraw(pool: pool, amount: "100"),
            .claim(pool: pool)
        ]

        for mutation in mutations {
            let executor = DemeterMutationExecutorSpy()
            let service = DemeterMutationService(
                initialCapabilities: .testComplete,
                callBuilder: DemeterMutationCallBuilderStub(),
                submissionAuthorizer: DemeterMutationSubmissionAuthorizerStub(
                    result: .failure(.poolUnavailable)
                ),
                initialExecutor: executor,
                mutationsEnabled: { true }
            )

            do {
                _ = try await service.submit(mutation)
                XCTFail("Expected final Demeter authorization to reject submission")
            } catch {
                XCTAssertEqual(error as? DemeterSubmissionError, .poolUnavailable)
            }
            XCTAssertEqual(executor.submitCount, 0)
        }
    }

    func testDemeterMutationServiceRechecksKillSwitchAndFinalIdentityGuard() async {
        let pool = makeDemeterPool()
        let executor = DemeterMutationExecutorSpy()
        let switchState = SequencedBoolean([true, false])
        let service = DemeterMutationService(
            initialCapabilities: .testComplete,
            callBuilder: DemeterMutationCallBuilderStub(),
            submissionAuthorizer: DemeterMutationSubmissionAuthorizerStub(
                result: .success(
                    DemeterAuthorizedSubmission(
                        builder: { $0 },
                        executor: executor,
                        finalGuard: {}
                    )
                )
            ),
            initialExecutor: executor,
            mutationsEnabled: { switchState.next() }
        )

        do {
            _ = try await service.submit(.claim(pool: pool))
            XCTFail("Expected the final kill-switch recheck to reject submission")
        } catch {
            XCTAssertTrue(error is PolkamarktServiceError)
        }
        XCTAssertEqual(executor.submitCount, 0)

        let guardedExecutor = DemeterMutationExecutorSpy()
        let guardedService = DemeterMutationService(
            initialCapabilities: .testComplete,
            callBuilder: DemeterMutationCallBuilderStub(),
            submissionAuthorizer: DemeterMutationSubmissionAuthorizerStub(
                result: .success(
                    DemeterAuthorizedSubmission(
                        builder: { $0 },
                        executor: guardedExecutor,
                        finalGuard: { throw DemeterSubmissionError.selectedWalletChanged }
                    )
                )
            ),
            initialExecutor: guardedExecutor,
            mutationsEnabled: { true }
        )
        do {
            _ = try await guardedService.submit(.claim(pool: pool))
            XCTFail("Expected the final selected-wallet guard to reject submission")
        } catch {
            XCTAssertEqual(error as? DemeterSubmissionError, .selectedWalletChanged)
        }
        XCTAssertEqual(guardedExecutor.submitCount, 0)
    }

    func testPolkamarktMutationServiceNeverSubmitsWhenFinalAuthorizationFails() async {
        let failures: [PolkamarktSubmissionError] = [
            .runtimeUnavailable,
            .signerUnavailable,
            .selectedWalletChanged,
            .marketUnavailable,
            .marketClosed,
            .quoteMismatch,
            .collateralFeeMismatch,
            .insufficientShares,
            .claimUnavailable,
            .balanceUnavailable,
            .insufficientCollateral,
            .insufficientFee
        ]
        let mutation = PolkamarktMutation.buy(
            marketId: "7",
            outcome: .yes,
            collateralIn: "100",
            minSharesOut: "1"
        )

        for failure in failures {
            let executor = PolkamarktMutationExecutorSpy()
            let service = PolkamarktMutationService(
                initialCapabilities: .testComplete,
                callBuilder: PolkamarktMutationCallBuilderStub(),
                submissionAuthorizer: PolkamarktMutationSubmissionAuthorizerStub(
                    result: .failure(failure)
                ),
                initialExecutor: executor,
                mutationsEnabled: { true },
                disclaimerAccepted: { true }
            )

            do {
                _ = try await service.submit(mutation)
                XCTFail("Expected final authorization to reject \(failure)")
            } catch {
                XCTAssertEqual(error as? PolkamarktSubmissionError, failure)
            }
            XCTAssertEqual(executor.submitCount, 0)
        }
    }

    func testPolkamarktMutationServiceRechecksPolicyAfterAuthorization() async {
        let executor = PolkamarktMutationExecutorSpy()
        let authorized = PolkamarktAuthorizedSubmission(
            builder: { $0 },
            executor: executor,
            finalGuard: {}
        )
        let switchState = SequencedBoolean([true, false])
        let service = PolkamarktMutationService(
            initialCapabilities: .testComplete,
            callBuilder: PolkamarktMutationCallBuilderStub(),
            submissionAuthorizer: PolkamarktMutationSubmissionAuthorizerStub(
                result: .success(authorized)
            ),
            initialExecutor: executor,
            mutationsEnabled: { switchState.next() },
            disclaimerAccepted: { true }
        )

        do {
            _ = try await service.submit(.claimTrader(marketId: "7"))
            XCTFail("Expected the final policy recheck to reject submission")
        } catch {
            XCTAssertTrue(error is PolkamarktServiceError)
        }
        XCTAssertEqual(executor.submitCount, 0)

        let disclaimerExecutor = PolkamarktMutationExecutorSpy()
        let disclaimerState = SequencedBoolean([true, false])
        let disclaimerService = PolkamarktMutationService(
            initialCapabilities: .testComplete,
            callBuilder: PolkamarktMutationCallBuilderStub(),
            submissionAuthorizer: PolkamarktMutationSubmissionAuthorizerStub(
                result: .success(
                    PolkamarktAuthorizedSubmission(
                        builder: { $0 },
                        executor: disclaimerExecutor,
                        finalGuard: {}
                    )
                )
            ),
            initialExecutor: disclaimerExecutor,
            mutationsEnabled: { true },
            disclaimerAccepted: { disclaimerState.next() }
        )
        do {
            _ = try await disclaimerService.submit(.claimTrader(marketId: "7"))
            XCTFail("Expected the final persisted-disclaimer recheck to reject submission")
        } catch {
            XCTAssertTrue(error is PolkamarktServiceError)
        }
        XCTAssertEqual(disclaimerExecutor.submitCount, 0)
    }

    func testPolkamarktFinalGuardRejectsWalletSwitchAfterAuthorizationBeforeSubmit() async {
        let executor = PolkamarktMutationExecutorSpy()
        let identity = SubmissionIdentityState(walletToken: "wallet-a")
        let service = PolkamarktMutationService(
            initialCapabilities: .testComplete,
            callBuilder: PolkamarktMutationCallBuilderStub(),
            submissionAuthorizer: PolkamarktMutationSubmissionAuthorizerStub(
                result: .success(
                    PolkamarktAuthorizedSubmission(
                        builder: { $0 },
                        executor: executor,
                        finalGuard: {
                            guard identity.walletToken == "wallet-a" else {
                                throw PolkamarktSubmissionError.selectedWalletChanged
                            }
                        }
                    )
                ),
                didAuthorize: { identity.walletToken = "wallet-b" }
            ),
            initialExecutor: executor,
            mutationsEnabled: { true },
            disclaimerAccepted: { true }
        )

        do {
            _ = try await service.submit(.claimTrader(marketId: "7"))
            XCTFail("Expected the wallet identity guard to reject submission")
        } catch {
            XCTAssertEqual(error as? PolkamarktSubmissionError, .selectedWalletChanged)
        }
        XCTAssertEqual(executor.submitCount, 0)
    }

    func testPolkamarktFinalGuardRejectsRuntimeOrConnectionReplacementBeforeSubmit() async {
        for replacement in SubmissionContextReplacement.allCases {
            let executor = PolkamarktMutationExecutorSpy()
            let identity = SubmissionIdentityState(walletToken: "wallet-a")
            let authorizedRuntime = identity.runtime
            let authorizedConnection = identity.connection
            let service = PolkamarktMutationService(
                initialCapabilities: .testComplete,
                callBuilder: PolkamarktMutationCallBuilderStub(),
                submissionAuthorizer: PolkamarktMutationSubmissionAuthorizerStub(
                    result: .success(
                        PolkamarktAuthorizedSubmission(
                            builder: { $0 },
                            executor: executor,
                            finalGuard: {
                                guard identity.runtime === authorizedRuntime,
                                      identity.connection === authorizedConnection else {
                                    throw PolkamarktSubmissionError.runtimeUnavailable
                                }
                            }
                        )
                    ),
                    didAuthorize: { identity.replace(replacement) }
                ),
                initialExecutor: executor,
                mutationsEnabled: { true },
                disclaimerAccepted: { true }
            )

            do {
                _ = try await service.submit(.claimTrader(marketId: "7"))
                XCTFail("Expected the \(replacement) identity guard to reject submission")
            } catch {
                XCTAssertEqual(error as? PolkamarktSubmissionError, .runtimeUnavailable)
            }
            XCTAssertEqual(executor.submitCount, 0)
        }
    }

    func testPolkamarktIndexerRetriesLegacySchemaAndSortsClientSide() async throws {
        let root = try polkamarktFixtureObject()
        let catalog = try XCTUnwrap(root["catalog"] as? [String: Any])
        let failure = try XCTUnwrap(catalog["latestQueryFailure"] as? [String: String])
        XCTAssertEqual(failure["expectedAction"], "retryLegacyQuery")
        let errorData = try JSONSerialization.data(
            withJSONObject: ["errors": [["message": try XCTUnwrap(failure["message"])]]]
        )
        let legacyData = try JSONSerialization.data(
            withJSONObject: try XCTUnwrap(catalog["legacyQueryResponse"])
        )
        let transport = PolkamarktScriptedTransport(responses: [errorData, legacyData])
        let client = PolkamarktIndexerClient(
            endpoint: try XCTUnwrap(URL(string: "https://indexer.invalid/graphql")),
            transport: transport
        )

        let markets = try await client.markets()
        XCTAssertEqual(Set(markets.map(\.marketId)), Set(["7", "8"]))
        let bodies = transport.recordedBodies()
        XCTAssertEqual(bodies.count, 2)
        XCTAssertTrue(String(decoding: bodies[0], as: UTF8.self).contains("dpmCollateral"))
        XCTAssertFalse(String(decoding: bodies[1], as: UTF8.self).contains("orderBy"))
    }

    func testPolkamarktDeepLinkIsCanonicalAndOneShot() throws {
        let suiteName = "MainTabBarTests.polkamarkt.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let handler = PolkamarktDeepLinkHandler(
            eventCenter: EventCenterProtocolStub(),
            userDefaults: defaults
        )

        XCTAssertTrue(handler.handle(url: try XCTUnwrap(URL(string: "fearless://defi/polkamarkt/7"))))
        XCTAssertEqual(PolkamarktDeepLinkHandler.consumePending(userDefaults: defaults), "7")
        XCTAssertNil(PolkamarktDeepLinkHandler.consumePending(userDefaults: defaults))
        XCTAssertFalse(handler.handle(url: try XCTUnwrap(URL(string: "fearless://defi/polkamarkt/not-a-market"))))
    }

    func testRuntimeMutationArgumentsEncodeExactPalletFieldNames() throws {
        let buy = PolkamarktBuyCall(
            marketId: "7",
            outcome: "Yes",
            collateralIn: "1000000000000000001",
            minSharesOut: "1"
        )
        XCTAssertEqual(
            try encodedScaleKeys(buy),
            Set(["market_id", "outcome", "collateral_in", "min_shares_out"])
        )

        let assetId = fearless.SoraAssetId(
            wrappedValue: "0x" + String(repeating: "00", count: 32)
        )
        let deposit = DemeterDepositCall(
            baseAsset: assetId,
            poolAsset: assetId,
            rewardAsset: assetId,
            isFarm: true,
            pooledTokens: "9007199254740993"
        )
        XCTAssertEqual(
            try encodedScaleKeys(deposit),
            Set(["base_asset", "pool_asset", "reward_asset", "is_farm", "pooled_tokens"])
        )
    }

    func testNftPortfolioSectionsPreserveSameNameCollectionsAcrossNetworksAndContracts() {
        let firstChain = makeChain(id: "nft-chain-a", name: "Alpha")
        let secondChain = makeChain(id: "nft-chain-b", name: "Beta")
        let collections = [
            makeNftCollection(chain: firstChain, address: "0xaaa", name: "Same Name"),
            makeNftCollection(chain: firstChain, address: "0xbbb", name: "Same Name"),
            makeNftCollection(chain: secondChain, address: "0xaaa", name: "Same Name")
        ]

        let sections = NftListViewModelFactory().buildViewModel(
            from: collections,
            locale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(sections.map(\.chainId), [firstChain.chainId, secondChain.chainId])
        XCTAssertEqual(sections.map(\.items.count), [2, 1])
        let identities = sections.flatMap(\.items).map(\.identity)
        XCTAssertEqual(Set(identities).count, 3)
        XCTAssertEqual(Set(identities.map(\.chainId)), Set([firstChain.chainId, secondChain.chainId]))
    }

    func testSwapInteractorNeverSubmitsWhenFinalAuthorizationFails() {
        let failures: [PolkaswapSubmissionError] = [
            .selectedWalletChanged,
            .soraRuntimeUnavailable,
            .accountUnavailable,
            .watchOnly,
            .unregisteredAsset,
            .invalidAmount,
            .balanceUnavailable,
            .insufficientInputBalance,
            .insufficientFeeBalance
        ]

        for failure in failures {
            let executor = PolkaswapExtrinsicExecutorSpy()
            let output = PolkaswapConfirmationOutputSpy(
                expectation: expectation(description: "Reject \(failure)")
            )
            let interactor = PolkaswapSwapConfirmationInteractor(
                params: makePolkaswapPreviewParams(),
                submissionAuthorizer: PolkaswapSubmissionAuthorizerStub(result: .failure(failure)),
                mutationsEnabled: { true },
                disclaimerAccepted: { true }
            )
            interactor.setup(with: output)

            interactor.submit()
            wait(for: [output.expectation], timeout: 1)

            XCTAssertEqual(output.error as? PolkaswapSubmissionError, failure)
            XCTAssertEqual(executor.submitCount, 0)
        }
    }

    func testSwapInteractorRechecksSwitchAndDisclaimerAfterAuthorization() {
        let cases: [(enabled: Bool, accepted: Bool, error: PolkaswapSubmissionError)] = [
            (false, true, .actionsPaused),
            (true, false, .disclaimerRequired)
        ]

        for testCase in cases {
            let executor = PolkaswapExtrinsicExecutorSpy()
            let output = PolkaswapConfirmationOutputSpy(
                expectation: expectation(description: "Policy rejection \(testCase.error)")
            )
            let interactor = PolkaswapSwapConfirmationInteractor(
                params: makePolkaswapPreviewParams(),
                submissionAuthorizer: PolkaswapSubmissionAuthorizerStub(
                    result: .success(
                        PolkaswapAuthorizedSubmission(
                            builder: { $0 },
                            executor: executor,
                            finalGuard: {}
                        )
                    )
                ),
                mutationsEnabled: { testCase.enabled },
                disclaimerAccepted: { testCase.accepted }
            )
            interactor.setup(with: output)

            interactor.submit()
            wait(for: [output.expectation], timeout: 1)

            XCTAssertEqual(output.error as? PolkaswapSubmissionError, testCase.error)
            XCTAssertEqual(executor.submitCount, 0)
        }
    }

    func testSwapFinalGuardRejectsWalletSwitchAfterAuthorizationBeforeSubmit() {
        let executor = PolkaswapExtrinsicExecutorSpy()
        let identity = SubmissionIdentityState(walletToken: "wallet-a")
        let output = PolkaswapConfirmationOutputSpy(
            expectation: expectation(description: "Wallet identity rejected")
        )
        let interactor = PolkaswapSwapConfirmationInteractor(
            params: makePolkaswapPreviewParams(),
            submissionAuthorizer: PolkaswapSubmissionAuthorizerStub(
                result: .success(
                    PolkaswapAuthorizedSubmission(
                        builder: { $0 },
                        executor: executor,
                        finalGuard: {
                            guard identity.walletToken == "wallet-a" else {
                                throw PolkaswapSubmissionError.selectedWalletChanged
                            }
                        }
                    )
                ),
                didAuthorize: { identity.walletToken = "wallet-b" }
            ),
            mutationsEnabled: { true },
            disclaimerAccepted: { true }
        )
        interactor.setup(with: output)

        interactor.submit()
        wait(for: [output.expectation], timeout: 1)

        XCTAssertEqual(output.error as? PolkaswapSubmissionError, .selectedWalletChanged)
        XCTAssertEqual(executor.submitCount, 0)
    }

    func testSwapFinalGuardRejectsRuntimeOrConnectionReplacementBeforeSubmit() {
        for replacement in SubmissionContextReplacement.allCases {
            let executor = PolkaswapExtrinsicExecutorSpy()
            let identity = SubmissionIdentityState(walletToken: "wallet-a")
            let authorizedRuntime = identity.runtime
            let authorizedConnection = identity.connection
            let output = PolkaswapConfirmationOutputSpy(
                expectation: expectation(description: "Reject \(replacement)")
            )
            let interactor = PolkaswapSwapConfirmationInteractor(
                params: makePolkaswapPreviewParams(),
                submissionAuthorizer: PolkaswapSubmissionAuthorizerStub(
                    result: .success(
                        PolkaswapAuthorizedSubmission(
                            builder: { $0 },
                            executor: executor,
                            finalGuard: {
                                guard identity.runtime === authorizedRuntime,
                                      identity.connection === authorizedConnection else {
                                    throw PolkaswapSubmissionError.soraRuntimeUnavailable
                                }
                            }
                        )
                    ),
                    didAuthorize: { identity.replace(replacement) }
                ),
                mutationsEnabled: { true },
                disclaimerAccepted: { true }
            )
            interactor.setup(with: output)

            interactor.submit()
            wait(for: [output.expectation], timeout: 1)

            XCTAssertEqual(output.error as? PolkaswapSubmissionError, .soraRuntimeUnavailable)
            XCTAssertEqual(executor.submitCount, 0)
        }
    }

    func testSwapAmountResolverRejectsZeroLimitAndUsesMaximumInputForDesiredOutput() throws {
        let invalid = makePolkaswapPreviewParams(minMaxValue: .zero)
        XCTAssertThrowsError(try PolkaswapSwapResolvedAmounts.resolve(invalid)) { error in
            XCTAssertEqual(error as? PolkaswapSubmissionError, .invalidAmount)
        }

        let desiredOutput = makePolkaswapPreviewParams(
            fromAmount: 4,
            toAmount: 2,
            swapVariant: .desiredOutput,
            minMaxValue: 5
        )
        let resolved = try PolkaswapSwapResolvedAmounts.resolve(desiredOutput)
        XCTAssertEqual(resolved.requiredInput, BigUInt(5_000_000_000_000_000_000))
        XCTAssertGreaterThan(resolved.desired, .zero)
        XCTAssertGreaterThan(resolved.slip, .zero)
    }

    func testSwapRegistryResolverRejectsSameSymbolAndAmbiguousCanonicalIdentity() throws {
        let params = makePolkaswapPreviewParams()
        let chain = params.swapToChainAsset.chain
        XCTAssertNoThrow(
            try PolkaswapRegisteredAssetResolver.exactAsset(
                params.swapToChainAsset,
                in: chain
            )
        )

        let sameSymbolDifferentIdentity = AssetModel(
            id: "unreviewed-row",
            name: params.swapToChainAsset.asset.name,
            symbol: params.swapToChainAsset.asset.symbol,
            precision: params.swapToChainAsset.asset.precision,
            currencyId: "0x" + String(repeating: "02", count: 32),
            isUtility: false,
            isNative: false,
            type: .soraAsset
        )
        XCTAssertThrowsError(
            try PolkaswapRegisteredAssetResolver.exactAsset(
                ChainAsset(chain: chain, asset: sameSymbolDifferentIdentity),
                in: chain
            )
        ) { error in
            XCTAssertEqual(error as? PolkaswapSubmissionError, .unregisteredAsset)
        }

        let duplicateCanonicalIdentity = AssetModel(
            id: "duplicate-registry-row",
            name: "Duplicate",
            symbol: "OTHER",
            precision: params.swapToChainAsset.asset.precision,
            currencyId: params.swapToChainAsset.asset.currencyId,
            isUtility: false,
            isNative: false,
            type: .soraAsset
        )
        chain.assets.insert(duplicateCanonicalIdentity)
        XCTAssertThrowsError(
            try PolkaswapRegisteredAssetResolver.exactAsset(
                params.swapToChainAsset,
                in: chain
            )
        ) { error in
            XCTAssertEqual(error as? PolkaswapSubmissionError, .unregisteredAsset)
        }
    }

    func testDisclaimerAcceptanceIsVersionedAndMigratesReleasedV2Flag() {
        let storage = InMemorySettingsManager()
        XCTAssertFalse(PolkaswapDisclaimerPolicy.isAccepted(in: storage))

        storage.set(
            value: true,
            for: PolkaswapDisclaimerKeys.polkaswapDisclaimerIsRead2.rawValue
        )
        XCTAssertTrue(PolkaswapDisclaimerPolicy.isAccepted(in: storage))
        XCTAssertEqual(
            storage.integer(for: PolkaswapDisclaimerKeys.polkaswapDisclaimerAcceptedVersion.rawValue),
            PolkaswapDisclaimerPolicy.currentVersion
        )

        storage.set(
            value: PolkaswapDisclaimerPolicy.currentVersion - 1,
            for: PolkaswapDisclaimerKeys.polkaswapDisclaimerAcceptedVersion.rawValue
        )
        storage.set(
            value: false,
            for: PolkaswapDisclaimerKeys.polkaswapDisclaimerIsRead2.rawValue
        )
        XCTAssertFalse(PolkaswapDisclaimerPolicy.isAccepted(in: storage))

        PolkaswapDisclaimerPolicy.acceptCurrentVersion(in: storage)
        XCTAssertTrue(PolkaswapDisclaimerPolicy.isAccepted(in: storage))
    }

    private func makeViewController() -> (MainTabBarViewController, MainTabBarPresenterStub) {
        let viewControllers = MainTabBarDestination.allCases.map { destination -> UIViewController in
            let viewController = UIViewController()
            let item = UITabBarItem(
                title: destination.title,
                image: UIImage(systemName: "circle"),
                tag: destination.rawValue
            )
            viewController.tabBarItem = item
            return viewController
        }
        let presenter = MainTabBarPresenterStub()
        let viewController = MainTabBarViewController(
            viewControllers: viewControllers,
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        return (viewController, presenter)
    }

    private func makePolkaswapPreviewParams(
        fromAmount: Decimal = 2,
        toAmount: Decimal = 1,
        swapVariant: SwapVariant = .desiredInput,
        minMaxValue: Decimal = 1
    ) -> PolkaswapPreviewParams {
        let chain = makeChain(id: Chain.soraMain.genesisHash, name: "SORA Mainnet")
        let xor = AssetModel(
            id: "xor-registry-row",
            name: "SORA",
            symbol: "XOR",
            precision: 18,
            currencyId: PolkamarktConstants.feeAssetId,
            isUtility: true,
            isNative: true,
            type: .soraAsset
        )
        let token = AssetModel(
            id: "token-registry-row",
            name: "Token",
            symbol: "TKN",
            precision: 18,
            currencyId: "0x" + String(repeating: "01", count: 32),
            isUtility: false,
            isNative: false,
            type: .soraAsset
        )
        chain.assets = [xor, token]
        let xorChainAsset = ChainAsset(chain: chain, asset: xor)
        let tokenChainAsset = ChainAsset(chain: chain, asset: token)
        let details = PolkaswapAdjustmentDetailsViewModel(
            minMaxReceiveVieModel: nil,
            minMaxReceiveValue: minMaxValue,
            route: "XOR → TKN",
            fromPerToTitle: "XOR per TKN",
            fromPerToValue: "2",
            toPerFromTitle: "TKN per XOR",
            toPerFromValue: "0.5"
        )

        return PolkaswapPreviewParams(
            wallet: AccountGenerator.generateMetaAccount(),
            soraChinAsset: xorChainAsset,
            swapFromChainAsset: xorChainAsset,
            swapToChainAsset: tokenChainAsset,
            fromAmount: fromAmount,
            toAmount: toAmount,
            slippadgeTolerance: 0.5,
            swapVariant: swapVariant,
            market: .smart,
            polkaswapDexForRoute: PolkaswapDex(
                name: "SORA",
                code: 0,
                assetId: PolkamarktConstants.feeAssetId
            ),
            networkFee: BalanceViewModel(amount: "0.01 XOR", price: nil),
            detailsViewModel: details,
            minMaxValue: minMaxValue
        )
    }

    private func polkamarktFixtureData() throws -> Data {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try Data(
            contentsOf: testsDirectory
                .appendingPathComponent("Fixtures")
                .appendingPathComponent("Contracts")
                .appendingPathComponent("polkamarkt-v1.json")
        )
    }

    private func polkamarktFixtureObject() throws -> [String: Any] {
        try XCTUnwrap(
            JSONSerialization.jsonObject(with: polkamarktFixtureData()) as? [String: Any]
        )
    }

    private func encodedScaleKeys<T: Encodable>(_ value: T) throws -> Set<String> {
        let data = try JSONEncoder.scaleCompatible().encode(value)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return Set(object.keys)
    }

    private func assertStableTabBar(
        _ viewController: MainTabBarViewController,
        expectedTabBar: UITabBar,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(viewController.tabBar === expectedTabBar, file: file, line: line)
        XCTAssertEqual(viewController.tabBar.items?.count, expectedItemCount, file: file, line: line)
        XCTAssertEqual(
            viewController.tabBar.items?.compactMap(\.title),
            MainTabBarDestination.allCases.map(\.title),
            file: file,
            line: line
        )

        let allControls = controls(in: viewController.tabBar)
        let middleButtons = allControls.compactMap { $0 as? TabBarMiddleButton }

        XCTAssertEqual(middleButtons.count, 1, file: file, line: line)
        XCTAssertEqual(
            viewController.tabBar.subviews.compactMap { $0 as? TabBarBackgroundView }.count,
            1,
            file: file,
            line: line
        )

        if #available(iOS 26.0, *) {
            XCTAssertEqual(viewController.tabBarMinimizeBehavior, .never, file: file, line: line)
        }
    }

    private func assertRenderedItemControls(
        _ viewController: MainTabBarViewController,
        in window: UIWindow,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let allControls = controls(in: viewController.tabBar)
        let middleButtons = allControls.compactMap { $0 as? TabBarMiddleButton }
        let visibleSystemControls = allControls.filter { control in
            !(control is TabBarMiddleButton) &&
                isEffectivelyVisible(control, in: window)
        }
        let controlDescription = visibleSystemControls.map { control in
            let parent = control.superview.map { String(describing: type(of: $0)) } ?? "nil"
            let frame = control.convert(control.bounds, to: viewController.tabBar)
            return "\(String(describing: type(of: control))) " +
                "parent=\(parent) enabled=\(control.isEnabled) frame=\(frame)"
        }.joined(separator: "\n")
        let controlsBySlot = Dictionary(grouping: visibleSystemControls) { control in
            let centerX = control.convert(control.bounds, to: viewController.tabBar).midX
            return Int((centerX * window.screen.scale).rounded())
        }
        let sortedSlots = controlsBySlot.sorted { $0.key < $1.key }

        XCTAssertEqual(middleButtons.count, 1, file: file, line: line)
        XCTAssertTrue(
            middleButtons.first.map { isEffectivelyVisible($0, in: window) } == true,
            file: file,
            line: line
        )
        XCTAssertTrue(viewController.tabBar.subviews.last === middleButtons.first, file: file, line: line)

        XCTAssertEqual(
            sortedSlots.count,
            expectedItemCount,
            "Unexpected rendered tab slots. Controls:\n\(controlDescription)",
            file: file,
            line: line
        )

        for (index, slot) in sortedSlots.enumerated() {
            XCTAssertTrue(
                slot.value.allSatisfy(\.isEnabled),
                "Incorrect enabled state for tab slot \(index). Controls:\n\(controlDescription)",
                file: file,
                line: line
            )
        }
    }

    private func performAppearanceTransition(
        on viewController: UIViewController,
        appearing: Bool
    ) {
        viewController.beginAppearanceTransition(appearing, animated: false)
        viewController.endAppearanceTransition()
    }

    private func controls(in view: UIView) -> [UIControl] {
        view.subviews.reduce(into: []) { result, subview in
            if let control = subview as? UIControl {
                result.append(control)
            }

            result.append(contentsOf: controls(in: subview))
        }
    }

    private func isEffectivelyVisible(_ view: UIView, in window: UIWindow) -> Bool {
        guard view.window === window, !view.bounds.isEmpty else {
            return false
        }

        var currentView: UIView? = view

        while let current = currentView {
            guard !current.isHidden, current.alpha > 0.01 else {
                return false
            }

            if current === window {
                return true
            }

            currentView = current.superview
        }

        return false
    }

    private func makeChain(
        id: String,
        name: String,
        xcm: XcmChain? = nil,
        asset: AssetModel? = nil
    ) -> ChainModel {
        let chain = ChainModel(
            rank: nil,
            disabled: false,
            chainId: id,
            parentId: nil,
            paraId: nil,
            name: name,
            xcm: xcm,
            nodes: [],
            addressPrefix: 42,
            types: nil,
            icon: nil,
            options: nil,
            externalApi: nil,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
        if let asset {
            chain.assets.insert(asset)
        }
        return chain
    }

    private func makeAsset(
        id: String,
        symbol: String,
        precision: UInt16,
        currencyId: String? = nil
    ) -> AssetModel {
        AssetModel(
            id: id,
            name: symbol,
            symbol: symbol,
            precision: precision,
            currencyId: currencyId,
            isUtility: false,
            isNative: false
        )
    }

    private func makeSoraLiquidityPositionFixture() -> (
        chain: ChainModel,
        baseAssetId: String,
        targetAssetIds: [String]
    ) {
        let baseAssetId = PolkamarktConstants.feeAssetId
        let targetAssetIds = [
            "0x0200010000000000000000000000000000000000000000000000000000000000",
            "0x0200020000000000000000000000000000000000000000000000000000000000"
        ]
        let chain = makeChain(id: PolkamarktConstants.soraChainId, name: "SORA")
        chain.assets.insert(
            makeAsset(
                id: "xor-catalog-row",
                symbol: "XOR",
                precision: 18,
                currencyId: baseAssetId
            )
        )
        for (index, assetId) in targetAssetIds.enumerated() {
            chain.assets.insert(
                makeAsset(
                    id: "same-symbol-catalog-row-\(index)",
                    symbol: "USD",
                    precision: 18,
                    currencyId: assetId
                )
            )
        }

        return (chain, baseAssetId, targetAssetIds)
    }

    private func makeNftCollection(
        chain: ChainModel,
        address: String,
        name: String
    ) -> NFTCollection {
        NFTCollection(
            address: address,
            numberOfTokens: 1,
            isSpam: false,
            title: name,
            name: name,
            creator: nil,
            price: nil,
            media: nil,
            tokenType: .erc721,
            desc: nil,
            opensea: nil,
            chain: chain,
            totalSupply: "1",
            nfts: [],
            availableNfts: []
        )
    }
}

private final class MainTabBarPresenterStub: MainTabBarPresenterProtocol {
    private(set) var didLoadCallCount = 0

    func didLoad(view _: MainTabBarViewProtocol) {
        didLoadCallCount += 1
    }
}

private final class MainTabBarInteractorOutputSpy: MainTabBarInteractorOutputProtocol {
    private(set) var didPrepareChainsCallCount = 0
    var onDidPrepareChains: (() -> Void)?

    func didChangeSelectedAccount(_: MetaAccountModel) {}

    func didPrepareChains() {
        didPrepareChainsCallCount += 1
        onDidPrepareChains?()
    }

    func didRequestImportAccount() {}
    func didRequestPolkamarkt(marketId _: String) {}
}

private final class MainTabBarServiceCoordinatorSpy: ServiceCoordinatorProtocol {
    private(set) var setupCallCount = 0

    func setup() {
        setupCallCount += 1
    }

    func throttle() {}
    func updateOnAccountChange() {}
}

private final class MainTabBarKeystoreImportServiceStub: KeystoreImportServiceProtocol {
    var definition: KeystoreDefinition? = nil

    func handle(url _: URL) -> Bool { false }
    func add(observer _: KeystoreImportObserver) {}
    func remove(observer _: KeystoreImportObserver) {}
    func clear() {}
}

private struct PolkamarktFixtureMarketResponse: Decodable {
    let data: Payload

    struct Payload: Decodable {
        let markets: Markets
    }

    struct Markets: Decodable {
        let edges: [Edge]
    }

    struct Edge: Decodable {
        let node: PolkamarktMarketNode?
    }
}

private final class PolkamarktScriptedTransport: PolkamarktHTTPTransport, @unchecked Sendable {
    private let queue = DispatchQueue(label: "fearless.tests.polkamarkt.transport")
    private var responses: [Data]
    private var bodies: [Data] = []

    init(responses: [Data]) {
        self.responses = responses
    }

    func post(_ body: Data, to _: URL) async throws -> Data {
        try queue.sync {
            bodies.append(body)
            guard !responses.isEmpty else {
                throw PolkamarktServiceError.invalidResponse
            }
            return responses.removeFirst()
        }
    }

    func recordedBodies() -> [Data] {
        queue.sync { bodies }
    }
}

private enum DeFiPositionSourceTestError: LocalizedError {
    case offline

    var errorDescription: String? { "Source offline" }
}

private final class DeFiPositionSourceStub: DeFiPositionSourceLoading {
    let feature: DeFiFeature
    let title: String
    private var results: [Result<[DeFiHubPositionRow], DeFiPositionSourceTestError>]

    init(
        feature: DeFiFeature,
        title: String,
        results: [Result<[DeFiHubPositionRow], DeFiPositionSourceTestError>]
    ) {
        self.feature = feature
        self.title = title
        self.results = results
    }

    func loadPositions() async throws -> [DeFiHubPositionRow] {
        guard !results.isEmpty else { return [] }
        return try results.removeFirst().get()
    }
}

private struct SoraLiquidityPoolPositionLoaderStub: SoraLiquidityPoolPositionLoading {
    let result: Result<[AccountPool], DeFiPositionSourceTestError>

    func loadPositions(accountId _: Data) async throws -> [AccountPool] {
        try result.get()
    }
}

private struct PolkaswapSubmissionAuthorizerStub: PolkaswapSubmissionAuthorizing {
    let result: Result<PolkaswapAuthorizedSubmission, PolkaswapSubmissionError>
    let didAuthorize: () -> Void

    init(
        result: Result<PolkaswapAuthorizedSubmission, PolkaswapSubmissionError>,
        didAuthorize: @escaping () -> Void = {}
    ) {
        self.result = result
        self.didAuthorize = didAuthorize
    }

    func authorize(params _: PolkaswapPreviewParams) async throws -> PolkaswapAuthorizedSubmission {
        let authorized = try result.get()
        didAuthorize()
        return authorized
    }
}

private final class PolkaswapExtrinsicExecutorSpy: PolkaswapExtrinsicExecuting {
    private(set) var submitCount = 0

    func estimateFee(_: @escaping ExtrinsicBuilderClosure) async throws -> RuntimeDispatchInfo {
        RuntimeDispatchInfo(feeValue: BigUInt(1))
    }

    func submit(_: @escaping ExtrinsicBuilderClosure) async throws -> String {
        submitCount += 1
        return "unexpected"
    }
}

private final class PolkaswapConfirmationOutputSpy: PolkaswapSwapConfirmationInteractorOutput {
    let expectation: XCTestExpectation
    private(set) var error: Error?

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func didReceive(extrinsicResult: SubmitExtrinsicResult) {
        if case let .failure(error) = extrinsicResult {
            self.error = error
        }
        expectation.fulfill()
    }
}

private final class InMemorySettingsManager: SettingsManagerProtocol {
    private var values: [String: Any] = [:]

    func set(value: Bool, for key: String) { values[key] = value }
    func set(value: Int, for key: String) { values[key] = value }
    func set(value: Double, for key: String) { values[key] = value }
    func set(value: String, for key: String) { values[key] = value }
    func set(value: Data, for key: String) { values[key] = value }
    func set(anyValue: Any, for key: String) { values[key] = anyValue }
    func bool(for key: String) -> Bool? { values[key] as? Bool }
    func integer(for key: String) -> Int? { values[key] as? Int }
    func double(for key: String) -> Double? { values[key] as? Double }
    func string(for key: String) -> String? { values[key] as? String }
    func data(for key: String) -> Data? { values[key] as? Data }
    func anyValue(for key: String) -> Any? { values[key] }
    func removeValue(for key: String) { values.removeValue(forKey: key) }
    func removeAll() { values.removeAll() }
}

private extension DemeterRuntimeCapabilities {
    static var testComplete: DemeterRuntimeCapabilities {
        DemeterRuntimeCapabilities(
            palletAvailable: true,
            storage: ["Pools", "TokenInfos", "UserInfos"],
            calls: ["deposit", "withdraw", "getRewards"]
        )
    }
}

private func makeDemeterPool(isRemoved: Bool = false) -> DemeterPool {
    DemeterPool(
        identity: DemeterPoolIdentity(
            baseAssetId: "0x0100000000000000000000000000000000000000000000000000000000000000",
            poolAssetId: "0x0300000000000000000000000000000000000000000000000000000000000042",
            rewardAssetId: "0x0400000000000000000000000000000000000000000000000000000000000000",
            isFarm: true
        ),
        multiplier: "1",
        depositFee: "0",
        isCore: false,
        totalTokensInPool: "1000",
        rewards: "100",
        rewardsToBeDistributed: "100",
        isRemoved: isRemoved
    )
}

private func makeDemeterSnapshot(
    pool: DemeterPool,
    pooledTokens: String,
    rewards: String
) -> DemeterSnapshot {
    DemeterSnapshot(
        pools: [pool],
        rewardTokens: [:],
        positions: [
            DemeterAccountPosition(
                identity: pool.identity,
                pooledTokens: pooledTokens,
                rewards: rewards
            )
        ],
        capabilities: .testComplete
    )
}

private func makeDemeterBalances(
    pool: DemeterPool,
    poolSpendable: BigUInt,
    feeSpendable: BigUInt
) -> DemeterAuthoritativeBalances {
    DemeterAuthoritativeBalances(
        poolAssetKey: AssetKey(
            ecosystem: "substrate",
            chainId: PolkamarktConstants.soraChainId,
            assetId: pool.identity.poolAssetId
        ),
        feeAssetKey: AssetKey(
            ecosystem: "substrate",
            chainId: PolkamarktConstants.soraChainId,
            assetId: PolkamarktConstants.feeAssetId
        ),
        poolAssetSpendable: poolSpendable,
        feeSpendable: feeSpendable
    )
}

private struct DemeterMutationCallBuilderStub: DemeterMutationCallBuilding {
    func builder(
        for _: DemeterMutation,
        capabilities _: DemeterRuntimeCapabilities
    ) throws -> ExtrinsicBuilderClosure {
        { $0 }
    }
}

private struct DemeterMutationSubmissionAuthorizerStub:
    DemeterMutationSubmissionAuthorizing
{
    let result: Result<DemeterAuthorizedSubmission, DemeterSubmissionError>

    func authorize(_: DemeterMutation) async throws -> DemeterAuthorizedSubmission {
        try result.get()
    }
}

private final class DemeterMutationExecutorSpy: DemeterMutationExtrinsicExecuting {
    private(set) var submitCount = 0

    func estimateFee(_: @escaping ExtrinsicBuilderClosure) async throws -> RuntimeDispatchInfo {
        RuntimeDispatchInfo(feeValue: BigUInt(1))
    }

    func submit(_: @escaping ExtrinsicBuilderClosure) async throws -> String {
        submitCount += 1
        return "unexpected"
    }
}

private extension PolkamarktRuntimeCapabilities {
    static var testComplete: PolkamarktRuntimeCapabilities {
        PolkamarktRuntimeCapabilities(
            palletAvailable: true,
            storage: ["Markets", "Conditions"],
            rpc: ["marketState", "quoteBuy", "quoteSell", "claimable"],
            calls: ["buy", "sell", "claimMarket", "claimCreatorFees"],
            claimablePayoutFieldAvailable: true
        )
    }
}

private struct PolkamarktMutationCallBuilderStub: PolkamarktMutationCallBuilding {
    func builder(
        for _: PolkamarktMutation,
        capabilities _: PolkamarktRuntimeCapabilities
    ) throws -> ExtrinsicBuilderClosure {
        { $0 }
    }
}

private struct PolkamarktMutationSubmissionAuthorizerStub:
    PolkamarktMutationSubmissionAuthorizing
{
    let result: Result<PolkamarktAuthorizedSubmission, PolkamarktSubmissionError>
    let didAuthorize: () -> Void

    init(
        result: Result<PolkamarktAuthorizedSubmission, PolkamarktSubmissionError>,
        didAuthorize: @escaping () -> Void = {}
    ) {
        self.result = result
        self.didAuthorize = didAuthorize
    }

    func authorize(_: PolkamarktMutation) async throws -> PolkamarktAuthorizedSubmission {
        let authorized = try result.get()
        didAuthorize()
        return authorized
    }
}

private final class PolkamarktMutationExecutorSpy: PolkamarktMutationExtrinsicExecuting {
    private(set) var submitCount = 0

    func estimateFee(_: @escaping ExtrinsicBuilderClosure) async throws -> RuntimeDispatchInfo {
        RuntimeDispatchInfo(feeValue: BigUInt(1))
    }

    func submit(_: @escaping ExtrinsicBuilderClosure) async throws -> String {
        submitCount += 1
        return "unexpected"
    }
}

private enum SubmissionContextReplacement: String, CaseIterable {
    case runtime
    case connection
}

private final class SubmissionIdentityState {
    var walletToken: String
    var runtime: AnyObject
    var connection: AnyObject

    init(
        walletToken: String,
        runtime: AnyObject = NSObject(),
        connection: AnyObject = NSObject()
    ) {
        self.walletToken = walletToken
        self.runtime = runtime
        self.connection = connection
    }

    func replace(_ replacement: SubmissionContextReplacement) {
        switch replacement {
        case .runtime:
            runtime = NSObject()
        case .connection:
            connection = NSObject()
        }
    }
}

private struct ReviewedCrossChainAuthorizerStub: ReviewedCrossChainSubmissionAuthorizing {
    let submission: ReviewedCrossChainAuthorizedSubmission

    func authorize() async throws -> ReviewedCrossChainAuthorizedSubmission {
        submission
    }
}

private final class ReviewedCrossChainExecutorSpy: ReviewedCrossChainExtrinsicExecuting {
    private(set) var submitCount = 0

    func estimateFee(_: @escaping ExtrinsicBuilderClosure) async throws -> RuntimeDispatchInfo {
        RuntimeDispatchInfo(feeValue: BigUInt(1))
    }

    func submit(_: @escaping ExtrinsicBuilderClosure) async throws -> String {
        submitCount += 1
        return "unexpected"
    }
}

private final class ReviewedCrossChainConfirmationOutputSpy: CrossChainConfirmationInteractorOutput {
    let expectation: XCTestExpectation
    private(set) var error: Error?

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func didTransfer(result: Result<String, Error>) {
        if case let .failure(error) = result {
            self.error = error
        }
        expectation.fulfill()
    }
}

private func makeCrossChainConfirmationDataForBoundaryTest() -> CrossChainConfirmationData {
    let definition = ReviewedXcmRouteRegistry.routes.first {
        $0.originSymbol == "DOT"
    } ?? ReviewedXcmRouteRegistry.routes[0]
    let originAsset = AssetModel(
        id: definition.originAssetId,
        name: definition.originSymbol,
        symbol: definition.originSymbol,
        precision: definition.originPrecision,
        currencyId: reviewedRuntimeCurrencyId(definition),
        isUtility: false,
        isNative: false
    )
    let origin = ChainModel(
        rank: nil,
        disabled: false,
        chainId: definition.originChainId,
        parentId: nil,
        paraId: nil,
        name: "SORA",
        assets: [originAsset],
        xcm: nil,
        nodes: [],
        addressPrefix: 69,
        types: nil,
        icon: nil,
        options: nil,
        externalApi: nil,
        selectedNode: nil,
        customNodes: nil,
        iosMinAppVersion: nil,
        identityChain: nil
    )
    let destination = ChainModel(
        rank: nil,
        disabled: false,
        chainId: definition.execution.destinationChainId,
        parentId: nil,
        paraId: nil,
        name: "Destination",
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
    return CrossChainConfirmationData(
        wallet: AccountGenerator.generateMetaAccount(),
        originChainAsset: ChainAsset(chain: origin, asset: originAsset),
        destChainModel: destination,
        amount: 1,
        displayAmount: "1",
        originChainFee: BalanceViewModel(amount: "1", price: nil),
        destChainFee: BalanceViewModel(amount: "1", price: nil),
        destChainFeeDecimal: 1,
        recipientAddress: "recipient",
        reviewedRoute: ReviewedCrossChainRouteContext(
            definition: definition,
            providerId: "polkaswap-sora-substrate"
        )
    )
}

private func reviewedRuntimeCurrencyId(_ definition: ReviewedXcmRouteDefinition) -> String? {
    switch definition.execution.asset {
    case let .soraAsset(currencyId), let .liberlandAsset(currencyId):
        return currencyId
    case .liberlandNativeLLD:
        return nil
    }
}

private func reviewedOriginAssetKey(_ definition: ReviewedXcmRouteDefinition) -> AssetKey {
    AssetKey(
        ecosystem: "substrate",
        chainId: definition.originChainId,
        assetId: definition.execution.asset.canonicalAssetId(
            originCatalogId: definition.originAssetId
        )
    )
}

private final class StaticPolkaswapSettingsDataFactory: DataOperationFactoryProtocol {
    private let data: Data

    init(data: Data) {
        self.data = data
    }

    func fetchData(from _: URL) -> BaseOperation<Data> {
        ClosureOperation { self.data }
    }
}

private final class PolkaswapSettingsRepositoryProbe: DataProviderRepositoryProtocol {
    typealias Model = PolkaswapRemoteSettings

    private let lock = NSLock()
    private var settings: [PolkaswapRemoteSettings]
    private var saves = 0

    var savedSettings: [PolkaswapRemoteSettings] {
        lock.lock()
        defer { lock.unlock() }
        return settings
    }

    var saveCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return saves
    }

    init(localSettings: [PolkaswapRemoteSettings]) {
        settings = localSettings
    }

    func fetchOperation(
        by modelIdsClosure: @escaping () throws -> [String],
        options _: RepositoryFetchOptions
    ) -> BaseOperation<[PolkaswapRemoteSettings]> {
        ClosureOperation {
            let identifiers = try modelIdsClosure()
            return self.savedSettings.filter { identifiers.contains($0.identifier) }
        }
    }

    func fetchOperation(
        by modelIdClosure: @escaping () throws -> String,
        options _: RepositoryFetchOptions
    ) -> BaseOperation<PolkaswapRemoteSettings?> {
        ClosureOperation {
            let identifier = try modelIdClosure()
            return self.savedSettings.first { $0.identifier == identifier }
        }
    }

    func fetchAllOperation(
        with _: RepositoryFetchOptions
    ) -> BaseOperation<[PolkaswapRemoteSettings]> {
        ClosureOperation { self.savedSettings }
    }

    func fetchOperation(
        by _: RepositorySliceRequest,
        options _: RepositoryFetchOptions
    ) -> BaseOperation<[PolkaswapRemoteSettings]> {
        ClosureOperation { self.savedSettings }
    }

    func saveOperation(
        _ updateModelsBlock: @escaping () throws -> [PolkaswapRemoteSettings],
        _ deleteIdsBlock: @escaping () throws -> [String]
    ) -> BaseOperation<Void> {
        ClosureOperation {
            let updates = try updateModelsBlock()
            let deletedIds = try deleteIdsBlock()
            self.lock.lock()
            defer { self.lock.unlock() }
            self.saves += 1
            self.settings.removeAll { deletedIds.contains($0.identifier) }
            updates.forEach { update in
                self.settings.removeAll { $0.identifier == update.identifier }
                self.settings.append(update)
            }
        }
    }

    func saveBatchOperation(
        _ updateModelsBlock: @escaping () throws -> [PolkaswapRemoteSettings],
        _ deleteIdsBlock: @escaping () throws -> [String]
    ) -> BaseOperation<Void> {
        saveOperation(updateModelsBlock, deleteIdsBlock)
    }

    func replaceOperation(
        _ newModelsBlock: @escaping () throws -> [PolkaswapRemoteSettings]
    ) -> BaseOperation<Void> {
        ClosureOperation {
            let replacements = try newModelsBlock()
            self.lock.lock()
            defer { self.lock.unlock() }
            self.settings = replacements
        }
    }

    func fetchCountOperation() -> BaseOperation<Int> {
        ClosureOperation { self.savedSettings.count }
    }

    func deleteAllOperation() -> BaseOperation<Void> {
        ClosureOperation {
            self.lock.lock()
            defer { self.lock.unlock() }
            self.settings.removeAll()
        }
    }
}

private final class PolkaswapSettingsEventCenterProbe: EventCenterProtocol {
    private let repository: PolkaswapSettingsRepositoryProbe
    private let expectation: XCTestExpectation
    private let lock = NSLock()
    private(set) var observedPersistedSettings = false
    private var fulfilled = false

    init(
        repository: PolkaswapSettingsRepositoryProbe,
        expectation: XCTestExpectation
    ) {
        self.repository = repository
        self.expectation = expectation
    }

    func notify(with event: EventProtocol) {
        guard let update = event as? PolkaswapSettingsDidUpdate else {
            return
        }

        lock.lock()
        defer { lock.unlock() }
        observedPersistedSettings = repository.savedSettings.contains(update.settings)
        guard !fulfilled else {
            return
        }
        fulfilled = true
        expectation.fulfill()
    }

    func add(observer _: EventVisitorProtocol, dispatchIn _: DispatchQueue?) {}
    func remove(observer _: EventVisitorProtocol) {}
}

private actor InMemoryChainModelRepository: AsyncCoreDataRepository {
    typealias Model = ChainModel

    private var modelsById: [String: ChainModel]

    init(models: [ChainModel]) {
        modelsById = Dictionary(uniqueKeysWithValues: models.map { ($0.chainId, $0) })
    }

    func fetch(
        by modelIds: [String],
        options _: RepositoryFetchOptions
    ) async throws -> [ChainModel] {
        modelIds.compactMap { modelsById[$0] }
    }

    func fetch(
        by modelId: String,
        options _: RepositoryFetchOptions
    ) async throws -> ChainModel? {
        modelsById[modelId]
    }

    func fetchAll(with _: RepositoryFetchOptions) async throws -> [ChainModel] {
        Array(modelsById.values)
    }

    func save(models: [ChainModel], deleteIds: [String]) async {
        deleteIds.forEach { modelsById.removeValue(forKey: $0) }
        models.forEach { modelsById[$0.chainId] = $0 }
    }
}

private final class SequencedBoolean {
    private let lock = NSLock()
    private var values: [Bool]

    init(_ values: [Bool]) {
        self.values = values
    }

    func next() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return values.isEmpty ? false : values.removeFirst()
    }
}
