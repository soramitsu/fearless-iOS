import XCTest
import BigInt
import CoreData
import RobinHood
import SSFModels
import SSFRuntimeCodingService
#if canImport(SSFAssetManagmentStorage)
    import SSFAssetManagmentStorage
#endif
@testable import fearless

final class CovHSendInteractorTests: XCTestCase {
    func testLocalChainLoadsBalanceDepositAndSubscribesTheScopedListener() throws {
        let chainAsset = CovHSendFixtures.chainAsset(chainName: "Covh Local", assetUtility: true)
        let fixture = CovHSendInteractorFixture(chainAsset: chainAsset)
        fixture.interactor.updateSubscriptions(for: chainAsset)
        CovHSendWait.until { fixture.output.dependencies.count == 1 && fixture.output.minimumBalances.count == 1 && fixture.output.accountInfos.count == 1 }

        XCTAssertEqual(fixture.output.dependencies.map(\.chainAssetId), [chainAsset.chainAssetId])
        XCTAssertEqual(fixture.output.minimumBalances, [5])
        XCTAssertEqual(fixture.output.accountInfos.first?.isSuccess, true)
        XCTAssertEqual(fixture.adapter.resets, 1)
        XCTAssertEqual(fixture.adapter.wallets.map(\.metaId), [fixture.wallet.metaId])
        XCTAssertEqual(fixture.adapter.subscribed.first?.map(\.asset.id), [chainAsset.asset.id])
        XCTAssertNotNil(fixture.adapter.handler)
        XCTAssertEqual(fixture.output.assetAccountInfos, 1, "A normal asset has no assets-pallet record")
        XCTAssertEqual(fixture.accountInfoFetching.requested.map(\.asset.id), [chainAsset.asset.id])
        XCTAssertTrue(fixture.output.tips.isEmpty)
    }

    func testTokenReadsAssetsPalletAndSubscribesWithTheFeeAsset() throws {
        let native = CovHSendFixtures.asset(id: "native", symbol: "NAT", utility: true)
        let token = AssetModel(
            id: "token", name: "TOK", symbol: "TOK", precision: 10, currencyId: "TOK", isUtility: false, isNative: false, type: .ormlAsset
        )
        let chain = CovHSendFixtures.chain(name: "Covh Orml", assets: [native, token])
        let chainAsset = ChainAsset(chain: chain, asset: token)
        let fixture = CovHSendInteractorFixture(chainAsset: chainAsset)
        fixture.interactor.updateSubscriptions(for: chainAsset)
        CovHSendWait.until { fixture.output.dependencies.count == 1 && fixture.output.assetAccountInfos == 1 && fixture.output.accountInfos.count == 1 }

        XCTAssertNotNil(chainAsset.currencyId)
        XCTAssertEqual(fixture.output.assetAccountInfos, 1)
        XCTAssertEqual(Set(fixture.adapter.subscribed.first?.map(\.asset.id) ?? []), Set([token.id, native.id]))
        XCTAssertEqual(fixture.existentialDeposit.requested.map(\.asset.id), [native.id], "The deposit is read for the fee asset")
    }

    func testTipRequiredChainReportsTheTipLookup() {
        let asset = CovHSendFixtures.asset(id: "native", symbol: "NAT", utility: true)
        let chain = CovHSendFixtures.chain(name: "Covh Tip", assets: [asset], options: [.tipRequired])
        let chainAsset = ChainAsset(chain: chain, asset: asset)
        let fixture = CovHSendInteractorFixture(chainAsset: chainAsset)
        fixture.interactor.updateSubscriptions(for: chainAsset)
        CovHSendWait.until { fixture.output.tips.count == 1 }
        XCTAssertEqual(fixture.output.tips, [false], "The stub runtime cannot decode the default tip")
    }

    func testMissingRuntimeSkipsConstants() {
        let chainAsset = CovHSendFixtures.chainAsset(chainName: "Covh NoRuntime", assetUtility: true)
        let fixture = CovHSendInteractorFixture(chainAsset: chainAsset, runtime: false)
        fixture.interactor.updateSubscriptions(for: chainAsset)
        CovHSendWait.until { fixture.output.dependencies.count == 1 }
        CovHSendWait.until(timeout: 0.3) { false }
        XCTAssertTrue(fixture.output.minimumBalances.isEmpty)
        XCTAssertTrue(fixture.existentialDeposit.requested.isEmpty)
    }

