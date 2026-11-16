import XCTest
import SSFModels
@testable import fearless

/// AccountInfoUpdatingService attaches account subscriptions only for non-Ethereum chains, through the Substrate
/// service, which keeps the subscription. Removing one always detached through the Substrate service, which is the
/// right one for every subscription this service makes; resubscribing picked the service from the chain's current
/// type, so a chain that turned Ethereum after attaching was detached through the Ethereum service, which does not
/// hold it, and the node subscription stayed. Each subscription now remembers the service that attached it.
final class AccountInfoSubscriptionDetachRoutingTests: XCTestCase {
    func testResubscribingAChainThatTurnedEthereumDetachesThroughTheAttachingService() throws {
        let (harness, service, substrateChain, ethereumChain, accountId) = makeTurnedEthereumChain()
        let detached = expectation(description: "detached")
        harness.substrate.onDetach = { detached.fulfill() }

        service.processChainsUpdated(event: ChainsUpdatedEvent(updatedChains: [ethereumChain]))
        wait(for: [detached], timeout: 5)
        harness.substrate.onDetach = nil
        covFBalSettle()

        let key = ChainAsset(chain: substrateChain, asset: try XCTUnwrap(substrateChain.assets.first)).uniqueKey(accountId: accountId)
        XCTAssertEqual(harness.substrate.detachedKeys, [key])
        XCTAssertTrue(harness.ethereum.detachedIds.isEmpty)
    }

    func testRemovingASubscriptionDetachesThroughTheAttachingService() throws {
        let (harness, service, substrateChain, _, accountId) = makeTurnedEthereumChain()
        let detached = expectation(description: "detached")
        harness.substrate.onDetach = { detached.fulfill() }

        service.update(selectedMetaAccount: AccountGenerator.generateMetaAccount())
        wait(for: [detached], timeout: 5)
        // Releasing the service at the end of the test detaches the new wallet's subscription too.
        harness.substrate.onDetach = nil
        covFBalSettle()

        let key = ChainAsset(chain: substrateChain, asset: try XCTUnwrap(substrateChain.assets.first)).uniqueKey(accountId: accountId)
        XCTAssertEqual(harness.substrate.detachedKeys, [key])
        XCTAssertTrue(harness.ethereum.detachedIds.isEmpty)
    }

    private func makeTurnedEthereumChain() -> (CovFBalAccountInfoHarness, AccountInfoUpdatingService, ChainModel, ChainModel, Data) {
        let chainId = covFBalChainId()
        let accountId = Data(repeating: 7, count: 32)
        let asset = CovFBalChains.asset()
        let substrateChain = CovFBalChains.chain(id: chainId, assets: [asset])
        let ethereumChain = CovFBalChains.chain(id: chainId, assets: [asset], options: [.ethereum])
        let harness = CovFBalAccountInfoHarness()
        let service = harness.makeService(wallet: CovFBalWallets.withChainAccount(chainId: chainId, accountId: accountId))
        harness.subscribe(service, to: substrateChain, testCase: self)
        return (harness, service, substrateChain, ethereumChain, accountId)
    }
}
