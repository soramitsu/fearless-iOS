import UIKit

final class SwapContainerViewLayout: UIView {
    var polkaswapContainer: UIView?
    var okxContainer: UIView?

    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func addPolkaswapView(_ view: UIView) {
        polkaswapContainer = view
        addSubview(view)
        view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func addOkxView(_ view: UIView) {
        okxContainer = view
        addSubview(view)
        view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    // MARK: - Private methods

    private func applyLocalization() {}
}
