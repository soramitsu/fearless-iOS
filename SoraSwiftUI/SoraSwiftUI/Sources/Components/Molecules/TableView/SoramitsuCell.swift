import UIKit

public final class SoramitsuCell<Content: SoramitsuTableViewCellProtocol>: SoramitsuTableViewCell {

	public let content = Content()

	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		setup()
	}

	public override func prepareForReuse() {
		super.prepareForReuse()
		content.prepareForReuse()
	}

	public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

	private func setup() {
		addSubview(content)
		content.pinToSuperView(respectingSafeArea: false)
	}
}

extension SoramitsuCell: SoramitsuTableViewCellProtocol {
	public func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
		content.set(item: item, context: context)
	}
}
