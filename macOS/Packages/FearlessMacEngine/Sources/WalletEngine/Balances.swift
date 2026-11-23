import BigInt
import Foundation
import IrohaCrypto
import SSFModels
import SSFUtils
import WalletCore

struct Funds {
    var free, total, transferable, minimum: BigUInt
    var exists: Bool
    var preserved: BigUInt {
        min(transferable, free > minimum ? free - minimum : 0)
    }

    static func system(_ account: JSON?, minimum: BigUInt) throws -> Funds {
        guard let account else { return Funds(free: 0, total: 0, transferable: 0, minimum: minimum, exists: false) }
        let free = try SubstrateRuntime.number(account["data"]?["free"])
        let reserved = try SubstrateRuntime.number(account["data"]?["reserved"])
        let frozen = try SubstrateRuntime.number(account["data"]?["frozen"])
        let providers = try SubstrateRuntime.number(account["providers"])
        let consumers = try SubstrateRuntime.number(account["consumers"])
        let floor = max(frozen > reserved ? frozen - reserved : 0, consumers > 0 && providers <= 1 ? minimum : 0)
        return Funds(
            free: free,
            total: free + reserved,
            transferable: free > floor ? free - floor : 0,
            minimum: minimum,
            exists: true
        )
    }

    static func asset(_ account: JSON?, details: JSON, frozen: JSON?, held: JSON?) throws -> Funds {
        let minimum = try SubstrateRuntime.number(details["min_balance"] ?? details["minBalance"])
        let supply = try SubstrateRuntime.number(details["supply"])
        let onHold = try held.map(SubstrateRuntime.number) ?? 0
        let freeze = try frozen.map(SubstrateRuntime.number) ?? 0
        let amount = try account.map { try SubstrateRuntime.number($0["balance"]) } ?? 0
        // pallet-assets enforces the minimum even for an expendable transfer when either
        // the holder or freezer supplies an entry. Stored zero and absent are distinct.
        let locked = freeze > onHold ? freeze - onHold : 0
        let floor = frozen == nil && held == nil ? 0 : max(minimum, locked)
        let liquid = account?["status"]?[0]?.stringValue == "Liquid" && details["status"]?[0]?.stringValue == "Live"
        let reducible = liquid && amount > floor ? min(supply, amount - floor) : 0
        return Funds(
            free: amount,
            total: amount + onHold,
            transferable: reducible,
            minimum: minimum,
            exists: account != nil
        )
    }
}

extension NetworkServices: BalanceServicing {
    static func quantity(_ value: Any) throws -> BigUInt {
        guard let string = value as? String, string.hasPrefix("0x"), string.count <= 66,
              let quantity = BigUInt(string.dropFirst(2), radix: 16)
        else { throw WalletError.network("Invalid EVM quantity.") }
        return quantity
    }

    static func amount(_ value: BigUInt, decimals: Int) throws -> TokenAmount {
        guard let amount = TokenAmount(units: String(value), decimals: decimals)
        else { throw WalletError.unsupportedAsset }
        return amount
    }

    func funds(_ asset: AssetID, address: String, at fixedBlock: String? = nil) async throws -> Funds {
        let chain = try Catalog.chain(asset.chainID)
        guard chain.assets.contains(where: { $0.key == asset.key }) else { throw WalletError.unsupportedAsset }
        if let prefix = chain.prefix {
            let block: String
            if let fixedBlock {
                block = fixedBlock
            } else {
                block = try await blockHash(chain.id)
            }
            let rt = try await runtime(chain.id, block: block)
            let key = try SS58AddressFactory().accountId(fromAddress: address, type: prefix)
            if asset.isNative {
                return try await Funds.system(
                    value(rt, chain.id, block: block, module: "System", name: "Account", keys: [key]),
                    minimum: rt.existentialDeposit
                )
            }
            guard var index = UInt32(asset.key.dropFirst(6))?.littleEndian else { throw WalletError.unsupportedAsset }
            let encoded = withUnsafeBytes(of: &index) { Data($0) }
            let keys = [encoded, key]
            async let details = value(rt, chain.id, block: block, module: "Assets", name: "Asset", keys: [encoded])
            async let holder = value(rt, chain.id, block: block, module: "Assets", name: "Account", keys: keys)
            async let frozen = value(
                rt,
                chain.id,
                block: block,
                module: "AssetsFreezer",
                name: "FrozenBalances",
                keys: keys
            )
            async let held = value(
                rt,
                chain.id,
                block: block,
                module: "AssetsHolder",
                name: "BalancesOnHold",
                keys: keys
            )
            guard let record = try await details else { throw WalletError.unsupportedAsset }
            return try await Funds.asset(holder, details: record, frozen: frozen, held: held)
        }
        let result: Any
        if asset.isNative {
            result = try await rpc(chain.id, "eth_getBalance", [address, "latest"])
        } else {
            let input = "0x70a08231" + String(repeating: "0", count: 24) + address.dropFirst(2)
            result = try await rpc(
                chain.id,
                "eth_call",
                [["to": String(asset.key.dropFirst(6)), "data": input], "latest"]
            )
            guard (result as? String)?.count == 66 else { throw WalletError.network("Invalid ERC-20 balance.") }
        }
        let amount = try Self.quantity(result)
        return Funds(free: amount, total: amount, transferable: amount, minimum: 0, exists: amount > 0)
    }

    static func boundedFunds(
        timeout: Duration = .seconds(15),
        read: @escaping @Sendable () async throws -> Funds
    ) async throws -> Funds {
        // A cancelled waiter on shared runtime metadata can remain suspended until the
        // underlying decode completes. Deliver the timeout without joining that waiter.
        let (results, continuation) = AsyncThrowingStream<Funds, Error>.makeStream(bufferingPolicy: .bufferingOldest(1))
        let worker = Task {
            do {
                try continuation.yield(await read())
                continuation.finish()
            } catch { continuation.finish(throwing: error) }
        }
        let timer = Task {
            try await Task.sleep(for: timeout)
            continuation.finish(throwing: WalletError.network("Balance request timed out."))
        }
        defer {
            worker.cancel()
            timer.cancel()
            continuation.finish()
        }
        var iterator = results.makeAsyncIterator()
        guard let funds = try await iterator.next() else { throw CancellationError() }
        return funds
    }

    func balances(of walletID: WalletID, assets: [AssetID]) async -> [AssetID: Result<AssetBalance, WalletError>] {
        await withTaskGroup(of: (AssetID, Result<AssetBalance, WalletError>).self) { group in
            for id in Set(assets) {
                group.addTask {
                    do {
                        guard let token = try Catalog.chain(id.chainID).assets.first(where: { $0.key == id.key })
                        else { throw WalletError.unsupportedAsset }
                        let funds = try await Self.boundedFunds {
                            let address = try await self.store.address(of: walletID, on: id.chainID)
                            try Task.checkCancellation()
                            return try await self.funds(id, address: address)
                        }
                        return try (id, .success(AssetBalance(
                            assetID: id,
                            total: Self.amount(funds.total, decimals: token.decimals),
                            transferable: Self.amount(funds.transferable, decimals: token.decimals),
                            locked: Self.amount(funds.total - funds.transferable, decimals: token.decimals)
                        )))
                    } catch { return (id, .failure(error as? WalletError ?? .network("Could not decode the balance.")))
                    }
                }
            }
            var results: [AssetID: Result<AssetBalance, WalletError>] = [:]
            for await(id, result) in group {
                results[id] = result
            }
            return results
        }
    }
}
