import UIKit

public enum ElementType {
	case atom
	case molecule
	case organism
}

public protocol Element: UIResponder {
	associatedtype ConfigurationType
	var sora: ConfigurationType { get }
	var elementType: ElementType { get }
}
