import CoreGraphics

public func map(value: CGFloat, startA: CGFloat, endA: CGFloat, startB: CGFloat, endB: CGFloat) -> CGFloat {
	if startA == endA {
		return value > startA ? endB : startB
	}
	return ((value - startA) / (endA - startA)) * (endB - startB) + startB
}

public func clamp(_ value: CGFloat, minValue: CGFloat, maxValue: CGFloat) -> CGFloat {
	return min(maxValue, max(minValue, value))
}
