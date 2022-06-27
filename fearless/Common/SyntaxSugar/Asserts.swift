import Foundation

func assertNotNil(_ object: Any?) {
    assert(object != nil)
}

func assertNotNil(_ object: Any?, _ message: String) {
    assert(object != nil, message)
}

func assertNil(_ object: Any?) {
    assert(object == nil)
}

func assertNil(_ object: Any?, _ message: String) {
    assert(object == nil, message)
}
