import Foundation
import CommonWallet
import RobinHood
import IrohaCrypto
import BigInt

extension WalletNetworkFacade: WalletNetworkOperationFactoryProtocol {
    func fetchBalanceOperation(_ assets: [String]) -> CompoundOperationWrapper<[BalanceData]?> {
        let userAssets: [WalletAsset] = assets.compactMap { identifier in
            guard identifier != totalPriceAssetId.rawValue else {
                return nil
            }

            return accountSettings.assets.first { $0.identifier == identifier }
        }

        let balanceOperation = fetchBalanceInfoForAsset(userAssets)
        let priceOperations: [CompoundOperationWrapper<Price?>] = userAssets.compactMap {
            if let assetId = WalletAssetId(rawValue: $0.identifier) {
                return fetchPriceOperation(assetId)
            } else {
                return nil
            }
        }

        let minimalBalanceOperation: CompoundOperationWrapper<BigUInt> = fetchMinimalBalanceOperation()

        let currentTotalPriceId = totalPriceAssetId.rawValue

        let mergeOperation: BaseOperation<[BalanceData]?> = ClosureOperation {
            // extract prices

            let prices = priceOperations.compactMap { operation in
                try? operation.targetOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            }

            let rawMinimalBalance = try minimalBalanceOperation.targetOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            // match balance with price and form context

            let balances: [BalanceData]? = try balanceOperation.targetOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)?
                .map { balanceData in
                    let minimalBalance: Decimal
                    if let asset = userAssets.first(where: { $0.identifier == balanceData.identifier }) {
                        minimalBalance = Decimal.fromSubstrateAmount(
                            rawMinimalBalance,
                            precision: asset.precision
                        ) ?? .zero
                    } else {
                        minimalBalance = .zero
                    }

                    let context = BalanceContext(context: balanceData.context ?? [:])
                        .byChangingMinimalBalance(to: minimalBalance)

                    let contextWithPrice: BalanceContext = {
                        guard
                            let price = prices.first(where: { $0.assetId.rawValue == balanceData.identifier })
                        else { return context }
                        return context.byChangingPrice(price.lastValue, newPriceChange: price.change)
                    }()

                    return BalanceData(
                        identifier: balanceData.identifier,
                        balance: balanceData.balance,
                        context: contextWithPrice.toContext()
                    )
                }

            // calculate total assets price

            let totalPrice: Decimal = (balances ?? []).reduce(Decimal.zero) { result, balanceData in
                let price = BalanceContext(context: balanceData.context ?? [:]).price
                return result + price * balanceData.balance.decimalValue
            }

            // append separate record for total balance and return the list

            let totalPriceBalance = BalanceData(
                identifier: currentTotalPriceId,
                balance: AmountDecimal(value: totalPrice)
            )

            return [totalPriceBalance] + (balances ?? [])
        }

        let flatenedPriceOperations: [Operation] = priceOperations
            .reduce(into: []) { result, compoundOperation in
                result.append(contentsOf: compoundOperation.allOperations)
            }

        flatenedPriceOperations.forEach { priceOperation in
            balanceOperation.allOperations.forEach { balanceOperation in
                balanceOperation.addDependency(priceOperation)
            }
        }

        let dependencies = balanceOperation.allOperations + flatenedPriceOperations + minimalBalanceOperation.allOperations

