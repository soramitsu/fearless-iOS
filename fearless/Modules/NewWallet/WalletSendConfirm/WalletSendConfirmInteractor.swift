import UIKit
import RobinHood
import Web3
import IrohaCrypto
import SSFModels
import SSFCrypto
import SoraKeystore
import Web3PromiseKit

final class WalletSendConfirmInteractor: RuntimeConstantFetching {
    weak var presenter: WalletSendConfirmInteractorOutputProtocol?

    internal let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    private let selectedMetaAccount: MetaAccountModel
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let operationManager: OperationManagerProtocol
    private let receiverAddress: String
    private let signingWrapper: SigningWrapperProtocol
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private var equilibriumTotalBalanceService: EquilibriumTotalBalanceServiceProtocol?

    private var gasPrice: EthereumQuantity?
    private var gasCount: EthereumQuantity?

    let dependencyContainer: SendDepencyContainer

    private var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var utilityPriceProvider: AnySingleValueProvider<PriceData>?

    init(
        selectedMetaAccount: MetaAccountModel,
        chainAsset: ChainAsset,
        receiverAddress: String,
        feeProxy: ExtrinsicFeeProxyProtocol,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        operationManager: OperationManagerProtocol,
        signingWrapper: SigningWrapperProtocol,
        dependencyContainer: SendDepencyContainer,
        wallet: MetaAccountModel
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.chainAsset = chainAsset
        self.feeProxy = feeProxy
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.receiverAddress = receiverAddress
        self.operationManager = operationManager
        self.signingWrapper = signingWrapper
        self.dependencyContainer = dependencyContainer
        self.wallet = wallet
    }

    private func provideConstants() {
        guard let utilityAsset = getFeePaymentChainAsset(for: chainAsset),
              let dependencies = dependencyContainer.prepareDepencies(chainAsset: utilityAsset) else {
            return
        }

        dependencies.existentialDepositService.fetchExistentialDeposit(
            chainAsset: utilityAsset
        ) { [weak self] result in
            self?.presenter?.didReceiveMinimumBalance(result: result)
        }
    }

    private func subscribeToAccountInfo() {
        var chainsAssets = [chainAsset]
        if chainAsset.chain.isUtilityFeePayment, !chainAsset.isUtility,
           let utilityAsset = getFeePaymentChainAsset(for: chainAsset) {
            chainsAssets.append(utilityAsset)
        }
        accountInfoSubscriptionAdapter.subscribe(
            chainsAssets: chainsAssets,
            handler: self,
            deliveryOn: .main
        )
    }

    private func subscribeToPrice() {
        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        } else {
            presenter?.didReceivePriceData(result: .success(nil), for: nil)
        }
        if chainAsset.chain.isSora, !chainAsset.isUtility,
           let utilityAsset = getFeePaymentChainAsset(for: chainAsset),
           let priceId = utilityAsset.asset.priceId {
            utilityPriceProvider = subscribeToPrice(for: priceId)
        }
    }

    func setup() {
        feeProxy.delegate = self

        subscribeToPrice()
        subscribeToAccountInfo()
        provideConstants()
    }
}

extension WalletSendConfirmInteractor: WalletSendConfirmInteractorInputProtocol {
    func estimateFee(for _: BigUInt, tip _: BigUInt?) {
//        guard let accountId = try? AddressFactory.accountId(
//            from: receiverAddress,
//            chain: chainAsset.chain
//        ),
//            let dependencies = dependencyContainer.prepareDepencies(chainAsset: chainAsset) else { return }
//
//        let call = dependencies.callFactory.transfer(to: accountId, amount: amount, chainAsset: chainAsset)
//        var identifier = String(amount)
//        if let tip = tip {
//            identifier += "_\(String(tip))"
//        }
//        feeProxy.estimateFee(using: dependencies.extrinsicService, reuseIdentifier: identifier) { builder in
//            var nextBuilder = try builder.adding(call: call)
//            if let tip = tip {
//                nextBuilder = builder.with(tip: tip)
//            }
//            return nextBuilder
//        }
        let web3 = Web3(rpcURL: "https://rpc.sepolia.org")

        if let ethAddress = try? EthereumAddress(hex: "0x5a4e4c9F2Bae446Ee6c7867A6f11d398246Af203", eip55: true) {
            let call = EthereumCall(to: ethAddress)

            web3.eth.gasPrice { resp in
                self.gasPrice = resp.result
            }

            web3.eth.estimateGas(call: call) { [weak self] resp in
                self?.gasCount = resp.result
                DispatchQueue.main.async {
                    if let fee = resp.result?.quantity {
                        let runtimeDispatchInfo = RuntimeDispatchInfo(inclusionFee: FeeDetails(baseFee: fee, lenFee: .zero, adjustedWeightFee: .zero))
                        self?.presenter?.didReceiveFee(result: .success(runtimeDispatchInfo))
                    } else if let error = resp.error {
                        self?.presenter?.didReceiveFee(result: .failure(error))
                    }
                }
            }
        }
    }

