import Foundation
import WalletCore
import XCTest
@testable import WalletEngine

final class LiveTests: XCTestCase {
    func testReadOnlyBalancesPricesAndTestnetFeeQuotes() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["FEARLESS_LIVE_TESTS"] == "1",
            "Read-only public RPC smoke is opt-in."
        )
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var config = WalletEngineConfiguration.default
        config.storageDirectory = root
        config.keychainService = UUID().uuidString
        let svc = WalletEngineFactory.makeLiveServices(configuration: config)
        // Public relay account and a public Sepolia sender observed in a finalized block.
        let wallet = try await svc.wallets.addWallet(name: "Public addresses", source: .watchOnly(
            substrateAddress: "165GUHN1DS7cSeJWA6VPQNnVcKGuyBB7F48PaEb2bcSLnYur",
            evmAddress: "0xcfced70c8f6e916fe4d063cc1a0d89cd8767de91"
        ))
        let assets = await svc.catalog.assets()
        var balances = await svc.balances.balances(of: wallet.id, assets: assets.map(\.id))
        let retry = balances.compactMap { id, value -> AssetID? in
            if case .failure(.network) = value {
                return id
            }
            return nil
        }
        print(
            "Live balances: \(balances.count - retry.count) returned on the first request; \(retry.count) transient failures retried."
        )
        if !retry.isEmpty {
            let refreshed = await svc.balances.balances(of: wallet.id, assets: retry)
            balances.merge(refreshed) { _, latest in latest }
        }
        XCTAssertEqual(balances.count, 13)
        for asset in assets {
            do {
                let balance = try XCTUnwrap(balances[asset.id]).get()
                XCTAssertEqual(balance.assetID, asset.id)
            } catch { XCTFail("\(asset.id): \(error.localizedDescription)") }
        }
        for chain in await svc.catalog.chains() where chain.isTestnet {
            let address: String
            if let prefix = chain.ss58Prefix {
                address = try WalletKeys.address(WalletAccount(
                    ecosystem: .substrate,
                    cryptoType: .sr25519,
                    publicKey: Data(repeating: 2, count: 32),
                    derivationPath: nil
                ), prefix: prefix)
            } else {
                address = "0x0000000000000000000000000000000000000001"
            }
            let decimals = try XCTUnwrap(assets.first { $0.id == chain.nativeAssetID }?.decimals)
            let result = try await svc.transfers.prepare(TransferRequest(
                walletID: wallet.id,
                assetID: chain.nativeAssetID,
                recipient: address,
                amount: XCTUnwrap(TokenAmount(units: "1", decimals: decimals))
            ))
            XCTAssertNotNil(result.fee, "\(chain.name): \(result.issues)")
            XCTAssertTrue(result.issues.contains(.watchOnlyWallet))
        }
        let prices = try await svc.prices.prices(for: ["polkadot", "ethereum"], in: .usd)
        XCTAssertEqual(prices.count, 2)
        let relayAssets = await svc.catalog.chains().filter { ["Polkadot", "Kusama"].contains($0.name) }
            .map(\.nativeAssetID)
        let page = try await svc.activity.activity(of: wallet.id, assets: relayAssets)
        XCTAssertTrue(page.unavailable.isEmpty, "Relay history unavailable: \(page.unavailable)")
        XCTAssertTrue(page.items.contains { $0.assetID == relayAssets.first && $0.direction == .incoming })
    }
}
