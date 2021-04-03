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
            let storageKeyFactory = StorageKeyFactory()

            let accountInfoKey = try storageKeyFactory.accountInfoKeyForId(accountId)
            let upgradeKey = try storageKeyFactory.updatedDualRefCount()
            let activeEraKey = try storageKeyFactory.activeEra()

            let upgradeCheckOperation: CompoundOperationWrapper<Bool?> = queryStorageByKey(upgradeKey)

            let accountInfoOperation: CompoundOperationWrapper<AccountInfo?> =
                queryAccountInfoByKey(accountInfoKey, dependingOn: upgradeCheckOperation)

            let stakingLedgerOperation =
                StakingLedgerLocalOperation(
                    stashAddress: address,
                    storageService: storageFacade.databaseService
                )

            let activeEraOperation: CompoundOperationWrapper<UInt32?> =
                queryStorageByKey(activeEraKey)

            let mappingOperation = ClosureOperation<[BalanceData]?> {
                switch accountInfoOperation.targetOperation.result {
                case let .success(info):
                    var context = BalanceContext(context: [:])

                    if let accountData = info?.data {
                        context = context.byChangingAccountInfo(
                            accountData,
                            precision: asset.precision
                        )

                        if
                            let activeEra = try? activeEraOperation
                            .targetOperation.extractResultData(throwing:
                                BaseOperationError.parentOperationCancelled),
                            let stakingLedger = try? stakingLedgerOperation
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
                case .none:
                    throw BaseOperationError.parentOperationCancelled
                case let .failure(error):
                    throw error
                }
            }

            let dependencies = upgradeCheckOperation.allOperations + accountInfoOperation.allOperations +
                activeEraOperation.allOperations + [stakingLedgerOperation]

            dependencies.forEach { mappingOperation.addDependency($0) }

            return CompoundOperationWrapper(
                targetOperation: mappingOperation,
                dependencies: dependencies
            )

        } catch {
            return CompoundOperationWrapper<[BalanceData]?>
                .createWithError(error)
        }
    }

    func queryStorageByKey<T: ScaleDecodable>(_ storageKey: Data) -> CompoundOperationWrapper<T?> {
        let identifier = localStorageIdFactory.createIdentifier(for: storageKey)
        return chainStorage.queryStorageByKey(identifier)
    }

    func queryAccountInfoByKey(
        _ storageKey: Data,
        dependingOn upgradeOperation: CompoundOperationWrapper<Bool?>
    ) -> CompoundOperationWrapper<AccountInfo?> {
        let identifier = localStorageIdFactory.createIdentifier(for: storageKey)

        let fetchOperation = chainStorage
            .fetchOperation(
                by: identifier,
                options: RepositoryFetchOptions()
            )

        let decoderOperation: ClosureOperation<AccountInfo?> = ClosureOperation {
            let isUpgraded = (try upgradeOperation.targetOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)) ?? false

            let item = try fetchOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            guard let data = item?.data else {
                return nil
            }

            let decoder = try ScaleDecoder(data: data)

            if isUpgraded {
                return try AccountInfo(scaleDecoder: decoder)
            } else {
                let v27 = try AccountInfoV27(scaleDecoder: decoder)
                return AccountInfo(v27: v27)
            }
        }

        decoderOperation.addDependency(fetchOperation)

        upgradeOperation.allOperations.forEach { decoderOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: decoderOperation,
            dependencies: [fetchOperation]
        )
    }
}
