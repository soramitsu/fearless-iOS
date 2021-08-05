import Foundation
import RobinHood
import FearlessUtils
import BigInt

final class MortalEraOperationFactory {
    static let fallbackMaxHashCount: BlockNumber = 250
    static let maxFinalityLag: BlockNumber = 5
    static let fallbackPeriod: Moment = 6 * 1000
    static let mortalPeriod: UInt64 = 5 * 60 * 1000

    private func createFinalizedHeaderOperation(
        from connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<Block.Header> {
        let finalizedBlockHashOperation: JSONRPCListOperation<String> = JSONRPCListOperation(
            engine: connection,
            method: RPCMethod.getFinalizedBlockHash
        )

        let finalizedHeaderOperation: JSONRPCListOperation<Block.Header> = JSONRPCListOperation(
            engine: connection,
            method: RPCMethod.getBlockHeader
        )

        finalizedHeaderOperation.configurationBlock = {
            do {
                let blockHash = try finalizedBlockHashOperation.extractNoCancellableResultData()
                finalizedHeaderOperation.parameters = [blockHash]
            } catch {
                finalizedHeaderOperation.result = .failure(error)
            }
        }

        finalizedHeaderOperation.addDependency(finalizedBlockHashOperation)

        return CompoundOperationWrapper(
            targetOperation: finalizedHeaderOperation,
            dependencies: [finalizedBlockHashOperation]
        )
    }

    private func createBestHeaderOperation(
        from connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<Block.Header> {
        let currentHeaderOperation: JSONRPCListOperation<Block.Header> = JSONRPCListOperation(
            engine: connection,
            method: RPCMethod.getBlockHeader
        )

        let bestHeaderOperation: JSONRPCListOperation<Block.Header> = JSONRPCListOperation(
            engine: connection,
            method: RPCMethod.getBlockHeader
        )

        bestHeaderOperation.configurationBlock = {
            do {
                let header = try currentHeaderOperation.extractNoCancellableResultData()

                if !header.parentHash.isEmpty {
                    bestHeaderOperation.parameters = [header.parentHash]
                } else {
                    bestHeaderOperation.result = .success(header)
                }
            } catch {
                bestHeaderOperation.result = .failure(error)
            }
        }

        bestHeaderOperation.addDependency(currentHeaderOperation)

        return CompoundOperationWrapper(
            targetOperation: bestHeaderOperation,
            dependencies: [currentHeaderOperation]
        )
    }

    private func createBlockNumberOperation(
        from connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<BlockNumber> {
        let finalizedHeaderWrapper = createFinalizedHeaderOperation(from: connection)
        let bestHeaderWrapper = createBestHeaderOperation(from: connection)

        let mapOperation = ClosureOperation<BlockNumber> {
            let finalizedHeader = try finalizedHeaderWrapper.targetOperation
                .extractNoCancellableResultData()
            let bestHeader = try bestHeaderWrapper.targetOperation.extractNoCancellableResultData()

            guard
                let bestNumber = BigUInt.fromHexString(bestHeader.number),
                let finalizedNumber = BigUInt.fromHexString(finalizedHeader.number) else {
                throw BaseOperationError.unexpectedDependentResult
            }

            let blockNumber = bestNumber - finalizedNumber > Self.maxFinalityLag ? bestNumber : finalizedNumber

            return BlockNumber(blockNumber)
        }

        mapOperation.addDependency(finalizedHeaderWrapper.targetOperation)
        mapOperation.addDependency(bestHeaderWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: finalizedHeaderWrapper.allOperations + bestHeaderWrapper.allOperations
        )
    }

    private func createBlockTimeOperation(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<Moment> {
        let expectedBlockTimeOperation = PrimitiveConstantOperation<Moment>(path: .babeBlockTime)
        expectedBlockTimeOperation.configurationBlock = {
            do {
                expectedBlockTimeOperation.codingFactory = try codingFactoryOperation
                    .extractNoCancellableResultData()
            } catch {
                expectedBlockTimeOperation.result = .failure(error)
            }
        }

        let minimumPeriodOperation = PrimitiveConstantOperation<Moment>(path: .minimumPeriodBetweenBlocks)
        minimumPeriodOperation.configurationBlock = {
            do {
                minimumPeriodOperation.codingFactory = try codingFactoryOperation
                    .extractNoCancellableResultData()
            } catch {
                minimumPeriodOperation.result = .failure(error)
            }
        }

        let mapOperation = ClosureOperation<Moment> {
            let expectedBlockTime = try? expectedBlockTimeOperation.extractNoCancellableResultData()
            let minimumPeriod = try? minimumPeriodOperation.extractNoCancellableResultData()

            return (expectedBlockTime ?? minimumPeriod) ?? Moment(Self.fallbackPeriod)
        }

        mapOperation.addDependency(expectedBlockTimeOperation)
        mapOperation.addDependency(minimumPeriodOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [expectedBlockTimeOperation, minimumPeriodOperation]
        )
    }

    private func createBlockHashCountOperation(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<BlockNumber> {
        let blockHashCountOperation = PrimitiveConstantOperation<BlockNumber>(path: .blockHashCount)
        blockHashCountOperation.configurationBlock = {
            do {
                blockHashCountOperation.codingFactory = try codingFactoryOperation
                    .extractNoCancellableResultData()
            } catch {
                blockHashCountOperation.result = .failure(error)
            }
        }

        let mapOperation = ClosureOperation<BlockNumber> {
            let blockHashCount = try? blockHashCountOperation.extractNoCancellableResultData()

            return blockHashCount ?? BlockNumber(Self.fallbackMaxHashCount)
        }

        mapOperation.addDependency(blockHashCountOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [blockHashCountOperation]
        )
    }

    private func createMortalLengthOperation(
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<UInt64> {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let blockHashCountWrapper = createBlockHashCountOperation(
            dependingOn: codingFactoryOperation
        )

        let blockTimeWrapper = createBlockTimeOperation(
            dependingOn: codingFactoryOperation
        )

        blockHashCountWrapper.addDependency(operations: [codingFactoryOperation])
        blockTimeWrapper.addDependency(operations: [codingFactoryOperation])

        let mapper = ClosureOperation<UInt64> {
            let blockTime = try blockTimeWrapper.targetOperation.extractNoCancellableResultData()
            let blockHashCount = try blockHashCountWrapper.targetOperation
                .extractNoCancellableResultData()

            guard blockTime > 0 else {
                throw BaseOperationError.unexpectedDependentResult
            }

            let unmappedPeriod = (Self.mortalPeriod / UInt64(blockTime)) + UInt64(Self.maxFinalityLag)

            return min(UInt64(blockHashCount), unmappedPeriod)
        }

        mapper.addDependency(blockHashCountWrapper.targetOperation)
        mapper.addDependency(blockTimeWrapper.targetOperation)

        let dependencies = [codingFactoryOperation] + blockHashCountWrapper.allOperations +
            blockTimeWrapper.allOperations

        return CompoundOperationWrapper(
            targetOperation: mapper,
            dependencies: dependencies
        )
    }
}

extension MortalEraOperationFactory: ExtrinsicEraOperationFactoryProtocol {
    func createOperation(
        from connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<ExtrinsicEraParameters> {
        let mortalLengthWrapper = createMortalLengthOperation(runtimeService: runtimeService)
        let blockNumberWrapper = createBlockNumberOperation(from: connection)

        let mapOperation = ClosureOperation<ExtrinsicEraParameters> {
            let mortalLength = try mortalLengthWrapper.targetOperation.extractNoCancellableResultData()
            let blockNumber = try blockNumberWrapper.targetOperation.extractNoCancellableResultData()

            let constrainedPeriod: UInt64 = min(1 << 16, max(4, mortalLength))
            var period: UInt64 = 1

            while period < constrainedPeriod {
                period = period << 1
            }

            let unquantizedPhase = UInt64(blockNumber) % period
            let quantizeFactor = max(period >> 12, 1)
            let phase = (unquantizedPhase / quantizeFactor) * quantizeFactor

            let eraBlockNumber = ((UInt64(blockNumber) - phase) / period) * period + phase

            return ExtrinsicEraParameters(
                blockNumber: BlockNumber(eraBlockNumber),
                extrinsicEra: .mortal(period: period, phase: phase)
            )
        }

        mapOperation.addDependency(mortalLengthWrapper.targetOperation)
        mapOperation.addDependency(blockNumberWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: mortalLengthWrapper.allOperations + blockNumberWrapper.allOperations
        )
    }
}
