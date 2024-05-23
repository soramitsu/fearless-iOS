import Foundation
import RobinHood
import SSFUtils
import SSFModels

protocol EraStakersFetching {
    func fetchEraStakers(
        activeEra: UInt32,
        completion: @escaping ((EraStakersInfo) -> Void)
    )
}
