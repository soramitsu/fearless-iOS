import Foundation
import SSFModels

extension ChainModel {
    var isNomisSupported: Bool {
        chainId == "137" || chainId == "1" || chainId == "56"
    }
}
