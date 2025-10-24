import Foundation
@testable import fearless
import RobinHood
import SSFRuntimeCodingService
import SSFUtils

final class SlashesOperationFactoryStub: SlashesOperationFactoryProtocol {
    let slashingSpans: SlashingSpans?

    init(slashingSpans: SlashingSpans?) {
        self.slashingSpans = slashingSpans
    }

    func createSlashingSpansOperationForStash(
        _ stashAddress: AccountAddress,
        engine: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        chainAsset: SSFModels.ChainAsset
    ) -> CompoundOperationWrapper<SlashingSpans?> {
        CompoundOperationWrapper.createWithResult(slashingSpans)
    }
}
