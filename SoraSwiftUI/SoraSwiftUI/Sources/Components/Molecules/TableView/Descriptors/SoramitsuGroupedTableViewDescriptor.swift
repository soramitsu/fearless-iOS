import CoreGraphics

struct SoramitsuGroupedTableViewDescriptor: SoramitsuElementDescriptor {

	private struct Constants {
		static let headerHeight = CGFloat.leastNonzeroMagnitude
	}

	/// Конфигурироание форм вью
	func configure(_ element: SoramitsuTableView) {
		let header = SoramitsuView(style: element.sora.style)
		header.sora.useAutoresizingMask = true
		header.frame.size.height = Constants.headerHeight
        header.sora.backgroundColor = .custom(uiColor: .clear)
		element.sora.tableViewHeader = header
		element.sectionHeaderHeight = .leastNormalMagnitude
		element.sectionFooterHeight = .leastNormalMagnitude
	}
}
