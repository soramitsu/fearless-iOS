public class SoramitsuConfiguration<Type: AnyObject & Hashable>: SoramitsuObserver {

	public var meta = [String: Any]()

	weak var owner: Type? {
		didSet {
			configureOwner()
		}
	}

	let style: SoramitsuStyle
	var palette: Palette { style.palette }
	var radii: Radii { style.radii }
	var shady: Shady { style.shady }
	var statusBar: StatusBarStyleValues { style.statusBar }

	private var ownerHashValue = 0
	private var ownerRelatedBlocks = [String: () -> Void]()

	init(style: SoramitsuStyle) {
		self.style = style
		style.addObserver(self)

		MainThreadChecker.default.check()
	}

	deinit {
		ownerRelatedBlocks.values.forEach { $0() }
		style.removeObserver(self)
	}

	public func styleDidChange(options: UpdateOptions) {}

	func configureOwner() {
		if let owner = owner {
			ownerHashValue = owner.hashValue
		} else {
			ownerRelatedBlocks.values.forEach { $0() }
		}
	}

	public func addOwnerRelatedBlock(for key: String, block: @escaping () -> Void) {
		ownerRelatedBlocks[key] = block
	}

	public func removeOwnerRelatedBlock(for key: String) {
		ownerRelatedBlocks[key] = nil
	}
}

extension SoramitsuConfiguration: Hashable {
	public static func == (lhs: SoramitsuConfiguration<Type>, rhs: SoramitsuConfiguration<Type>) -> Bool {
		return lhs.owner == rhs.owner
	}

	public func hash(into hasher: inout Hasher) {
		hasher.combine(ownerHashValue)
	}
}
