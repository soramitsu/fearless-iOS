import Foundation
@testable import fearless
import RobinHood
import SSFModels

final class CrowdloanLocalSubscriptionFactoryStub: CrowdloanLocalSubscriptionFactoryProtocol {
    let blockNumber: BlockNumber?
    let crowdloanFunds: CrowdloanFunds?

    init(blockNumber: BlockNumber? = nil, crowdloanFunds: CrowdloanFunds? = nil) {
        self.blockNumber = blockNumber
        self.crowdloanFunds = crowdloanFunds
    }

    func getBlockNumberProvider(
        for chainId: SSFModels.ChainModel.Id
    ) throws -> AnyDataProvider<DecodedBlockNumber> {
        let localIdentifierFactory = LocalStorageKeyFactory()

        let blockNumberModel: DecodedBlockNumber = try {
            let localKey = try localIdentifierFactory.createFromStoragePath(.blockNumber, chainId: chainId)
            if let blockNumber = blockNumber {
                return DecodedBlockNumber(identifier: localKey, item: StringScaleMapper(value: blockNumber))
            } else {
                return DecodedBlockNumber(identifier: localKey, item: nil)
            }
        }()

        return AnyDataProvider(DataProviderStub(models: [blockNumberModel]))
    }

    func getCrowdloanFundsProvider(
        for paraId: ParaId,
        chainId: SSFModels.ChainModel.Id
    ) throws -> AnyDataProvider<DecodedCrowdloanFunds> {
        let localIdentifierFactory = LocalStorageKeyFactory()

        let fundsModel: DecodedCrowdloanFunds = try {
            let localKey = try localIdentifierFactory.createFromStoragePath(
                .crowdloanFunds,
                encodableElement: paraId,
                chainId: chainId
            )

            if let funds = crowdloanFunds {
                return DecodedCrowdloanFunds(identifier: localKey, item: funds)
            } else {
                return DecodedCrowdloanFunds(identifier: localKey, item: nil)
            }
        }()

        return AnyDataProvider(DataProviderStub(models: [fundsModel]))
    }
}
