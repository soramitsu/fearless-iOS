import UIKit

open class SoramitsuBaseViewController: UIViewController, ObservableViewController {

	public let soramitsuView: SoramitsuView

	public private(set) var lifeCycleState: SoramitsuViewControllerLifeCycleState = .initial {
		didSet {
			lifeCycleStateDidChangeHandler?(lifeCycleState)
		}
	}

	var lifeCycleStateDidChangeHandler: ((SoramitsuViewControllerLifeCycleState) -> Void)?

	init(style: SoramitsuStyle) {
        soramitsuView = SoramitsuView(style: style, frame: UIScreen.main.bounds)
		super.init(nibName: nil, bundle: nil)

		setupViews()
	}

	@available(*, unavailable)
	required public init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
	@available(*, unavailable)
	public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
		fatalError("init has not been implemented")
	}

	open override func loadView() {
		view = soramitsuView
	}

	public func presentAnimations() {
		// определить в наследниках
	}

	public func dismissAnimations() {
		// определить в наследниках
	}

	private func setupViews() {
        soramitsuView.sora.backgroundColor = .accentPrimary
        soramitsuView.sora.useAutoresizingMask = true
	}
}

// MARK: - Life Cycle

extension SoramitsuBaseViewController {
	open override func viewDidLoad() {
		super.viewDidLoad()
		lifeCycleState = .loaded
	}

	open override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		lifeCycleState = .appearing
	}

	open override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		lifeCycleState = .appeared
	}

	open override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		lifeCycleState = .disappearing
	}

	open override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		lifeCycleState = .disappeared
	}
}
