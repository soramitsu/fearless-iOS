import Foundation

final class ControllersReducer: ListReducing {
    typealias InputType = AccountId?
    typealias OutputType = Set<AccountId>

    func reduce(list: [InputType], initialValue: OutputType) -> OutputType {
        list.reduce(into: initialValue) { result, item in
            guard let item = item else {
                return
            }

            result.insert(item)
        }
    }
}
