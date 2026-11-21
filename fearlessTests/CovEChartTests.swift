@testable import fearless
import UIKit
import XCTest

/// The Charts pod is not on the test target's framework search path (`import Charts` resolves to Apple's Swift Charts),
/// so these tests reach the chart views through the app's own protocols and read Charts state through the
/// Objective-C runtime instead of naming Charts types.
@MainActor
final class CovEChartTests: XCTestCase {
    func testLineChartHandlesEmptySingleAndMultipleAmountsAndSelection() throws {
        let header = AnalyticsStakeHeaderView(frame: .zero)
        var chart = header.chartView
        let delegate = CovEChartDelegate()
        chart.chartDelegate = delegate
        let window = host(chart, size: CGSize(width: 350, height: 200))
        defer { CovEHost.close(window) }
        let probe = CovEChartProbe(chart: chart)

        chart.setChartData(data([]), animated: false)
        XCTAssertEqual(probe.yValues(), [0], "an empty series is drawn as one zero point")
        chart.setChartData(data([3]), animated: true)
        XCTAssertEqual(probe.yValues(), [3, 3], "a single amount is drawn as a flat line")
        XCTAssertEqual(probe.bool("leftAxis.isAxisMinCustom"), false)
        chart.setChartData(data([0, 2, 4]), animated: false)
        XCTAssertEqual(probe.yValues(), [0, 2, 4])
        XCTAssertEqual(probe.bool("leftAxis.isAxisMinCustom"), true, "a zero amount pins the axis minimum")
        XCTAssertEqual(probe.double("leftAxis.axisMinimum"), 0)
        XCTAssertEqual(probe.dataSetBool("isDrawFilledEnabled"), true)
        XCTAssertEqual(probe.dataSetBool("isDrawCirclesEnabled"), false)
        XCTAssertEqual(probe.bool("rightAxis.enabled"), false)
        XCTAssertEqual(probe.colors(), [R.color.colorPink()])

        let legend = try XCTUnwrap(CovEFind.first(FWXAxisChartLegendView.self, in: chart))
        XCTAssertEqual(CovEFind.texts(in: legend), ["Mon", "Tue"])
        XCTAssertEqual(probe.format(0, formatterKey: "yAxisFormatter"), "0 DOT")
        XCTAssertEqual(probe.format(3, formatterKey: "yAxisFormatter").flatMap(Double.init), 3)
        XCTAssertEqual(probe.format(3, formatterKey: "xAxisEmptyFormatter"), "")

        try probe.select(x: 2)
        try probe.clearSelection()
        XCTAssertEqual(delegate.selected, [2])
        XCTAssertEqual(delegate.unselected, 1)
    }

    func testBarsReflectFilledAndSelectedAmountsAndPositionTheAverage() throws {
        let widget = RewardAnalyticsWidgetView(frame: .zero)
        var chart = widget.barChartView
        let delegate = CovEChartDelegate()
        chart.chartDelegate = delegate
        let window = host(chart, size: CGSize(width: 350, height: 200))
        defer { CovEHost.close(window) }
        let probe = CovEChartProbe(chart: chart)
        let average = try XCTUnwrap(CovEFind.mirror(chart, "averageAmountLabel", as: UILabel.self))

        for selected in [false, true] {
            let amounts = [
                ChartAmount(value: 2, selected: selected, filled: true),
                ChartAmount(value: 6, selected: false, filled: false)
            ]
            chart.setChartData(fearless.ChartData(
                amounts: amounts,
                xAxisValues: ["A", "B"],
                bottomYValue: "0 DOT",
                averageAmountValue: 3,
                averageAmountText: "AVG 3"
            ), animated: selected)
            chart.layoutIfNeeded()
            XCTAssertEqual(probe.yValues(), [2, 6])
            XCTAssertEqual(probe.colors(), [R.color.colorPink(), selected ? R.color.colorAlmostBlack() : R.color.colorGray()])
            XCTAssertEqual(average.text, "AVG 3")
            XCTAssertFalse(average.isHidden)
            XCTAssertGreaterThan(average.bounds.width, 0)
            let line = try XCTUnwrap(CovEFind.mirror(chart, "averageLineLayer", as: CAShapeLayer.self))
            XCTAssertFalse(line.isHidden, "the dashed average line is shown with the label")
            XCTAssertNotNil(line.path)
        }

        chart.setChartData(data([5, 5], average: 5), animated: false)
        chart.layoutIfNeeded()
        XCTAssertFalse(average.isHidden, "equal amounts put the average on top")
        chart.setChartData(data([1, 9], average: 1.2), animated: false)
        chart.layoutIfNeeded()
        XCTAssertFalse(average.isHidden, "an average near the bottom is lifted above the line")
        chart.setChartData(data([]), animated: false)
        chart.layoutIfNeeded()
        XCTAssertTrue(average.isHidden, "no amounts hide the average")

        chart.setChartData(data([2, 6], average: nil), animated: false)
        chart.layoutIfNeeded()
        XCTAssertTrue(average.isHidden)
        try probe.select(x: 1)
        try probe.clearSelection()
        XCTAssertEqual(delegate.selected, [1])
        XCTAssertEqual(delegate.unselected, 1)
        XCTAssertEqual(probe.format(0, formatterKey: "yAxisFormatter", axisKey: "leftAxis"), "0 DOT")
        XCTAssertEqual(probe.format(3, formatterKey: "yAxisFormatter"), "", "middle labels are hidden on bars")
        let top = try XCTUnwrap(probe.doubles("leftAxis.entries").max())
        XCTAssertEqual(probe.format(top, formatterKey: "yAxisFormatter", axisKey: "leftAxis")?.isEmpty, false)
    }

