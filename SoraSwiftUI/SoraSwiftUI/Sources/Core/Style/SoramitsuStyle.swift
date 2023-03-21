import Foundation

final class SoramitsuStyle {

	private(set) var palette: Palette
	private(set) var statusBar: StatusBarStyleValues
    private(set) var radii: Radii
    private(set) var shady: Shady
    private(set) var layout: SoramitsuLayout

	private var observers = NSHashTable<SoramitsuObserver>.weakObjects()
	private var paletteObservers: NSMapTable<AnyObject, NSMutableArray> = NSMapTable.weakToStrongObjects()

	init(palette: Palette,
         radii: Radii,
         shady: Shady,
         layout: SoramitsuLayout,
		 statusBar: StatusBarStyleValues) {
		self.palette = palette
        self.radii = radii
        self.shady = shady
        self.layout = layout
		self.statusBar = statusBar
	}

	func apply(_ palette: Palette) {
		self.palette = palette
		notifyObservers(with: .palette)
	}

	func apply(_ statusBar: StatusBarStyleValues) {
		self.statusBar = statusBar
		notifyObservers(with: .statusBar)
	}

	func addPaletteObserver(_ observer: AnyObject, handler: @escaping (() -> Void)) {
		if paletteObservers.object(forKey: observer) == nil {
			paletteObservers.setObject([], forKey: observer)
		}
		paletteObservers.object(forKey: observer)?.add(handler)
	}

	private func notifyObservers(with options: UpdateOptions) {
		for observer in observers.allObjects {
			observer.styleDidChange(options: options)
		}

		if options.contains(.palette) {
			guard let safePaletteObservers = paletteObservers.copy() as? NSMapTable<AnyObject, NSMutableArray> else { return }
			for observer in safePaletteObservers.keyEnumerator() {
				safePaletteObservers.object(forKey: observer as AnyObject)?
					.compactMap { $0 as? () -> Void }
					.forEach { $0() }
			}
		}
	}
}

extension SoramitsuStyle: SoramitsuObservable {

	func addObserver(_ observer: SoramitsuObserver) {
		observers.add(observer)
	}

	func removeObserver(_ observer: SoramitsuObserver) {
		observers.remove(observer)
	}
}
