import Foundation
import IrohaCrypto

extension ConnectionItem {
    static var defaultConnection: ConnectionItem {
        #if F_DEV
            return ConnectionItem(title: "Soramitsu Westend node",
                                  url: URL(string: "wss://ws.validator.dev.polkadot-rust.soramitsu.co.jp:443")!,
                                  type: SNAddressType.genericSubstrate.rawValue)
        #else
            return ConnectionItem(title: "Parity Kusama public node",
                                  url: URL(string: "wss://kusama-rpc.polkadot.io/")!,
                                  type: SNAddressType.kusamaMain.rawValue)
        #endif
    }

    static var supportedConnections: [ConnectionItem] {
        let westend = ConnectionItem(title: "Soramitsu Westend node",
                                     url: URL(string: "wss://ws.validator.dev.polkadot-rust.soramitsu.co.jp:443")!,
                                     type: SNAddressType.genericSubstrate.rawValue)
        let kusama = ConnectionItem(title: "Parity Kusama public node",
                                    url: URL(string: "wss://kusama-rpc.polkadot.io/")!,
                                    type: SNAddressType.kusamaMain.rawValue)

        let polkadot = ConnectionItem(title: "Parity Polkadot public node",
                                      url: URL(string: "wss://rpc.polkadot.io")!,
                                      type: SNAddressType.polkadotMain.rawValue)

        return [westend, kusama, polkadot]
    }
}
