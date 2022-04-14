import Foundation

protocol BaseFilterItem {
    var id: String { get }
    var title: String { get }

    mutating func reset()
}
