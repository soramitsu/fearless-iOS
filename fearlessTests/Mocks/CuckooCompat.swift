import Cuckoo

// Backward-compat helper: allow syntax `when(stub).property.get` used in existing tests
// by overloading `when` to pass through Cuckoo stubbing proxies.
func when<T: Cuckoo.StubbingProxy>(_ stubbing: T) -> T { stubbing }

