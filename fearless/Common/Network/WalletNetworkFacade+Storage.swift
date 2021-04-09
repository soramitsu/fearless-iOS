import Foundation
import CommonWallet
import RobinHood
import FearlessUtils

extension WalletNetworkFacade {
    func fetchBalanceInfoForAsset(_ assets: [WalletAsset])
        -> CompoundOperationWrapper<[BalanceData]?> {
        do {
            guard let asset = assets.first else {
                throw BaseOperationError.unexpectedDependentResult
            }

            let accountId = try Data(hexString: accountSettings.accountId)
            let storageKeyFactory = StorageKeyFactory()

            let accountInfoKey = try storageKeyFactory.accountInfoKeyForId(accountId)
            let upgradeKey = try storageKeyFactory.updatedTripleRefCount()
            let eraKey = try storageKeyFactory.activeEra()
            let stakingInfoKey = try storageKeyFactory.stakingInfoForControllerId(accountId)

            let upgradeCheckOperation: CompoundOperationWrapper<Bool?> = queryStorageByKey(upgradeKey)

            let accountInfoOperation: CompoundOperationWrapper<AccountInfo?> =
                queryAccountInfoByKey(accountInfoKey, dependingOn: upgradeCheckOperation)

            let stakingLedgerOperation: CompoundOperationWrapper<StakingLedger?> =
                queryStorageByKey(stakingInfoKey)

            let activeEraOperation: CompoundOperationWrapper<UInt32?> =
                queryStorageByKey(eraKey)

            let mappingOperation = ClosureOperation<[BalanceData]?> {
                switch accountInfoOperation.targetOperation.result {
                case .success(let info):
                    var context: BalanceContext = BalanceContext(context: [:])

                    if let accountData = info?.data {
                        context = context.byChangingAccountInfo(accountData,
                                                                precision: asset.precision)

                        if
                            let activeEra = try? activeEraOperation
                                .targetOperation.extractResultData(throwing:
                                    BaseOperationError.parentOperationCancelled),
                            let stakingLedger = try? stakingLedgerOperation.targetOperation
                                .extractResultData(throwing: BaseOperationError.parentOperationCancelled) {

                            context = context.byChangingStakingInfo(stakingLedger,
                                                                    activeEra: activeEra,
                                                                    precision: asset.precision)
                        }

                    }

                    let balance = BalanceData(identifier: asset.identifier,
                                              balance: AmountDecimal(value: context.total),
                                              context: context.toContext())

                    return [balance]
                case .none:
                    throw BaseOperationError.parentOperationCancelled
                case .failure(let error):
                    throw error
                }
            }

            let dependencies = upgradeCheckOperation.allOperations + accountInfoOperation.allOperations +
                activeEraOperation.allOperations + stakingLedgerOperation.allOperations

            dependencies.forEach { mappingOperation.addDependency($0) }

            return CompoundOperationWrapper(targetOperation: mappingOperation,
                                            dependencies: dependencies)

        } catch {
            return CompoundOperationWrapper<[BalanceData]?>
                .createWithError(error)
        }
    }

    func queryStorageByKey<T: ScaleDecodable>(_ storageKey: Data) -> CompoundOperationWrapper<T?> {
        do {
            let identifier = try localStorageIdFactory.createIdentifier(for: storageKey)
            return chainStorage.queryStorageByKey(identifier)
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }

    func queryAccountInfoByKey(_ storageKey: Data,
                               dependingOn upgradeOperation: CompoundOperationWrapper<Bool?>) ->
    CompoundOperationWrapper<AccountInfo?> {
        do {
            let identifier = try localStorageIdFactory.createIdentifier(for: storageKey)

            let fetchOperation = chainStorage
                .fetchOperation(by: identifier,
                                options: RepositoryFetchOptions())

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
                    let v28 = try AccountInfoV28(scaleDecoder: decoder)
                    return AccountInfo(v28: v28)
                }
            }

            decoderOperation.addDependency(fetchOperation)

            upgradeOperation.allOperations.forEach { decoderOperation.addDependency($0) }

            return CompoundOperationWrapper(targetOperation: decoderOperation,
                                            dependencies: [fetchOperation])
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }
}
