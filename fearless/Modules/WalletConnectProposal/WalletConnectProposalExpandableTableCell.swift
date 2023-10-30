import Foundation
import UIKit

final class WalletConnectProposalExpandableTableCell: UITableViewCell {
    private enum Constants {
        static let iconSize = CGSize(width: 12, height: 12)
    }

    let cellStackView: UIStackView = {
        let stackView = UIFactory.default.createVerticalStackView()
        stackView.distribution = .fill
        stackView.alignment = .fill
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0)
        return stackView
    }()

    let visibleStackView: UIStackView = {
        let stackView = UIFactory.default.createHorizontalStackView()
        stackView.distribution = .fillProportionally
        stackView.alignment = .center
        return stackView
    }()

    let visibleTitle: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        return label
    }()

    let expandableAccesoryImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconSmallAdd()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    let expandableBackground: TriangularedView = {
        let view = TriangularedView()
        view.fillColor = R.color.colorSemiBlack()!
        view.highlightedFillColor = R.color.colorSemiBlack()!
        view.strokeColor = R.color.colorWhite16()!
        view.highlightedStrokeColor = R.color.colorWhite16()!
        view.strokeWidth = 0.5
        view.shadowOpacity = 0.0
        return view
    }()

    let expandableContentStack: UIStackView = {
        let stackView = UIFactory.default.createVerticalStackView()
        stackView.alignment = .fill
        stackView.distribution = .fill
        return stackView
    }()

    let chainNameLabel: UILabel = {
        let label = UILabel()
        label.font = .h4Title
        label.textColor = R.color.colorStrokeGray()
        return label
    }()

    let methodsLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.numberOfLines = 0
        return label
    }()

    let eventsLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.numberOfLines = 0
        return label
    }()

    let methodsTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .h4Title
        label.textColor = R.color.colorStrokeGray()
        return label
    }()

    let eventsTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .h4Title
        label.textColor = R.color.colorStrokeGray()
        return label
    }()

    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = R.color.colorBlack19()
        separatorInset = .zero
        selectionStyle = .none
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: WalletConnectProposalCellModel.ExpandableViewModel) {
        visibleTitle.text = viewModel.cellTitle
        chainNameLabel.text = viewModel.chain
        methodsLabel.text = viewModel.methods
        eventsLabel.text = viewModel.events

        eventsTitleLabel.isHidden = viewModel.events.isEmpty
        eventsLabel.isHidden = viewModel.events.isEmpty

        expandableBackground.isHidden = !viewModel.isExpanded
        expandableAccesoryImageView.image = viewModel.isExpanded ? R.image.basicMinus() : R.image.basicPlus()
    }

    // MARK: - Private methods

    private func setupLayout() {
        contentView.addSubview(cellStackView)
        cellStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        let separator = UIFactory.default.createSeparatorView()
        [visibleStackView, expandableBackground].forEach { cellStackView.addArrangedSubview($0) }
        [visibleTitle, expandableAccesoryImageView].forEach { visibleStackView.addArrangedSubview($0) }
        cellStackView.setCustomSpacing(UIConstants.defaultOffset, after: visibleStackView)

        visibleStackView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.cellHeight40)
        }

        visibleStackView.addSubview(separator)
        separator.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(UIConstants.separatorHeight)
        }

        expandableBackground.addSubview(expandableContentStack)
        expandableContentStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIConstants.offset12)
        }

        expandableAccesoryImageView.snp.makeConstraints { make in
            make.size.equalTo(24)
        }

        expandableContentStack.addArrangedSubview(chainNameLabel)
        expandableContentStack.addArrangedSubview(methodsTitleLabel)
        expandableContentStack.addArrangedSubview(methodsLabel)
        expandableContentStack.addArrangedSubview(eventsTitleLabel)
        expandableContentStack.addArrangedSubview(eventsLabel)

        expandableContentStack.setCustomSpacing(UIConstants.defaultOffset, after: chainNameLabel)
        expandableContentStack.setCustomSpacing(UIConstants.minimalOffset, after: methodsTitleLabel)
        expandableContentStack.setCustomSpacing(UIConstants.bigOffset, after: methodsLabel)
        expandableContentStack.setCustomSpacing(UIConstants.minimalOffset, after: eventsTitleLabel)
    }

    private func applyLocalization() {
        methodsTitleLabel.text = R.string.localizable.commonMethods(preferredLanguages: locale.rLanguages)
        eventsTitleLabel.text = R.string.localizable.commonEvents(preferredLanguages: locale.rLanguages)
    }
}
