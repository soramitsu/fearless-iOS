func retrigger<Object: AnyObject, Value>(_ object: Object, _ keyPath: ReferenceWritableKeyPath<Object, Value>) {
	object[keyPath: keyPath] = object[keyPath: keyPath]
}