        dependencies.forEach { mergeOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: dependencies
        )
    }

    func fetchTransactionHistoryOperation(
        _ request: WalletHistoryRequest,
        pagination: Pagination
    ) -> CompoundOperationWrapper<AssetTransactionPageData?> {
        let filter = WalletHistoryFilter(string: request.filter)

        let historyContext = TransactionHistoryContext(
            context: pagination.context ?? [:],
            defaultRow: pagination.count
        ).byApplying(filter: filter)

        guard !historyContext.isComplete,
              let asset = accountSettings.assets.first(where: { $0.identifier != totalPriceAssetId.rawValue }),
              let assetId = WalletAssetId(rawValue: asset.identifier)
        else {
            let pageData = AssetTransactionPageData(
                transactions: [],
                context: nil
            )

            let operation = BaseOperation<AssetTransactionPageData?>()
            operation.result = .success(pageData)
            return CompoundOperationWrapper(targetOperation: operation)
        }

        let remoteHistoryWrapper: CompoundOperationWrapper<WalletRemoteHistoryData>

        if let baseUrl = assetId.subscanUrl {
            let remoteHistoryFactory = WalletRemoteHistoryFactory(
                baseURL: baseUrl,
                filter: WalletRemoteHistoryClosureFilter.transfersInExtrinsics
            )

            remoteHistoryWrapper = remoteHistoryFactory.createOperationWrapper(
                for: historyContext,
                address: address,
                count: pagination.count
            )
        } else {
            let context = TransactionHistoryContext(context: [:], defaultRow: 0)
            let result = WalletRemoteHistoryData(historyItems: [], context: context)
            remoteHistoryWrapper = CompoundOperationWrapper.createWithResult(result)
        }

        var dependencies = remoteHistoryWrapper.allOperations

        let localFetchOperation: BaseOperation<[TransactionHistoryItem]>?

        if pagination.context == nil {
            let operation = txStorage.fetchAllOperation(with: RepositoryFetchOptions())
            dependencies.append(operation)

            remoteHistoryWrapper.allOperations.forEach { operation.addDependency($0) }

            localFetchOperation = operation
        } else {
            localFetchOperation = nil
        }

        let mergeOperation = createHistoryMergeOperation(
            dependingOn: remoteHistoryWrapper.targetOperation,
            localOperation: localFetchOperation,
            asset: asset,
            address: address
        )

        dependencies.forEach { mergeOperation.addDependency($0) }

        dependencies.append(mergeOperation)

        if pagination.context == nil {
            let clearOperation = txStorage.saveOperation({ [] }, {
                let mergeResult = try mergeOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                return mergeResult.identifiersToRemove
            })

            dependencies.append(clearOperation)
            clearOperation.addDependency(mergeOperation)
        }

        let mapOperation = createHistoryMapOperation(
            dependingOn: mergeOperation,
            remoteOperation: remoteHistoryWrapper.targetOperation
        )

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: dependencies
        )
    }

    func transferMetadataOperation(
        _ info: TransferMetadataInfo
    ) -> CompoundOperationWrapper<TransferMetaData?> {
        nodeOperationFactory.transferMetadataOperation(info)
    }

    func transferOperation(_ info: TransferInfo) -> CompoundOperationWrapper<Data> {
        do {
            let currentNetworkType = networkType

            let transferWrapper = nodeOperationFactory.transferOperation(info)

            let addressFactory = SS58AddressFactory()

            let destinationId = try Data(hexString: info.destination)
            let destinationAddress = try addressFactory
                .address(
                    fromPublicKey: AccountIdWrapper(rawData: destinationId),
                    type: currentNetworkType
                )
            let contactSaveWrapper = contactsOperationFactory.saveByAddressOperation(destinationAddress)

            let txSaveOperation = txStorage.saveOperation({
                switch transferWrapper.targetOperation.result {
                case let .success(txHash):
                    let item = try TransactionHistoryItem
                        .createFromTransferInfo(
                            info,
                            transactionHash: txHash,
                            networkType: currentNetworkType,
                            addressFactory: addressFactory
                        )
                    return [item]
                case let .failure(error):
                    throw error
                case .none:
                    throw BaseOperationError.parentOperationCancelled
                }
            }, { [] })

            transferWrapper.allOperations.forEach { transaferOperation in
                txSaveOperation.addDependency(transaferOperation)

                contactSaveWrapper.allOperations.forEach { $0.addDependency(transaferOperation) }
            }

            let completionOperation: BaseOperation<Data> = ClosureOperation {
                try txSaveOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                try contactSaveWrapper.targetOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                return try transferWrapper.targetOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            }

            let dependencies = [txSaveOperation] + contactSaveWrapper.allOperations +
                transferWrapper.allOperations

            completionOperation.addDependency(txSaveOperation)
            completionOperation.addDependency(contactSaveWrapper.targetOperation)

            return CompoundOperationWrapper(
                targetOperation: completionOperation,
                dependencies: dependencies
            )
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }

    func searchOperation(_ searchString: String) -> CompoundOperationWrapper<[SearchData]?> {
        let fetchOperation = contactsOperation()

        let normalizedSearch = searchString.lowercased()

        let filterOperation: BaseOperation<[SearchData]?> = ClosureOperation {
            let result = try fetchOperation.targetOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            return result?.filter {
                ($0.firstName.lowercased().range(of: normalizedSearch) != nil) ||
                    ($0.lastName.lowercased().range(of: normalizedSearch) != nil)
            }
        }

        let dependencies = fetchOperation.allOperations
        dependencies.forEach { filterOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: filterOperation,
            dependencies: dependencies
        )
    }

    func contactsOperation() -> CompoundOperationWrapper<[SearchData]?> {
        let currentNetworkType = networkType

        let accountsOperation = accountsRepository.fetchAllOperation(with: RepositoryFetchOptions())
        let contactsOperation = contactsOperationFactory.fetchContactsOperation()
        let mapOperation: BaseOperation<[SearchData]?> = ClosureOperation {
            let accounts = try accountsOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            let existingAddresses = Set<String>(
                accounts.map(\.address)
            )

            let addressFactory = SS58AddressFactory()

            let accountsResult = try accounts.map {
                try SearchData.createFromAccountItem(
                    $0,
                    addressFactory: addressFactory
                )
            }

            let contacts = try contactsOperation.targetOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                .filter { !existingAddresses.contains($0.peerAddress) }

            let contactsResult = try contacts.map { contact in
                try SearchData.createFromContactItem(
                    contact,
                    networkType: currentNetworkType,
                    addressFactory: addressFactory
                )
            }

            return accountsResult + contactsResult
        }

        mapOperation.addDependency(contactsOperation.targetOperation)
        mapOperation.addDependency(accountsOperation)

        let dependencies = contactsOperation.allOperations + [accountsOperation]

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: dependencies
        )
    }

    func withdrawalMetadataOperation(
        _ info: WithdrawMetadataInfo
    ) -> CompoundOperationWrapper<WithdrawMetaData?> {
        nodeOperationFactory.withdrawalMetadataOperation(info)
    }

    func withdrawOperation(_ info: WithdrawInfo) -> CompoundOperationWrapper<Data> {
        nodeOperationFactory.withdrawOperation(info)
    }
}
