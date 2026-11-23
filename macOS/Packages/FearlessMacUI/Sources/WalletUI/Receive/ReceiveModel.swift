import DesignSystem
import Foundation
import Observation
import WalletCore

/// The receive sheet: one wallet, one network, its address.
@MainActor
@Observable
final class ReceiveModel: Identifiable {
    enum AddressState: Equatable {
        case loading
        case loaded(String)
        case failed(String)
    }

    let id = UUID()
    let wallet: Wallet
    let chains: [Chain]
    @ObservationIgnored private let services: WalletServices
    @ObservationIgnored private var generation = 0

    private(set) var chainID: ChainID?
    private(set) var state: AddressState = .loading
    /// Symbols of the assets this network carries, for the warning line.
    private(set) var assetSymbols: [String] = []
    @ObservationIgnored private let assets: [Asset]

    init(wallet: Wallet, chains: [Chain], assets: [Asset], initialChainID: ChainID?, services: WalletServices) {
        self.wallet = wallet
        self.chains = chains
        self.assets = assets
        self.services = services
        if let initialChainID, chains.contains(where: { $0.id == initialChainID }) {
            chainID = initialChainID
        } else {
            chainID = chains.first?.id
        }
        assetSymbols = Self.symbols(for: chainID, in: assets)
    }

    private static func symbols(for chainID: ChainID?, in assets: [Asset]) -> [String] {
        var seen: Set<String> = []
        return assets.filter { $0.chainID == chainID }.map(\.symbol).filter { seen.insert($0).inserted }
    }

    var chain: Chain? {
        chains.first { $0.id == chainID }
    }

    var address: String? {
        if case .loaded(let address) = state { return address }
        return nil
    }

    var explorerURL: URL? {
        guard let address, let chain else { return nil }
        return AddressFormat.webURL(chain.explorer?.accountURL(address: address))
    }

    /// "Send only DOT, USDT and USDC on Polkadot Asset Hub to this address."
    var warning: String {
        guard let chain else { return "" }
        let list: String
        switch assetSymbols.count {
        case 0: list = "assets"
        case 1: list = assetSymbols[0]
        default: list = assetSymbols.dropLast().joined(separator: ", ") + " and " + (assetSymbols.last ?? "")
        }
        return "Send only \(list) on the \(chain.name) network to this address. Anything sent from another network may be lost."
    }

    func select(_ id: ChainID) async {
        guard id != chainID, chains.contains(where: { $0.id == id }) else { return }
        chainID = id
        assetSymbols = Self.symbols(for: id, in: assets)
        await load()
    }

    func load() async {
        guard let chainID else {
            state = .failed("This wallet has no account on the available networks.")
            return
        }
        generation += 1
        let current = generation
        state = .loading
        do {
            let address = try await services.wallets.address(of: wallet.id, on: chainID)
            guard current == generation else { return }
            state = .loaded(address)
        } catch {
            guard current == generation else { return }
            state = .failed(ErrorText.message(for: error))
        }
    }
}
