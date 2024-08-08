import Foundation
import SSFChainConnection
import RobinHood
import SSFModels
import BigInt
import TonAPI
import TonSwift

final class TonHistoryOperationFactory {
    private lazy var tonAPIClient: TonAPI.Client? = {
        try? ChainRegistryFacade.sharedRegistry.getTonApiAssembly().tonAPIClient()
    }()

    private func createOperation(
        address: String,
        chainAsset: ChainAsset,
        before_lt: Int64?
    ) -> BaseOperation<TonAccountEvents> {
        AwaitOperation { [weak self] in
            guard let self else {
                throw ConvenienceError(error: "Memory error")
            }
            let accountId = try TonSwift.Address.parse(address).toRaw()
            switch chainAsset.asset.assetType.tonAssetType {
            case .normal:
                let events = try await self.fetchAccountEvents(address: accountId, before_lt: before_lt)
                return events
            case .jetton:
                guard let jettonAddress = chainAsset.asset.currencyId else {
                    throw ConvenienceError(error: "Missing jetton address")
                }
                let events = try await self.fetchJettonsHistory(
                    accountAddress: accountId,
                    jettonAddress: jettonAddress,
                    before_lt: before_lt
                )
                return events
            case .none:
                throw ConvenienceError(error: "Missing asset type")
            }
        }
    }

    private func fetchAccountEvents(
        address: String,
        before_lt: Int64?
    ) async throws -> TonAccountEvents {
        guard let tonAPIClient else {
            throw ConvenienceError(error: "Client not initialized")
        }
        let response = try await tonAPIClient.getAccountEvents(
            path: .init(account_id: address),
            query: .init(
                before_lt: before_lt,
                limit: 25,
                start_date: nil,
                end_date: nil
            )
        )
        let entity = try response.ok.body.json
        let events: [TonAccountEvent] = entity.events.compactMap {
            guard let activityEvent = try? TonAccountEvent(accountEvent: $0) else { return nil }
            return activityEvent
        }
        let remoteEvents = TonAccountEvents(
            address: try TonSwift.Address.parse(address),
            events: events,
            startFrom: before_lt ?? 0,
            nextFrom: entity.next_from
        )
        return remoteEvents
//        let tonEvents = filterTonEvents(events: remoteEvents)
//        return tonEvents
    }

    private func fetchJettonsHistory(
        accountAddress: String,
        jettonAddress: String,
        before_lt: Int64?
    ) async throws -> TonAccountEvents {
        guard let tonAPIClient else {
            throw ConvenienceError(error: "Client not initialized")
        }
        let response = try await tonAPIClient.getAccountJettonHistoryByID(
            path: .init(
                account_id: accountAddress,
                jetton_id: jettonAddress
            ),
            query: .init(
                before_lt: before_lt,
                limit: 25,
                start_date: nil,
                end_date: nil
            )
        )
        let entity = try response.ok.body.json
        let events: [TonAccountEvent] = entity.events.compactMap {
            guard let activityEvent = try? TonAccountEvent(accountEvent: $0) else { return nil }
            return activityEvent
        }
        return TonAccountEvents(
            address: try TonSwift.Address.parse(accountAddress),
            events: events,
            startFrom: before_lt ?? 0,
            nextFrom: entity.next_from
        )
    }

//    private func filterTonEvents(events: TonAccountEvents) -> TonAccountEvents {
//        let filteredEvents = events.events.compactMap { event -> TonAccountEvent? in
//            let filteredActions = event.actions.compactMap { action -> AccountEventAction? in
//                guard case .tonTransfer = action.type else { return nil }
//                return action
//            }
//            guard !filteredActions.isEmpty else { return nil }
//            return TonAccountEvent(
//                eventId: event.eventId,
//                timestamp: event.timestamp,
//                account: event.account,
//                isScam: event.isScam,
//                isInProgress: event.isInProgress,
//                fee: event.fee,
//                actions: filteredActions
//            )
//        }
//        return filteredEvents
//    }

    private func createMapOperation(
        dependingOn remoteOperation: BaseOperation<TonAccountEvents>,
        address: String,
        asset: AssetModel,
        chain: ChainModel
    ) -> BaseOperation<AssetTransactionPageData?> {
        ClosureOperation {
            let events = try remoteOperation.extractNoCancellableResultData().events

            let transactions = events
                .compactMap { event in
                    event.actions.compactMap {
                        AssetTransactionData.createTransaction(
                            event: event,
                            action: $0,
                            address: address,
                            chain: chain,
                            asset: asset
                        )
                    }
                }
                .reduce([], +)
                .sorted(by: { $0.timestamp > $1.timestamp })

            let context = try remoteOperation.extractNoCancellableResultData().toContext()
            return AssetTransactionPageData(transactions: transactions, context: context)
        }
    }
}

extension TonHistoryOperationFactory: HistoryOperationFactoryProtocol {
    func fetchTransactionHistoryOperation(
        asset: AssetModel,
        chain: ChainModel,
        address: String,
        filters _: [WalletTransactionHistoryFilter],
        pagination: Pagination
    ) -> CompoundOperationWrapper<AssetTransactionPageData?> {
        var before_lt: Int64?
        if let before = pagination.context?["nextFrom"] {
            before_lt = Int64(before)
        }
        let remoteOperation = createOperation(
            address: address,
            chainAsset: ChainAsset(chain: chain, asset: asset),
            before_lt: before_lt
        )

        let mapOperation = createMapOperation(
            dependingOn: remoteOperation,
            address: address,
            asset: asset,
            chain: chain
        )

        mapOperation.addDependency(remoteOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [remoteOperation])
    }
}
