// A dApp on the live WalletConnect relay that asks the wallet for real signatures and checks them with code that is
// not Fearless's: `ox` recovers the EVM signer, `@noble/curves` verifies the Polkadot ed25519 signature.
//
// The WalletConnect SDK and those libraries are installed outside the repository and are never its dependencies
// (the SDK is under the WalletConnect Community License). Pass the install as WALLETCONNECT_REFERENCE_SDK:
//
//   WALLETCONNECT_REFERENCE_SDK=<dir> WALLETCONNECT_PROJECT_ID=<id> FEARLESS_WC_EXCHANGE=<dir> \
//     node scripts/walletconnect/reference-dapp-sign.mjs
//
// It writes the pairing link to <exchange>/uri-sign.txt for the wallet test (fearlessTests,
// WalletConnectLiveSigningTests), then asks for personal_sign, eth_signTypedData_v4 and polkadot_signMessage, checks
// each signature against the account the session granted, ends the session, and records the outcome in result.json.

import fs from 'node:fs/promises';
import { createRequire } from 'node:module';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const reference = process.env.WALLETCONNECT_REFERENCE_SDK;
const projectId = process.env.WALLETCONNECT_PROJECT_ID;
const exchange = process.env.FEARLESS_WC_EXCHANGE;
const relayUrl = process.env.WALLETCONNECT_RELAY_URL ?? 'wss://relay.walletconnect.org';
if (!reference || !projectId || !exchange) {
  console.error('Set WALLETCONNECT_REFERENCE_SDK, WALLETCONNECT_PROJECT_ID and FEARLESS_WC_EXCHANGE.');
  process.exit(2);
}

const requireFrom = createRequire(path.join(path.resolve(reference), 'package.json'));
const sdk = await import(pathToFileURL(requireFrom.resolve('@walletconnect/sign-client')).href);
const SignClient = sdk.SignClient ?? sdk.default?.SignClient ?? sdk.default;
const PersonalMessage = requireFrom('ox/PersonalMessage');
const TypedData = requireFrom('ox/TypedData');
const Signature = requireFrom('ox/Signature');
const Secp256k1 = requireFrom('ox/Secp256k1');
const Hex = requireFrom('ox/Hex');
const Base58 = requireFrom('ox/Base58');
const { ed25519 } = requireFrom('@noble/curves/ed25519');
const version = JSON.parse(
  await fs.readFile(path.join(path.resolve(reference), 'node_modules/@walletconnect/sign-client/package.json'), 'utf8')
).version;

const values = new Map();
const storage = {
  getKeys: async () => [...values.keys()],
  getEntries: async () => [...values.entries()].map(([key, value]) => [key, JSON.parse(value)]),
  getItem: async (key) => (values.has(key) ? JSON.parse(values.get(key)) : undefined),
  // The SDK keeps integers beyond 2^53 (some wallets' response ids) as BigInt.
  setItem: async (key, value) => void values.set(key, JSON.stringify(value, (_, v) => (typeof v === 'bigint' ? v.toString() : v))),
  removeItem: async (key) => void values.delete(key),
};

const steps = [];
const step = (name, detail = {}) => {
  steps.push({ name, at: new Date().toISOString(), ...detail });
  console.log(`[dapp] ${name}`, JSON.stringify(detail));
};
const timeout = (ms, label) =>
  new Promise((_, reject) => setTimeout(() => reject(new Error(`timed out: ${label}`)), ms));

const polkadotChain = 'polkadot:91b171bb158e2d3848fa23a9f1c25182';
const namespaces = {
  eip155: { chains: ['eip155:1'], methods: ['personal_sign', 'eth_signTypedData_v4'], events: ['chainChanged', 'accountsChanged'] },
  polkadot: { chains: [polkadotChain], methods: ['polkadot_signMessage'], events: [] },
};

const typedData = {
  domain: { name: 'Fearless interop', version: '1', chainId: 1, verifyingContract: '0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC' },
  types: {
    Person: [
      { name: 'name', type: 'string' },
      { name: 'wallet', type: 'address' },
    ],
    Mail: [
      { name: 'from', type: 'Person' },
      { name: 'to', type: 'Person' },
      { name: 'contents', type: 'string' },
    ],
  },
  primaryType: 'Mail',
  message: {
    from: { name: 'Cow', wallet: '0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826' },
    to: { name: 'Bob', wallet: '0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB' },
    contents: 'Hello, Bob!',
  },
};
// What the wallet receives: the standard v4 document, with the domain's type spelled out.
const typedDataV4 = {
  ...typedData,
  types: {
    EIP712Domain: [
      { name: 'name', type: 'string' },
      { name: 'version', type: 'string' },
      { name: 'chainId', type: 'uint256' },
      { name: 'verifyingContract', type: 'address' },
    ],
    ...typedData.types,
  },
};

