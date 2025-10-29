import Cuckoo

// Backward-compat helper: allow legacy syntax `when(stub).property.get` and
// pass-through for modern calls `when(stub.method(...))` by returning the input unchanged.
public func when<T>(_ stubbing: T) -> T { stubbing }
