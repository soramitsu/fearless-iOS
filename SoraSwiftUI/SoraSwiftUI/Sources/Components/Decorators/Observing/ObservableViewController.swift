public enum SoramitsuViewControllerLifeCycleState {

	case initial

	case loaded

	case appearing

	case appeared

	case disappearing

	case disappeared
}

protocol ObservableViewController {


	var lifeCycleState: SoramitsuViewControllerLifeCycleState { get }


	var lifeCycleStateDidChangeHandler: ((SoramitsuViewControllerLifeCycleState) -> Void)? { get set }
}
