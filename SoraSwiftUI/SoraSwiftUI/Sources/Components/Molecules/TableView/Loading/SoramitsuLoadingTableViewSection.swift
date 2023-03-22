import CoreGraphics

public final class SoramitsuLoadingTableViewSection: SoramitsuTableViewSection {

	public init(rowsCount: Int,
				height: CGFloat,
				type: SoramitsuLoadingPlaceholderType = .shimmer,
				insets: SoramitsuInsets = SoramitsuInsets(all: 16)) {
		let rows = Array(0..<rowsCount).map { _ in SoramitsuLoadingTableViewItem(height: height, type: type, insets: insets) }
		super.init(rows: rows)
	}
}
