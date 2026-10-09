import Foundation

final class UniversalWalletIndexerClientFactory {
    private let transport: UniversalWalletHTTPTransport
    private let irohaTransport: IrohaToriiHTTPTransport
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        transport: UniversalWalletHTTPTransport = URLSessionUniversalWalletHTTPTransport(),
        irohaTransport: IrohaToriiHTTPTransport = IrohaNoRedirectHTTPTransport(),
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder()
    ) {
        self.transport = transport
        self.irohaTransport = irohaTransport
        self.decoder = decoder
        self.encoder = encoder
    }

    func bitcoinClient() -> BitcoinIndexerClient {
        BitcoinIndexerClient(transport: transport, decoder: decoder)
    }

    func solanaClient() -> SolanaIndexerClient {
        SolanaIndexerClient(transport: transport, decoder: decoder, encoder: encoder)
    }

    func tonClient() -> TonIndexerClient {
        TonIndexerClient(transport: transport, decoder: decoder, encoder: encoder)
    }

    func irohaClient() -> IrohaToriiClient {
        IrohaToriiClient(transport: irohaTransport, decoder: decoder, encoder: encoder)
    }
}
