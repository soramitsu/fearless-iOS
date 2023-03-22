
enum PagePosition {
	case bottom
	case top
}

protocol SoramitsuTableViewPaginatorDelegate: AnyObject {

	func endRefreshing()

	func addLoadingIndicator(position: PagePosition)

	func removeLoadingIndicator(position: PagePosition)

	func appendSections(_ sections: [SoramitsuTableViewSectionProtocol], position: PagePosition)

	func appendItems(_ items: [SoramitsuTableViewItemProtocol], position: PagePosition)

	func addItemsOnTop(_ items: [SoramitsuTableViewItemProtocol], position: PagePosition)

	func reloadEmptyView()
}

final class SoramitsuTableViewPaginator {

	var delegate: SoramitsuTableViewPaginatorDelegate? {
		set {
			bottomPagination?.delegate = newValue
			topPagination?.delegate = newValue
		}
		get {
			return bottomPagination?.delegate
		}
	}

	private var topPagination: SoramitsuTableViewTopPagination?
	private var bottomPagination: SoramitsuTableViewBasicPagination?

	init(handler: SoramitsuTableViewPaginationHandlerProtocol) {
		switch handler.paginationType {
		case .both:
			bottomPagination = SoramitsuTableViewBasicPagination(handler: handler)
			topPagination = SoramitsuTableViewTopPagination(handler: handler)
		case .bottom:
			bottomPagination = SoramitsuTableViewBasicPagination(handler: handler)
		}
	}

	func start() {
		bottomPagination?.requestNextPage()
		topPagination?.requestNextPage()
	}

	func appendPageOnTop(with items: [SoramitsuTableViewItemProtocol]) {
		if topPagination != nil {
			topPagination?.appendPageOnTop(with: items)
			return
		}
		bottomPagination?.appendPageOnTop(with: items)
	}

	func requestNextPageIfAvailable(pageType: PagePosition) {
		switch pageType {
		case .bottom:
			if bottomPagination?.pageAvailable == true {
				bottomPagination?.requestNextPage()
			}
		case .top:
			if topPagination?.pageAvailable == true {
				topPagination?.requestNextPage()
			}
		}
	}
}
