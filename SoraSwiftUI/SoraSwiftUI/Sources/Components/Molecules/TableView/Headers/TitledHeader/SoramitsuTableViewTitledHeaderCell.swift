import UIKit

public final class SoramitsuTableViewTitledHeaderCell: UITableViewHeaderFooterView {
	private let soraLabel: SoramitsuLabel = {
		let label = SoramitsuLabel(style: SoramitsuUI.shared.style)
		label.sora.alignment = .left
        label.sora.font = FontType.textL
        label.sora.backgroundColor = .bgSurface
		return label
	}()

	private let backgroundSoraView = SoramitsuView(style: SoramitsuUI.shared.style)

	public override init(reuseIdentifier: String?) {
		super.init(reuseIdentifier: reuseIdentifier)
		self.backgroundView = backgroundSoraView
		addSubview(soraLabel)
	}

	required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

extension SoramitsuTableViewTitledHeaderCell: SoramitsuTableViewCellProtocol {
	public func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
		guard let item = item as? SoramitsuTableViewTitledHeader else {
			assertionFailure("Некорректный тип")
			return
		}

        soraLabel.sora.text = item.title
        soraLabel.sora.font = item.font
        soraLabel.sora.textColor = item.textColor
        soraLabel.sora.alignment = item.textAlignment
        soraLabel.pinToSuperView(insets: item.insets)
        backgroundSoraView.sora.backgroundColor = item.backgroundColor
	}
}
