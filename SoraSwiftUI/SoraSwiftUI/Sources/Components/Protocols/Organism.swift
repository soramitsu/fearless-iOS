public protocol Organism: Element {}

extension Organism {
	public var elementType: ElementType {
		return .organism
	}
}