const client = await SignClient.init({
  projectId,
  relayUrl,
  metadata: { name: 'Fearless signing dApp', description: 'Reference SDK peer', url: 'https://fearlesswallet.io/', icons: [] },
  storage,
});
step('sdk ready', { version, relayUrl });

const result = { sdk: `@walletconnect/sign-client ${version}`, relayUrl, ok: false, steps, checks: {} };
try {
  const { uri, approval } = await client.connect({ optionalNamespaces: namespaces });
  await fs.writeFile(path.join(exchange, 'uri-sign.txt'), uri);
  step('proposal published');
  const session = await Promise.race([approval(), timeout(180_000, 'approval')]);
  const evmAccount = session.namespaces.eip155.accounts[0].split(':')[2];
  const polkadotAccount = session.namespaces.polkadot.accounts[0].split(':')[2];
  step('session settled', { evmAccount, polkadotAccount });

  // EIP-191 personal_sign.
  const message = Hex.fromString('Hello from the Fearless interop dApp');
  const personal = await Promise.race([
    client.request({ topic: session.topic, chainId: 'eip155:1', request: { method: 'personal_sign', params: [message, evmAccount] } }),
    timeout(120_000, 'personal_sign'),
  ]);
  const personalSigner = Secp256k1.recoverAddress({
    payload: PersonalMessage.getSignPayload(message),
    signature: Signature.fromHex(personal),
  });
  result.checks.personalSign = { signature: personal, recovered: personalSigner, ok: personalSigner.toLowerCase() === evmAccount.toLowerCase() };
  step('personal_sign checked', result.checks.personalSign);

  // EIP-712 eth_signTypedData_v4.
  const typed = await Promise.race([
    client.request({
      topic: session.topic,
      chainId: 'eip155:1',
      request: { method: 'eth_signTypedData_v4', params: [evmAccount, JSON.stringify(typedDataV4)] },
    }),
    timeout(120_000, 'eth_signTypedData_v4'),
  ]);
  const typedSigner = Secp256k1.recoverAddress({
    payload: TypedData.getSignPayload(typedData),
    signature: Signature.fromHex(typed),
  });
  result.checks.signTypedDataV4 = { signature: typed, recovered: typedSigner, ok: typedSigner.toLowerCase() === evmAccount.toLowerCase() };
  step('eth_signTypedData_v4 checked', result.checks.signTypedDataV4);

  // polkadot_signMessage: an ed25519 signature over the <Bytes> envelope, as polkadot-js signs messages.
  const polkadotMessage = Hex.fromString('Sign in to the Fearless interop dApp');
  const polkadot = await Promise.race([
    client.request({
      topic: session.topic,
      chainId: polkadotChain,
      request: { method: 'polkadot_signMessage', params: { address: polkadotAccount, message: polkadotMessage } },
    }),
    timeout(120_000, 'polkadot_signMessage'),
  ]);
  const publicKey = Base58.toBytes(polkadotAccount).slice(1, 33);
  const wrapped = Hex.toBytes(Hex.concat(Hex.fromString('<Bytes>'), polkadotMessage, Hex.fromString('</Bytes>')));
  const signatureBytes = Hex.toBytes(polkadot.signature);
  result.checks.polkadotSignMessage = {
    signature: polkadot.signature,
    ok: ed25519.verify(signatureBytes, wrapped, publicKey),
    bareMessageRejected: !ed25519.verify(signatureBytes, Hex.toBytes(polkadotMessage), publicKey),
  };
  step('polkadot_signMessage checked', result.checks.polkadotSignMessage);

  await client.disconnect({ topic: session.topic, reason: { code: 6000, message: 'Interop check done' } });
  step('session ended by the dApp');
  await fs.writeFile(path.join(exchange, 'dapp-done.txt'), session.topic);

  result.ok = Object.values(result.checks).every((check) => check.ok) && result.checks.polkadotSignMessage.bareMessageRejected;
} catch (error) {
  step('failed', { error: error?.stack ?? error?.message ?? JSON.stringify(error) });
} finally {
  await fs.writeFile(path.join(exchange, 'result.json'), JSON.stringify(result, null, 2));
  await client.core.relayer.transportClose().catch(() => undefined);
  process.exit(result.ok ? 0 : 1);
}
