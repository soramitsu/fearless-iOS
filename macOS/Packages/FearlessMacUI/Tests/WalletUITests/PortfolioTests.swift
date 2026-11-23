import Foundation
import Testing
import WalletCore
@testable import WalletPreviewSupport
@testable import WalletUI

@MainActor
@Suite("Portfolio")
struct PortfolioTests {
    @Test func totalsAreTheSumOfPricedHoldings() async throws {
        let fixture = try await Fixture.make()
        let rows = AssetFilter(showTestnets: false).apply(to: fixture.rows)
        let summary = PortfolioSummary(rows: rows)

        var expected: Decimal = 0
        for row in rows {
            guard let total = row.total, let price = row.price else { continue }
            expected += total.decimalValue * price.value
        }
        #expect(summary.total == expected)
        // 1250.5 + 320.75 DOT at 4.12, stablecoins near 1, 45.625 KSM, 1.2345 ETH, 2.5 BNB, 1500 POL.
        #expect(summary.total > 17_000 && summary.total < 18_500)
        #expect(summary.pricedRowCount == 12)
        #expect(summary.previousTotal > 0)
        let percent = try #require(summary.changePercent)
        #expect(percent > 0 && percent < 3)
        #expect(summary.change == summary.total - summary.previousTotal)
    }

    @Test func allocationSharesAddUpAndFollowValue() async throws {
        let fixture = try await Fixture.make()
        let summary = PortfolioSummary(rows: AssetFilter().apply(to: fixture.rows))
        let assetShares = summary.byAsset.reduce(Decimal(0)) { $0 + $1.share }
        let networkShares = summary.byNetwork.reduce(Decimal(0)) { $0 + $1.share }
        #expect(abs(assetShares - 1) < Decimal(string: "0.0000001")!)
        #expect(abs(networkShares - 1) < Decimal(string: "0.0000001")!)
        #expect(summary.byAsset.first?.name == "DOT", "the largest slice comes first")
        #expect(summary.byAsset.map(\.value) == summary.byAsset.map(\.value).sorted(by: >))
        #expect(summary.byAsset.first { $0.name == "USDT" }?.value == Decimal(string: "3350.25")! * Decimal(string: "1.0003")!, "USDT on two networks is one slice")
        #expect(!summary.byNetwork.contains { $0.name == "Westend" }, "testnets carry no price")
    }

    @Test func topHoldingsAreRankedByValue() async throws {
        let fixture = try await Fixture.make()
        let summary = PortfolioSummary(rows: fixture.rows, topCount: 3)
        #expect(summary.topHoldings.count == 3)
        #expect(summary.topHoldings.map(\.asset.symbol) == ["DOT", "ETH", "USDT"])
        let values = summary.topHoldings.compactMap(\.fiatValue)
        #expect(values == values.sorted(by: >))
    }

    @Test func tableSortsByEachColumn() async throws {
        let fixture = try await Fixture.make()
        let rows = AssetFilter().apply(to: fixture.rows)
        let byValue = rows.sorted(using: KeyPathComparator(\AssetRow.sortValue, order: .reverse))
        #expect(byValue.first?.id == PreviewCatalog.dot.id)
        let bySymbol = rows.sorted(using: KeyPathComparator(\AssetRow.sortSymbol))
        #expect(bySymbol.first?.asset.symbol == "BNB")
        let byPrice = rows.sorted(using: KeyPathComparator(\AssetRow.sortPrice, order: .reverse))
        #expect(byPrice.first?.asset.symbol == "ETH")
        let byChange = rows.sorted(using: KeyPathComparator(\AssetRow.sortChange, order: .reverse))
        #expect(byChange.first?.asset.symbol == "POL")
        let byNetwork = rows.sorted(using: KeyPathComparator(\AssetRow.sortNetwork))
        #expect(byNetwork.first?.chain.name == "BNB Smart Chain")
    }

