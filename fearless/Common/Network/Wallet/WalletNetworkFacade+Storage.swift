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

            let accountInfoWrapper: CompoundOperationWrapper<AccountInfo?> =
                localStorageRequestFactory.queryItems(
                    repository: chainStorage,
                    keyParam: { accountId },
                    factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                    params: StorageRequestParams(path: .account)
                )

            let balanceLocksWrapper: CompoundOperationWrapper<[BalanceLock]?> =
                localStorageRequestFactory.queryItems(
                    repository: chainStorage,
                    keyParam: { accountId },
                    factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                    params: StorageRequestParams(path: .balanceLocks)
                )

            let mappingOperation = createBalanceMappingOperation(
                asset: asset,
                dependingOn: accountInfoWrapper,
                balanceLocksWrapper: balanceLocksWrapper
            )

            let storageOperations = accountInfoWrapper.allOperations + balanceLocksWrapper.allOperations

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
        dependingOn accountInfoWrapper: CompoundOperationWrapper<AccountInfo?>,
        balanceLocksWrapper: CompoundOperationWrapper<[BalanceLock]?>
    ) -> BaseOperation<[BalanceData]?> {
        ClosureOperation<[BalanceData]?> {
            let accountInfo = try accountInfoWrapper.targetOperation.extractNoCancellableResultData()
            var context = BalanceContext(context: [:])

            if let accountData = accountInfo?.data {
                context = context.byChangingAccountInfo(
                    accountData,
                    precision: asset.precision
                )

                if let balanceLocks = try? balanceLocksWrapper.targetOperation.extractNoCancellableResultData() {
                    context = context.byChangingBalanceLocks(balanceLocks)
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
}