    func testPieChartShowsInactiveSegmentAndHighlightsSegments() throws {
        let header = AnalyticsValidatorsHeaderView(frame: .zero)
        let view = try XCTUnwrap(CovEFind.all(UIView.self, in: header).first { $0 is FWPieChartViewProtocol })
        let chart = try XCTUnwrap(view as? FWPieChartViewProtocol)
        let window = host(view, size: CGSize(width: 200, height: 200))
        defer { CovEHost.close(window) }
        let probe = CovEChartProbe(chart: view)

        chart.setAmounts(segmentValues: [2, 3], inactiveSegmentValue: 5, animated: true)
        XCTAssertEqual(probe.int("data.entryCount"), 3)
        XCTAssertEqual(probe.colors(), [R.color.colorPink(), R.color.colorPink(), R.color.colorDarkGray()])
        XCTAssertEqual(probe.double("holeRadiusPercent"), 0.85)

        let title = NSAttributedString(string: "10 DOT")
        chart.setCenterText(title)
        XCTAssertEqual(view.value(forKey: "centerAttributedText") as? NSAttributedString, title)

        chart.highlightSegment(index: 1)
        XCTAssertEqual(probe.highlightedX(), [1])
        try probe.clearSelection()
        XCTAssertEqual(probe.highlightedX(), [])

        chart.setAmounts(segmentValues: [7], inactiveSegmentValue: nil, animated: false)
        XCTAssertEqual(probe.int("data.entryCount"), 1)
        XCTAssertEqual(probe.colors(), [R.color.colorPink()])
    }

    func testAxisLegendSpreadsValuesAcrossTheWidth() {
        let legend = FWXAxisChartLegendView()
        let window = CovEHost.window(for: legend, frame: CGRect(x: 0, y: 0, width: 300, height: 20))
        defer { CovEHost.close(window) }
        legend.setValues(["Jan", "Feb", "Mar"])
        legend.layoutIfNeeded()
        XCTAssertEqual(CovEFind.texts(in: legend), ["Jan", "Feb", "Mar"])
        let frames = CovEFind.all(UILabel.self, in: legend).map(\.frame.minX)
        XCTAssertEqual(frames, frames.sorted(), "labels are laid out from left to right")
        legend.setValues(["Q1"])
        XCTAssertEqual(CovEFind.texts(in: legend), ["Q1"])
    }

    private func host(_ chart: UIView, size: CGSize) -> UIWindow {
        chart.removeFromSuperview()
        chart.translatesAutoresizingMaskIntoConstraints = true
        return CovEHost.window(for: chart, frame: CGRect(origin: CGPoint(x: 20, y: 100), size: size))
    }

    private func data(_ values: [Double], average: Double? = nil) -> fearless.ChartData {
        fearless.ChartData(
            amounts: values.map { ChartAmount(value: $0, selected: false, filled: true) },
            xAxisValues: ["Mon", "Tue"],
            bottomYValue: "0 DOT",
            averageAmountValue: average,
            averageAmountText: "AVG"
        )
    }
}

