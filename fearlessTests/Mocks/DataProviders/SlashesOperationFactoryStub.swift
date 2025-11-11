import Foundation
@testable import fearless
import RobinHood
import SSFUtils
import SSFModels
import SSFRuntimeCodingService

final class SlashesOperationFactoryStub: SlashesOperationFactoryProtocol {
    let slashingSpans: SlashingSpans?

    init(slashingSpans: SlashingSpans?) {
        self.slashingSpans = slashingSpans
    }

    func createSlashingSpansOperationForStash(
        _ stashAddress: AccountAddress,
        engine: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        chainAsset: ChainAsset) -> CompoundOperationWrapper<SlashingSpans?> {
        return CompoundOperationWrapper.createWithResult(slashingSpans)
    }
}
