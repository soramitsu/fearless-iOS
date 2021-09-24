import Foundation
@testable import fearless
import RobinHood

final class CrowdloanLocalSubscriptionFactoryStub: CrowdloanLocalSubscriptionFactoryProtocol {
    let blockNumber: BlockNumber?

    init(blockNumber: BlockNumber? = nil) {
        self.blockNumber = blockNumber
    }

    func getBlockNumberProvider(
        for chainId: ChainModel.Id
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
}
