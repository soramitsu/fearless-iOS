import Foundation

protocol Emptyable {
    static func empty() -> Self
    var isEmpty: Bool { get }
    var isNotEmpty: Bool { get }
}

extension Emptyable {
    var isNotEmpty: Bool {
        !isEmpty
    }
}

// MARK: - String

extension String: Emptyable {
    static func empty() -> String {
        ""
    }
}

// MARK: - Array

extension Array: Emptyable {
    static func empty() -> [Element] {
        []
    }
}

// MARK: - Set

extension Set: Emptyable {
    static func empty() -> Set<Element> {
        []
    }
}

// MARK: - Data

extension Data: Emptyable {
    static func empty() -> Data {
        .init()
    }
}
