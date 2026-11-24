// Writes cryptography vectors computed by the WalletConnect SDK most dApps ship, for the differential check in
// Packages/FearlessWalletConnect (ReferenceVectorTests). The SDK is under the WalletConnect Community License, so it
// is never a dependency of this repository: install @walletconnect/utils and @walletconnect/relay-auth outside it.
//
//   WALLETCONNECT_REFERENCE_SDK=<dir> node scripts/walletconnect/reference-vectors.mjs <out.json> [count]

import { randomBytes } from 'node:crypto';
import fs from 'node:fs/promises';
import { createRequire } from 'node:module';
import path from 'node:path';

const reference = process.env.WALLETCONNECT_REFERENCE_SDK;
const [output, countArgument] = process.argv.slice(2);
if (!reference || !output) {
  console.error('Set WALLETCONNECT_REFERENCE_SDK and pass the output file.');
  process.exit(2);
}

const requireFrom = createRequire(path.join(path.resolve(reference), 'package.json'));
const utils = requireFrom('@walletconnect/utils');
const relayAuth = requireFrom('@walletconnect/relay-auth');
const version = JSON.parse(
  await fs.readFile(path.join(path.resolve(reference), 'node_modules/@walletconnect/utils/package.json'), 'utf8')
).version;

const hex = (bytes) => Buffer.from(bytes).toString('hex');
const count = Number(countArgument ?? 400);
const samples = [
  '{}',
  '{"id":1,"jsonrpc":"2.0","result":true}',
  '{"id":1,"jsonrpc":"2.0","method":"wc_sessionPing","params":{"text":"ü😀 \\u0000 \\" \\\\"}}',
];

const cases = [];
for (let index = 0; index < count; index++) {
  const self = utils.generateKeyPair();
  const peer = utils.generateKeyPair();
  const symKey = utils.deriveSymKey(self.privateKey, peer.publicKey);
  const message =
    samples[index % samples.length] + ' '.repeat(index % 7) + hex(randomBytes(index % 97)) + '中文'.repeat(index % 3);
  const iv = hex(randomBytes(12));
  const sealed = utils.encrypt({ symKey, message, iv });
  if (utils.decrypt({ symKey, encoded: sealed }) !== message) throw new Error('reference round trip failed');

  const seed = randomBytes(32);
  const keyPair = relayAuth.generateKeyPair(seed);
  const audience = index % 2 ? 'wss://relay.walletconnect.com' : 'wss://relay.walletconnect.org';
  const subject = hex(randomBytes(32));
  const issuedAt = 1_700_000_000 + index;
  const jwt = await relayAuth.signJWT(subject, audience, 86_400, keyPair, issuedAt);

  cases.push({
    privateKey: self.privateKey,
    publicKey: self.publicKey,
    peerPublicKey: peer.publicKey,
    symKey,
    topic: utils.hashKey(symKey),
    message,
    messageHash: utils.hashMessage(message),
    iv,
    sealed,
    seed: hex(seed),
    did: relayAuth.encodeIss(keyPair.publicKey),
    audience,
    subject,
    issuedAt,
    jwt,
  });
}

await fs.writeFile(output, JSON.stringify({ reference: `@walletconnect/utils ${version}`, cases }, null, 1));
console.log(`wrote ${cases.length} cases from @walletconnect/utils ${version}`);