    @Test func filtersHideZeroBalancesTestnetsHiddenAssetsAndSearchMisses() async throws {
        let fixture = try await Fixture.make()
        let all = fixture.rows
        #expect(all.count == PreviewCatalog.assets.count)

        let mainnet = AssetFilter().apply(to: all)
        #expect(!mainnet.contains { $0.chain.isTestnet })
        #expect(mainnet.count == 12)

        let nonZero = AssetFilter(hideZeroBalances: true).apply(to: all)
        #expect(nonZero.count == 10)
        #expect(nonZero.allSatisfy { $0.hasBalance })

        let hidden = AssetFilter(hiddenAssetKeys: [PreviewCatalog.dot.id.description]).apply(to: all)
        #expect(!hidden.contains { $0.id == PreviewCatalog.dot.id })
        #expect(hidden.contains { $0.id == PreviewCatalog.dotAssetHub.id }, "hiding is per asset and network")

        #expect(AssetFilter(search: "usd").apply(to: all).allSatisfy { $0.asset.isStablecoin })
        #expect(AssetFilter(search: "asset hub").apply(to: all).allSatisfy { $0.chain.name.contains("Asset Hub") })
        #expect(AssetFilter(search: "  KUSAMA ").apply(to: all).count == 3)
        #expect(AssetFilter(search: "nothing-matches").apply(to: all).isEmpty)

        var evm = AssetFilter(showTestnets: true)
        evm.ecosystem = .evm
        #expect(evm.apply(to: all).allSatisfy { $0.chain.ecosystem == .evm })
        #expect(evm.apply(to: all).contains { $0.id == PreviewCatalog.sepoliaETH.id })
    }

    @Test func aFailingNetworkNeverHidesTheOthers() async throws {
        let fixture = try await Fixture.make(.balanceFailure)
        let store = fixture.store
        #expect(store.chainSync[PreviewCatalog.kusama.id] != .synced)
        if case .failed(let message)? = store.chainSync[PreviewCatalog.kusama.id] {
            #expect(message.contains("Kusama"))
        } else {
            Issue.record("Kusama should be reported as failed")
        }
        #expect(store.chainSync[PreviewCatalog.polkadot.id] == .synced)
        #expect(store.failedChains.map(\.chain.id) == [PreviewCatalog.kusama.id])
        let counts = store.syncCounts
        #expect(counts.total == 9)
        #expect(counts.failed == 1)
        #expect(counts.done == 8)
        #expect(!store.isRefreshing)

        let ksm = try fixture.row(PreviewCatalog.ksm)
        #expect(ksm.balance.errorMessage != nil)
        #expect(ksm.fiatValue == nil)
        let dot = try fixture.row(PreviewCatalog.dot)
        #expect(dot.balance.balance?.transferable == amount("750.5", 10))
        #expect(dot.locked == amount("500", 10))
        #expect(PortfolioSummary(rows: fixture.rows).total > 0, "the total still counts the networks that answered")
    }

    @Test func aPriceFailureKeepsBalancesAndReportsTheProblem() async throws {
        let fixture = try await Fixture.make(PreviewScenario(pricesFail: true))
        #expect(fixture.store.priceError != nil)
        #expect(fixture.store.prices.isEmpty)
        #expect(try fixture.row(PreviewCatalog.dot).total == amount("1250.5", 10))
        #expect(PortfolioSummary(rows: fixture.rows).pricedRowCount == 0)
    }

    @Test func pricesFollowTheSelectedCurrency() async throws {
        let fixture = try await Fixture.make()
        let usd = try #require(try fixture.row(PreviewCatalog.eth).price?.value)
        await fixture.store.refresh(wallet: fixture.wallet, fiat: .eur, includeTestnets: false)
        let eur = try #require(try fixture.row(PreviewCatalog.eth).price?.value)
        #expect(eur == usd * Decimal(string: "0.92")!)
        #expect(fixture.store.priceCurrency == .eur)
        #expect(fixture.store.chainSync[PreviewCatalog.westend.id] == nil, "testnets are not asked when they are hidden")
    }

    @Test func resetDropsEverythingOfTheWallet() async throws {
        let fixture = try await Fixture.make()
        #expect(!fixture.rows.isEmpty)
        fixture.store.reset()
        #expect(fixture.store.balances.isEmpty)
        #expect(fixture.store.prices.isEmpty)
        #expect(fixture.store.chainSync.isEmpty)
        #expect(fixture.store.walletID == nil)
        #expect(fixture.rows.allSatisfy { $0.balance == .loading })
    }

    @Test func aWatchOnlyWalletOnlyListsItsEcosystem() async throws {
        let fixture = try await Fixture.make(walletID: PreviewSampleData.watchWalletID)
        #expect(fixture.rows.allSatisfy { $0.chain.ecosystem == .substrate })
        #expect(fixture.store.syncCounts.total == 5)
    }
}

