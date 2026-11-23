import Foundation
import IrohaCrypto
import WalletCore

extension NetworkServices {
    func reconcileAfterUnlock() async {
        guard let records = try? await store.localTransfers() else { return }
        await reconcile(records)
    }

    func reconcile(_ records: [LocalTransfer]) async {
        for record in records where record.item.status == .pending && record.mortality?.exhausted != true {
            guard !Task.isCancelled else { return }
            let item = record.item
            do {
                let chain = try Catalog.chain(item.assetID.chainID)
                if chain.evmID != nil {
                    if case let .confirmed(fee) = try await receipt(item, chain: chain, included: { _ in }) {
                        try await store.update(item, status: .success, actualFee: fee)
                    }
                } else if let mortality = record.mortality {
                    try await reconcileMortal(item, chain: chain, mortality: mortality)
                } else if let hash = item.hash {
                    // Older versions persisted only the extrinsic hash. Query it directly where an indexer exists.
                    let address = try await store.address(of: item.walletID, on: chain.id)
                    let rows = try await history(chain, wallet: item.walletID, address: address, hash: hash)
                    if let row = rows.first(where: {
                        $0.hash?.lowercased() == hash.lowercased() && $0.direction == item.direction &&
                            $0.amount == item.amount && $0.assetID == item.assetID && $0.counterparty == item.counterparty
                    }) {
                        try await store.update(item, status: row.status, actualFee: row.fee)
                    }
                }
            } catch WalletError.transferRejected {
                _ = try? await store.update(item, status: .failed)
            } catch { /* Retain pending and retry when activity is next requested. */ }
        }
    }

    private func reconcileMortal(_ item: ActivityItem, chain: Catalog.Network, mortality: MortalTransfer) async throws {
        guard let hash = item.hash, let prefix = chain.prefix, mortality.birth <= UInt64.max - 64 else { return }
        let head = try await blockHash(chain.id)
        guard let header = try await rpc(chain.id, "chain_getHeader", [head]) as? [String: Any],
              let number = header["number"], let height = try UInt64(exactly: Self.quantity(number)) else { return }
        let expired = height >= mortality.birth + 64
        if !expired {
            let address = try await store.address(of: item.walletID, on: chain.id)
            let key = try SS58AddressFactory().accountId(fromAddress: address, type: prefix)
            let rt = try await runtime(chain.id, block: head)
            guard let account = try await value(rt, chain.id, block: head, module: "System", name: "Account", keys: [key]),
                  try SubstrateRuntime.number(account["nonce"]) > mortality.nonce else { return }
        }
        // Only search finalized blocks that could contain this signed era. Checkpoint complete batches.
        let last = min(height, mortality.birth + 63)
        var cursor = mortality.nextHeight ?? mortality.birth
        while cursor <= last {
            try Task.checkCancellation()
            let end = cursor + min(3, last - cursor)
            let match = try await withThrowingTaskGroup(of: (String, String, Int)?.self) { group in
                for number in cursor ... end {
                    group.addTask {
                        guard let block = try await self.rpc(chain.id, "chain_getBlockHash", [number]) as? String else {
                            throw WalletError.network("Finalized block unavailable.")
                        }
                        let (parent, calls) = try await self.finalizedBody(chain.id, block: block)
                        return try Self.extrinsicIndex(hash, in: calls).map { (block, parent, $0) }
                    }
                }
                for try await found in group {
                    if let found {
                        group.cancelAll(); return found as (String, String, Int)?
                    }
                }
                return nil
            }
            if let (block, parent, index) = match {
                try await dispatch(chain.id, block: block, parent: parent, index: index)
                try await store.update(item, status: .success)
                return
            }
            cursor = end + 1
            var checkpoint = mortality
            checkpoint.nextHeight = cursor
            checkpoint.exhausted = cursor == mortality.birth + 64
            try await store.update(item, status: .pending, scanned: checkpoint)
        }
    }
}
