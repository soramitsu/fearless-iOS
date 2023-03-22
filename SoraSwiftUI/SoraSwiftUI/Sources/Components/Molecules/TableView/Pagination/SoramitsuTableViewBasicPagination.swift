class SoramitsuTableViewBasicPagination {

	private struct Consts {
		static let firstPage = 0
	}

	weak var delegate: SoramitsuTableViewPaginatorDelegate?
	weak var handler: SoramitsuTableViewPaginationHandlerProtocol?

	var pageNumber = Consts.firstPage
	var pagePosition: PagePosition = .bottom
	var pageAvailable = false

	init(handler: SoramitsuTableViewPaginationHandlerProtocol) {
		self.handler = handler
	}

	func requestNextPage() {
		delegate?.addLoadingIndicator(position: pagePosition)
		pageAvailable = false
		handler?.didRequestNewPage(with: pageNumber) { [weak self] result in
			DispatchQueue.mainAsyncIfNeeded {
				self?.handlePagingResponse(result)
			}
		}
	}

	func incrementPage() {
		pageNumber += 1
	}

	func isFirstPage() -> Bool {
		return pageNumber == Consts.firstPage
	}

	func appendPageOnTop(with items: [SoramitsuTableViewItemProtocol]) {
		if isFirstPage() {
			pageAvailable = true
			delegate?.appendSections([SoramitsuTableViewSection(rows: items)], position: pagePosition)
		} else {
			delegate?.addItemsOnTop(items, position: pagePosition)
		}
		incrementPage()
	}

	private func handlePagingResponse(_ result: NextPageLoadResult) {
		switch result {
		case let .loadingSuccessWithSections(sections, hasNextPage):
			if sections.isEmpty {
				pageAvailable = false
				delegate?.reloadEmptyView()
			} else {
				pageAvailable = hasNextPage
				delegate?.appendSections(sections, position: pagePosition)
				incrementPage()
			}
		case let .loadingSuccessWithItems(items, hasNextPage):
			if items.isEmpty {
				pageAvailable = false
				delegate?.reloadEmptyView()
			} else {
				pageAvailable = hasNextPage
				appendItems(items)
				incrementPage()
			}
		case let .loadingSuccessWith(items: items, sections: sections, hasNextPage: hasNextPage):
			if sections.isEmpty && items.isEmpty {
				pageAvailable = false
				delegate?.reloadEmptyView()
			} else {
				pageAvailable = hasNextPage
				appendItems(items)
				delegate?.appendSections(sections, position: pagePosition)
				incrementPage()
			}
		case .loadingFailure:
			pageAvailable = true
		}
		delegate?.removeLoadingIndicator(position: pagePosition)
		delegate?.endRefreshing()
	}

	private func appendItems(_ items: [SoramitsuTableViewItemProtocol]) {
		if isFirstPage() {
			delegate?.appendSections([SoramitsuTableViewSection(rows: items)], position: pagePosition)
		} else {
			delegate?.appendItems(items, position: pagePosition)
		}
	}
}
