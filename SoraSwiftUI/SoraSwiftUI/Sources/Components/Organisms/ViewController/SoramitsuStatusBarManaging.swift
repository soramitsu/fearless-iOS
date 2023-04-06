import UIKit

public protocol SoramitsuStatusBarManaging: AnyObject {

	var statusBarStyle: StatusBarStyle { get set }

	var statusBarHidden: Bool { get set }

	var statusBarUpdateAnimation: UIStatusBarAnimation { get set }
}
