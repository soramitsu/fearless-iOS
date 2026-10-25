# SSF-signer-ios

[![CI Status](https://img.shields.io/travis/Alex Lebedko/SSF-signer-ios.svg?style=flat)](https://travis-ci.org/Alex Lebedko/SSF-signer-ios)
[![Version](https://img.shields.io/cocoapods/v/SSF-signer-ios.svg?style=flat)](https://cocoapods.org/pods/SSF-signer-ios)
[![License](https://img.shields.io/cocoapods/l/SSF-signer-ios.svg?style=flat)](https://cocoapods.org/pods/SSF-signer-ios)
[![Platform](https://img.shields.io/cocoapods/p/SSF-signer-ios.svg?style=flat)](https://cocoapods.org/pods/SSF-signer-ios)

## Description

SSFSigner used to sign blockchain transactions using 1 of the 4 types of cryptography supported: sr25519, ed25519, ecdsa, ethereum ecdsa.

### Usage
Main interface provided by library - TransactionSignerProtocol.

```
public func sign(_ originalData: Data) throws -> IRSignatureProtocol
```

where 
'originalData' - encoded transaction that needs to be signed
'IRSignatureProtocol' - signed transaction

SSFSigner doesn't store any private data. To sign transactions, you need to pass your keypair and cryptography type to library. There are TransactionSigner class that implements TransactionSignerProtocol. TransactionSigner class initializer takes 3 parameters: private key, public key, cryptography type.

```
let signer: TransactionSignerProtocol = TransactionSigner(publicKeyData: #YOUR_PUBLIC_KEY, secretKeyData: #YOUR_SECRET_KEY, cryptoType: #CRYPTO_TYPE)
let signature = signer.sign(#ENCODED_TRANSACTION)
```

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

## Installation

SSF-signer-ios is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'SSF-signer-ios'
```

## Author

Alex Lebedko, lebedko@soramitsu.co.jp

## License

SSF-signer-ios is available under Apache-2.0 OR MIT, at your option. See [LICENSE](LICENSE) for the license choices and original notices.
