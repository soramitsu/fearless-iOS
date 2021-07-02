import UIKit
import BeaconSDK

final class SignerConnectInteractor {
    weak var presenter: SignerConnectInteractorOutputProtocol!

    private var client: Beacon.Client?

    let peer: Beacon.P2PPeer
    let logger: LoggerProtocol?

    init(info: BeaconConnectionInfo, logger: LoggerProtocol? = nil) {
        peer = Beacon.P2PPeer(
            name: info.name,
            publicKey: info.publicKey,
            relayServer: info.relayServer,
            version: info.version
        )

        self.logger = logger
    }

    deinit {
        client?.remove([.p2p(peer)], completion: { _ in })
    }

    private func connect(using client: Beacon.Client) {
        self.client = client

        client.connect { [weak self] result in
            switch result {
            case .success:
                self?.addPeer()
            case let .failure(error):
                self?.logger?.error("Could not connect, got error: \(error)")
                self?.client = nil
            }
        }
    }

    private func addPeer() {
        client?.add([.p2p(peer)]) { [weak self] result in
            switch result {
            case .success:
                self?.startListenRequests()
            case let .failure(error):
                self?.logger?.error("Error while adding peer: \(error)")
                self?.client = nil
            }
        }
    }

    private func startListenRequests() {
        client?.listen(onRequest: onBeaconRequest(result:))
    }

    private func onBeaconRequest(result: Result<Beacon.Request, Beacon.Error>) {
        switch result {
        case let .success(request):
            DispatchQueue.main.async {
                self.handle(request: request)
            }
        case let .failure(error):
            logger?.error("Error while processing incoming messages: \(error)")
        }
    }

    private func handle(request: Beacon.Request) {
        logger?.info("Did receive request: \(request)")
    }
}

extension SignerConnectInteractor: SignerConnectInteractorInputProtocol {
    func connect() {
        Beacon.Client.create(with: Beacon.Client.Configuration(name: "Fearless")) { [weak self] result in
            switch result {
            case let .success(client):
                self?.connect(using: client)
            case let .failure(error):
                self?.logger?.error("Could not create Beacon client, got error: \(error)")
            }
        }
    }
}
