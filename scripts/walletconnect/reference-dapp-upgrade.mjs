// The upgrade check on the live WalletConnect relay: a dApp pairs with an earlier Fearless build (Reown 1.8.0) and
// keeps its session while the simulator is updated to this branch's build, which must go on serving it.
//
// The WalletConnect SDK is under the WalletConnect Community License, so it is never a dependency of this
// repository; install @walletconnect/sign-client outside it and pass that directory as WALLETCONNECT_REFERENCE_SDK.
//
//   WALLETCONNECT_REFERENCE_SDK=<dir> WALLETCONNECT_PROJECT_ID=<id> FEARLESS_WC_EXCHANGE=<dir> \
//     node scripts/walletconnect/reference-dapp-upgrade.mjs
//
// Steps, with the exchange directory carrying links and markers between the two builds' tests:
//   1. pairing link -> uri-upgrade.txt; the earlier build approves (phase A);
//   2. a request the earlier build declines (its signing policy is off);
//   3. after phase-a-done, a request sent while no wallet runs: the relay holds it for the new build;
//   4. the new build declines it, both sides ping, and the new build ends the session (phase B).

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
const timeout = (ms, label) => new Promise((_, reject) => setTimeout(() => reject(new Error(`timed out: ${label}`)), ms));
const waitForFile = async (name, ms) => {
  const deadline = Date.now() + ms;
  while (Date.now() < deadline) {
    try {
      const text = await fs.readFile(path.join(exchange, name), 'utf8');
      if (text) return text;
    } catch {
      /* not yet */
    }
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  throw new Error(`timed out waiting for ${name}`);
};
const refusal = async (promise, label, ms) => {
  try {
    const value = await Promise.race([promise, timeout(ms, label)]);
    return { answered: true, value };
  } catch (error) {
    return { code: error.code, message: error.message };
  }
};

const client = await SignClient.init({
  projectId,
  relayUrl,
  metadata: { name: 'Fearless upgrade dApp', description: 'Reference SDK peer', url: 'https://fearlesswallet.io/', icons: [] },
  storage,
});
step('sdk ready', { version, relayUrl });

const result = { sdk: `@walletconnect/sign-client ${version}`, relayUrl, ok: false, steps };
try {
  const { uri, approval } = await client.connect({
    optionalNamespaces: {
      eip155: { chains: ['eip155:1'], methods: ['personal_sign'], events: ['chainChanged', 'accountsChanged'] },
      polkadot: { chains: ['polkadot:91b171bb158e2d3848fa23a9f1c25182'], methods: ['polkadot_signMessage'], events: [] },
    },
  });
  await fs.writeFile(path.join(exchange, 'uri-upgrade.txt'), uri);
  step('proposal published');
  const session = await Promise.race([approval(), timeout(15 * 60_000, 'approval by the earlier build')]);
  step('session settled by the earlier build', {
    accounts: Object.values(session.namespaces).flatMap((namespace) => namespace.accounts),
    expiry: session.expiry,
  });
  const polkadotAddress = session.namespaces.polkadot.accounts[0].split(':')[2];
  const evmAddress = session.namespaces.eip155.accounts[0].split(':')[2];

  const before = await refusal(
    client.request({
      topic: session.topic,
      chainId: 'polkadot:91b171bb158e2d3848fa23a9f1c25182',
      request: { method: 'polkadot_signMessage', params: { address: polkadotAddress, message: '0x01' } },
    }),
    'request to the earlier build',
    120_000
  );
  step('earlier build answered a request', before);
  await fs.writeFile(path.join(exchange, 'dapp-phase-a-request-done.txt'), String(before.code ?? 'answered'));

  await waitForFile('phase-a-done.txt', 30 * 60_000);
  step('earlier build stopped; requesting while no wallet runs');
  const deleted = new Promise((resolve) => client.on('session_delete', resolve));
  const held = refusal(
    client.request({ topic: session.topic, chainId: 'eip155:1', request: { method: 'personal_sign', params: ['0x48656c6c6f', evmAddress] } }),
    'request held for the new build',
    40 * 60_000
  );
  await fs.writeFile(path.join(exchange, 'dapp-held-request-sent.txt'), session.topic);
  const after = await held;
  step('new build answered the held request', after);

  await Promise.race([client.ping({ topic: session.topic }), timeout(120_000, 'ping to the new build')]);
  step('new build answered a ping');
  await fs.writeFile(path.join(exchange, 'dapp-ping-done.txt'), 'ok');

  const deletion = await Promise.race([deleted, timeout(10 * 60_000, 'disconnection by the new build')]);
  step('new build ended the session', { sameTopic: deletion.topic === session.topic });

  result.before = before;
  result.after = after;
  result.ok = before.code === 4001 && after.code === 4001 && deletion.topic === session.topic;
} catch (error) {
  step('failed', { error: String(error?.stack ?? error) });
} finally {
  await fs.writeFile(path.join(exchange, 'result.json'), JSON.stringify(result, null, 2));
  await client.core.relayer.transportClose().catch(() => undefined);
  process.exit(result.ok ? 0 : 1);
}
