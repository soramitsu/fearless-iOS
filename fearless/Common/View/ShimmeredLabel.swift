import Foundation
import UIKit
import SoraUI

enum ShimmeredLabelStateType {
    case text(String?)
    case attributed(NSAttributedString?)
}

enum ShimmeredLabelState: Hashable {
    case stopShimmering
    case normal(String?)
    case normalAttributed(NSAttributedString?)
    case updating(String?)
    case updatingAttributed(NSAttributedString?)

    init(value: ShimmeredLabelStateType, isUpdated: Bool) {
        switch value {
        case let .text(text):
            if isUpdated {
                self = .normal(text)
            } else {
                self = .updating(text)
            }
        case let .attributed(attributed):
            if isUpdated {
                self = .normalAttributed(attributed)
            } else {
                self = .updatingAttributed(attributed)
            }
        }
    }
}

final class ShimmeredLabel: SkeletonLabel, ShimmeredProtocol {
    private var state: ShimmeredLabelState?

    // MARK: - Public methods

    init() {
        super.init(skeletonSize: .zero)
    }

    override init(skeletonSize: CGSize) {
        super.init(skeletonSize: skeletonSize)
    }

    func apply(state: ShimmeredLabelState?) {
        guard let state else {
            updateTextWithLoading(nil)
            return
        }

        self.state = state
        switch state {
        case .stopShimmering:
            stopShimmeringAnimation()
        case let .normal(text):
            self.text = text
            stopShimmeringAnimation()
        case let .normalAttributed(attributedText):
            self.attributedText = attributedText
            stopShimmeringAnimation()
        case let .updating(text):
            self.text = text
            startLoadingIfNeeded()
        case let .updatingAttributed(attributedText):
            self.attributedText = attributedText
            startLoadingIfNeeded()
        }
    }

    private func startLoadingIfNeeded() {
        guard let state = state else {
            return
        }

        switch state {
        case .normal, .normalAttributed, .stopShimmering:
            break
        case .updating, .updatingAttributed:
            startShimmeringAnimation()
        }
    }
}
