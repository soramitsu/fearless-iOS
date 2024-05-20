import UIKit
import SSFPools

protocol LiquidityPoolSupplyInteractorOutput: AnyObject {}

final class LiquidityPoolSupplyInteractor {
    // MARK: - Private properties
    private weak var output: LiquidityPoolSupplyInteractorOutput?
    private let lpService: PoolsOperationService
    
    init(lpService: PoolsOperationService) {
        
    }
}

// MARK: - LiquidityPoolSupplyInteractorInput
extension LiquidityPoolSupplyInteractor: LiquidityPoolSupplyInteractorInput {
    func setup(with output: LiquidityPoolSupplyInteractorOutput) {
        self.output = output
    }
}
