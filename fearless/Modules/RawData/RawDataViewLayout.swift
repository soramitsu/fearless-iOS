import UIKit

final class RawDataViewLayout: UIView {
    let navigationBar: BaseNavigationBar = {
        let bar = BaseNavigationBar()
        bar.set(.present)
        return bar
    }()

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.scrollView.contentInset = UIEdgeInsets(
            top: UIConstants.bigOffset,
            left: 0,
            bottom: UIConstants.actionHeight + UIConstants.bigOffset,
            right: 0
        )
        return view
    }()

    let label: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.numberOfLines = 0
        return label
    }()

    let closeButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()

    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorBlack19()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func set(text: String) {
        label.text = text
    }

    // MARK: - Private methods

    private func setupLayout() {
        addSubview(navigationBar)
        addSubview(contentView)
        addSubview(closeButton)

        contentView.addArrangedSubview(label)
        label.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
        }

        navigationBar.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalTo(safeAreaLayoutGuide)
        }

        closeButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalTo(safeAreaLayoutGuide)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }

    private func applyLocalization() {
        navigationBar.setTitle("Transaction raw data")
        closeButton.imageWithTitleView?.title = "Close"
    }
}
