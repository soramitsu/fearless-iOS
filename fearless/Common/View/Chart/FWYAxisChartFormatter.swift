import Charts

/// Returns Y axis value with custom bottom one, i.e. `0 KSM` or `0 DOT`
class FWYAxisChartFormatter: DefaultAxisValueFormatter {
    let hideMiddleLabels: Bool

    init(hideMiddleLabels: Bool) {
        self.hideMiddleLabels = hideMiddleLabels
        super.init()
    }

    var bottomValueString: String?

    override func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        if let bottomValueString = bottomValueString, value < .leastNonzeroMagnitude {
            return bottomValueString
        }

        if hideMiddleLabels {
            if let axis = axis, axis.entries.max() == value {
                return super.stringForValue(value, axis: axis)
            }
            return ""
        } else {
            return super.stringForValue(value, axis: axis)
        }
    }
}
