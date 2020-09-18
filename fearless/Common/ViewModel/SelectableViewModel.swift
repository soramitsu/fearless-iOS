import Foundation

struct SelectableViewModel<T> {
    let underlyingViewModel: T
    let selectable: Bool
}
