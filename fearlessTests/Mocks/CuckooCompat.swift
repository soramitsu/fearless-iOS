import Foundation
import Cuckoo

// Compatibility shim for legacy Cuckoo stubbing style used in tests:
// Allows `when(stub).someMethod()` by overloading `when` to accept a stubbing proxy
// and return it unchanged, so the following member call returns a BaseStubFunctionTrait.
@inlinable
public func when<P: Cuckoo.StubbingProxy>(_ proxy: P) -> P { proxy }

