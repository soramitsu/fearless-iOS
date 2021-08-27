import Charts

/// Returns Y axis value with custom bottom one, i.e. `0 KSM` or `0 DOT`
class FWYAxisChartFormatter: DefaultAxisValueFormatter {
    var bottomValueString: String?

    override func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        if let bottomValueString = bottomValueString, value < .leastNonzeroMagnitude {
            return bottomValueString
        }
        return super.stringForValue(value, axis: axis)
    }
}
