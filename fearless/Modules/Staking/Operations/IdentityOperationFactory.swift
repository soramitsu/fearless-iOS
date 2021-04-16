import Foundation
import FearlessUtils
import RobinHood
import IrohaCrypto

protocol IdentityOperationFactoryProtocol {
    func createIdentityWrapper(
        for accountIdClosure: @escaping () throws -> [AccountId],
        engine: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        chain: Chain
    ) -> CompoundOperationWrapper<[AccountAddress: AccountIdentity]>
}

final class IdentityOperationFactory {
    let requestFactory: StorageRequestFactoryProtocol

    init(requestFactory: StorageRequestFactoryProtocol) {
        self.requestFactory = requestFactory
    }

    private func createSuperIdentityOperation(
        dependingOn coderFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        accountIds: @escaping () throws -> [Data],
        engine: JSONRPCEngine
    ) -> SuperIdentityWrapper {
        let path = StorageCodingPath.superIdentity

        let factory: () throws -> RuntimeCoderFactoryProtocol = {
            try coderFactoryOperation.extractNoCancellableResultData()
        }

        let superIdentityWrapper: SuperIdentityWrapper = requestFactory.queryItems(
            engine: engine,
            keyParams: accountIds,
            factory: factory,
            storagePath: path
        )

        return superIdentityWrapper
    }

    private func createIdentityMergeOperation(
        dependingOn superOperation: SuperIdentityOperation,
        identityOperation: IdentityOperation,
        chain: Chain
    ) -> BaseOperation<[AccountAddress: AccountIdentity]> {
        ClosureOperation<[AccountAddress: AccountIdentity]> {
            let addressFactory = SS58AddressFactory()

            let superIdentities = try superOperation.extractNoCancellableResultData()
            let identities = try identityOperation.extractNoCancellableResultData()
                .reduce(into: [String: Identity]()) { result, item in
                    if let value = item.value {
                        let address = try addressFactory
                            .addressFromAccountId(
                                data: item.key.getAccountIdFromKey(),
                                type: chain.addressType
                            )
                        result[address] = value
                    }
                }

            return try superIdentities.reduce(into: [String: AccountIdentity]()) { result, item in
                let address = try addressFactory
                    .addressFromAccountId(
                        data: item.key.getAccountIdFromKey(),
                        type: chain.addressType
                    )

                if let value = item.value {
                    let parentAddress = try addressFactory
                        .addressFromAccountId(
                            data: value.parentAccountId,
                            type: chain.addressType
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
        dependingOn superIdentity: SuperIdentityOperation,
        runtime: BaseOperation<RuntimeCoderFactoryProtocol>,
        engine: JSONRPCEngine,
        chain: Chain
    ) -> CompoundOperationWrapper<[AccountAddress: AccountIdentity]> {
        let path = StorageCodingPath.identity

        let keyParams: () throws -> [Data] = {
            let responses = try superIdentity.extractNoCancellableResultData()
            return responses.map { response in
                if let value = response.value {
                    return value.parentAccountId
                } else {
                    return response.key.getAccountIdFromKey()
                }
            }
        }

        let factory: () throws -> RuntimeCoderFactoryProtocol = {
            try runtime.extractNoCancellableResultData()
        }

        let identityWrapper: IdentityWrapper = requestFactory.queryItems(
            engine: engine,
            keyParams: keyParams,
            factory: factory,
            storagePath: path
        )

        let mergeOperation = createIdentityMergeOperation(
            dependingOn: superIdentity,
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
        chain: Chain
    ) -> CompoundOperationWrapper<[AccountAddress: AccountIdentity]> {
        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let superIdentityWrapper = createSuperIdentityOperation(
            dependingOn: coderFactoryOperation,
            accountIds: accountIdClosure,
            engine: engine
        )

        superIdentityWrapper.allOperations.forEach {
            $0.addDependency(coderFactoryOperation)
        }

        let identityWrapper = createIdentityWrapper(
            dependingOn: superIdentityWrapper.targetOperation,
            runtime: coderFactoryOperation,
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
