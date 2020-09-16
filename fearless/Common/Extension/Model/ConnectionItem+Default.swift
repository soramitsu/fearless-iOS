import Foundation
import IrohaCrypto

extension ConnectionItem {
    static var defaultConnection: ConnectionItem {
        #if F_DEV
            return ConnectionItem(title: "Westend, Parity node",
                                  url: URL(string: "wss://westend-rpc.polkadot.io")!,
                                  type: SNAddressType.genericSubstrate.rawValue)
        #else
            return ConnectionItem(title: "Kusama, Parity node",
                                  url: URL(string: "wss://kusama-rpc.polkadot.io")!,
                                  type: SNAddressType.kusamaMain.rawValue)
        #endif
    }

    static var supportedConnections: [ConnectionItem] {
        return [
            ConnectionItem(title: "Kusama, Parity node",
                           url: URL(string: "wss://kusama-rpc.polkadot.io")!,
                           type: SNAddressType.kusamaMain.rawValue),
            ConnectionItem(title: "Kusama, Web3 Foundation node",
                           url: URL(string: "wss://cc3-5.kusama.network")!,
                           type: SNAddressType.kusamaMain.rawValue),
            ConnectionItem(title: "Polkadot, Parity node",
                           url: URL(string: "wss://rpc.polkadot.io")!,
                           type: SNAddressType.polkadotMain.rawValue),
            ConnectionItem(title: "Polkadot, Web3 Foundation node",
                           url: URL(string: "wss://cc1-1.polkadot.network")!,
                           type: SNAddressType.polkadotMain.rawValue),
            ConnectionItem(title: "Westend, Parity node",
                           url: URL(string: "wss://westend-rpc.polkadot.io")!,
                           type: SNAddressType.genericSubstrate.rawValue),
            ConnectionItem(title: "Westend, Soramitsu node",
                           url: URL(string: "wss://ws.validator.dev.polkadot-rust.soramitsu.co.jp:443")!,
                           type: SNAddressType.genericSubstrate.rawValue)
        ]
    }
}
