import RobinHood
import SSFModels
import XCTest
@testable import fearless

/// The chain registry reports a removed chain by its id, but AccountInfoUpdatingService stores its account
/// subscriptions by chain-asset key, so a removal found nothing: it only logged "Expected to remove subscription", the
/// node subscriptions of every asset of the chain stayed, and the next wallet change attached the removed chain again.
final class AccountInfoChainRemovalTests: XCTestCase {
    func testRemovingAChainEndsTheSubscriptionOfEachOfItsAssets() throws {
        let harness = CovFBalAccountInfoHarness()
        let wallet = AccountGenerator.generateMetaAccount()
        let accountId = try XCTUnwrap(wallet.substrateAccountId)
        let removed = CovFBalChains.chain(assets: [
            CovFBalChains.asset(id: "0"),
            CovFBalChains.asset(id: "1", utility: false)
        ])
        let kept = CovFBalChains.chain(assets: [CovFBalChains.asset(id: "0")])
        let service = harness.makeService(wallet: wallet)
        attach(service, harness: harness, chains: [removed, kept])

        let detached = expectation(description: "each asset of the removed chain detached")
        detached.expectedFulfillmentCount = 2
        harness.substrate.onDetach = { detached.fulfill() }

        harness.registry.deliver([.delete(deletedIdentifier: removed.chainId)])
        wait(for: [detached], timeout: 5)
        harness.substrate.onDetach = nil
        covFBalSettle()

        let removedKeys = removed.chainAssets.map { $0.uniqueKey(accountId: accountId) }
        XCTAssertEqual(Set(harness.substrate.detachedKeys), Set(removedKeys))
        XCTAssertEqual(harness.substrate.detachedKeys.count, 2)
        XCTAssertFalse(harness.logger.errors.contains { $0.contains("Expected to remove") }, "\(harness.logger.errors)")
        XCTAssertTrue(harness.ethereum.detachedIds.isEmpty)
    }

    func testARemovedChainIsNotAttachedAgainWhenTheWalletChanges() throws {
        let harness = CovFBalAccountInfoHarness()
        let removed = CovFBalChains.chain(assets: [CovFBalChains.asset(id: "0")])
        let kept = CovFBalChains.chain(assets: [CovFBalChains.asset(id: "0")])
        let service = harness.makeService(wallet: AccountGenerator.generateMetaAccount())
        attach(service, harness: harness, chains: [removed, kept])

        harness.registry.deliver([.delete(deletedIdentifier: removed.chainId)])
        covFBalSettle()

        let next = AccountGenerator.generateMetaAccount()
        let nextAccountId = try XCTUnwrap(next.substrateAccountId)
        let reattached = expectation(description: "the kept chain attached for the next wallet")
        reattached.assertForOverFulfill = false
        harness.substrate.onAttach = { reattached.fulfill() }

        service.update(selectedMetaAccount: next)
        wait(for: [reattached], timeout: 5)
        covFBalSettle(0.5)
        harness.substrate.onAttach = nil

        let attachedForNext = zip(harness.substrate.attachedAccountIds, harness.substrate.attachedChainAssets)
            .filter { $0.0 == nextAccountId }
            .map(\.1.chain.chainId)
        XCTAssertEqual(attachedForNext, [kept.chainId], "only the chain still in the registry is attached")
    }

    /// Sets the service up with `chains` available and waits until every asset's subscription is stored.
    private func attach(_ service: AccountInfoUpdatingService, harness: CovFBalAccountInfoHarness, chains: [ChainModel]) {
        harness.registry.availableIds = Set(chains.map(\.chainId))
        service.setup()
        let attached = expectation(description: "attached")
        attached.expectedFulfillmentCount = chains.map(\.assets.count).reduce(0, +)
        harness.substrate.onAttach = { attached.fulfill() }
        harness.registry.deliver(chains.map { .insert(newItem: $0) })
        wait(for: [attached], timeout: 5)
        harness.substrate.onAttach = nil
        covFBalSettle()
    }
}
