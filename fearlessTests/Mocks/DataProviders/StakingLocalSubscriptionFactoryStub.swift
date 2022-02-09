import Foundation
@testable import fearless
import RobinHood
import BigInt

final class StakingLocalSubscriptionFactoryStub: StakingLocalSubscriptionFactoryProtocol {
    let minNominatorBond: BigUInt?
    let counterForNominators: UInt32?
    let maxNominatorsCount: UInt32?
    let nomination: Nomination?
    let validatorPrefs: ValidatorPrefs?
    let ledgerInfo: StakingLedger?
    let activeEra: ActiveEraInfo?
    let currentEra: EraIndex?
    let payee: RewardDestinationArg?
    let totalReward: TotalRewardItem?
    let stashItem: StashItem?
    let storageFacade: StorageFacadeProtocol

    init(
        minNominatorBond: BigUInt? = nil,
        counterForNominators: UInt32? = nil,
        maxNominatorsCount: UInt32? = nil,
        nomination: Nomination? = nil,
        validatorPrefs: ValidatorPrefs? = nil,
        ledgerInfo: StakingLedger? = nil,
        activeEra: ActiveEraInfo? = nil,
        currentEra: EraIndex? = nil,
        payee: RewardDestinationArg? = nil,
        totalReward: TotalRewardItem? = nil,
        stashItem: StashItem? = nil,
        storageFacade: StorageFacadeProtocol = SubstrateStorageTestFacade()
    ) {
        self.minNominatorBond = minNominatorBond
        self.counterForNominators = counterForNominators
        self.maxNominatorsCount = maxNominatorsCount
        self.nomination = nomination
        self.validatorPrefs = validatorPrefs
        self.ledgerInfo = ledgerInfo
        self.activeEra = activeEra
        self.currentEra = currentEra
        self.payee = payee
        self.totalReward = totalReward
        self.stashItem = stashItem
        self.storageFacade = storageFacade
    }

    func getMinNominatorBondProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedBigUInt> {
        let localIdentifierFactory = LocalStorageKeyFactory()

        let minNominatorBondModel: DecodedBigUInt = try {
            let localKey = try localIdentifierFactory.createFromStoragePath(
                .minNominatorBond,
                chainId: chainId
            )

            if let minNominatorBond = minNominatorBond {
                return DecodedBigUInt(
                    identifier: localKey,
                    item: StringScaleMapper(value: minNominatorBond)
                )
            } else {
                return DecodedBigUInt(identifier: localKey, item: nil)
            }
        }()

        return AnyDataProvider(DataProviderStub(models: [minNominatorBondModel]))
    }

