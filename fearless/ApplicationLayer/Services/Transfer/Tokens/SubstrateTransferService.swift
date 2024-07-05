import Foundation
import SSFModels
import SSFExtrinsicKit
import SSFSigner
import SSFUtils
import BigInt
import SSFChainConnection

final class SubstrateTransferService: TransferServiceProtocol {
    private let extrinsicService: SSFExtrinsicKit.ExtrinsicServiceProtocol
    private let callFactory: SubstrateCallFactoryProtocol
    private let signer: TransactionSignerProtocol
    private let engine: SubstrateConnection

    init(
        extrinsicService: SSFExtrinsicKit.ExtrinsicServiceProtocol,
        callFactory: SubstrateCallFactoryProtocol,
        signer: TransactionSignerProtocol,
        engine: SubstrateConnection
    ) {
        self.extrinsicService = extrinsicService
        self.callFactory = callFactory
        self.signer = signer
        self.engine = engine
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

            if let appId = transfer.appId {
                resultBuilder = resultBuilder.with(appId: appId)
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

            if let appId = transfer.appId {
                resultBuilder = resultBuilder.with(appId: appId)
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

            if let appId = transfer.appId {
                resultBuilder = resultBuilder.with(appId: appId)
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

    func submitAndWatch(transfer: Transfer) async throws -> String {
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

            if let appId = transfer.appId {
                resultBuilder = resultBuilder.with(appId: appId)
            }

            return resultBuilder
        }

        return try await withCheckedThrowingContinuation { continuation in
            extrinsicService.submitAndWatch(extrinsicBuilderClosure, signer: signer, runningIn: .main) { result, hash in
                guard let hash = hash else { return } // TODO: show internal error
                let updateClosure: (JSONRPCSubscriptionUpdate<ExtrinsicStatus>) -> Void = { statusUpdate in
                    let state = statusUpdate.params.result
                    print("Submit and watch received status update: ", state)
                    switch state {
                    case let .finalized(block):
                        continuation.resume(with: .success(block))
                    default:
                        // Do nothing, wait until finalization
                        break
                    }
                }

                let failureClosure: (Error, Bool) -> Void = { error, _ in
                    continuation.resume(with: .failure(error))
                }
                switch result {
                case let .success(hash):
                    print("Submit and watch received hash to subscribe: ", hash)

                    let requestId = self.engine.generateRequestId()

                    let subscription = JSONRPCSubscription(
                        requestId: requestId,
                        requestData: .init(),
                        requestOptions: .init(resendOnReconnect: true),
                        updateClosure: updateClosure,
                        failureClosure: failureClosure
                    )

                    subscription.remoteId = hash
                    self.engine.addSubscription(subscription)
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }
        }
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
