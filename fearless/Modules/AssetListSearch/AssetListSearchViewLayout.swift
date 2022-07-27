import UIKit

final class AssetListSearchViewLayout: UIView {
    let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.image = R.image.backgroundImage()
        return imageView
    }()

    let searchTextField: SearchTextField = {
        let searchTextField = SearchTextField()
        searchTextField.triangularedView?.cornerCut = [.bottomRight, .topLeft]
        searchTextField.triangularedView?.overlayView.strokeWidth = UIConstants.separatorHeight
        searchTextField.triangularedView?.overlayView.strokeColor = R.color.colorStrokeGray() ?? .lightGray
        return searchTextField
    }()

    let cancelButton: UIButton = {
        let button = UIButton()
        button.titleLabel?.font = .h4Title
        return button
    }()

    var locale = Locale.current {
        didSet {
            applyLocalization()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(backgroundImageView)
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        let hStackView = UIFactory.default.createHorizontalStackView(spacing: 12)
        hStackView.distribution = .fill
        addSubview(hStackView)
        hStackView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide).offset(UIConstants.bigOffset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        cancelButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        hStackView.addArrangedSubview(searchTextField)
        hStackView.addArrangedSubview(cancelButton)
    }

    private func applyLocalization() {
        let cancelTitle = R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
        cancelButton.setTitle(cancelTitle, for: .normal)
    }
}
