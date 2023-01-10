import UIKit

public final class SoramitsuLoadingTableViewCell: UITableViewCell {

	private let view: SoramitsuView = {
		let view = SoramitsuView(style: SoramitsuUI.shared.style)
        view.sora.backgroundColor = .custom(uiColor: .clear)
		view.sora.cornerRadius = .medium
		return view
	}()
	private var heightConstraint: NSLayoutConstraint?

	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		setupViews()
	}

	required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

	private func setupViews() {
		addSubview(view)
		backgroundColor = .clear
		view.pinToSuperView(respectingSafeArea: false)
	}
}

extension SoramitsuLoadingTableViewCell: SoramitsuTableViewCellProtocol {
	public func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
		guard let item = item as? SoramitsuLoadingTableViewItem else { return }
		view.sora.loadingPlaceholder.type = item.placeholderType
		view.sora.cornerRadius = item.cornerRadius
		removeAllConstraints()
		view.pinToSuperView(insets: item.insets, respectingSafeArea: false)
		rebuildLayout()
	}
}
