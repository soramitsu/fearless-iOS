import UIKit

open class KeyboardEventsListnerHelper {

	public typealias Action = (Notification) -> Void

	private var observerTokens: [NSObjectProtocol]?

	private enum KeyboardState: CaseIterable {

		case hidden
		case appearing
		case shown
		case disappearing
	}

	private var keyboardState = KeyboardState.hidden

	public init(willShowAction: Action? = nil, didShowAction: Action? = nil, willHideAction: Action? = nil, didHideAction: Action? = nil) {
		assert(willShowAction != nil || didShowAction != nil || willHideAction != nil || didHideAction != nil, "No arguments passed")
		let entities = [UIResponder.keyboardWillShowNotification: actionWrapper(allowedStates: [.hidden],
																		   newState: .appearing,
																		   originalAction: willShowAction),
						UIResponder.keyboardDidShowNotification: actionWrapper(allowedStates: [.disappearing, .appearing],
																		  newState: .shown,
																		  originalAction: didShowAction),
						UIResponder.keyboardWillHideNotification: actionWrapper(allowedStates: [.appearing, .shown],
																		   newState: .disappearing,
																		   originalAction: willHideAction),
						UIResponder.keyboardDidHideNotification: actionWrapper(allowedStates: [.disappearing],
																		  newState: .hidden,
																		  originalAction: didHideAction)]
		observerTokens = entities.map { name, action in
			return NotificationCenter.default.addObserver(forName: name,
														  object: nil,
														  queue: .main,
														  using: action)
		}
	}

	private func actionWrapper(allowedStates: [KeyboardState], newState: KeyboardState, originalAction: Action?) -> Action {
		return { [weak self] notification in
			guard let self = self else { return }
			if allowedStates.contains(self.keyboardState) {
				originalAction?(notification)
				self.keyboardState = newState
			}
		}
	}

	deinit {
		observerTokens?.forEach { NotificationCenter.default.removeObserver($0) }
	}
}
