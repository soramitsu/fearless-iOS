import UIKit

public final class SoramitsuTableViewSpacerItem: NSObject {

	private let space: CGFloat

	public var backgroundColor: SoramitsuColor

    public init(space: CGFloat, color: SoramitsuColor = .bgSurface) {
		self.space = space
		backgroundColor = color
	}

}

extension SoramitsuTableViewSpacerItem: SoramitsuTableViewItemProtocol {
	public var cellType: AnyClass {
		SoramitsuCell<SoramitsuTableViewSpaceView>.self
	}

	public func itemHeight(forWidth width: CGFloat, context: SoramitsuTableViewContext?) -> CGFloat {
		return space
	}
}
