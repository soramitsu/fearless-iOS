import Foundation

public class CaseInsensitiveResolver: TypeResolving {
    public init() {}

    public func resolve(typeName: String, using availableNames: Set<String>) -> String? {
        availableNames.first { $0.caseInsensitiveCompare(typeName) == .orderedSame }
    }
}
