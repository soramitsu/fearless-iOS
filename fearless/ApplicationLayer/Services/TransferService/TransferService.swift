import Foundation
import OrderedCollections
import Web3
import SSFModels
import SSFExtrinsicKit
import SSFSigner
import Web3ContractABI
import Web3PromiseKit
import SSFUtils

protocol TransferFeeEstimationListener: AnyObject {
    func didReceiveFee(fee: BigUInt)
    func didReceiveFeeError(feeError: Error)
}

enum TransferServiceError: Error {
    case cannotEstimateFee(String)
}

struct Transfer {
    let chainAsset: ChainAsset
    let amount: BigUInt
    let receiver: String
    let tip: BigUInt?
}

protocol TransferServiceProtocol {
    func estimateFee(for transfer: Transfer) async throws -> BigUInt
    func submit(transfer: Transfer) async throws -> String
    func subscribeForFee(transfer: Transfer, listener: TransferFeeEstimationListener)
}

class SubstrateTransferService: TransferServiceProtocol {
    private let extrinsicService: SSFExtrinsicKit.ExtrinsicServiceProtocol
    private let callFactory: SubstrateCallFactoryProtocol
    private let signer: TransactionSignerProtocol

    init(
        extrinsicService: SSFExtrinsicKit.ExtrinsicServiceProtocol,
        callFactory: SubstrateCallFactoryProtocol,
        signer: TransactionSignerProtocol
    ) {
        self.extrinsicService = extrinsicService
        self.callFactory = callFactory
        self.signer = signer
    }

    func subscribeForFee(transfer _: Transfer, listener _: TransferFeeEstimationListener) {
//        func accountId(from address: String?, chain: ChainModel) -> AccountId {
//            guard let address = address,
//                  let accountId = try? AddressFactory.accountId(from: address, chain: chain)
//            else {
//                return AddressFactory.randomAccountId(for: chain)
//            }
//
//            return accountId
//        }
//
//        let accountId = accountId(from: transfer.receiver, chain: transfer.chainAsset.chain)
//        let call = callFactory.transfer(
//            to: accountId,
//            amount: transfer.amount,
//            chainAsset: transfer.chainAsset
//        )
//        let extrinsicBuilderClosure: ExtrinsicBuilderClosure = { builder in
//            var nextBuilder = try builder.adding(call: call)
//            if let tip = transfer.tip {
//                nextBuilder = builder.with(tip: tip)
//            }
//            return nextBuilder
//        }
//
//        extrinsicService.estimateFee(extrinsicBuilderClosure, runningIn: .main) { feeResult in
//            switch feeResult {
//            case let .success(runtimeDispatchInfo):
//                listener.didReceiveFee(fee: runtimeDispatchInfo.feeValue)
//            case let .failure(error):
//                listener.didReceiveFeeError(feeError: error)
//            }
//        }
    }

    func estimateFee(for _: Transfer) async throws -> BigUInt {
        BigUInt.zero
//        func accountId(from address: String?, chain: ChainModel) -> AccountId {
//            guard let address = address,
//                  let accountId = try? AddressFactory.accountId(from: address, chain: chain)
//            else {
//                return AddressFactory.randomAccountId(for: chain)
//            }
//
//            return accountId
//        }
//
//        let accountId = accountId(from: transfer.receiver, chain: transfer.chainAsset.chain)
//        let call = callFactory.transfer(
//            to: accountId,
//            amount: transfer.amount,
//            chainAsset: transfer.chainAsset
//        )
//        let extrinsicBuilderClosure: ExtrinsicBuilderClosure = { builder in
//            var nextBuilder = try builder.adding(call: call)
//            if let tip = transfer.tip {
//                nextBuilder = builder.with(tip: tip)
//            }
//            return nextBuilder
//        }
//
//        let feeResult = try await withCheckedThrowingContinuation { continuation in
//            extrinsicService.estimateFee(
//                extrinsicBuilderClosure,
//                runningIn: .main
//            ) { result in
//                switch result {
//                case let .success(fee):
//                    continuation.resume(with: .success(fee.feeValue))
//                case let .failure(error):
//                    continuation.resume(with: .failure(error))
//                }
//            }
//        }
//
//        return feeResult
    }

