import UIKit
import SnapKit

class MultilineTriangularedView: UIView {
    enum Layout {
        static let verticalOffset: CGFloat = 8
        static let horizontalOffset: CGFloat = 16
    }

    private(set) var backgroundView: TriangularedView!
    private(set) var titleLabel: UILabel!
    private(set) var subtitleLabel: UILabel!
    private var wrapsContent = false

    func configureWrapping(locale: Locale, compatibleWith traits: UITraitCollection) {
        if !wrapsContent {
            wrapsContent = true
            backgroundView.snp.remakeConstraints { $0.edges.equalToSuperview() }
            titleLabel.snp.remakeConstraints {
                $0.top.equalToSuperview().offset(Layout.verticalOffset)
                $0.leading.trailing.equalToSuperview().inset(Layout.horizontalOffset)
            }
            subtitleLabel.snp.remakeConstraints {
                $0.top.equalTo(titleLabel.snp.bottom).offset(8)
                $0.bottom.equalToSuperview().inset(Layout.verticalOffset)
                $0.leading.trailing.equalToSuperview().inset(Layout.horizontalOffset)
            }
        }
        titleLabel.numberOfLines = 0
        titleLabel.font = .fw(.bodyS, locale: locale, compatibleWith: traits)
        subtitleLabel.lineBreakMode = .byCharWrapping
        subtitleLabel.font = .fw(.monoS, locale: locale, compatibleWith: traits)
        setNeedsLayout()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        configure()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !wrapsContent else { return }

        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Layout.verticalOffset)
            make.leading.equalToSuperview().offset(Layout.horizontalOffset)
            make.trailing.equalToSuperview().offset(-Layout.horizontalOffset)
        }
        subtitleLabel.snp.makeConstraints { make in
            make.bottom.equalToSuperview().offset(-Layout.verticalOffset)
            make.leading.equalToSuperview().offset(Layout.horizontalOffset)
            make.trailing.equalToSuperview().offset(-Layout.horizontalOffset)
            make.top.greaterThanOrEqualTo(titleLabel.snp.bottom)
        }
    }

    private func configure() {
        backgroundColor = .clear

        if backgroundView == nil {
            backgroundView = TriangularedView()
            backgroundView.isUserInteractionEnabled = false
            addSubview(backgroundView)
        }

        if titleLabel == nil {
            titleLabel = UILabel()
            addSubview(titleLabel)
        }

        if subtitleLabel == nil {
            subtitleLabel = UILabel()
            subtitleLabel.numberOfLines = 0
            addSubview(subtitleLabel)
        }
    }
}
