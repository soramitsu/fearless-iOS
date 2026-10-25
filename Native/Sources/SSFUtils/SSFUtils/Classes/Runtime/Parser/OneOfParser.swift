import Foundation

public class OneOfParser: TypeParser {
    public let children: [TypeParser]

    public init(children: [TypeParser]) {
        self.children = children
    }

    public func parse(json: JSON) -> [JSON]? {
        for child in children {
            if let node = child.parse(json: json) {
                return node
            }
        }

        return nil
    }
}
