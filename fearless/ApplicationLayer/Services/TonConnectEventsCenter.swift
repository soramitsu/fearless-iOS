import Foundation
import SoraKeystore
import SSFModels
import TonConnectAPI
import EventSource
import TonSwift

protocol TonConnectEventsCenterDelegate: AnyObject {
    func didReceive(event: TonConnectEventsCenter.Event) async
}

actor TonConnectEventsCenter {
    private enum Constant {
        static let lastEventKey = "ton.connect.last.event.key"
    }
    enum Event {
        case request(
            request: TonConnect.AppRequest,
            walletId: MetaAccountId,
            app: TonConnectApp
        )
    }

    private weak var delegate: TonConnectEventsCenterDelegate?
    private let chainRegistry: ChainRegistryProtocol
    private let lastEventStore: SettingsManagerProtocol
    private let logger: LoggerProtocol

    private var observableApps: [TonConnectApp] = []
    private var task: Task<Void, Error>?
    private lazy var jsonDecoder = JSONDecoder()

    init(
        chainRegistry: ChainRegistryProtocol,
        lastEventStore: SettingsManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.lastEventStore = lastEventStore
        self.logger = logger
    }

    func set(delegate: TonConnectEventsCenterDelegate) {
        self.delegate = delegate
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    func start(with apps: [TonConnectApp]) throws {
        observableApps = apps
        let apiClient = try chainRegistry.getTonApiAssembly().tonConnectAPIClient()
        task?.cancel()

        let task = Task {
            let ids = apps
                .map { $0.keyPair.publicKey.hexString }
                .compactMap { $0 }
                .joined(separator: ",")
            let lastEventId = lastEventStore.value(of: String.self, for: Constant.lastEventKey)

            let errorParser = EventSourceDecodableErrorParser<TonConnectError>()
            let stream = try await EventSource.eventSource({
                let response = try await apiClient.events(
                    query: .init(
                        client_id: [ids],
                        last_event_id: lastEventId
                    )
                )
                return try response.ok.body.text_event_hyphen_stream
            }, errorParser: errorParser)

            for try await events in stream {
                await handleEventSourceEvents(events)
            }

            guard !Task.isCancelled else { return }
            try start(with: apps)
        }
        self.task = task
    }

    // MARK: - Private methods

    private func handleEventSourceEvents(_ events: [EventSource.Event]) async {
        guard
            let event = events.last(where: { $0.event == "message" }),
            let data = event.data?.data(using: .utf8),
            let tonConnectEvent = try? jsonDecoder.decode(TonConnectEvent.self, from: data)
        else {
            return
        }

        lastEventStore.set(value: event.id, for: Constant.lastEventKey)
        await handleEvent(tonConnectEvent)
    }

    private func handleEvent(_ tonConnectEvent: TonConnectEvent) async {
        guard let app = observableApps.first(where: { $0.clientId == tonConnectEvent.from }) else {
            return
        }

        do {
            let sessionCrypto = try TonConnectSessionCrypto(privateKey: app.keyPair.privateKey)
            guard
                let senderPublicKey = Data(tonHex: app.clientId),
                let message = Data(base64Encoded: tonConnectEvent.message)
            else {
                return
            }
            let decryptedMessage = try sessionCrypto.decrypt(
                message: message,
                senderPublicKey: senderPublicKey
            )
            let request = try jsonDecoder.decode(
                TonConnect.AppRequest.self,
                from: decryptedMessage
            )

            await delegate?.didReceive(
                event: .request(
                    request: request,
                    walletId: app.walletId,
                    app: app
                )
            )
        } catch {
            logger.customError(error)
        }
    }
}