    func submitExtrinsic(for _: BigUInt, tip _: BigUInt?, receiverAddress _: String) {
        guard let address = wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress() else {
            return
        }

        let web3 = Web3(rpcURL: "https://rpc.sepolia.org")

        let tag: String = KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId, accountId: nil)
        do {
            let secretKey = try Keychain().fetchKey(for: tag)

            let keypairFactory = EcdsaKeypairFactory()
            let privateKey = try keypairFactory
                .createKeypairFromSeed(secretKey.miniSeed, chaincodeList: [])
                .privateKey()

            firstly {
                web3.eth.getTransactionCount(address: try EthereumAddress(hex: "0xd7330e4152c2FEC60a3631682F98b8043E7c538C", eip55: true), block: .latest)
            }.then { nonce in
                let tx = try EthereumTransaction(
                    nonce: nonce,
                    gasPrice: self.gasPrice!,
                    gasLimit: self.gasCount!,
                    to: EthereumAddress(hex: "0x5a4e4c9F2Bae446Ee6c7867A6f11d398246Af203", eip55: true),
                    value: EthereumQuantity(quantity: 100_000.gwei)
                )

                return try tx.sign(with: EthereumPrivateKey(privateKey.rawData().bytes), chainId: 11_155_111).promise
            }.then { tx in
                web3.eth.sendRawTransaction(transaction: tx)
            }.done { hash in
                print(hash)
                self.presenter?.didTransfer(result: .success(hash.hex()))
            }.catch { error in
                self.presenter?.didTransfer(result: .failure(error))
            }
        } catch {
            presenter?.didTransfer(result: .failure(error))
        }
//        guard let accountId = try? AddressFactory.accountId(
//            from: receiverAddress,
//            chain: chainAsset.chain
//        ),
//            let dependencies = dependencyContainer.prepareDepencies(chainAsset: chainAsset) else { return }
//
//        let call = dependencies.callFactory.transfer(
//            to: accountId,
//            amount: transferAmount,
//            chainAsset: chainAsset
//        )
//
//        let builderClosure: ExtrinsicBuilderClosure = { builder in
//            var nextBuilder = try builder.adding(call: call)
//            if let tip = tip {
//                nextBuilder = builder.with(tip: tip)
//            }
//            return nextBuilder
//        }
//
//        dependencies.extrinsicService.submit(
//            builderClosure,
//            signer: signingWrapper,
//            runningIn: .main,
//            completion: { [weak self] result in
//                self?.presenter?.didTransfer(result: result)
//            }
//        )
    }

    func getFeePaymentChainAsset(for chainAsset: ChainAsset?) -> ChainAsset? {
        guard let chainAsset = chainAsset else { return nil }
        if chainAsset.chain.isUtilityFeePayment, !chainAsset.isUtility,
           let utilityAsset = chainAsset.chain.utilityAssets().first {
            return ChainAsset(chain: chainAsset.chain, asset: utilityAsset)
        }
        return chainAsset
    }

    func fetchEquilibriumTotalBalance(chainAsset: ChainAsset, amount: Decimal) {
        if chainAsset.chain.isEquilibrium {
            let service = dependencyContainer
                .prepareDepencies(chainAsset: chainAsset)?
                .equilibruimTotalBalanceService
            equilibriumTotalBalanceService = service

            let totalBalanceAfterTransfer = equilibriumTotalBalanceService?
                .totalBalanceAfterTransfer(chainAsset: chainAsset, amount: amount) ?? .zero
            presenter?.didReceive(eqTotalBalance: totalBalanceAfterTransfer)
        }
    }
}

extension WalletSendConfirmInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(
        result: Swift.Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainAsset: ChainAsset
    ) {
        presenter?.didReceiveAccountInfo(result: result, for: chainAsset)
    }
}

extension WalletSendConfirmInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Swift.Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        presenter?.didReceivePriceData(result: result, for: priceId)
    }
}

extension WalletSendConfirmInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Swift.Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter?.didReceiveFee(result: result)
    }
}
