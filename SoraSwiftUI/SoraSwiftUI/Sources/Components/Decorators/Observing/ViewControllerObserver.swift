import UIKit

final class ViewControllerObserver: NSObject {

	enum ObservationError: Error {
		case unexpectedType
	}

	typealias State = SoramitsuViewControllerLifeCycleState

	private var actions = [State: [() -> Void]]()

	func observe(_ viewController: UIViewController) throws {
		guard var observable = viewController as? ObservableViewController else {
			throw ObservationError.unexpectedType
		}
		observable.lifeCycleStateDidChangeHandler = { [weak self] state in
			self?.actions[state]?.forEach { $0() }
		}
	}

	func addHandler(for states: State..., handler: @escaping () -> Void) {
		Array(states).forEach {
			var stateActions = actions[$0] ?? []
			stateActions.append(handler)
			actions[$0] = stateActions
		}
	}
}
