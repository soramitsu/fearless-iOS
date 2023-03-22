public protocol SoramitsuTableViewObserver: AnyObject {
	func didSelectRow(at indexPath: IndexPath)
    func didMoveRow(at sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath)
}
