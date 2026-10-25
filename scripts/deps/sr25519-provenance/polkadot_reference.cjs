// Reference values from @polkadot/keyring + @polkadot/util-crypto (sr25519 through
// @scure/sr25519, a pure JavaScript implementation that shares no code with the Rust
// schnorrkel crate inside sr25519lib.xcframework).
//
// usage: node polkadot_reference.cjs <node_modules owner dir> <request.json>  -> JSON on stdout
// request: { derive: [{id, suri}], seeds: [{id, seedHex}], sign: [{id, messageHex}],
//            verify: [{publicKey, messageHex, signature}],
//            exportJson: [{id, password, name}], decodeJson: [{json, password}] }
const fs = require('fs');
const path = require('path');
const { createRequire } = require('module');

const [owner, requestPath] = process.argv.slice(2);
const load = createRequire(path.join(path.resolve(owner), 'package.json'));
const { Keyring } = load('@polkadot/keyring');
const utilCrypto = load('@polkadot/util-crypto');
const { hexToU8a, u8aToHex } = load('@polkadot/util');

const hex = (bytes) => u8aToHex(bytes).slice(2);
const unhex = (text) => hexToU8a('0x' + text);
const version = (name) => JSON.parse(
  fs.readFileSync(path.join(path.resolve(owner), 'node_modules', name, 'package.json'), 'utf8')
).version;

async function main() {
  await utilCrypto.cryptoWaitReady();
  const request = JSON.parse(fs.readFileSync(requestPath, 'utf8'));
  const pairs = {};
  const out = {
    libraries: {
      '@polkadot/keyring': version('@polkadot/keyring'),
      '@polkadot/util-crypto': version('@polkadot/util-crypto'),
      '@scure/sr25519': version('@scure/sr25519'),
    },
    derive: [], sign: [], verify: [], exportJson: [], decodeJson: [],
  };

  for (const { id, suri } of request.derive || []) {
    const { password, path: junctions, phrase } = utilCrypto.keyExtractSuri(suri);
    const root = utilCrypto.sr25519PairFromSeed(utilCrypto.mnemonicToMiniSecret(phrase, password));
    pairs[id] = { raw: utilCrypto.keyFromPath(root, junctions, 'sr25519'), suri };
  }
  for (const { id, seedHex } of request.seeds || []) {
    pairs[id] = { raw: utilCrypto.sr25519PairFromSeed(unhex(seedHex)), suri: '0x' + seedHex };
  }
  for (const [id, { raw }] of Object.entries(pairs)) {
    out.derive.push({
      id,
      publicKey: hex(raw.publicKey),
      // polkadot-js keeps the secret in the Ed25519-expanded form (scalar * 8 || nonce).
      secretKeyEd25519: hex(raw.secretKey),
      ss58: Object.fromEntries([0, 2, 42].map((prefix) => [prefix, utilCrypto.encodeAddress(raw.publicKey, prefix)])),
    });
  }
  for (const { id, messageHex } of request.sign || []) {
    const signature = utilCrypto.sr25519Sign(unhex(messageHex), pairs[id].raw);
    out.sign.push({ id, messageHex, signature: hex(signature) });
  }
  for (const { publicKey, messageHex, signature } of request.verify || []) {
    out.verify.push(utilCrypto.sr25519Verify(unhex(messageHex), unhex(signature), unhex(publicKey)));
  }
  for (const { id, password, name } of request.exportJson || []) {
    const keyring = new Keyring({ type: 'sr25519', ss58Format: 42 });
    const pair = keyring.addFromUri(pairs[id].suri, { name }, 'sr25519');
    const json = pair.toJson(password);
    // A soft junction draws a new nonce on every derivation, so the secret inside this JSON
    // is read back from the JSON (PKCS8: 16-byte header, 64-byte secret, 5-byte divider,
    // public key) rather than taken from `derive`.
    const pkcs8 = utilCrypto.jsonDecrypt(json, password);
    if (pkcs8.length !== 117 || hex(pkcs8.subarray(85)) !== hex(pair.publicKey)) {
      throw new Error(`unexpected PKCS8 layout for ${id}`);
    }
    out.exportJson.push({ id, password, json, secretKeyEd25519: hex(pkcs8.subarray(16, 80)) });
  }
  for (const { json, password } of request.decodeJson || []) {
    const keyring = new Keyring({ type: 'sr25519', ss58Format: 42 });
    const pair = keyring.addFromJson(json);
    pair.decodePkcs8(password);
    const message = unhex('00');
    const pkcs8 = utilCrypto.jsonDecrypt(json, password);
    out.decodeJson.push({
      address: pair.address,
      publicKey: hex(pair.publicKey),
      type: pair.type,
      // PKCS8 secret in polkadot-js's Ed25519-expanded form (scalar * 8 || nonce).
      secretKeyEd25519: hex(pkcs8.subarray(16, 80)),
      // A verifying signature proves the keyring decoded the pair.
      signature: hex(pair.sign(message)),
      messageHex: '00',
    });
  }
  process.stdout.write(JSON.stringify(out, null, 1) + '\n');
}

main().catch((error) => { console.error(error); process.exit(1); });
