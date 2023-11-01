import Foundation
import SSFModels
import SSFExtrinsicKit
import SSFSigner
import SSFUtils
import BigInt

final class SubstrateTransferService: TransferServiceProtocol {
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

    func subscribeForFee(transfer: Transfer, listener: TransferFeeEstimationListener) {
        func accountId(from address: String?, chain: ChainModel) -> AccountId {
            guard let address = address,
                  let accountId = try? AddressFactory.accountId(from: address, chain: chain)
            else {
                return AddressFactory.randomAccountId(for: chain)
            }

            return accountId
        }

        let accountId = accountId(from: transfer.receiver, chain: transfer.chainAsset.chain)
        let call = callFactory.transfer(
            to: accountId,
            amount: transfer.amount,
            chainAsset: transfer.chainAsset
        )

        let extrinsicBuilderClosure: ExtrinsicBuilderClosure = { builder in
            var resultBuilder = builder
            resultBuilder = try builder.adding(call: call)

            if let tip = transfer.tip {
                resultBuilder = resultBuilder.with(tip: tip)
            }
            return resultBuilder
        }

        extrinsicService.estimateFee(extrinsicBuilderClosure, runningIn: .main) { feeResult in
            switch feeResult {
            case let .success(runtimeDispatchInfo):
                listener.didReceiveFee(fee: runtimeDispatchInfo.feeValue)
            case let .failure(error):
                listener.didReceiveFeeError(feeError: error)
            }
        }
    }

    func estimateFee(for transfer: Transfer) async throws -> BigUInt {
        func accountId(from address: String?, chain: ChainModel) -> AccountId {
            guard let address = address,
                  let accountId = try? AddressFactory.accountId(from: address, chain: chain)
            else {
                return AddressFactory.randomAccountId(for: chain)
            }

            return accountId
        }

        let accountId = accountId(from: transfer.receiver, chain: transfer.chainAsset.chain)
        let call = callFactory.transfer(
            to: accountId,
            amount: transfer.amount,
            chainAsset: transfer.chainAsset
        )

        let extrinsicBuilderClosure: ExtrinsicBuilderClosure = { builder in
            var resultBuilder = builder
            resultBuilder = try builder.adding(call: call)

            if let tip = transfer.tip {
                resultBuilder = resultBuilder.with(tip: tip)
            }
            return resultBuilder
        }

        let feeResult = try await withCheckedThrowingContinuation { continuation in
            extrinsicService.estimateFee(
                extrinsicBuilderClosure,
                runningIn: .main
            ) { result in
                switch result {
                case let .success(fee):
                    continuation.resume(with: .success(fee.feeValue))
                case let .failure(error):
                    continuation.resume(with: .failure(error))
                }
            }
        }

        return feeResult
    }

    func submit(transfer: Transfer) async throws -> String {
        let accountId = try AddressFactory.accountId(from: transfer.receiver, chain: transfer.chainAsset.chain)
        let call = callFactory.transfer(
            to: accountId,
            amount: transfer.amount,
            chainAsset: transfer.chainAsset
        )

        let extrinsicBuilderClosure: ExtrinsicBuilderClosure = { builder in
            var resultBuilder = builder
            resultBuilder = try builder.adding(call: call)

            if let tip = transfer.tip {
                resultBuilder = resultBuilder.with(tip: tip)
            }
            return resultBuilder
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

    func unsubscribe() {}
}

extension SubstrateTransferService {
    func estimateFee(for transfer: XorlessTransfer) async throws -> BigUInt {
        let call = callFactory.xorlessTransfer(transfer)

        let extrinsicBuilderClosure: ExtrinsicBuilderClosure = { builder in
            var resultBuilder = builder
            resultBuilder = try builder.adding(call: call)
            return resultBuilder
        }

        let feeResult = try await withCheckedThrowingContinuation { continuation in
            extrinsicService.estimateFee(
                extrinsicBuilderClosure,
                runningIn: .main
            ) { result in
                switch result {
                case let .success(fee):
                    continuation.resume(with: .success(fee.feeValue))
                case let .failure(error):
                    continuation.resume(with: .failure(error))
                }
            }
        }

        return feeResult
    }

    func submit(transfer: XorlessTransfer) async throws -> String {
        let call = callFactory.xorlessTransfer(transfer)

        let extrinsicBuilderClosure: ExtrinsicBuilderClosure = { builder in
            var resultBuilder = builder
            resultBuilder = try builder.adding(call: call)
            return resultBuilder
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
