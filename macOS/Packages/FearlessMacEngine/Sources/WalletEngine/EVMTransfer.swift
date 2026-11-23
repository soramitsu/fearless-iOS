import BigInt
import Foundation
import SSFModels
import Web3
import WalletCore

struct EVMTransfer {
    let chain: UInt64
    var nonce: BigUInt
    let gas, feeCap: BigUInt
    let priority: BigUInt?
    let to: Data
    let value: BigUInt
    let input: Data

    var cost: BigUInt {
        gas * feeCap
    }

    // Bounds for the catalog's native transfers and ERC-20 transfer(address,uint256).
    static let maximumGas: BigUInt = 2_000_000
    static let maximumPrice: BigUInt = 10_000_000_000_000 // 10,000 gwei per gas

    static func gasLimit(estimate: BigUInt, hasData: Bool) throws -> BigUInt {
        guard estimate >= 21000, estimate <= maximumGas else {
            throw WalletError.network("Implausible gas estimate.")
        }
        let limit = hasData ? (estimate * 5 + 3) / 4 : estimate
        guard limit <= maximumGas else { throw WalletError.network("Gas limit exceeds the transfer bound.") }
        return limit
    }

    static func validatePrice(_ price: BigUInt) throws {
        guard price > 0, price <= maximumPrice else { throw WalletError.network("Implausible gas price.") }
    }

    func encode(signature: Data? = nil) throws -> Data {
        var fields: [RLPItem] = [.bigUInt(nonce)]
        if let priority {
            fields = [.bigUInt(BigUInt(chain)), .bigUInt(nonce), .bigUInt(priority)]
        }
        fields += [.bigUInt(feeCap), .bigUInt(gas), .bytes(Array(to)), .bigUInt(value), .bytes(Array(input))]
        if priority != nil {
            fields.append(.array([]))
        }
        if let signature {
            guard signature.count == 65, let parity = signature.last,
                  parity <= 1 else { throw WalletError.transferRejected("Invalid signature.") }
            let recoveryValue = priority == nil ? BigUInt(chain) * 2 + 35 + BigUInt(parity) : BigUInt(parity)
            fields += [
                .bigUInt(recoveryValue),
                .bigUInt(BigUInt(signature.prefix(32))),
                .bigUInt(BigUInt(signature.dropFirst(32).prefix(32)))
            ]
        } else if priority == nil {
            fields += [.bigUInt(BigUInt(chain)), 0, 0]
        }
        let prefix = priority == nil ? Data() : Data([2])
        return try prefix + Data(RLPEncoder().encode(.array(fields)))
    }
}

extension NetworkServices {
    func evmQuote(
        _ request: TransferRequest,
        chain: Catalog.Network,
        sender: String,
        amount: BigUInt
    ) async throws -> EVMTransfer {
        guard let id = chain.evmID, amount.bitWidth <= 256 else { throw WalletError.unsupportedAsset }
        let native = request.assetID.isNative
        let target = native ? request.recipient : String(request.assetID.key.dropFirst(6))
        var input = Data()
        if !native {
            input = Data([0xA9, 0x05, 0x9C, 0xBB]) + Data(repeating: 0, count: 12)
            input += try Data(hexStringSSF: request.recipient)
            let bytes = amount.serialize()
            input += Data(repeating: 0, count: 32 - bytes.count) + bytes
        }
        let value = native ? amount : 0
        let tx = [
            "from": sender,
            "to": target,
            "value": "0x" + String(value, radix: 16),
            "data": input.toHex(includePrefix: true)
        ]
        async let nonce = Self.quantity(rpc(chain.id, "eth_getTransactionCount", [sender, "pending"]))
        async let gas = Self.quantity(rpc(chain.id, "eth_estimateGas", [tx]))
        let feeCap: BigUInt
        let priority: BigUInt?
        let block = try await rpc(chain.id, "eth_getBlockByNumber", ["latest", false]) as? [String: Any]
        if id != 56 {
            guard let base = block?["baseFeePerGas"] else { throw WalletError.network("Missing EIP-1559 base fee.") }
            let tip = try await Self.quantity(rpc(chain.id, "eth_maxPriorityFeePerGas"))
            priority = tip
            feeCap = try 2 * Self.quantity(base) + tip
        } else {
            priority = nil
            feeCap = try await Self.quantity(rpc(chain.id, "eth_gasPrice"))
        }
        try EVMTransfer.validatePrice(feeCap)
        return try await EVMTransfer(
            chain: id,
            nonce: nonce,
            gas: EVMTransfer.gasLimit(estimate: gas, hasData: !input.isEmpty),
            feeCap: feeCap,
            priority: priority,
            to: Data(hexStringSSF: target),
            value: value,
            input: input
        )
    }

    func refresh(_ reviewed: EVMTransfer, chain: ChainID, sender: String) async throws -> EVMTransfer {
        if let tip = reviewed.priority {
            guard let block = try await rpc(chain, "eth_getBlockByNumber", ["latest", false]) as? [String: Any],
                  let base = block["baseFeePerGas"] else { throw WalletError.network("Missing current base fee.") }
            guard try Self.quantity(base) + tip <= reviewed.feeCap else {
                throw WalletError.transferRejected("Base fee plus the reviewed tip exceeds the fee cap. Review again.")
            }
        }
        var tx = reviewed
        tx.nonce = try await Self.quantity(rpc(chain, "eth_getTransactionCount", [sender, "pending"]))
        return tx
    }
}
