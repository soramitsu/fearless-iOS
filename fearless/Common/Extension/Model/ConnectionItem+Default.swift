import Foundation
import IrohaCrypto

extension ConnectionItem {
    static var defaultConnection: ConnectionItem {
        ConnectionItem(
            title: "Kusama, OnFinality node",
            url: URL(string: "wss://kusama.api.onfinality.io/ws?apikey=767ba403-66b9-402b-8018-640799c48793")!,
            type: SNAddressType.kusamaMain
        )
    }

    static var supportedConnections: [ConnectionItem] {
        [
            ConnectionItem(
                title: "Kusama, OnFinality node",
                url: URL(string: "wss://kusama.api.onfinality.io/ws?apikey=767ba403-66b9-402b-8018-640799c48793")!,
                type: SNAddressType.kusamaMain
            ),
            ConnectionItem(
                title: "Kusama, Parity node",
                url: URL(string: "wss://kusama-rpc.polkadot.io")!,
                type: SNAddressType.kusamaMain
            ),
            ConnectionItem(
                title: "Kusama, Patract node",
                url: URL(string: "wss://kusama.elara.patract.io")!,
                type: SNAddressType.kusamaMain
            ),
            ConnectionItem(
                title: "Polkadot, OnFinality node",
                url: URL(string: "wss://polkadot.api.onfinality.io/ws?apikey=767ba403-66b9-402b-8018-640799c48793")!,
                type: SNAddressType.polkadotMain
            ),
            ConnectionItem(
                title: "Polkadot, Parity node",
                url: URL(string: "wss://rpc.polkadot.io")!,
                type: SNAddressType.polkadotMain
            ),
            ConnectionItem(
                title: "Polkadot, Patract node",
                url: URL(string: "wss://polkadot.elara.patract.io")!,
                type: SNAddressType.polkadotMain
            ),
            ConnectionItem(
                title: "Westend, Parity node",
                url: URL(string: "wss://westend-rpc.polkadot.io")!,
                type: SNAddressType.genericSubstrate
            ),
            ConnectionItem(
                title: "Rococo, Laminar node",
                url: URL(string: "wss://rococo-community-rpc.laminar.codes/ws")!,
                type: SNAddressType.kusamaSecondary
            )
        ]
    }

    static var deprecatedConnections: [ConnectionItem] {
        [
            ConnectionItem(
                title: "Kusama, Web3 Foundation node",
                url: URL(string: "wss://cc3-5.kusama.network")!,
                type: SNAddressType.kusamaMain
            ),
            ConnectionItem(
                title: "Polkadot, Web3 Foundation node",
                url: URL(string: "wss://cc1-1.polkadot.network")!,
                type: SNAddressType.polkadotMain
            )
        ]
    }
}
