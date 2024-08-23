//
//  WalletConnectConfirmationViewModelFactory.swift
//  fearless
//
//  Created by Soramitsu on 01.09.2023.
//  Copyright © 2023 Soramitsu. All rights reserved.
//

import Foundation
import UIKit
import WalletConnectSign

protocol WalletConnectConfirmationViewModelFactory {
    func buildViewModel() -> WalletConnectConfirmationViewModel
}

final class WalletConnectConfirmationViewModelFactoryImpl: WalletConnectConfirmationViewModelFactory {
    private enum Constants {
        static let imageVerticalPosition: CGFloat = 3
        static let imageWidth: CGFloat = 6
        static let imageHeight: CGFloat = 12
    }

    private let inputData: WalletConnectConfirmationInputData

    init(inputData: WalletConnectConfirmationInputData) {
        self.inputData = inputData
    }

    func buildViewModel() -> WalletConnectConfirmationViewModel {
        switch inputData.variant {
        case let .walletConnect(request, session, method):
            return buildWalletConnectViewModel(
                resuest: request,
                session: session,
                method: method
            )
        case let .tonJsBridge(_, dapp, request, moduleOutput):
            return buildTonConnectViewModel(
                appName: dapp.name,
                appHost: dapp.url.host ?? "",
                request: request
            )
        case let .tonConnect(request: request, app: app):
            return buildTonConnectViewModel(
                appName: app.appUrl.absoluteString,
                appHost: app.appUrl.host ?? "",
                request: request
            )
        }
    }

    private func buildWalletConnectViewModel(
        resuest _: Request,
        session: Session,
        method: WalletConnectMethod
    ) -> WalletConnectConfirmationViewModel {
        let originShadowColor = HexColorConverter.hexStringToUIColor(
            hex: inputData.chain.utilityAssets().first?.color
        )?.cgColor
        let symbolViewModel = SymbolViewModel(
            iconViewModel: RemoteImageViewModel(url: inputData.chain.icon),
            shadowColor: originShadowColor
        )

        let dAppUrlString = session.peer.url
        let dAppUrl = URL(string: dAppUrlString)
        let host = dAppUrl?.host ?? dAppUrlString

        return WalletConnectConfirmationViewModel(
            symbolViewModel: symbolViewModel,
            method: method.rawValue,
            amount: nil,
            walletName: inputData.wallet.name,
            dApp: session.peer.name,
            host: host,
            chain: inputData.chain.name,
            rawData: rawDataAttributed()
        )
    }

    private func buildTonConnectViewModel(
        appName: String,
        appHost: String,
        request: TonConnect.AppRequest
    ) -> WalletConnectConfirmationViewModel {
        let originShadowColor = HexColorConverter.hexStringToUIColor(
            hex: inputData.chain.utilityAssets().first?.color
        )?.cgColor
        let symbolViewModel = SymbolViewModel(
            iconViewModel: RemoteImageViewModel(url: inputData.chain.icon),
            shadowColor: originShadowColor
        )

        return WalletConnectConfirmationViewModel(
            symbolViewModel: symbolViewModel,
            method: request.method.rawValue,
            amount: nil,
            walletName: inputData.wallet.name,
            dApp: appName,
            host: appHost,
            chain: inputData.chain.name,
            rawData: rawDataAttributed()
        )
    }

    // MARK: - Private methods

    private func rawDataAttributed() -> NSAttributedString {
        let rawDataAttributed = NSMutableAttributedString(string: "")
        let imageAttachment = NSTextAttachment()
        imageAttachment.bounds = CGRect(
            x: 0,
            y: -Constants.imageVerticalPosition,
            width: Constants.imageWidth,
            height: Constants.imageHeight
        )
        if let iconAboutArrowImage = R.image.dropTriangle() {
            imageAttachment.image = iconAboutArrowImage.rotate(radians: .pi / -2)
        }

        let imageString = NSAttributedString(attachment: imageAttachment)
        rawDataAttributed.append(imageString)

        return rawDataAttributed
    }
}
