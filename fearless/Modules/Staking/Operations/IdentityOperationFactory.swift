import Foundation
import SSFUtils
import RobinHood
import IrohaCrypto
import SSFModels
import SSFRuntimeCodingService

protocol IdentityOperationFactoryProtocol {
    func createIdentityWrapper(
        for accountIdClosure: @escaping () throws -> [AccountId],
        engine: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        chain: ChainModel
    ) -> CompoundOperationWrapper<[AccountAddress: AccountIdentity]>
}

final class IdentityOperationFactory {
    let requestFactory: StorageRequestFactoryProtocol

    init(requestFactory: StorageRequestFactoryProtocol) {
        self.requestFactory = requestFactory
    }

    private func createSuperIdentityOperation(
        dependingOn coderFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        accountIds: @escaping () throws -> [AccountId],
        engine: JSONRPCEngine,
        chain: ChainModel
    ) -> SuperIdentityWrapper {
        let path = StorageCodingPath.superIdentity

        let factory: () throws -> RuntimeCoderFactoryProtocol = {
            try coderFactoryOperation.extractNoCancellableResultData()
        }

        guard let chainStakingSettings = chain.stakingSettings else {
            return CompoundOperationWrapper.createWithError(ConvenienceError(error: "No staking settings found for \(chain.name) chain"))
        }

        let superIdentityWrapper: SuperIdentityWrapper = chainStakingSettings.queryItems(
            engine: engine,
            keyParams: accountIds,
            factory: factory,
            storagePath: path,
            using: requestFactory
        )

        return superIdentityWrapper
    }

    private func createIdentityMergeOperation(
        dependingOn superOperation: SuperIdentityOperation,
        identityOperation: IdentityOperation,
        chain: ChainModel
    ) -> BaseOperation<[AccountAddress: AccountIdentity]> {
        ClosureOperation<[AccountAddress: AccountIdentity]> {
            let superIdentities = try superOperation.extractNoCancellableResultData()
            let identities = try identityOperation.extractNoCancellableResultData()
                .reduce(into: [AccountAddress: Identity]()) { result, item in
                    if let value = item.value {
                        let address = try AddressFactory.address(
                            for: item.key.getAccountIdFromKey(accountIdLenght: chain.accountIdLenght),
                            chainFormat: chain.chainFormat
                        )

                        result[address] = value
                    }
                }

            return try superIdentities.reduce(into: [String: AccountIdentity]()) { result, item in
                let address = try AddressFactory
                    .address(
                        for: item.key.getAccountIdFromKey(accountIdLenght: chain.accountIdLenght),
                        chainFormat: chain.chainFormat
                    )

                if let value = item.value {
                    let parentAddress = try AddressFactory
                        .address(
                            for: value.parentAccountId,
                            chainFormat: chain.chainFormat
                        )

                    if let parentIdentity = identities[parentAddress] {
                        result[address] = AccountIdentity(
                            name: value.data.stringValue ?? "",
                            parentAddress: parentAddress,
                            parentName: parentIdentity.info.display.stringValue,
                            identity: parentIdentity.info
                        )
                    } else {
                        result[address] = AccountIdentity(name: value.data.stringValue ?? "")
                    }

                } else if let identity = identities[address] {
                    result[address] = AccountIdentity(
                        name: identity.info.display.stringValue ?? "",
                        parentAddress: nil,
                        parentName: nil,
                        identity: identity.info
                    )
                }
            }
        }
    }

    private func createIdentityWrapper(
        dependingOn superIdentityOperation: SuperIdentityOperation,
        runtimeOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        engine: JSONRPCEngine,
        chain: ChainModel
    ) -> CompoundOperationWrapper<[AccountAddress: AccountIdentity]> {
        guard let stakingSettings = chain.stakingSettings else {
            return CompoundOperationWrapper.createWithError(ConvenienceError(error: "No staking settings found for \(chain.name) chain"))
        }

        let path = StorageCodingPath.identity

        let keyParams: () throws -> [Data] = {
            let responses = try superIdentityOperation.extractNoCancellableResultData()
            return responses.map { response in
                if let value = response.value {
                    return value.parentAccountId
                } else {
                    return response.key.getAccountIdFromKey(accountIdLenght: chain.accountIdLenght)
                }
            }
        }

        let factory: () throws -> RuntimeCoderFactoryProtocol = {
            try runtimeOperation.extractNoCancellableResultData()
        }

        let identityWrapper: IdentityWrapper = stakingSettings.queryItems(engine: engine, keyParams: keyParams, factory: factory, storagePath: path, using: requestFactory)

        let mergeOperation = createIdentityMergeOperation(
            dependingOn: superIdentityOperation,
            identityOperation: identityWrapper.targetOperation,
            chain: chain
        )

        mergeOperation.addDependency(identityWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: identityWrapper.allOperations
        )
    }
}

extension IdentityOperationFactory: IdentityOperationFactoryProtocol {
    func createIdentityWrapper(
        for accountIdClosure: @escaping () throws -> [AccountId],
        engine: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        chain: ChainModel
    ) -> CompoundOperationWrapper<[AccountAddress: AccountIdentity]> {
        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let superIdentityWrapper = createSuperIdentityOperation(
            dependingOn: coderFactoryOperation,
            accountIds: accountIdClosure,
            engine: engine,
            chain: chain
        )

        superIdentityWrapper.allOperations.forEach {
            $0.addDependency(coderFactoryOperation)
        }

        let identityWrapper = createIdentityWrapper(
            dependingOn: superIdentityWrapper.targetOperation,
            runtimeOperation: coderFactoryOperation,
            engine: engine,
            chain: chain
        )

        identityWrapper.allOperations.forEach {
            $0.addDependency(superIdentityWrapper.targetOperation)
            $0.addDependency(coderFactoryOperation)
        }

        let dependencies = identityWrapper.dependencies + superIdentityWrapper.allOperations
            + [coderFactoryOperation]

        return CompoundOperationWrapper(
            targetOperation: identityWrapper.targetOperation,
            dependencies: dependencies
        )
    }
}
