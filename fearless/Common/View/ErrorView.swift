import UIKit

struct ErrorViewModel {
    let title: String?
    let message: String?
    let actionTitle: String?
    let actionHandler: (() -> Void)?
}

final class ErrorView: UIView {
    let backgroundView: TriangularedView = {
        let view = TriangularedView()
        view.fillColor = R.color.colorSemiBlack()!
        view.highlightedFillColor = R.color.colorSemiBlack()!
        view.strokeColor = R.color.colorWhite16()!
        view.highlightedStrokeColor = R.color.colorWhite16()!
        view.strokeWidth = 0.5
        view.shadowOpacity = 0.0

        return view
    }()

    let iconView = UIImageView(image: R.image.iconBell())

    let hStack: UIStackView = {
        let hStack = UIFactory.default.createHorizontalStackView(spacing: 8)
        hStack.alignment = .center
        hStack.distribution = .fillProportionally
        return hStack
    }()

    let vStack = UIFactory.default.createVerticalStackView(spacing: 12)

    let titleLabel: UILabel = {
        let titleLabel = UILabel()
        titleLabel.textColor = R.color.colorOrange()
        titleLabel.font = .h5Title
        return titleLabel
    }()

    let textLabel: UILabel = {
        let textLabel = UILabel()
        textLabel.textColor = R.color.colorWhite()
        textLabel.font = .p1Paragraph
        textLabel.numberOfLines = 0
        return textLabel
    }()

    let actionButton: TriangularedButton = {
        let button = TriangularedButton()
        button.triangularedView?.sideLength = 6
        button.applyErrorStyle()
        return button
    }()

    var actionHandler: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        drawSubviews()
        setupConstraints()
        actionButton.addTarget(self, action: #selector(actionTap), for: .touchUpInside)
    }

    func bindError(viewModel: ErrorViewModel) {
        titleLabel.text = viewModel.title
        textLabel.text = viewModel.message
        actionButton.imageWithTitleView?.title = viewModel.actionTitle
        actionHandler = viewModel.actionHandler
        actionButton.isHidden = viewModel.actionHandler == nil
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func drawSubviews() {
        addSubview(backgroundView)
        backgroundView.addSubview(vStack)

        hStack.addArrangedSubview(iconView)
        hStack.addArrangedSubview(titleLabel)

        vStack.addArrangedSubview(hStack)
        vStack.addArrangedSubview(textLabel)
        vStack.addArrangedSubview(actionButton)
    }

    private func setupConstraints() {
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        vStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(12)
        }

        iconView.snp.makeConstraints { make in
            make.size.equalTo(24)
        }

        actionButton.snp.makeConstraints { make in
            make.width.equalTo(textLabel).dividedBy(2)
            make.height.equalTo(24)
        }
    }

    @objc func actionTap() {
        actionHandler?()
    }
}
