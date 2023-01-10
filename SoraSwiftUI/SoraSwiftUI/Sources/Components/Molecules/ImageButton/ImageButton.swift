//
//  ImageButton.swift
//  SoraSwiftUI
//
//  Created by Ivan Shlyapkin on 14.09.2022.
//

import Foundation
import UIKit

public final class ImageButton: UIButton, Molecule {

    public let sora: ImageButtonConfiguration<ImageButton>

    private var size: CGSize = .zero

    init(style: SoramitsuStyle, size: CGSize) {
        sora = ImageButtonConfiguration(style: style)
        self.size = size
        super.init(frame: .zero)
        sora.owner = self
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension ImageButton {
    func setup() {
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: size.height),
            widthAnchor.constraint(equalToConstant: size.width)
        ])
    }
}

public extension ImageButton {
    convenience init(size: CGSize) {
        let sora = SoramitsuUI.shared
        self.init(style: sora.style, size: size)
    }
}