    func submit(transfer: Transfer) async throws -> String {
        let accountId = try AddressFactory.accountId(from: transfer.receiver, chain: transfer.chainAsset.chain)
        let call = callFactory.transfer(
            to: accountId,
            amount: transfer.amount,
            chainAsset: transfer.chainAsset
        )
        let extrinsicBuilderClosure: ExtrinsicBuilderClosure = { builder in
            var nextBuilder = try builder.adding(call: call)
            if let tip = transfer.tip {
                nextBuilder = builder.with(tip: tip)
            }
            return nextBuilder
        }

        let submitResult = try await withCheckedThrowingContinuation { continuation in
            extrinsicService.submit(extrinsicBuilderClosure, signer: signer, runningIn: .main) { result in
                switch result {
                case let .success(hash):
                    continuation.resume(with: .success(hash))
                case let .failure(error):
                    continuation.resume(with: .failure(error))
                }
            }
        }

        return submitResult
    }
}

class EthereumTransferService: TransferServiceProtocol {
    private let eth: Web3.Eth
    private let ws: Web3.Eth
    private let privateKey: EthereumPrivateKey
    private let senderAddress: String
    private var feeSubscriptionId: UInt16?

    init(
        eth: Web3.Eth,
        ws: Web3.Eth,
        privateKey: EthereumPrivateKey,
        senderAddress: String
    ) {
        self.eth = eth
        self.ws = ws
        self.privateKey = privateKey
        self.senderAddress = senderAddress
    }

    func estimateFee(for transfer: Transfer) async throws -> BigUInt {
        if transfer.chainAsset.asset.isUtility {
            let address = try EthereumAddress(rawAddress: transfer.receiver.hexToBytes())
            let call = EthereumCall(to: address)

            let gasPrice = try await queryGasPrice()
            let gasLimit = try await queryGasLimit(call: call)
            return gasLimit.quantity * gasPrice.quantity
        } else {
            let senderAddress = try EthereumAddress(rawAddress: senderAddress.hexToBytes())
            let contractAddress = try EthereumAddress(rawAddress: transfer.chainAsset.asset.id.hexToBytes())
            let contract = eth.Contract(type: GenericERC20Contract.self, address: contractAddress)
            let transfer = contract.transfer(to: contractAddress, value: transfer.amount)
            let gasPrice = try await queryGasPrice()
            let transferGasLimit = try await queryGasLimit(from: senderAddress, amount: EthereumQuantity(quantity: BigUInt.zero), transfer: transfer)

            return gasPrice.quantity * transferGasLimit.quantity
        }
    }

    func estimateFee(for transfer: Transfer, baseFeePerGas: EthereumQuantity) async throws -> BigUInt {
        if transfer.chainAsset.asset.isUtility {
            let address = try EthereumAddress(rawAddress: transfer.receiver.hexToBytes())
            let call = EthereumCall(to: address)

            let maxPriorityFeePerGas = try await queryMaxPriorityFeePerGas()
            let gasLimit = try await queryGasLimit(call: call)
            return gasLimit.quantity * (baseFeePerGas.quantity + maxPriorityFeePerGas.quantity)
        } else {
            let senderAddress = try EthereumAddress(rawAddress: senderAddress.hexToBytes())
            let contractAddress = try EthereumAddress(rawAddress: transfer.chainAsset.asset.id.hexToBytes())
            let contract = eth.Contract(type: GenericERC20Contract.self, address: contractAddress)
            let transfer = contract.transfer(to: contractAddress, value: transfer.amount)
            let maxPriorityFeePerGas = try await queryMaxPriorityFeePerGas()
            let transferGasLimit = try await queryGasLimit(from: senderAddress, amount: EthereumQuantity(quantity: BigUInt.zero), transfer: transfer)

            return (maxPriorityFeePerGas.quantity + baseFeePerGas.quantity) * transferGasLimit.quantity
        }
    }

