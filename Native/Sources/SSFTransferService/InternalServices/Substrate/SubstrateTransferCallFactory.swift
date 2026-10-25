import BigInt
import Foundation
import SSFModels
import SSFRuntimeCodingService
import SSFUtils

protocol SubstrateTransferCallFactory {
    func transfer(
        to receiver: AccountId,
        amount: BigUInt,
        chainAsset: ChainAsset
    ) -> any RuntimeCallable

    func xorlessTransfer(
        _ transfer: XorlessTransfer
    ) -> any RuntimeCallable
}

final class SubstrateTransferCallFactoryDefault: SubstrateTransferCallFactory {
    private let runtimeService: RuntimeProviderProtocol

    init(runtimeService: RuntimeProviderProtocol) {
        self.runtimeService = runtimeService
    }

    // MARK: - SubstrateCallFactory

    func transfer(
        to receiver: AccountId,
        amount: BigUInt,
        chainAsset: ChainAsset
    ) -> any RuntimeCallable {
        switch chainAsset.chainAssetType {
        case .normal, .none:
            return transferNormalAssetWith(
                specific: .init(from: chainAsset.chain),
                receiver: receiver,
                amount: amount,
                chainAsset: chainAsset
            )
        case .ormlChain:
            return ormlChainTransfer(
                to: receiver,
                amount: amount,
                currencyId: chainAsset.currencyId
            )
        case
            .ormlAsset,
            .foreignAsset,
            .stableAssetPoolToken,
            .liquidCrowdloan,
            .vToken,
            .vsToken,
            .stable,
            .assetId,
            .token2,
            .xcm:
            return ormlAssetTransfer(
                to: receiver,
                amount: amount,
                currencyId: chainAsset.currencyId,
                path: .ormlAssetTransfer
            )
        case .equilibrium:
            return equilibriumAssetTransfer(
                to: receiver,
                amount: amount,
                currencyId: chainAsset.currencyId
            )
        case .soraAsset:
            return ormlAssetTransfer(
                to: receiver,
                amount: amount,
                currencyId: chainAsset.currencyId,
                path: .assetsTransfer
            )
        case .assets:
            return assetsTransfer(
                to: receiver,
                amount: amount,
                currencyId: chainAsset.currencyId,
                isEthereumBased: chainAsset.chain.isEthereumBased
            )
        }
    }

    func xorlessTransfer(_ transfer: XorlessTransfer) -> any RuntimeCallable {
        let path: SubstrateCallPath = .xorlessTransfer
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: transfer
        )
    }

    // MARK: - Private methods

    private func transferNormalAssetWith(
        specific: ChainTransferSpecificParameter,
        receiver: AccountId,
        amount: BigUInt,
        chainAsset: ChainAsset
    ) -> any RuntimeCallable {
        switch specific {
        case .sora:
            return ormlAssetTransfer(
                to: receiver,
                amount: amount,
                currencyId: chainAsset.currencyId,
                path: .assetsTransfer
            )
        case .reef:
            return reefTransfer(to: receiver, amount: amount)
        case .default:
            return defaultTransfer(to: receiver, amount: amount)
        }
    }

    private func ormlChainTransfer(
        to receiver: AccountId,
        amount: BigUInt,
        currencyId: CurrencyId?
    ) -> any RuntimeCallable {
        let args = TransferCall(dest: .accoundId(receiver), value: amount, currencyId: currencyId)
        let path: SubstrateCallPath = .ormlChainTransfer
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    private func ormlAssetTransfer(
        to receiver: AccountId,
        amount: BigUInt,
        currencyId: CurrencyId?,
        path: SubstrateCallPath
    ) -> any RuntimeCallable {
        let args = TransferCall(dest: .accoundId(receiver), value: amount, currencyId: currencyId)
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    private func equilibriumAssetTransfer(
        to receiver: AccountId,
        amount: BigUInt,
        currencyId: CurrencyId?
    ) -> any RuntimeCallable {
        let args = TransferCall(dest: .accountTo(receiver), value: amount, currencyId: currencyId)
        let path: SubstrateCallPath = .equilibriumAssetTransfer
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    private func assetsTransfer(
        to receiver: AccountId,
        amount: BigUInt,
        currencyId: CurrencyId?,
        isEthereumBased: Bool
    ) -> any RuntimeCallable {
        let dest: MultiAddress = isEthereumBased ? .accountTo(receiver) : .accoundId(receiver)
        let args = TransferCall(dest: dest, value: amount, currencyId: currencyId)
        let path: SubstrateCallPath = .assetsTransfer
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    private func reefTransfer(
        to receiver: AccountId,
        amount: BigUInt
    ) -> any RuntimeCallable {
        let args = TransferCall(dest: .indexedString(receiver), value: amount, currencyId: nil)
        let path: SubstrateCallPath = .defaultTransfer
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }

    private func defaultTransfer(
        to receiver: AccountId,
        amount: BigUInt
    ) -> any RuntimeCallable {
        guard let metadata = runtimeService.snapshot?.metadata else {
            let args = TransferCall(dest: .accoundId(receiver), value: amount, currencyId: nil)
            let path: SubstrateCallPath = .defaultTransfer
            return RuntimeCall(
                moduleName: path.moduleName,
                callName: path.callName,
                args: args
            )
        }

        let transferAllowDeathAvailable = try? metadata.modules
            .first(where: {
                $0.name.lowercased() == SubstrateCallPath.transferAllowDeath.moduleName
                    .lowercased()
            })?
            .calls(using: metadata.schemaResolver)?
            .first(where: {
                $0.name.lowercased() == SubstrateCallPath.transferAllowDeath.callName.lowercased()
            }) != nil

        let path: SubstrateCallPath = transferAllowDeathAvailable == true ? .transferAllowDeath :
            .defaultTransfer

        let args = TransferCall(dest: .accoundId(receiver), value: amount, currencyId: nil)
        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.callName,
            args: args
        )
    }
}

private enum ChainTransferSpecificParameter {
    case sora
    case reef
    case `default`

    init(from chain: ChainModel) {
        switch chain.knownChainEquivalent {
        case .soraMain, .soraTest:
            self = .sora
        case .reef, .scuba:
            self = .reef
        default:
            self = .default
        }
    }
}
