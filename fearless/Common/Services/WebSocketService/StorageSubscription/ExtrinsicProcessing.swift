import Foundation
import FearlessUtils
import BigInt

struct ExtrinsicProcessingResult {
    let extrinsic: Extrinsic
    let callPath: CallCodingPath
    let fee: BigUInt?
    let peerId: AccountId?
    let isSuccess: Bool
}

protocol ExtrinsicProcessing {
    func process(
        extrinsicIndex: UInt32,
        extrinsicData: Data,
        eventRecords: [EventRecord],
        coderFactory: RuntimeCoderFactoryProtocol
    ) -> ExtrinsicProcessingResult?
}

final class ExtrinsicProcessor {
    let accountId: Data

    init(accountId: Data) {
        self.accountId = accountId
    }

    private func matchStatus(
        for index: UInt32,
        eventRecords: [EventRecord],
        metadata: RuntimeMetadata
    ) -> Bool? {
        eventRecords.filter { record in
            guard record.extrinsicIndex == index,
                  let eventPath = metadata.createEventCodingPath(from: record.event) else {
                return false
            }

            return [.extrisicSuccess, .extrinsicFailed].contains(eventPath)
        }.first.map { metadata.createEventCodingPath(from: $0.event) == .extrisicSuccess }
    }

    private func findFee(
        for index: UInt32,
        eventRecords: [EventRecord],
        metadata: RuntimeMetadata
    ) -> BigUInt {
        eventRecords.compactMap { record in
            guard record.extrinsicIndex == index,
                  let eventPath = metadata.createEventCodingPath(from: record.event) else {
                return nil
            }

            if eventPath == .balanceDeposit {
                return try? record.event.params.map(to: BalanceDepositEvent.self).amount
            }

            if eventPath == .treasuryDeposit {
                return try? record.event.params.map(to: TreasuryDepositEvent.self).amount
            }

            return nil
        }.reduce(BigUInt(0)) { (totalFee: BigUInt, partialFee: BigUInt) in
            totalFee + partialFee
        }
    }

    private func matchTransfer(
        extrinsicIndex: UInt32,
        extrinsic: Extrinsic,
        eventRecords: [EventRecord],
        metadata: RuntimeMetadata
    ) -> ExtrinsicProcessingResult? {
        do {
            let sender = try extrinsic.signature?.address.map(to: MultiAddress.self).accountId
            let call = try extrinsic.call.map(to: RuntimeCall<TransferCall>.self)
            let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)
            let isAccountMatched = accountId == sender || accountId == call.args.dest.accountId

            guard
                callPath.isTransfer,
                isAccountMatched,
                let isSuccess = matchStatus(
                    for: extrinsicIndex,
                    eventRecords: eventRecords,
                    metadata: metadata
                ) else {
                return nil
            }

            let fee = findFee(
                for: extrinsicIndex,
                eventRecords: eventRecords,
                metadata: metadata
            )

            let peerId = accountId == sender ? call.args.dest.accountId : sender

            return ExtrinsicProcessingResult(
                extrinsic: extrinsic,
                callPath: callPath,
                fee: fee,
                peerId: peerId,
                isSuccess: isSuccess
            )

        } catch {
            return nil
        }
    }

    private func matchExtrinsic(
        extrinsicIndex: UInt32,
        extrinsic: Extrinsic,
        eventRecords: [EventRecord],
        metadata: RuntimeMetadata
    ) -> ExtrinsicProcessingResult? {
        do {
            let sender = try extrinsic.signature?.address.map(to: MultiAddress.self).accountId
            let call = try extrinsic.call.map(to: RuntimeCall<NoRuntimeArgs>.self)
            let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)
            let isAccountMatched = accountId == sender

            guard
                isAccountMatched,
                let isSuccess = matchStatus(
                    for: extrinsicIndex,
                    eventRecords: eventRecords,
                    metadata: metadata
                ) else {
                return nil
            }

            let fee = findFee(
                for: extrinsicIndex,
                eventRecords: eventRecords,
                metadata: metadata
            )

            return ExtrinsicProcessingResult(
                extrinsic: extrinsic,
                callPath: callPath,
                fee: fee,
                peerId: nil,
                isSuccess: isSuccess
            )

        } catch {
            return nil
        }
    }
}

extension ExtrinsicProcessor: ExtrinsicProcessing {
    func process(
        extrinsicIndex: UInt32,
        extrinsicData: Data,
        eventRecords: [EventRecord],
        coderFactory: RuntimeCoderFactoryProtocol
    ) -> ExtrinsicProcessingResult? {
        do {
            let decoder = try coderFactory.createDecoder(from: extrinsicData)
            let extrinsic: Extrinsic = try decoder.read(of: GenericType.extrinsic.name)

            if let processingResult = matchTransfer(
                extrinsicIndex: extrinsicIndex,
                extrinsic: extrinsic,
                eventRecords: eventRecords,
                metadata: coderFactory.metadata
            ) {
                return processingResult
            }

            return matchExtrinsic(
                extrinsicIndex: extrinsicIndex,
                extrinsic: extrinsic,
                eventRecords: eventRecords,
                metadata: coderFactory.metadata
            )
        } catch {
            return nil
        }
    }
}
