public extension NSObject {

	func SoramitsuColorable(_ handler: @escaping () -> Void) {
		handler()
		SoramitsuUI.shared.style.addPaletteObserver(self, handler: handler)
	}
}
