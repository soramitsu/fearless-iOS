import SwiftUI

/// Shikiban motion: the duration ladder and easings of the brand kit.
/// Durations are 90, 128, 180, 255, 360, 510, 720 and 1020 ms and nothing else.
public enum BrandMotion {
    public static let d90: Double = 0.090
    public static let d128: Double = 0.128
    public static let d180: Double = 0.180
    public static let d255: Double = 0.255
    public static let d360: Double = 0.360
    public static let d510: Double = 0.510
    public static let d720: Double = 0.720
    public static let d1020: Double = 1.020

    /// Decelerating arrival (`easing.settle`).
    public static func settle(_ duration: Double = d360) -> Animation {
        .timingCurve(0.05, 0.7, 0.1, 1, duration: duration)
    }

    /// Accelerating exit (`easing.depart`).
    public static func depart(_ duration: Double = d128) -> Animation {
        .timingCurve(0.3, 0, 1, 1, duration: duration)
    }

    /// Movement between two resting places (`easing.glide`).
    public static func glide(_ duration: Double = d255) -> Animation {
        .timingCurve(0.4, 0, 0.2, 1, duration: duration)
    }
}

private struct StaticRenderingKey: EnvironmentKey {
    static let defaultValue = false
}

private struct BalancesHiddenKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    /// True when views must draw their final state without animating
    /// (snapshot rendering). Reduce Motion is honoured separately.
    var staticRendering: Bool {
        get { self[StaticRenderingKey.self] }
        set { self[StaticRenderingKey.self] = newValue }
    }

    /// Privacy mode: every amount is masked.
    var balancesHidden: Bool {
        get { self[BalancesHiddenKey.self] }
        set { self[BalancesHiddenKey.self] = newValue }
    }
}

/// Reads Reduce Motion and the snapshot flag as one answer.
@propertyWrapper
public struct MotionAllowed: DynamicProperty {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.staticRendering) private var staticRendering

    public init() {}

    public var wrappedValue: Bool { !reduceMotion && !staticRendering }
}
