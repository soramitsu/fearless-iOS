import Foundation
import RobinHood
import SSFPools
import SSFUtils

public final class PoolRepositoryFactory {
    private let storageFacade: StorageFacadeProtocol

    public init(storageFacade: StorageFacadeProtocol) {
        self.storageFacade = storageFacade
    }

    func createRepository(
        for _: NSPredicate? = nil,
        sortDescriptors _: [NSSortDescriptor] = []
    ) -> CoreDataRepository<AccountPool, CDAccountPool> {
        storageFacade.createRepository()
    }

    func createRepository(
        for _: NSPredicate? = nil,
        sortDescriptors _: [NSSortDescriptor] = []
    ) -> CoreDataRepository<LiquidityPair, CDLiquidityPair> {
        storageFacade.createRepository()
    }
}
