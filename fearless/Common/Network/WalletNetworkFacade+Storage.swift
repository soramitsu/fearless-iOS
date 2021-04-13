import Foundation
import CommonWallet
import RobinHood
import FearlessUtils

extension WalletNetworkFacade {
    func fetchBalanceInfoForAsset(
        _ assets: [WalletAsset]
    ) -> CompoundOperationWrapper<[BalanceData]?> {
        do {
            guard let asset = assets.first else {
                throw BaseOperationError.unexpectedDependentResult
            }

            let accountId = try Data(hexString: accountSettings.accountId)

            let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()

            let accountInfoWrapper: CompoundOperationWrapper<DyAccountInfo?> =
                localStorageRequestFactory.queryItems(
                    repository: chainStorage,
                    keyParam: { accountId },
                    factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                    params: StorageRequestParams(path: .account)
                )

            let stakingLedgerWrapper = createStakingLedgerOperation(
                for: accountId,
                dependingOn: codingFactoryOperation
            )

            let activeEraWrapper: CompoundOperationWrapper<ActiveEraInfo?> =
                localStorageRequestFactory.queryItems(
                    repository: chainStorage,
                    factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                    params: StorageRequestParams(path: .activeEra)
                )

            let mappingOperation = createBalanceMappingOperation(
                asset: asset,
                dependingOn: accountInfoWrapper,
                stakingLedgerWrapper: stakingLedgerWrapper,
                activeEraWrapper: activeEraWrapper
            )

            let storageOperations = accountInfoWrapper.allOperations +
                activeEraWrapper.allOperations + stakingLedgerWrapper.allOperations

            storageOperations.forEach { storageOperation in
                storageOperation.addDependency(codingFactoryOperation)
                mappingOperation.addDependency(storageOperation)
            }

            return CompoundOperationWrapper(
                targetOperation: mappingOperation,
                dependencies: [codingFactoryOperation] + storageOperations
            )

        } catch {
            return CompoundOperationWrapper<[BalanceData]?>
                .createWithError(error)
        }
    }

    private func createBalanceMappingOperation(
        asset: WalletAsset,
        dependingOn accountInfoWrapper: CompoundOperationWrapper<DyAccountInfo?>,
        stakingLedgerWrapper: CompoundOperationWrapper<DyStakingLedger?>,
        activeEraWrapper: CompoundOperationWrapper<ActiveEraInfo?>
    ) -> BaseOperation<[BalanceData]?> {
        ClosureOperation<[BalanceData]?> {
            let accountInfo = try accountInfoWrapper.targetOperation.extractNoCancellableResultData()
            var context = BalanceContext(context: [:])

            if let accountData = accountInfo?.data {
                context = context.byChangingAccountInfo(
                    accountData,
                    precision: asset.precision
                )

                if
                    let activeEra = try? activeEraWrapper
                    .targetOperation.extractNoCancellableResultData()?.index,
                    let stakingLedger = try? stakingLedgerWrapper.targetOperation
                    .extractNoCancellableResultData() {
                    context = context.byChangingStakingInfo(
                        stakingLedger,
                        activeEra: activeEra,
                        precision: asset.precision
                    )
                }
            }

            let balance = BalanceData(
                identifier: asset.identifier,
                balance: AmountDecimal(value: context.total),
                context: context.toContext()
            )

            return [balance]
        }
    }

    private func createStakingLedgerOperation(
        for accountId: Data,
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<DyStakingLedger?> {
        let controllerWrapper: CompoundOperationWrapper<Data?> =
            localStorageRequestFactory
                .queryItems(
                    repository: chainStorage,
                    keyParam: { accountId },
                    factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                    params: StorageRequestParams(path: .controller)
                )

        let controllerKey: () throws -> Data = {
            if let controllerAccountId = try controllerWrapper.targetOperation.extractNoCancellableResultData() {
                return controllerAccountId
            } else {
                throw BaseOperationError.unexpectedDependentResult
            }
        }

        let controllerLedgerWrapper: CompoundOperationWrapper<DyStakingLedger?> =
            localStorageRequestFactory.queryItems(
                repository: chainStorage,
                keyParam: controllerKey,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                params: StorageRequestParams(path: .stakingLedger)
            )

        controllerLedgerWrapper.allOperations.forEach { $0.addDependency(controllerWrapper.targetOperation) }

        let dependencies = controllerWrapper.allOperations + controllerLedgerWrapper.dependencies

        return CompoundOperationWrapper(
            targetOperation: controllerLedgerWrapper.targetOperation,
            dependencies: dependencies
        )
    }
}
