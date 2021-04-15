import Foundation

final class NominationsListReducer: ListReducing {
    typealias InputType = [[AccountId]]
    typealias OutputType = Set<Data>

    func reduce(list: [InputType], initialValue: OutputType) -> OutputType {
        list.flatMap { $0 }
            .flatMap { $0 }
            .reduce(into: initialValue) { $0.insert($1) }
    }
}