    func subscribeForFee(transfer: Transfer, listener: TransferFeeEstimationListener) {
        do {
            try ws.subscribeToNewHeads(subscribed: {
                _ in
                print("sub")
            }, onEvent: { result in
                if let blockObject = result.result {
                    self.handle(newHead: blockObject, listener: listener, transfer: transfer)
                } else if let error = result.error {
                    listener.didReceiveFeeError(feeError: error)
                } else {
                    listener.didReceiveFeeError(feeError: TransferServiceError.cannotEstimateFee("unexpected new block head response"))
                }
            })
        } catch {
            listener.didReceiveFeeError(feeError: error)
        }
    }

    private func handle(newHead: EthereumBlockObject, listener: TransferFeeEstimationListener, transfer: Transfer) {
        print("Block transactions: \(newHead.transactions?.compactMap { ($0.object?.from, $0.object?.to) })")
        guard let baseFeePerGas = newHead.baseFeePerGas else {
            listener.didReceiveFeeError(feeError: TransferServiceError.cannotEstimateFee("unexpected new block head response"))
            return
        }

        Task {
            let fee = try await estimateFee(for: transfer, baseFeePerGas: baseFeePerGas)
            listener.didReceiveFee(fee: fee)
        }
    }

    func submit(transfer: Transfer) async throws -> String {
        transfer.chainAsset.asset.isUtility ? try await transferNative(transfer: transfer) : try await transferERC20(transfer: transfer)
    }

    // MARK: Transfers

    private func transferNative(transfer: Transfer) async throws -> String {
        guard let chainIdValue = BigUInt(string: transfer.chainAsset.chain.chainId) else {
            throw EthereumSignedTransaction.Error.chainIdNotSet(msg: "EIP1559 transactions need a chainId")
        }

        let receiverAddress = try EthereumAddress(rawAddress: transfer.receiver.hexToBytes())
        let senderAddress = try EthereumAddress(rawAddress: self.senderAddress.hexToBytes())
        let quantity = EthereumQuantity(quantity: transfer.amount)

        let call = EthereumCall(to: receiverAddress, value: quantity)
        let nonce = try await queryNonce(ethereumAddress: senderAddress)
        let gasPrice = try await queryGasPrice()
        let gasLimit = try await queryGasLimit(call: call)
        let tx = EthereumTransaction(
            nonce: nonce,
            gasPrice: gasPrice,
            maxFeePerGas: gasPrice,
            maxPriorityFeePerGas: gasPrice,
            gasLimit: gasLimit,
            from: senderAddress,
            to: receiverAddress,
            value: quantity,
            accessList: [:],
            transactionType: .eip1559
        )

        let rawTransaction = try tx.sign(with: privateKey, chainId: EthereumQuantity(quantity: chainIdValue))

        let result = try await withCheckedThrowingContinuation { continuation in
            do {
                try eth.sendRawTransaction(transaction: rawTransaction) { resp in
                    if let hash = resp.result {
                        continuation.resume(with: .success(hash))
                    } else if let error = resp.error {
                        continuation.resume(with: .failure(error))
                    }
                }
            } catch {
                continuation.resume(with: .failure(error))
            }
        }

        return result.hex()
    }

