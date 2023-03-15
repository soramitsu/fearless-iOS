@objc
public protocol SoramitsuObserver {
	@objc
    func styleDidChange(options: UpdateOptions)
}

@objc
public protocol SoramitsuObservable {
	func addObserver(_ observer: SoramitsuObserver)
	func removeObserver(_ observer: SoramitsuObserver)
}
