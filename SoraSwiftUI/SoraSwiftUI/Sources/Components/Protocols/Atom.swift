public protocol Atom: Element {}

extension Atom {
	public var elementType: ElementType {
		return .atom
	}
}
