import UIKit
import SoraUI

final class AboutViewLayout: UIView {
    // MARK: - UI

    /// The page and the stacked lockup whose crest lights it (sun-lit redesign, Yatagarasu brand).
    private let sunlitBackground = FWSunlitBackgroundView()

    private let logoImageView = FWLockupView()

    private let aboutTitle: UILabel = {
        let label = UILabel()
        label.font = .h2Title
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.textColor = R.color.colorWhite()
        return label
    }()

    private let headerContainer = UIView()

    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = .clear
        view.separatorStyle = .none
        view.contentInset = UIEdgeInsets(
            top: 0,
            left: 0,
            bottom: UIConstants.bigOffset,
            right: 0
        )
        return view
    }()

    // MARK: - Locale

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    func applyLocalization() {
        aboutTitle.text = R.string.localizable.aboutTitle(preferredLanguages: locale.rLanguages)
        setNeedsLayout()
    }

    // MARK: - Constructors

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            setNeedsLayout()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = tableView.bounds.width
        guard width > 0 else { return }
        aboutTitle.preferredMaxLayoutWidth = max(1, width - 2 * UIConstants.bigOffset)
        let size = headerContainer.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        let frame = CGRect(x: 0, y: 0, width: width, height: ceil(size.height))
        if headerContainer.frame != frame {
            headerContainer.frame = frame
            tableView.tableHeaderView = headerContainer
        }
        sunlitBackground.sunCenter = logoImageView.convert(logoImageView.crestCenterPoint, to: self)
    }

    // MARK: - Private methods

    private func setupLayout() {
        backgroundColor = FWSunlit.Palette.background
        addSubview(sunlitBackground)
        sunlitBackground.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        tableView.tableHeaderView = headerContainer

        let logoRow = UIView()
        headerContainer.addSubview(logoRow)
        logoRow.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalToSuperview().offset(20)
        }
        logoRow.addSubview(logoImageView)
        logoImageView.snp.makeConstraints { make in
            logoImageView.makePageConstraints(make)
            make.top.bottom.equalToSuperview()
        }

        headerContainer.addSubview(aboutTitle)
        aboutTitle.textAlignment = .center
        aboutTitle.snp.makeConstraints { make in
            make.top.equalTo(logoRow.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalToSuperview().offset(-UIConstants.bigOffset)
        }
    }
}
