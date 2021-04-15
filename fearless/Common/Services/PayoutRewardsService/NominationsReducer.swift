import Foundation

final class NominationsReducer: ListReducing {
    typealias InputType = [AccountId]
    typealias OutputType = Set<AccountId>

    func reduce(list: [InputType], initialValue: OutputType) -> OutputType {
        list.reduce(into: initialValue) { result, items in
            items.forEach { item in
                result.insert(item)
            }
        }
    }
}
