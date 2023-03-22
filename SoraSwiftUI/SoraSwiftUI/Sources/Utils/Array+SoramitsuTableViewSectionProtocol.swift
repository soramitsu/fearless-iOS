extension Array where Element == SoramitsuTableViewSectionProtocol {

	func indexPath(of item: SoramitsuTableViewItemProtocol) -> IndexPath? {
		for pair in enumerated() {
			guard let index = pair.element.rows.firstIndex(where: { row in row.isEqual(item) }) else {
				continue
			}
			return IndexPath(row: index, section: pair.offset)
		}
		return nil
	}

	func item(for indexPath: IndexPath) -> SoramitsuTableViewItemProtocol? {
		guard indexPath.section < count, indexPath.row < self[indexPath.section].rows.count else {
			return nil
		}
		return self[indexPath.section].rows[indexPath.row]
	}
}
