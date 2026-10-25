import BigInt
import Foundation
import RobinHood
import SSFModels
import SSFUtils
import TonAPI
import TonSwift

protocol TonHistoryRemoteProtocol {
    func events(address: String, chain: ChainModel, before: Int64?, limit: Int) async throws -> Components.Schemas.AccountEvents
    func jettonMaster(walletAddress: String, owner: String, chain: ChainModel) async throws -> String?
}

extension TonHistoryRemoteProtocol {
    func jettonMaster(walletAddress _: String, owner _: String, chain _: ChainModel) async throws -> String? { nil }
}

final class TonHistoryRemoteClient: TonHistoryRemoteProtocol {
    private let clientProvider: (ChainModel) throws -> TonAPI.Client

    init(clientProvider: @escaping (ChainModel) throws -> TonAPI.Client = { chain in
        let baseURL = try ChainRegistry.tonAPIBaseURL(for: chain)
        if let configured = try? ChainRegistryFacade.sharedRegistry.getTonApiClientFactory(),
           configured.serverURL == baseURL {
            return configured.tonAPIClient()
        }
        return TonAPIClientFactory(tonAPIURL: baseURL, token: "").tonAPIClient()
    }) {
        self.clientProvider = clientProvider
    }

    func events(address: String, chain: ChainModel, before: Int64?, limit: Int) async throws -> Components.Schemas.AccountEvents {
        let response = try await clientProvider(chain).getAccountEvents(
            path: .init(account_id: address),
            query: .init(subject_only: true, before_lt: before, limit: limit)
        )
        return try response.ok.body.json
    }

    func jettonMaster(walletAddress: String, owner: String, chain: ChainModel) async throws -> String? {
        let wallet = try TonSwift.Address.parse(walletAddress)
        let result = try await clientProvider(chain).execGetMethodForBlockchainAccount(
            path: .init(account_id: wallet.toRaw(), method_name: "get_wallet_data")
        ).ok.body.json
        // TEP-74 exposes the owner and master even when the token balance is zero.
        guard result.success, [0, 1].contains(result.exit_code) else { return nil }
        guard result.stack.count == 4, result.stack[0]._type == .num else { throw TonHistoryError.invalidResponse }
        let originalOwner = try Self.address(from: result.stack[1])
        guard originalOwner == (try TonSwift.Address.parse(owner)) else { return nil }
        return try Self.address(from: result.stack[2]).toRaw()
    }

    private static func address(from value: Components.Schemas.TvmStackRecord) throws -> TonSwift.Address {
        guard value._type == .cell, let text = value.slice ?? value.cell, text.utf8.count <= 2048 else {
            throw TonHistoryError.invalidResponse
        }
        let hex = text.hasPrefix("0x") ? String(text.dropFirst(2)) : text
        let data: Data
        if !hex.isEmpty, hex.count.isMultiple(of: 2), hex.utf8.allSatisfy({ (48 ... 57).contains($0) || (65 ... 70).contains($0) || (97 ... 102).contains($0) }) {
            let characters = Array(hex)
            data = Data(stride(from: 0, to: characters.count, by: 2).compactMap { UInt8(String(characters[$0 ... $0 + 1]), radix: 16) })
        } else if let decoded = Data(base64Encoded: text), decoded.base64EncodedString() == text {
            data = decoded
        } else { throw TonHistoryError.invalidResponse }
        let cell = try TonTransferTransactionBuilder.parseBoundedBoc(data, maximumBytes: 1024)
        let slice = try cell.beginParse()
        let address: TonSwift.Address = try slice.loadType()
        try slice.endParse()
        return address
    }
}

enum TonHistoryError: Error {
    case invalidPagination
    case invalidResponse
}

/// Uses the original account address; account history also covers tokens whose
/// old asset ID is a Jetton wallet address and whose current balance is zero.
final class TonHistoryOperationFactory: HistoryOperationFactoryProtocol {
    private let remote: TonHistoryRemoteProtocol

    init(remote: TonHistoryRemoteProtocol = TonHistoryRemoteClient()) {
        self.remote = remote
    }

