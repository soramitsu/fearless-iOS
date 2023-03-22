public enum AssociationType {
	case add
	case clear
}

public protocol Statable: AnyObject {

	associatedtype StateType: Hashable

	var stater: SoramitsuStateDecorator<Self, StateType> { get }

	func associate(states: StateType...,
					type: AssociationType,
					with action: @escaping ((_ g: Self) -> Void))

	func update(to state: StateType, animated: Bool)

	func removeAllAssociations()
}

public extension Statable {

	func associate(states: StateType...,
		type: AssociationType = .add,
		with action: @escaping ((_ g: Self) -> Void)) {
		stater.associate(states: states, type: type, with: action)
	}

	func update(to state: StateType, animated: Bool) {
		stater.update(to: state, animated: animated)
	}

	func removeAllAssociations() {
		stater.removeAllAssociations()
	}
}

public final class SoramitsuStateDecorator<ConfigurationType: AnyObject, StateType: Hashable> {

	public var animationDuration: Double = 0.15

	weak var g: ConfigurationType?

	private(set) var state: StateType

	private(set) var previousState: StateType

	private var statePairs = [StateType: [((g: ConfigurationType) -> Void)]]()

	init(state: StateType) {
		self.state = state
		self.previousState = state
	}

	public func associate(states: [StateType],
						  type: AssociationType = .add,
						  with action: @escaping ((_ g: ConfigurationType) -> Void)) {
		for state in states {
			var actions: [((ConfigurationType) -> Void)]
			switch type {
			case .add:
				actions = statePairs[state] ?? []
				actions.append(action)
			case .clear:
				actions = [action]
			}
			statePairs[state] = actions
			if state == self.state {
				update(to: state)
			}
		}
	}

	public func update(to state: StateType, animated: Bool = true) {
		self.previousState = self.state
		self.state = state
		performActions(for: state, animated: animated)
	}

	public func revertToPreviousState(animated: Bool = true) {
		update(to: previousState, animated: animated)
	}

	func retriggerActionsForCurrentState(animated: Bool = true) {
		performActions(for: state, animated: animated)
	}

	func removeAllAssociations() {
		statePairs.removeAll()
	}

	private func performActions(for state: StateType, animated: Bool) {
		guard let g = g, let actions = statePairs[state] else { return }
		let duration = animated ? animationDuration : 0
		SoramitsuView.animate(withDuration: duration,
					   delay: .zero,
					   options: [.allowUserInteraction, .curveEaseInOut],
					   animations: {
						for action in actions {
							action(g)
						}
		})
	}
}