    private func transferERC20(transfer: Transfer) async throws -> String {
        guard let chainIdValue = BigUInt(string: transfer.chainAsset.chain.chainId) else {
            throw EthereumSignedTransaction.Error.chainIdNotSet(msg: "EIP1559 transactions need a chainId")
        }
        let senderAddress = try EthereumAddress(rawAddress: self.senderAddress.hexToBytes())
        let address = try EthereumAddress(rawAddress: transfer.receiver.hexToBytes())
        let contractAddress = try EthereumAddress(rawAddress: transfer.chainAsset.asset.id.hexToBytes())
        let contract = eth.Contract(type: GenericERC20Contract.self, address: contractAddress)
        let transferCall = contract.transfer(to: address, value: transfer.amount)
        let nonce = try await queryNonce(ethereumAddress: senderAddress)
        let gasPrice = try await queryGasPrice()
        let transferGasLimit = EthereumQuantity(quantity: 500_000)

        guard let transferData = transferCall.encodeABI() else {
            throw ConvenienceError(error: "Cannot create ERC20 transfer transaction")
        }

        let tx = EthereumTransaction(
            nonce: nonce,
            gasPrice: gasPrice,
            maxFeePerGas: gasPrice,
            maxPriorityFeePerGas: gasPrice,
            gasLimit: transferGasLimit,
            from: senderAddress,
            to: contractAddress,
            value: EthereumQuantity(quantity: BigUInt.zero),
            data: transferData,
            accessList: [:],
            transactionType: .eip1559
        )

        let rawTransaction = try tx.sign(with: privateKey, chainId: EthereumQuantity(quantity: chainIdValue))

        let result = try await withCheckedThrowingContinuation { continuation in
            do {
                try eth.sendRawTransaction(transaction: rawTransaction) { resp in
                    if let hash = resp.result {
                        continuation.resume(with: .success(hash))
                    } else if let error = resp.error {
                        continuation.resume(with: .failure(error))
                    }
                }
            } catch {
                continuation.resume(with: .failure(error))
            }
        }

        return result.hex()
    }

    // MARK: Fee

    private func queryGasLimit(call: EthereumCall) async throws -> EthereumQuantity {
        let gasLimit = try await withCheckedThrowingContinuation { continuation in
            eth.estimateGas(call: call) { resp in
                if let limit = resp.result {
                    continuation.resume(with: .success(limit))
                } else if let error = resp.error {
                    continuation.resume(with: .failure(error))
                }
            }
        }

        return gasLimit
    }

    private func queryGasLimit(from: EthereumAddress?, amount: EthereumQuantity?, transfer: SolidityInvocation) async throws -> EthereumQuantity {
        try await withCheckedThrowingContinuation { continuation in
            transfer.estimateGas(from: from, gas: 50000, value: amount) { quantity, error in
                if let gas = quantity {
                    return continuation.resume(with: .success(gas))
                } else if let error = error {
                    return continuation.resume(with: .failure(error))
                } else {
                    return continuation.resume(with: .success(EthereumQuantity(quantity: .zero)))
                }
            }
        }
    }

    private func queryGasPrice() async throws -> EthereumQuantity {
        let gasPrice = try await withCheckedThrowingContinuation { continuation in
            eth.gasPrice { resp in
                if let price = resp.result {
                    continuation.resume(with: .success(price))
                } else if let error = resp.error {
                    continuation.resume(with: .failure(error))
                }
            }
        }

        return gasPrice
    }

    private func queryMaxPriorityFeePerGas() async throws -> EthereumQuantity {
        let gasPrice = try await withCheckedThrowingContinuation { continuation in
            eth.maxPriorityFeePerGas { resp in
                if let fee = resp.result {
                    continuation.resume(with: .success(fee))
                } else if let error = resp.error {
                    continuation.resume(with: .failure(error))
                }
            }
        }

        return gasPrice
    }

    // MARK: Additional

    private func queryNonce(ethereumAddress: EthereumAddress) async throws -> EthereumQuantity {
        let nonce = try await withCheckedThrowingContinuation { continuation in
            eth.getTransactionCount(address: ethereumAddress, block: .pending) { resp in
                if let nonce = resp.result {
                    continuation.resume(with: .success(nonce))
                } else if let error = resp.error {
                    continuation.resume(with: .failure(error))
                }
            }
        }

        return nonce
    }
}