    func fetchTransactionHistoryOperation(
        asset: AssetModel,
        chain: ChainModel,
        address: String,
        filters: [WalletTransactionHistoryFilter],
        pagination: Pagination
    ) -> CompoundOperationWrapper<AssetTransactionPageData?> {
        guard chain.isTonCompatibilityChain, pagination.count >= 1 else {
            return .createWithResult(AssetTransactionPageData(transactions: []))
        }
        let operation = AwaitOperation<AssetTransactionPageData?> { [remote] in
            let owner = try TonSwift.Address.parse(address)
            let before: Int64?
            if let cursor = pagination.context?["nextFrom"] {
                guard let value = Int64(cursor), value > 0 else { throw TonHistoryError.invalidPagination }
                before = value
            } else {
                before = nil
            }
            let result = try await remote.events(
                address: owner.toRaw(), chain: chain, before: before, limit: min(pagination.count, 100)
            )
            guard result.events.count <= 100, result.next_from >= 0,
                  result.events.allSatisfy({ $0.actions.count <= 256 && $0.timestamp >= 0 && (try? TonSwift.Address.parse($0.account.address)) == owner }) else {
                throw TonHistoryError.invalidResponse
            }
            let identifiers = [asset.id, asset.currencyId].compactMap { $0 }.compactMap { try? TonSwift.Address.parse($0) }
            let swaps = result.events.flatMap(\.actions).compactMap(\.JettonSwap).filter {
                (try? TonSwift.Address.parse($0.user_wallet.address)) == owner
            }
            var resolvedMaster: TonSwift.Address?
            if !asset.isNative, !swaps.isEmpty,
               filters.isEmpty || filters.contains(where: { $0.type == .swap && $0.selected }),
               !swaps.contains(where: { swap in
                   [swap.jetton_master_in, swap.jetton_master_out].compactMap { $0 }
                       .contains { (try? TonSwift.Address.parse($0.address)).map(identifiers.contains) == true }
               }), let candidate = identifiers.first,
               let master = try await remote.jettonMaster(walletAddress: candidate.toRaw(), owner: owner.toRaw(), chain: chain) {
                resolvedMaster = try TonSwift.Address.parse(master)
            }
            var transactions: [AssetTransactionData] = []
            for event in result.events {
                guard try TonSwift.Address.parse(event.account.address) == owner,
                      event.timestamp >= 0, event.actions.count <= 256 else {
                    throw TonHistoryError.invalidResponse
                }
                var feeIncluded = false
                for action in event.actions {
                    if let transaction = Self.transaction(
                        event: event, action: action, owner: owner, asset: asset,
                        chain: chain, filters: filters, includeFee: !feeIncluded, resolvedMaster: resolvedMaster
                    ) {
                        feeIncluded = feeIncluded || !transaction.fees.isEmpty
                        transactions.append(transaction)
                    }
                }
            }
            let context: [String: String]?
            if result.next_from > 0, before.map({ result.next_from < $0 }) ?? true {
                context = ["nextFrom": String(result.next_from)]
            } else {
                context = nil
            }
            return AssetTransactionPageData(
                transactions: transactions.sorted { $0.timestamp > $1.timestamp }, context: context
            )
        }
        // Errors propagate to the history provider, retaining its cached page.
        return CompoundOperationWrapper(targetOperation: operation)
    }

    private static func transaction(
        event: Components.Schemas.AccountEvent,
        action: Components.Schemas.Action,
        owner: TonSwift.Address,
        asset: AssetModel,
        chain: ChainModel,
        filters: [WalletTransactionHistoryFilter],
        includeFee: Bool,
        resolvedMaster: TonSwift.Address?
    ) -> AssetTransactionData? {
        if let swap = action.JettonSwap {
            return swapTransaction(
                event: event,
                action: action,
                swap: swap,
                owner: owner,
                asset: asset,
                chain: chain,
                filters: filters,
                includeFee: includeFee,
                resolvedMaster: resolvedMaster
            )
        }
        guard filters.isEmpty || filters.contains(where: { $0.type == .transfer && $0.selected }),
              asset.precision <= UInt16(Int16.max) else { return nil }
        let sender: TonSwift.Address
        let recipient: TonSwift.Address
        let units: BigUInt
        let comment: String?
        if asset.isNative, let transfer = action.TonTransfer,
           transfer.amount >= 0,
           let from = try? TonSwift.Address.parse(transfer.sender.address),
           let to = try? TonSwift.Address.parse(transfer.recipient.address) {
            sender = from
            recipient = to
            units = BigUInt(UInt64(transfer.amount))
            comment = transfer.comment
        } else if !asset.isNative, let transfer = action.JettonTransfer,
                  matches(asset: asset, jetton: transfer, owner: owner),
                  let from = transfer.sender.flatMap({ try? TonSwift.Address.parse($0.address) }),
                  let to = transfer.recipient.flatMap({ try? TonSwift.Address.parse($0.address) }),
                  let amount = BigUInt(transfer.amount) {
            sender = from
            recipient = to
            units = amount
            comment = transfer.comment
        } else {
            return nil
        }
        guard sender == owner || recipient == owner,
              let amount = Decimal.fromSubstrateAmount(units, precision: Int16(asset.precision)) else { return nil }
        let outgoing = sender == owner
        let peer = outgoing ? recipient : sender
        let peerAddress = peer.toFriendly(bounceable: false).toString()
        let status: AssetTransactionStatus = event.in_progress ? .pending : (action.status == .ok ? .commited : .rejected)
        var fees: [AssetTransactionFee] = []
        // TON event fees are always denominated in Toncoin, including Jetton transfers.
        if includeFee, outgoing, event.extra < 0,
           let nativeAsset = chain.assets.first(where: { $0.isNative }),
           let fee = Decimal.fromSubstrateAmount(BigUInt(event.extra.magnitude), precision: 9) {
            fees = [AssetTransactionFee(
                identifier: nativeAsset.id, assetId: nativeAsset.id,
                amount: AmountDecimal(value: fee), context: nil
            )]
        }
        return AssetTransactionData(
            transactionId: event.event_id, status: status, assetId: asset.id,
            peerId: peerAddress, peerFirstName: nil, peerLastName: nil, peerName: peerAddress,
            details: comment ?? "", amount: AmountDecimal(value: amount), fees: fees,
            timestamp: event.timestamp,
            type: outgoing ? TransactionType.outgoing.rawValue : TransactionType.incoming.rawValue,
            reason: "", context: asset.icon.map { ["icon": $0.absoluteString] }
        )
    }