@MainActor
@Suite("Activity")
struct ActivityTests {
    private func loadedRows(_ scenario: PreviewScenario = .standard) async throws -> ([ActivityRow], ActivityStore) {
        let fixture = try await Fixture.make(scenario)
        let store = ActivityStore(services: fixture.services)
        await store.refresh(wallet: fixture.wallet)
        return (store.rows(assets: fixture.store.assets, chains: fixture.store.chains), store)
    }

    @Test func loadsNewestFirstForTheWalletOnly() async throws {
        let (rows, store) = try await loadedRows()
        #expect(store.state == .loaded)
        #expect(rows.count == 14)
        #expect(rows.map(\.item.timestamp) == rows.map(\.item.timestamp).sorted(by: >))
        #expect(rows.allSatisfy { $0.item.walletID == PreviewSampleData.mainWalletID })
        #expect(store.pendingCount == 1)
        #expect(rows.allSatisfy { $0.asset != nil && $0.chain != nil })
    }

    @Test func filtersByKindStatusAndNetworkType() async throws {
        let (rows, _) = try await loadedRows()
        let mainnet = ActivityFilter().apply(to: rows)
        #expect(mainnet.count == 12, "testnet entries are hidden unless testnets are shown")
        #expect(ActivityFilter(showTestnets: true).apply(to: rows).count == 14)

        let sent = ActivityFilter(kind: .sent).apply(to: rows)
        #expect(sent.count == 5)
        #expect(sent.allSatisfy { $0.item.direction == .outgoing })
        let received = ActivityFilter(kind: .received).apply(to: rows)
        #expect(received.count == 4)
        let other = ActivityFilter(kind: .other).apply(to: rows)
        #expect(other.count == 3)
        #expect(other.contains { $0.typeName == "Staking reward" })
        #expect(other.contains { $0.typeName == "To Self" })

        #expect(ActivityFilter(status: .pending).apply(to: rows).count == 1)
        #expect(ActivityFilter(status: .failed).apply(to: rows).map(\.symbol) == ["KSM"])
        #expect(ActivityFilter(kind: .sent, status: .success).apply(to: rows).count == 3)
    }

    @Test func searchMatchesAssetNetworkAddressHashTypeAndStatus() async throws {
        let (rows, _) = try await loadedRows()
        #expect(ActivityFilter(search: "usdc").apply(to: rows).count == 1)
        #expect(ActivityFilter(search: "Asset Hub").apply(to: rows).count == 3)
        let toBob = ActivityFilter(search: String(PreviewSampleData.bob.polkadot.prefix(12)).lowercased()).apply(to: rows)
        #expect(toBob.count == 2)
        let first = try #require(rows.first?.item.hash)
        #expect(ActivityFilter(search: first).apply(to: rows).count == 1)
        #expect(ActivityFilter(search: "staking").apply(to: rows).count == 2)
        #expect(ActivityFilter(search: "pending").apply(to: rows).count == 1)
        #expect(ActivityFilter(search: "zzz").apply(to: rows).isEmpty)
    }

    @Test func tableSortsByAmountAndStatus() async throws {
        let (rows, _) = try await loadedRows()
        let byAmount = rows.sorted(using: KeyPathComparator(\ActivityRow.sortAmount, order: .reverse))
        #expect(byAmount.first?.symbol == "USDC")
        let byStatus = rows.sorted(using: KeyPathComparator(\ActivityRow.sortStatus))
        #expect(byStatus.first?.statusName == "Confirmed")
        #expect(byStatus.last?.statusName == "Pending")
    }

    @Test func networksWithoutHistoryAreReportedBesideTheRest() async throws {
        let (rows, store) = try await loadedRows(.balanceFailure)
        #expect(store.unavailable[PreviewCatalog.kusama.id]?.contains("Kusama") == true)
        #expect(!rows.contains { $0.chain?.id == PreviewCatalog.kusama.id })
        #expect(rows.count == 13)
    }

    @Test func resetAndWalletSwitchClearOldEntries() async throws {
        let fixture = try await Fixture.make()
        let store = ActivityStore(services: fixture.services)
        await store.refresh(wallet: fixture.wallet)
        #expect(!store.items.isEmpty)
        let savings = try #require(try await fixture.services.wallets.wallets().first { $0.id == PreviewSampleData.savingsWalletID })
        await store.refresh(wallet: savings)
        #expect(store.items.count == 3)
        #expect(store.items.allSatisfy { $0.walletID == savings.id })
        store.reset()
        #expect(store.items.isEmpty)
        #expect(store.state == .idle)
    }
}
