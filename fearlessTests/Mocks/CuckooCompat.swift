import Cuckoo

// Backward-compat helpers for Cuckoo stubbing syntax across versions.
// 1) Legacy style support: `when(stub).method(...)` — return the input unchanged to allow chaining.
public func when<T>(_ stubbing: T) -> T { stubbing }

// 2) Modern style passthrough: `when(stub.method(...))` — match Cuckoo's signature and forward the value unchanged.
public func when<F>(_ function: F) -> F where F: Cuckoo.BaseStubFunctionTrait { function }
