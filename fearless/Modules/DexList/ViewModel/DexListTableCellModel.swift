import Foundation

struct DexListTableCellModel {
    let dexIcon: RemoteImageViewModel?
    let routeTitle: String?
    let routeDescription: NSAttributedString?
    let amount: String?
    let txTime: String?
    let txCommission: String?
    let route: String?
    let isSelected: Bool
    let dexId: String
}