/// Reads Charts state with key-value coding and calls Charts selectors through their Objective-C entry points.
@MainActor
struct CovEChartProbe {
    let chart: NSObject

    init(chart: UIView) {
        self.chart = chart
    }

    private var firstDataSet: NSObject? {
        (value(chart, "data.dataSets") as? [NSObject])?.first
    }

    func int(_ path: String) -> Int? { value(chart, path) as? Int }
    func bool(_ path: String) -> Bool? { value(chart, path) as? Bool }
    func double(_ path: String) -> Double? { (value(chart, path) as? NSNumber)?.doubleValue }
    func doubles(_ path: String) -> [Double] { value(chart, path) as? [Double] ?? [] }
    func colors() -> [UIColor?] { (firstDataSet.flatMap { value($0, "colors") } as? [UIColor]) ?? [] }

    func dataSetBool(_ key: String) -> Bool? {
        firstDataSet.flatMap { value($0, key) } as? Bool
    }

    func yValues() -> [Double] {
        guard let set = firstDataSet, let count = value(set, "entryCount") as? Int else { return [] }
        let selector = NSSelectorFromString("entryForIndex:")
        guard set.responds(to: selector) else { return [] }
        typealias Call = @convention(c) (AnyObject, Selector, Int) -> AnyObject?
        let call = unsafeBitCast(set.method(for: selector), to: Call.self)
        return (0 ..< count).compactMap { index in
            (call(set, selector, index) as? NSObject).flatMap { value($0, "y") as? Double }
        }
    }

    func highlightedX() -> [Double] {
        ((value(chart, "highlighted") as? [NSObject]) ?? []).compactMap { value($0, "x") as? Double }
    }

    func select(x: Double) throws {
        let selector = NSSelectorFromString("highlightValueWithX:dataSetIndex:dataIndex:callDelegate:")
        try requireResponds(selector)
        typealias Call = @convention(c) (AnyObject, Selector, Double, Int, Int, Bool) -> Void
        unsafeBitCast(chart.method(for: selector), to: Call.self)(chart, selector, x, 0, -1, true)
    }

    func clearSelection() throws {
        let selector = NSSelectorFromString("highlightValue:callDelegate:")
        try requireResponds(selector)
        typealias Call = @convention(c) (AnyObject, Selector, AnyObject?, Bool) -> Void
        unsafeBitCast(chart.method(for: selector), to: Call.self)(chart, selector, nil, true)
    }

    /// Formats through `stringForValue:axis:`; the empty X formatter is a plain Swift class, so the runtime is used
    /// directly instead of `NSObject` methods.
    func format(_ number: Double, formatterKey: String, axisKey: String? = nil) -> String? {
        guard let formatter = CovEFind.mirror(chart, formatterKey, as: AnyObject.self) else { return nil }
        let selector = NSSelectorFromString("stringForValue:axis:")
        guard
            let type = object_getClass(formatter),
            class_respondsToSelector(type, selector),
            let implementation = class_getMethodImplementation(type, selector)
        else { return nil }
        let axis = axisKey.flatMap { value(chart, $0) as AnyObject? }
        typealias Call = @convention(c) (AnyObject, Selector, Double, AnyObject?) -> NSString
        return unsafeBitCast(implementation, to: Call.self)(formatter, selector, number, axis) as String
    }

    private func requireResponds(_ selector: Selector) throws {
        guard chart.responds(to: selector) else {
            throw CovEChartProbeError.missingSelector(NSStringFromSelector(selector))
        }
    }

    /// Key-value coding that returns nil instead of raising for keys the object does not answer.
    private func value(_ object: NSObject, _ path: String) -> Any? {
        var current: NSObject? = object
        var result: Any?
        for key in path.split(separator: ".").map(String.init) {
            guard let target = current, target.responds(to: NSSelectorFromString(key)) else { return nil }
            result = target.value(forKey: key)
            current = result as? NSObject
        }
        return result
    }
}

enum CovEChartProbeError: Error {
    case missingSelector(String)
}

final class CovEChartDelegate: FWChartViewDelegate {
    private(set) var selected: [Double] = []
    private(set) var unselected = 0

    func didSelectXValue(_ value: Double) {
        selected.append(value)
    }

    func didUnselect() {
        unselected += 1
    }
}
