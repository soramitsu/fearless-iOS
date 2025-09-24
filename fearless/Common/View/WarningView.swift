import UIKit

class WarningView: UIView {
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

    let iconView = UIImageView(image: R.image.iconWarning())

    let hStack: UIStackView = {
        let hStack = UIFactory.default.createHorizontalStackView(spacing: 8)
        hStack.alignment = .center
        hStack.distribution = .fillProportionally
        return hStack
    }()

    let vStack = UIFactory.default.createVerticalStackView(spacing: 4)

    let titleLabel: UILabel = {
        let titleLabel = UILabel()
        titleLabel.textColor = R.color.colorOrange()
        titleLabel.font = .h6Title
        return titleLabel
    }()

    let textLabel: UILabel = {
        let textLabel = UILabel()
        textLabel.textColor = R.color.colorWhite50()
        textLabel.font = .p3Paragraph
        textLabel.numberOfLines = 0
        return textLabel
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        drawSubviews()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func drawSubviews() {
        addSubview(backgroundView)
        backgroundView.addSubview(hStack)

        hStack.addArrangedSubview(iconView)
        hStack.addArrangedSubview(vStack)

        vStack.addArrangedSubview(titleLabel)
        vStack.addArrangedSubview(textLabel)
    }

    private func setupConstraints() {
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        hStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(12)
        }

        iconView.snp.makeConstraints { make in
            make.size.equalTo(16)
        }
    }
}
