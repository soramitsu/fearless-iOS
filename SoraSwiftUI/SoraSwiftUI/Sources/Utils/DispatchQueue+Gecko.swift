import Foundation

public extension DispatchQueue {

	static func mainAsyncIfNeeded(_ block: @escaping () -> Void) {
		if Thread.current.isMainThread {
			block()
		} else {
			DispatchQueue.main.async {
				block()
			}
		}
	}

	static func mainSyncIfNeeded(_ block: @escaping() -> Void) {
		if Thread.current.isMainThread {
			block()
		} else {
			DispatchQueue.main.sync {
				block()
			}
		}
	}
}
