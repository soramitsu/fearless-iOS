import UIKit
import Charts
import SnapKit

final class FWBarChartView: BarChartView {
    weak var chartDelegate: FWChartViewDelegate?

    let xAxisEmptyFormatter = FWXAxisEmptyValueFormatter()
    let xAxisLegend = FWXAxisChartLegendView()
    private var xAxisLegendLeadingInsetConstraint: Constraint!
    let yAxisFormatter = FWYAxisChartFormatter(hideMiddleLabels: true)

    private let averageAmountLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorGreen()
        label.font = .systemFont(ofSize: 9, weight: .semibold)
        label.numberOfLines = 2
        return label
    }()

    private var averageLabelHeightPercent: Double?
    private let averageLineLayer: CAShapeLayer = {
        let shapeLayer = CAShapeLayer()
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeColor = R.color.colorGreen()!.cgColor
        shapeLayer.lineWidth = 1
        shapeLayer.lineJoin = CAShapeLayerLineJoin.round
        shapeLayer.lineDashPattern = [3, 3]
        shapeLayer.lineWidth = 0.5
        return shapeLayer
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        delegate = self
        backgroundColor = .clear
        chartDescription.enabled = false

        autoScaleMinMaxEnabled = true
        doubleTapToZoomEnabled = false
        drawBarShadowEnabled = false
        drawValueAboveBarEnabled = false
        highlightFullBarEnabled = false
        pinchZoomEnabled = false
        scaleXEnabled = false
        scaleYEnabled = false
        dragYEnabled = false

        xAxis.drawGridLinesEnabled = false
        xAxis.labelPosition = .bottom
        xAxis.valueFormatter = xAxisEmptyFormatter

        extraTopOffset = 4

        leftAxis.spaceTop = 0
        leftAxis.yOffset = 0
        leftAxis.forceLabelsEnabled = true
        leftAxis.drawGridLinesEnabled = false
        leftAxis.drawAxisLineEnabled = false
        leftAxis.valueFormatter = yAxisFormatter
        leftAxis.labelFont = .systemFont(ofSize: 9, weight: .semibold)
        leftAxis.labelTextColor = R.color.colorWhite()!.withAlphaComponent(0.64)
        leftAxis.axisMinimum = 0

        rightAxis.enabled = false
        drawBordersEnabled = false
        minOffset = 0
        legend.enabled = false

        noDataText = ""

        addSubview(xAxisLegend)
        xAxisLegend.snp.makeConstraints { make in
            xAxisLegendLeadingInsetConstraint = make.leading.equalToSuperview().constraint
            xAxisLegendLeadingInsetConstraint.activate()
            make.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }

        addSubview(averageAmountLabel)
        layer.insertSublayer(averageLineLayer, at: 0)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        setupAverageLine()
    }

    func setupAverageLine() {
        guard let percent = averageLabelHeightPercent, percent > .leastNonzeroMagnitude else {
            averageAmountLabel.isHidden = true
            averageLineLayer.isHidden = true
            return
        }

        let actualXLegendHeight = xAxisLegend.bounds.height + 5
        let chartHeightWihoutXLegend = bounds.height - actualXLegendHeight
        let yPosition = CGFloat(1.0 - percent) * chartHeightWihoutXLegend
        let avgLabelSize = averageAmountLabel.intrinsicContentSize
        let avgLabelHeight = avgLabelSize.height
        var avgLabelYPosition: CGFloat = yPosition - avgLabelHeight / 2
        if percent < 0.1 || percent > 0.9 {
            avgLabelYPosition = yPosition - avgLabelHeight
        }
        averageAmountLabel.frame = CGRect(
            origin: CGPoint(x: 0, y: avgLabelYPosition),
            size: CGSize(width: avgLabelSize.width, height: avgLabelHeight)
        )
        averageAmountLabel.isHidden = false

        let legendLeadingInset = bounds.width - viewPortHandler.contentWidth
        xAxisLegendLeadingInsetConstraint.update(inset: legendLeadingInset)

        averageLineLayer.isHidden = false
        let path = CGMutablePath()
        path.move(to: CGPoint(x: averageAmountLabel.frame.maxX, y: yPosition))
        path.addLine(to: CGPoint(x: bounds.maxX, y: yPosition))
        averageLineLayer.path = path
    }
}

extension FWBarChartView: FWChartViewProtocol {
    func setChartData(_ data: ChartData, animated: Bool) {
        let dataEntries = data.amounts.enumerated().map { index, amount in
            BarChartDataEntry(x: Double(index), yValues: [amount.value])
        }

        let chartDataContainsSelectedBar = data.amounts.contains(where: { $0.selected == true })
        let realAmounts = data.amounts.map { chartAmount -> Double in
            if chartDataContainsSelectedBar {
                return chartAmount.value
            } else {
                return chartAmount.filled ? chartAmount.value : 0.0
            }
        }

        if
            let averageAmountValue = data.averageAmountValue,
            let min = realAmounts.min(),
            let max = realAmounts.max() {
            if max == min {
                averageLabelHeightPercent = 1.0
            } else {
                averageLabelHeightPercent = (averageAmountValue - min) / (max - min)
            }
        } else {
            averageLabelHeightPercent = nil
        }
        averageAmountLabel.text = data.averageAmountText
        setNeedsLayout()

        let set = BarChartDataSet(entries: dataEntries)
        set.highlightColor = R.color.colorPink()!
        set.drawIconsEnabled = false
        set.drawValuesEnabled = false
        set.colors = data.amounts.map { chartData in
            if chartData.selected {
                return R.color.colorPink()!
            } else {
                if chartDataContainsSelectedBar {
                    return R.color.colorAlmostBlack()!
                } else {
                    return chartData.filled ? R.color.colorPink()! : R.color.colorGray()!
                }
            }
        }

        xAxisLegend.setValues(data.xAxisValues)
        yAxisFormatter.bottomValueString = data.bottomYValue

        let barChartData = BarChartData(dataSet: set)
        barChartData.barWidth = 0.4

        self.data = barChartData
        if animated {
            animate(yAxisDuration: 0.3, easingOption: .easeInOutCubic)
        }
    }
}

extension FWBarChartView: ChartViewDelegate {
    func chartValueSelected(_: ChartViewBase, entry: ChartDataEntry, highlight _: Highlight) {
        chartDelegate?.didSelectXValue(entry.x)
    }

    func chartValueNothingSelected(_: ChartViewBase) {
        chartDelegate?.didUnselect()
    }
}
