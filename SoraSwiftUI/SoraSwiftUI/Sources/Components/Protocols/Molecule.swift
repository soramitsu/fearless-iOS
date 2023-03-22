public protocol Molecule: Element {}

extension Molecule {
	public var elementType: ElementType {
		return .molecule
	}
}
