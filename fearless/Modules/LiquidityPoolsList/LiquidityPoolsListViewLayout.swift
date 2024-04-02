import UIKit
import SoraUI

final class LiquidityPoolsListViewLayout: UIView {
    let topBar: BorderedContainerView = {
        let view = BorderedContainerView()
        view.borderType = .bottom
        view.fillColor = R.color.colorWhite8()
        return view
    }()
    
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h5Title
        label.textColor = .white
        return label
    }()
    
    let moreButton: UIButton = {
        let button = UIButton(type: .custom)
        button.titleLabel.font = .capsTitle
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = R.color.colorWhite8()
        return button
    }()
    
    let tableView: UITableView = {
        let tableView = UITableView()
        return tableView
    }()
    
    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        drawSubviews()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
        
        drawSubviews()
        setupConstraints()
    }
    
    func bind(viewModel: LiquidityPoolListViewModel) {
        titleLabel.text = viewModel.titleLabelText
        moreButton.isHidden = !viewModel.moreButtonVisible
    }
    
    private func drawSubviews() {
        addSubview(topBar)
        addSubview(tableView)
        
        topBar.addSubview(titleLabel)
        topBar.addSubview(moreButton)
    }
    
    private func setupConstraints() {
        topBar.snp.makeConstraints { make in
            make.height.equalTo(42)
            make.leading.trailing.top.equalToSuperview()
        }
        
        tableView.snp.makeConstraints { make in
            make.top.equalTo(topBar.snp.bottom).offset(8)
            make.leading.trailing.bottom.equalToSuperview()
            
        }
    }
    
    private func applyLocalization() {
    }
}