    func testRemoteChainReadsBalanceRemotelyAndReportsZeroDeposit() throws {
        let btc = try CovHSendFixtures.bitcoin()
        let fixture = CovHSendInteractorFixture(chainAsset: btc)
        fixture.interactor.updateSubscriptions(for: btc)
        CovHSendWait.until { fixture.output.accountInfos.count == 1 && fixture.output.dependencies.count == 1 }
        XCTAssertEqual(fixture.output.minimumBalances, [.zero])
        XCTAssertEqual(fixture.output.assetAccountInfos, 1)
        XCTAssertEqual(fixture.remote.requests.map(\.asset.id), [btc.asset.id])
        XCTAssertTrue(fixture.adapter.subscribed.isEmpty)

        let failing = CovHSendInteractorFixture(chainAsset: btc)
        failing.remote.error = CovHSendError.failed
        failing.interactor.updateSubscriptions(for: btc)
        CovHSendWait.until { failing.output.accountInfos.count == 1 }
        XCTAssertEqual(failing.output.accountInfos.first?.isSuccess, false)
    }

    func testRemoteTokenAlsoReadsTheFeeAssetBalance() throws {
        let token = try CovHSendFixtures.solanaToken()
        let fixture = CovHSendInteractorFixture(chainAsset: token)
        fixture.interactor.updateSubscriptions(for: token)
        CovHSendWait.until { fixture.output.accountInfos.count == 2 }
        let utility = try XCTUnwrap(token.chain.utilityAssets().first)
        XCTAssertEqual(Set(fixture.remote.requests.map(\.asset.id)), Set([token.asset.id, utility.id]))
    }

    func testFeeEstimationUsesTheReceiverOrTheSenderAndDeliversScopedFees() throws {
        let chainAsset = CovHSendFixtures.chainAsset(chainName: "Covh Fee", assetUtility: true)
        let fixture = CovHSendInteractorFixture(chainAsset: chainAsset)
        fixture.interactor.estimateFee(for: 1, tip: nil, for: "early", chainAsset: chainAsset)
        XCTAssertTrue(fixture.service.subscribedTransfers.isEmpty, "No fee before the dependencies are ready")

        fixture.interactor.updateSubscriptions(for: chainAsset)
        CovHSendWait.until { fixture.output.dependencies.count == 1 }
        fixture.interactor.estimateFee(for: 10, tip: 2, for: "receiver", chainAsset: chainAsset)
        let transfer = try XCTUnwrap(fixture.service.subscribedTransfers.last)
        XCTAssertEqual(transfer.receiver, "receiver")
        XCTAssertEqual(transfer.amount, 10)
        XCTAssertEqual(transfer.tip, 2)
        fixture.service.listener?.didReceiveFee(fee: 99)
        CovHSendWait.until { fixture.output.fees.count == 1 }
        XCTAssertEqual(fixture.output.fees.first?.value, 99)

        fixture.interactor.estimateFee(for: 10, tip: nil, for: nil, chainAsset: chainAsset)
        let sender = try XCTUnwrap(fixture.wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress())
        XCTAssertEqual(fixture.service.subscribedTransfers.last?.receiver, sender)
        fixture.service.listener?.didReceiveFeeError(feeError: CovHSendError.failed)
        CovHSendWait.until { fixture.output.fees.count == 2 }
        XCTAssertNil(fixture.output.fees.last?.value)

        let other = CovHSendFixtures.chainAsset(chainName: "Covh Other", assetUtility: true)
        let count = fixture.service.subscribedTransfers.count
        fixture.interactor.estimateFee(for: 1, tip: nil, for: "x", chainAsset: other)
        XCTAssertEqual(fixture.service.subscribedTransfers.count, count, "Another asset's fee is never quoted by these services")
    }

    func testXorlessFeeSuccessAndFailure() {
        let chainAsset = CovHSendFixtures.chainAsset(chainName: "Covh Xor", assetUtility: true)
        let fixture = CovHSendInteractorFixture(chainAsset: chainAsset)
        fixture.interactor.didReceive(xorlessTransfer: CovHSendFixtures.xorless())
        CovHSendWait.until(timeout: 0.2) { false }
        XCTAssertTrue(fixture.output.fees.isEmpty)

        fixture.interactor.updateSubscriptions(for: chainAsset)
        CovHSendWait.until { fixture.output.dependencies.count == 1 }
        fixture.service.xorlessFeeResult = .success(43)
        fixture.interactor.didReceive(xorlessTransfer: CovHSendFixtures.xorless())
        CovHSendWait.until { fixture.output.fees.count == 1 }
        XCTAssertEqual(fixture.output.fees.first?.value, 43)
        fixture.service.xorlessFeeResult = .failure(CovHSendError.failed)
        fixture.interactor.didReceive(xorlessTransfer: CovHSendFixtures.xorless())
        CovHSendWait.until { fixture.output.fees.count == 2 }
        XCTAssertNil(fixture.output.fees.last?.value)
    }

