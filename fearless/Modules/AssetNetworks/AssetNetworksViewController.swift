import UIKit
import SoraFoundation

final class AssetNetworksViewController: UIViewController, ViewHolder {
    typealias RootViewType = AssetNetworksViewLayout

    // MARK: Private properties

    private let output: AssetNetworksViewOutput
    private var cellViewModels: [AssetNetworksTableCellModel] = []

    var draggableView: UIView {
        rootView
    }

    var delegate: DraggableDelegate?

    var scrollPanRecognizer: UIPanGestureRecognizer? {
        nil
    }

    // MARK: - Constructor

    init(
        output: AssetNetworksViewOutput,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.output = output
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func loadView() {
        view = AssetNetworksViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        output.didLoad(view: self)
        setupTableView()
        rootView.networkSwitcher.delegate = self
        rootView.sortButton.addAction { [weak self] in
            self?.output.didTapSortButton()
        }
    }

    // MARK: - Private methods

    private func setupTableView() {
        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
        rootView.tableView.registerClassForCell(AssetNetworksTableCell.self)
    }
}

// MARK: - AssetNetworksViewInput

extension AssetNetworksViewController: AssetNetworksViewInput {
    func set(dragableState _: DraggableState, animated _: Bool) {}

    func set(contentInsets _: UIEdgeInsets, for _: DraggableState) {}

    func canDrag(from _: DraggableState) -> Bool {
        false
    }

    func animate(progress _: Double, from _: DraggableState, to _: DraggableState, finalFrame _: CGRect) {}

    func didReceive(viewModels: [AssetNetworksTableCellModel]) {
        cellViewModels = viewModels
        rootView.tableView.reloadData()
    }
}

// MARK: - Localizable

extension AssetNetworksViewController: Localizable {
    func applyLocalization() {}
}

extension AssetNetworksViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        cellViewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithType(AssetNetworksTableCell.self, forIndexPath: indexPath)
        if let viewModel = cellViewModels[safe: indexPath.row] {
            cell.bind(viewModel: viewModel)
        }
        return cell
    }

    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        80
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let chainAsset = cellViewModels[safe: indexPath.row]?.chainAsset else {
            return
        }

        output.didSelect(chainAsset: chainAsset)
    }
}

// MARK: - FWSegmentedControlDelegate

extension AssetNetworksViewController: FWSegmentedControlDelegate {
    func didSelect(_ segmentIndex: Int) {
        output.didChangeNetworkSwitcher(segmentIndex: segmentIndex)
    }
}
