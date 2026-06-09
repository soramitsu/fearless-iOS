/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

public protocol LoadingViewFactoryProtocol {
    static func createLoadingView() -> LoadingView
}

public protocol LoadingViewPresenterProtocol {
    var isPresented: Bool { get }

    func show(on view: UIView, animated: Bool)
    func show(on window: UIWindow, animated: Bool)
    func hide(animated: Bool)
}

open class LoadingViewPresenter {
    let factory: LoadingViewFactoryProtocol.Type

    var appearanceAnimationDuration: TimeInterval = 0.35
    var appearanceAnimationOptions: UIView.AnimationOptions = .curveLinear

    var hidingAnimationDuration: TimeInterval = 0.35
    var hidingAnimationOptions: UIView.AnimationOptions = .curveLinear

    private(set) weak var loadingView: LoadingView?

    public init(factory: LoadingViewFactoryProtocol.Type) {
        self.factory = factory
    }

    private func show(loadingView: LoadingView, animated: Bool) {
        loadingView.layer.removeAllAnimations()

        self.loadingView = loadingView

        loadingView.startAnimating()

        if animated {
            loadingView.alpha = 0.0
            UIView.animate(withDuration: appearanceAnimationDuration,
                           delay: 0.0,
                           options: appearanceAnimationOptions,
                           animations: {
                            loadingView.alpha = 1.0
            })
        } else {
            loadingView.alpha = 1.0
        }
    }
}

extension LoadingViewPresenter: LoadingViewPresenterProtocol {
    public var isPresented: Bool {
        return loadingView != nil
    }

    public func show(on view: UIView, animated: Bool) {
        let currentLoadingView = loadingView ?? factory.createLoadingView()
        currentLoadingView.frame = view.bounds
        view.addSubview(currentLoadingView)

        show(loadingView: currentLoadingView, animated: animated)
    }

    public func show(on window: UIWindow, animated: Bool) {
        let currentLoadingView = loadingView ?? factory.createLoadingView()
        currentLoadingView.frame = window.bounds
        window.addSubview(currentLoadingView)

        show(loadingView: currentLoadingView, animated: animated)
    }

    public func hide(animated: Bool) {
        guard animated else {
            loadingView?.removeFromSuperview()
            return
        }

        if let currentLoadingView = loadingView {
            UIView.animate(withDuration: hidingAnimationDuration,
                           delay: 0.0,
                           options: hidingAnimationOptions,
                           animations: {
                            currentLoadingView.alpha = 0.0
            }, completion: { (completed) in
                if completed {
                    currentLoadingView.stopAnimating()
                    currentLoadingView.removeFromSuperview()
                    self.loadingView = nil
                }
            })
        }
    }
}
