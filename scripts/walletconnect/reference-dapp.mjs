// A dApp on the live WalletConnect relay for the iOS interop check, driven by the WalletConnect SDK most dApps ship.
//
// The SDK is under the WalletConnect Community License, so it is never a dependency of this repository. Install
// @walletconnect/sign-client outside the repository and pass that directory as WALLETCONNECT_REFERENCE_SDK:
//
//   WALLETCONNECT_REFERENCE_SDK=<dir> WALLETCONNECT_PROJECT_ID=<id> FEARLESS_WC_EXCHANGE=<dir> \
//     node scripts/walletconnect/reference-dapp.mjs
//
// It writes pairing links to the exchange directory for the wallet test (Packages/FearlessWalletConnect,
// LiveRelayInteropTests) and records what it saw in result.json there:
//   1. a proposal the wallet approves, then a personal_sign request the wallet answers, a request the wallet
//      refuses, a ping, and the wallet's disconnection;
//   2. a second proposal the wallet refuses.

import fs from 'node:fs/promises';
import { createRequire } from 'node:module';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const reference = process.env.WALLETCONNECT_REFERENCE_SDK;
const projectId = process.env.WALLETCONNECT_PROJECT_ID;
const exchange = process.env.FEARLESS_WC_EXCHANGE;
const relayUrl = process.env.WALLETCONNECT_RELAY_URL ?? 'wss://relay.walletconnect.com';
if (!reference || !projectId || !exchange) {
  console.error('Set WALLETCONNECT_REFERENCE_SDK, WALLETCONNECT_PROJECT_ID and FEARLESS_WC_EXCHANGE.');
  process.exit(2);
}

const requireFrom = createRequire(path.join(path.resolve(reference), 'package.json'));
const sdk = await import(pathToFileURL(requireFrom.resolve('@walletconnect/sign-client')).href);
const SignClient = sdk.SignClient ?? sdk.default?.SignClient ?? sdk.default;
const version = JSON.parse(
  await fs.readFile(path.join(path.resolve(reference), 'node_modules/@walletconnect/sign-client/package.json'), 'utf8')
).version;

const values = new Map();
const storage = {
  getKeys: async () => [...values.keys()],
  getEntries: async () => [...values.entries()].map(([key, value]) => [key, JSON.parse(value)]),
  getItem: async (key) => (values.has(key) ? JSON.parse(values.get(key)) : undefined),
  setItem: async (key, value) => void values.set(key, JSON.stringify(value)),
  removeItem: async (key) => void values.delete(key),
};

const steps = [];
const step = (name, detail = {}) => {
  steps.push({ name, at: new Date().toISOString(), ...detail });
  console.log(`[dapp] ${name}`, JSON.stringify(detail));
};
const timeout = (ms, label) =>
  new Promise((_, reject) => setTimeout(() => reject(new Error(`timed out: ${label}`)), ms));

const client = await SignClient.init({
  projectId,
  relayUrl,
  metadata: { name: 'Fearless interop dApp', description: 'Reference SDK peer', url: 'https://fearlesswallet.io/', icons: [] },
  storage,
});
step('sdk ready', { version, relayUrl });

const namespaces = {
  eip155: { chains: ['eip155:1'], methods: ['personal_sign', 'eth_signTypedData_v4'], events: ['chainChanged', 'accountsChanged'] },
  polkadot: {
    chains: ['polkadot:91b171bb158e2d3848fa23a9f1c25182'],
    methods: ['polkadot_signMessage', 'polkadot_signTransaction'],
    events: [],
  },
};

const result = { sdk: `@walletconnect/sign-client ${version}`, relayUrl, ok: false, steps };
try {
  // 1. Approval, requests, ping and the wallet's disconnection.
  const first = await client.connect({ optionalNamespaces: namespaces });
  await fs.writeFile(path.join(exchange, 'uri-approve.txt'), first.uri);
  step('proposal published', { pairingTopic: first.uri.slice(3, 11) + '…' });
  const session = await Promise.race([first.approval(), timeout(180_000, 'approval')]);
  step('session settled', {
    accounts: Object.values(session.namespaces).flatMap((namespace) => namespace.accounts),
    controller: session.controller.slice(0, 8) + '…',
    expiry: session.expiry,
  });

  const deleted = new Promise((resolve) => client.on('session_delete', resolve));
  const account = session.namespaces.eip155.accounts[0].split(':')[2];
  const signature = await Promise.race([
    client.request({ topic: session.topic, chainId: 'eip155:1', request: { method: 'personal_sign', params: ['0x48656c6c6f', account] } }),
    timeout(120_000, 'personal_sign'),
  ]);
  step('personal_sign answered', { signature });

  let refusal;
  try {
    await Promise.race([
      client.request({
        topic: session.topic,
        chainId: 'polkadot:91b171bb158e2d3848fa23a9f1c25182',
        request: { method: 'polkadot_signMessage', params: { address: session.namespaces.polkadot.accounts[0].split(':')[2], message: '0x01' } },
      }),
      timeout(120_000, 'polkadot_signMessage'),
    ]);
  } catch (error) {
    refusal = { code: error.code, message: error.message };
  }
  step('polkadot_signMessage refused', refusal ?? { refused: false });

  await Promise.race([client.ping({ topic: session.topic }), timeout(60_000, 'ping')]);
  step('ping answered');
  await fs.writeFile(path.join(exchange, 'dapp-ready-for-delete.txt'), session.topic);

  const deletion = await Promise.race([deleted, timeout(120_000, 'session_delete')]);
  step('session deleted by the wallet', { topic: deletion.topic === session.topic });

  // 2. Refusal.
  const second = await client.connect({ optionalNamespaces: namespaces });
  await fs.writeFile(path.join(exchange, 'uri-reject.txt'), second.uri);
  step('second proposal published');
  try {
    await Promise.race([second.approval(), timeout(180_000, 'refusal')]);
    step('second proposal approved unexpectedly');
  } catch (error) {
    step('second proposal refused', { code: error.code, message: error.message });
    result.refusal = { code: error.code, message: error.message };
  }

  result.signature = signature;
  result.requestRefusal = refusal;
  result.ok = signature === '0xfearless-interop-signature' && refusal?.code === 4001 && result.refusal?.code === 5000;
} catch (error) {
  step('failed', { error: String(error?.stack ?? error) });
} finally {
  await fs.writeFile(path.join(exchange, 'result.json'), JSON.stringify(result, null, 2));
  await client.core.relayer.transportClose().catch(() => undefined);
  process.exit(result.ok ? 0 : 1);
}
