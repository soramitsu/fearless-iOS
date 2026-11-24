import Foundation
import Testing
import WalletCore
@testable import WalletPreviewSupport
@testable import WalletUI

/// Settings backed by a throwaway defaults suite, so tests never touch the
/// user's preferences or each other.
@MainActor
func makeSettings() -> AppSettings {
    let suite = "fearless.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite) ?? .standard
    defaults.removePersistentDomain(forName: suite)
    return AppSettings(defaults: defaults)
}

/// Polls a condition on the main actor until it holds or the time is up.
@MainActor
func waitUntil(timeout: Duration = .seconds(20), _ condition: @MainActor () -> Bool) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now + timeout
    while !condition() {
        if clock.now >= deadline { return false }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return true
}

/// An unlocked sample vault with the main wallet's balances loaded.
@MainActor
struct Fixture {
    let services: WalletServices
    let settings: AppSettings
    let wallet: Wallet
    let store: PortfolioStore

    static func make(_ scenario: PreviewScenario = .standard, walletID: WalletID = PreviewSampleData.mainWalletID) async throws -> Fixture {
        let services = PreviewWalletServices.make(scenario: scenario.instant())
        let settings = makeSettings()
        let wallets = try await services.wallets.wallets()
        let wallet = try #require(wallets.first { $0.id == walletID })
        let store = PortfolioStore(services: services)
        await store.refresh(wallet: wallet, fiat: .usd, includeTestnets: true)
        return Fixture(services: services, settings: settings, wallet: wallet, store: store)
    }

    var rows: [AssetRow] { store.rows(for: wallet) }

    func row(_ asset: Asset) throws -> AssetRow {
        try #require(rows.first { $0.id == asset.id })
    }

    func sendModel(asset: Asset = PreviewCatalog.dot, locale: Locale = Locale(identifier: "en_US")) -> SendModel {
        SendModel(wallet: wallet, rows: rows, initialAssetID: asset.id, fiat: .usd, services: services, locale: locale, debounce: .zero)
    }
}

let posix = Locale(identifier: "en_US_POSIX")

func amount(_ text: String, _ decimals: Int) -> TokenAmount {
    TokenAmount(decimalString: text, decimals: decimals, locale: posix) ?? .zero(decimals: decimals)
}
