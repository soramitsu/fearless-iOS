import CoreGraphics

 public enum Padding {

	@objc public enum Horizontal: Int, CaseIterable {
		case zero
		case smallest
		case molecule
		case edge

		public var value: CGFloat {
			return SoramitsuUI.shared.style.layout.value(horizontalPadding: self)
		}
	}

	@objc public enum Vertical: Int, CaseIterable {
		case zero
		case smallest
		case atom
		case molecule
		case organism
        
		public var value: CGFloat {
			return SoramitsuUI.shared.style.layout.value(verticalPadding: self)
		}
	}
}
