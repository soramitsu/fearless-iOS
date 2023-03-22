import UIKit

public typealias SoramitsuTableViewContext = SoramitsuScrollViewContext<SoramitsuTableView>

//public typealias SoramitsuCollectionViewContext = SoramitsuScrollViewContext<SoramitsuCollectionView>

public class SoramitsuScrollViewContext<ScrollView: UIScrollView & Molecule> {

	public weak var scrollView: ScrollView?

	public weak var viewController: UIViewController?

	public lazy var userInfo: NSMutableDictionary = [:]

	public init(scrollView: ScrollView? = nil, viewController: UIViewController? = nil) {
		self.scrollView = scrollView
		self.viewController = viewController
	}
}
