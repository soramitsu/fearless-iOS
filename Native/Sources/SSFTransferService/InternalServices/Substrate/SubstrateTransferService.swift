import BigInt
import Foundation
import SSFCrypto
import SSFExtrinsicKit
import SSFModels
import SSFSigner
import SSFUtils

protocol SubstrateTransferService {
    func submit(transfer: SubstrateTransfer, chainAsset: ChainAsset) async throws -> String
    func submit(transfer: XorlessTransfer, chainAsset: ChainAsset) async throws -> String

    func estimateFee(for transfer: SubstrateTransfer, chainAsset: ChainAsset)
        -> AsyncThrowingStream<BigUInt, Error>
    func estimateFee(for transfer: XorlessTransfer, chainAsset: ChainAsset)
        -> AsyncThrowingStream<BigUInt, Error>
}

final class SubstrateTransferServiceDefault: SubstrateTransferService {
    private let extrinsicService: ExtrinsicServiceProtocol
    private let callFactory: SubstrateTransferCallFactory
    private let signer: TransactionSignerProtocol

    init(
        extrinsicService: ExtrinsicServiceProtocol,
        callFactory: SubstrateTransferCallFactory,
        signer: TransactionSignerProtocol
    ) {
        self.extrinsicService = extrinsicService
        self.callFactory = callFactory
        self.signer = signer
    }

    // MARK: - SubstrateTransferService

    func submit(
        transfer: SubstrateTransfer,
        chainAsset: ChainAsset
    ) async throws -> String {
        let accountId = try AddressFactory.accountId(
            from: transfer.receiver,
            chain: chainAsset.chain
        )
        let call = callFactory.transfer(
            to: accountId,
            amount: transfer.amount,
            chainAsset: chainAsset
        )

        let extrinsicBuilderClosure = buildExtrinsicClosure(
            call: call,
            tip: transfer.tip
        )

        return try await submit(extrinsicBuilderClosure)
    }

    func submit(
        transfer: XorlessTransfer,
        chainAsset _: ChainAsset
    ) async throws -> String {
        let call = callFactory.xorlessTransfer(transfer)

        let extrinsicBuilderClosure = buildExtrinsicClosure(
            call: call,
            tip: nil
        )

        return try await submit(extrinsicBuilderClosure)
    }

    func estimateFee(
        for transfer: SubstrateTransfer,
        chainAsset: ChainAsset
    ) -> AsyncThrowingStream<BigUInt, Error> {
        func accountId(from address: String?, chain: ChainModel) -> AccountId {
            guard let address = address,
                  let accountId = try? AddressFactory.accountId(from: address, chain: chain) else
            {
                return AddressFactory.randomAccountId(for: chain.chainFormat)
            }

            return accountId
        }

        let accountId = accountId(from: transfer.receiver, chain: chainAsset.chain)
        let call = callFactory.transfer(
            to: accountId,
            amount: transfer.amount,
            chainAsset: chainAsset
        )

        let extrinsicBuilderClosure = buildExtrinsicClosure(
            call: call,
            tip: transfer.tip
        )

        return estimateFee(for: extrinsicBuilderClosure)
    }

    func estimateFee(
        for transfer: XorlessTransfer,
        chainAsset _: ChainAsset
    ) -> AsyncThrowingStream<BigUInt, Error> {
        let call = callFactory.xorlessTransfer(transfer)

        let extrinsicBuilderClosure = buildExtrinsicClosure(
            call: call,
            tip: nil
        )

        return estimateFee(for: extrinsicBuilderClosure)
    }

    // MARK: - Private methods

    private func submit(
        _ extrinsicBuilderClosure: @escaping ExtrinsicBuilderClosure
    ) async throws -> String {
        try await withUnsafeThrowingContinuation { continuation in
            extrinsicService.submit(
                extrinsicBuilderClosure,
                signer: self.signer,
                runningIn: .global()
            ) { result in
                switch result {
                case let .success(hash):
                    continuation.resume(returning: hash)
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func estimateFee(
        for extrinsicBuilderClosure: @escaping ExtrinsicBuilderClosure
    ) -> AsyncThrowingStream<BigUInt, Error> {
        AsyncThrowingStream { continuation in
            extrinsicService.estimateFee(
                extrinsicBuilderClosure,
                runningIn: .global()
            ) { result in
                switch result {
                case let .success(fee):
                    continuation.yield(fee.feeValue)
                    continuation.finish()
                case let .failure(error):
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func buildExtrinsicClosure(
        call: any RuntimeCallable,
        tip: BigUInt?
    ) -> ExtrinsicBuilderClosure {
        let extrinsicBuilderClosure: ExtrinsicBuilderClosure = { builder in
            var resultBuilder = builder
            resultBuilder = try builder.adding(call: call)

            if let tip = tip {
                resultBuilder = resultBuilder.with(tip: tip)
            }
            return resultBuilder
        }
        return extrinsicBuilderClosure
    }
}
