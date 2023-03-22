protocol Shady {
	var none: ShadowData { get }
	var `default`: ShadowData { get }
    var extraSmall: ShadowData { get }
	var small: ShadowData { get }
}

// #codegen
extension Shady {
	func shadow(_ gShadow: Shadow) -> ShadowData {
		switch gShadow {
		case .none: return none
		case .default: return `default`
		case .small: return small
        case .extraSmall: return extraSmall
		}
	}
}