    private static func swapTransaction(
        event: Components.Schemas.AccountEvent, action: Components.Schemas.Action,
        swap: Components.Schemas.JettonSwapAction, owner: TonSwift.Address,
        asset: AssetModel, chain: ChainModel, filters: [WalletTransactionHistoryFilter],
        includeFee: Bool, resolvedMaster: TonSwift.Address?
    ) -> AssetTransactionData? {
        guard filters.isEmpty || filters.contains(where: { $0.type == .swap && $0.selected }),
              (try? TonSwift.Address.parse(swap.user_wallet.address)) == owner,
              let input = swapLeg(jetton: swap.jetton_master_in, units: swap.amount_in, ton: swap.ton_in, chain: chain),
              let output = swapLeg(jetton: swap.jetton_master_out, units: swap.amount_out, ton: swap.ton_out, chain: chain) else { return nil }
        let ids = [asset.id, asset.currencyId].compactMap { $0 }.compactMap { try? TonSwift.Address.parse($0) } +
            (resolvedMaster.map { [$0] } ?? [])
        let relevant = asset.isNative ? input.native || output.native :
            [input.identifier, output.identifier].compactMap { try? TonSwift.Address.parse($0) }.contains(where: ids.contains)
        guard relevant else { return nil }
        var fees: [AssetTransactionFee] = []
        if includeFee, event.extra < 0, let native = chain.assets.first(where: { $0.isNative }),
           let fee = Decimal.fromSubstrateAmount(BigUInt(event.extra.magnitude), precision: 9) {
            fees = [.init(identifier: native.id, assetId: native.id, amount: AmountDecimal(value: fee), context: nil)]
        }
        return AssetTransactionData(
            transactionId: event.event_id,
            status: event.in_progress ? .pending : (action.status == .ok ? .commited : .rejected),
            assetId: output.identifier, peerId: input.identifier, peerFirstName: nil, peerLastName: nil,
            peerName: swap.router.address, details: NSDecimalNumber(decimal: input.amount).stringValue,
            amount: AmountDecimal(value: output.amount), fees: fees, timestamp: event.timestamp,
            type: TransactionType.swap.rawValue, reason: "",
            context: ["tonSwapInputSymbol": input.symbol, "tonSwapOutputSymbol": output.symbol]
        )
    }

    private static func swapLeg(
        jetton: Components.Schemas.JettonPreview?, units: String, ton: Int64?, chain: ChainModel
    ) -> (identifier: String, symbol: String, amount: Decimal, native: Bool)? {
        if let jetton {
            guard (0 ... 255).contains(jetton.decimals), units.utf8.count <= 78,
                  let address = try? TonSwift.Address.parse(jetton.address), let quantity = BigUInt(units),
                  let amount = Decimal.fromSubstrateAmount(quantity, precision: Int16(jetton.decimals)) else { return nil }
            return (address.toRaw(), String(jetton.symbol.prefix(32)), amount, false)
        }
        guard let ton, ton >= 0, let native = chain.assets.first(where: { $0.isNative }),
              let amount = Decimal.fromSubstrateAmount(BigUInt(UInt64(ton)), precision: 9) else { return nil }
        return (native.currencyId ?? native.id, native.symbol, amount, true)
    }

    private static func matches(asset: AssetModel, jetton: Components.Schemas.JettonTransferAction, owner: TonSwift.Address) -> Bool {
        let identifiers = [asset.id, asset.currencyId].compactMap { $0 }.compactMap { try? TonSwift.Address.parse($0) }
        if let master = try? TonSwift.Address.parse(jetton.jetton.address), identifiers.contains(master) {
            return true
        }
        if let sender = jetton.sender.flatMap({ try? TonSwift.Address.parse($0.address) }), sender == owner,
           let wallet = try? TonSwift.Address.parse(jetton.senders_wallet), identifiers.contains(wallet) {
            return true
        }
        return jetton.recipient.flatMap { try? TonSwift.Address.parse($0.address) } == owner &&
            (try? TonSwift.Address.parse(jetton.recipients_wallet)).map(identifiers.contains) == true
    }
}