    func testScamInfoDeliveryAndInvalidation() {
        let chainAsset = CovHSendFixtures.chainAsset(chainName: "Covh Scam", assetUtility: true)
        let fixture = CovHSendInteractorFixture(chainAsset: chainAsset)
        fixture.interactor.fetchScamInfo(for: "addr", chain: chainAsset.chain)
        fixture.interactor.invalidateScamInfo()
        CovHSendWait.until(timeout: 0.3) { false }
        XCTAssertEqual(fixture.output.scamDeliveries, 0)

        fixture.interactor.fetchScamInfo(for: "addr", chain: chainAsset.chain)
        CovHSendWait.until { fixture.output.scamDeliveries == 1 }
        XCTAssertEqual(fixture.output.scamDeliveries, 1)
        XCTAssertEqual(fixture.scam.addresses, ["addr"])
    }

    func testAvailableChainsAreTheVisibleMembersWithAccounts() {
        let chainAsset = CovHSendFixtures.chainAsset(chainName: "Covh Members", assetUtility: true)
        let unrelated = CovHSendFixtures.chainAsset(chainName: "Covh Unrelated", assetUtility: true)
        let fixture = CovHSendInteractorFixture(chainAsset: chainAsset)
        fixture.chainAssetFetching.result = .success([chainAsset, unrelated, chainAsset])
        var chains: [ChainModel]??
        fixture.interactor.defineAvailableChains(for: chainAsset, wallet: fixture.wallet) { chains = .some($0) }
        CovHSendWait.until { chains != nil }
        XCTAssertEqual(chains??.map(\.chainId), [chainAsset.chain.chainId])

        fixture.chainAssetFetching.result = .failure(CovHSendError.failed)
        chains = nil
        fixture.interactor.defineAvailableChains(for: chainAsset, wallet: fixture.wallet) { chains = .some($0) }
        CovHSendWait.until { chains != nil }
        XCTAssertNotNil(chains)
        XCTAssertNil(chains ?? nil)
    }

    func testValidationAndFeeAssetHelpers() throws {
        let chainAsset = CovHSendFixtures.chainAsset(chainName: "Covh Helpers", assetUtility: false)
        let fixture = CovHSendInteractorFixture(chainAsset: chainAsset)
        XCTAssertEqual(fixture.interactor.validate(address: "", for: chainAsset.chain), .invalid(""))
        XCTAssertEqual(fixture.interactor.validate(address: nil, for: chainAsset.chain), .invalid(nil))
        XCTAssertNil(fixture.interactor.getFeePaymentChainAsset(for: nil))
        XCTAssertEqual(fixture.interactor.getFeePaymentChainAsset(for: chainAsset)?.asset.id, chainAsset.asset.id)
        let btc = try CovHSendFixtures.bitcoin()
        XCTAssertEqual(fixture.interactor.getFeePaymentChainAsset(for: btc)?.asset.id, btc.asset.id)
    }

    func testEquilibriumTotalBalanceAfterConstants() {
        let asset = CovHSendFixtures.asset(id: "eq", symbol: "EQ", utility: true)
        let chain = CovHSendFixtures.chain(id: Chain.equilibrium.genesisHash, name: "Covh Equilibrium", assets: [asset])
        let chainAsset = ChainAsset(chain: chain, asset: asset)
        let fixture = CovHSendInteractorFixture(chainAsset: chainAsset)
        fixture.interactor.calculateEquilibriumBalance(chainAsset: chainAsset, amount: 1)
        XCTAssertEqual(fixture.output.eqBalances, [.zero], "Without the service the balance after transfer is zero")

        fixture.interactor.updateSubscriptions(for: chainAsset)
        CovHSendWait.until { fixture.output.dependencies.count == 1 }
        fixture.interactor.calculateEquilibriumBalance(chainAsset: chainAsset, amount: 1)
        XCTAssertEqual(fixture.output.eqBalances, [.zero, 7])

        let other = CovHSendFixtures.chainAsset(chainName: "Covh NotEq", assetUtility: true)
        fixture.interactor.calculateEquilibriumBalance(chainAsset: other, amount: 1)
        XCTAssertEqual(fixture.output.eqBalances.count, 2)
    }

    func testConvertNeedsReadyPolkaswapDependencies() async throws {
        let chainAsset = CovHSendFixtures.chainAsset(chainName: "Covh Swap", assetUtility: true)
        let fixture = await MainActor.run { CovHSendInteractorFixture(chainAsset: chainAsset) }
        do {
            _ = try await fixture.interactor.convert(chainAsset: chainAsset, toChainAsset: chainAsset, amount: 1)
            XCTFail("Conversion needs dependencies")
        } catch {
            XCTAssertTrue(error is ConvenienceError)
        }
    }
}