    func getCounterForNominatorsProvider(
        for chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedU32> {
        let localIdentifierFactory = LocalStorageKeyFactory()

        let counterForNominatorsModel: DecodedU32 = try {
            let localKey = try localIdentifierFactory.createFromStoragePath(
                .counterForNominators,
                chainId: chainId
            )

            if let counterForNominators = counterForNominators {
                return DecodedU32(
                    identifier: localKey,
                    item: StringScaleMapper(value: counterForNominators)
                )
            } else {
                return DecodedU32(identifier: localKey, item: nil)
            }
        }()

        return AnyDataProvider(DataProviderStub(models: [counterForNominatorsModel]))
    }

    func getMaxNominatorsCountProvider(for chainId: ChainModel.Id) throws -> AnyDataProvider<DecodedU32> {
        let localIdentifierFactory = LocalStorageKeyFactory()

        let maxNominatorsCountModel: DecodedU32 = try {
            let localKey = try localIdentifierFactory.createFromStoragePath(
                .maxNominatorsCount,
                chainId: chainId
            )

            if let maxNominatorsCount = maxNominatorsCount {
                return DecodedU32(
                    identifier: localKey,
                    item: StringScaleMapper(value: maxNominatorsCount)
                )
            } else {
                return DecodedU32(identifier: localKey, item: nil)
            }
        }()

        return AnyDataProvider(DataProviderStub(models: [maxNominatorsCountModel]))
    }

    func getNominationProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedNomination> {
        let localIdentifierFactory = LocalStorageKeyFactory()

        let nominationModel: DecodedNomination = try {
            let localKey = try localIdentifierFactory.createFromStoragePath(
                .nominators,
                accountId: accountId,
                chainId: chainId
            )

            if let nomination = nomination {
                return DecodedNomination(identifier: localKey, item: nomination)
            } else {
                return DecodedNomination(identifier: localKey, item: nil)
            }
        }()

        return AnyDataProvider(DataProviderStub(models: [nominationModel]))
    }

    func getValidatorProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedValidator> {
        let localIdentifierFactory = LocalStorageKeyFactory()

        let validatorModel: DecodedValidator = try {
            let localKey = try localIdentifierFactory.createFromStoragePath(
                .validatorPrefs,
                accountId: accountId,
                chainId: chainId
            )

            if let validatorPrefs = validatorPrefs {
                return DecodedValidator(identifier: localKey, item: validatorPrefs)
            } else {
                return DecodedValidator(identifier: localKey, item: nil)
            }
        }()

        return AnyDataProvider(DataProviderStub(models: [validatorModel]))
    }

    func getLedgerInfoProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedLedgerInfo> {
        let localIdentifierFactory = LocalStorageKeyFactory()

        let ledgerInfoModel: DecodedLedgerInfo = try {
            let localKey = try localIdentifierFactory.createFromStoragePath(
                .stakingLedger,
                accountId: accountId,
                chainId: chainId
            )

            if let ledgerInfo = ledgerInfo {
                return DecodedLedgerInfo(identifier: localKey, item: ledgerInfo)
            } else {
                return DecodedLedgerInfo(identifier: localKey, item: nil)
            }
        }()

        return AnyDataProvider(DataProviderStub(models: [ledgerInfoModel]))
    }

    func getPayee(
        for accountId: AccountId,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedPayee> {
        let localIdentifierFactory = LocalStorageKeyFactory()

        let payeeModel: DecodedPayee = try {
            let localKey = try localIdentifierFactory.createFromStoragePath(
                .payee,
                accountId: accountId,
                chainId: chainId
            )

            if let payee = payee {
                return DecodedPayee(identifier: localKey, item: payee)
            } else {
                return DecodedPayee(identifier: localKey, item: nil)
            }
        }()

        return AnyDataProvider(DataProviderStub(models: [payeeModel]))
    }

    func getActiveEra(for chainId: ChainModel.Id) throws -> AnyDataProvider<DecodedActiveEra> {
        let localIdentifierFactory = LocalStorageKeyFactory()

        let actveEraModel: DecodedActiveEra = try {
            let localKey = try localIdentifierFactory.createFromStoragePath(
                .activeEra,
                chainId: chainId
            )

            if let activeEra = activeEra {
                return DecodedActiveEra(identifier: localKey, item: activeEra)
            } else {
                return DecodedActiveEra(identifier: localKey, item: nil)
            }
        }()

        return AnyDataProvider(DataProviderStub(models: [actveEraModel]))
    }

    func getCurrentEra(for chainId: ChainModel.Id) throws -> AnyDataProvider<DecodedEraIndex> {
        let localIdentifierFactory = LocalStorageKeyFactory()

        let currentEraModel: DecodedEraIndex = try {
            let localKey = try localIdentifierFactory.createFromStoragePath(
                .currentEra,
                chainId: chainId
            )

            if let currentEra = currentEra {
                return DecodedU32(identifier: localKey, item: StringScaleMapper(value: currentEra))
            } else {
                return DecodedU32(identifier: localKey, item: nil)
            }
        }()

        return AnyDataProvider(DataProviderStub(models: [currentEraModel]))
    }

    func getTotalReward(
        for address: AccountAddress,
        api: ChainModel.ExternalApi,
        assetPrecision: Int16
    ) throws -> AnySingleValueProvider<TotalRewardItem> {
        AnySingleValueProvider(SingleValueProviderStub(item: totalReward))
    }

    func getStashItemProvider(for address: AccountAddress) -> StreamableProvider<StashItem> {
        let provider = SubstrateDataProviderFactory(
            facade: storageFacade,
            operationManager: OperationManager()
        ).createStashItemProvider(for: address)

        if let stashItem = stashItem {
            let repository: CoreDataRepository<StashItem, CDStashItem> = storageFacade.createRepository()
            let saveOperation = repository.saveOperation({ [stashItem] }, { [] })
            OperationQueue().addOperations([saveOperation], waitUntilFinished: true)
        }

        return provider
    }
}
