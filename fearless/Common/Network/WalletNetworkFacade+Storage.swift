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
            let eraKey = try storageKeyFactory.activeEra()
            let stakingInfoKey = try storageKeyFactory.stakingInfoForControllerId(accountId)

            let accountInfoOperation: CompoundOperationWrapper<AccountInfo?> =
                queryStorageByKey(accountInfoKey)

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

            let dependencies = accountInfoOperation.allOperations +
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
        let fetchOperation = chainStorage
            .fetchOperation(by: storageKey.toHex(includePrefix: true),
                            options: RepositoryFetchOptions())

        let decoderOperation = ScaleDecoderOperation<T>()
        decoderOperation.configurationBlock = {
            do {
                decoderOperation.data = try fetchOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)?
                    .data
            } catch {
                decoderOperation.result = .failure(error)
            }
        }

        decoderOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: decoderOperation,
                                        dependencies: [fetchOperation])
    }
}
