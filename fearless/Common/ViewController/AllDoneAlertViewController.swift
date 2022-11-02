//
//  AllDoneAlertViewController.swift
//  fearless
//
//  Created by Soramitsu on 02.11.2022.
//  Copyright © 2022 Soramitsu. All rights reserved.
//

import Foundation
import UIKit

final class AllDoneAlertViewController: UIViewController, ViewHolder {
    typealias RootViewType = AllDoneAlertViewLayout

    private let hashString: String

    init(hashString: String) {
        self.hashString = hashString
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = AllDoneAlertViewLayout(hashString: hashString)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }

    private func setup() {
        rootView.closeButton.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)
    }

    @objc private func dismissSelf() {
        dismiss(animated: true)
    }
}
