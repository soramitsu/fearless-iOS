"""Explicit public fixture inventories. No expected secrets or RC derivation lives here."""
import copy
import hashlib
from pathlib import Path

BASE = 'mnemonic-roots-v1'
CURVES = 'mnemonic-curves-paths-v1'
SEEDS = 'raw-seeds-v1'
JSON_ONLY = 'json-only-v1'
CHAINS = 'per-chain-v1'
TON = 'ton-typed-v1'
ETHEREUM_ROOT = '//44//60//0/0/0'
VARIANTS = {
    BASE: [
        ('GW-M1', 'GW-M1', 'sr25519', '', ETHEREUM_ROOT, 'GW-M1/sr25519/root/publicKey', 'GW-M1/ethereum/m44h-60h-0h-0-0/address'),
        ('GW-M2', 'GW-M2', 'sr25519', '', ETHEREUM_ROOT, 'GW-M2/sr25519/root/publicKey', 'GW-M2/ethereum/m44h-60h-0h-0-0/address'),
    ],
}
VARIANTS[CURVES] = VARIANTS[BASE] + [
    ('GW-M4-sr25519', 'GW-M4', 'sr25519', '//polkadot//0///p@ss', '//44//60//0/0/1', 'GW-M4/sr25519/hard-password/publicKey', 'GW-M4/ethereum/m44h-60h-0h-0-1/address'),
    ('GW-M4-ed25519', 'GW-M4', 'ed25519', '//polkadot//0///p@ss', '//44//60//0/0/1', 'GW-M4/ed25519/hard-password/publicKey', 'GW-M4/ethereum/m44h-60h-0h-0-1/address'),
    # This extra ECDSA/path case has historical writer evidence; the accepted golden catalog lacks this check.
    ('GW-M4-ecdsa', 'GW-M4', 'ecdsa', '//polkadot//0///p@ss', '//44//60//0/0/1', None, 'GW-M4/ethereum/m44h-60h-0h-0-1/address'),
    ('GW-M5-hard-soft', 'GW-M5', 'sr25519', '//polkadot/0', ETHEREUM_ROOT, 'GW-M5/sr25519/hard-soft/publicKey', 'GW-M1/ethereum/m44h-60h-0h-0-0/address'),
    ('GW-M5-soft', 'GW-M5', 'sr25519', '/0', ETHEREUM_ROOT, 'GW-M5/sr25519/soft/publicKey', 'GW-M1/ethereum/m44h-60h-0h-0-0/address'),
]

VARIANTS[SEEDS] = [
    ('GW-S1-sr25519', 'GW-S1', 'sr25519', '', None, 'GW-S1/sr25519/seed/publicKey', None),
    ('GW-S1-ed25519', 'GW-S1', 'ed25519', '', None, 'GW-S1/ed25519/seed/publicKey', None),
    ('GW-S1-with-GW-S2', 'GW-S1', 'sr25519', '', '', 'GW-S1/sr25519/seed/publicKey', 'GW-S2/ethereum-private-key/address'),
]

VARIANTS[JSON_ONLY] = [
    ('GW-J1-' + curve, 'GW-J1', curve, '', None, 'GW-J1/json-decrypt/' + curve + '/publicKey', None)
    for curve in ['sr25519', 'ed25519', 'ecdsa']
]

# Chain identifiers are checked against the exact historical Chain.genesisHash member by prepare.py.
CHAIN_IMPORTS = [
    ('GW-M2-kusama', 'GW-M2', 'mnemonic', 'sr25519', '', 'kusama',
     'b0a8d493285c2df73290dfb7e61f870f17b41801197a149ca93654499ea3dafe', 2, False,
     'GW-M2/sr25519/root/publicKey'),
    ('GW-S1-westend', 'GW-S1', 'seed', 'ed25519', '', 'westend',
     'e143f23803ac50e8f6f8e62695d1ce9e4e1d68aa36c1cd2cfd15340213f3423e', 42, False,
     'GW-S1/ed25519/seed/publicKey'),
    ('GW-J1-rococo', 'GW-J1', 'json', 'ecdsa', '', 'rococo',
     '6408de7737c59c238890533af25896a2c20608d8b380bb01029acb392781063e', 42, False,
     'GW-J1/json-decrypt/ecdsa/publicKey'),
    ('GW-M2-moonriver', 'GW-M2', 'mnemonic', 'ecdsa', ETHEREUM_ROOT, 'moonriver',
     '401a1f9dca3da46f5c4091016c8a2f26dcea05865116b286f60f668207d1474b', 1285, True,
     'GW-M2/ethereum/m44h-60h-0h-0-0/address'),
]
VARIANTS[CHAINS] = [('GW-M1-chain', *VARIANTS[BASE][0][1:])]

VARIANTS[TON] = [(name, name, 'ed25519', '', None, None, None) for name in ['GW-T1'] + ['GW-T2'+suffix for suffix in 'abcdef']]

def make_wallets(catalog, profile):
    by_id = {w['id']: w for w in catalog['wallets']}
    wallets = []
    for variant, source, curve, path, ethereum_path, _, address_check in VARIANTS[profile]:
        secret = copy.deepcopy(by_id[source]['secret'])
        if source == 'GW-M4' and (secret['substratePath'] != path or secret['ethereumPath'] != "m/44'/60'/0'/0/1"):
            raise ValueError('Custom-path public catalog drift')
        if source == 'GW-M5' and path not in secret['substratePaths']:
            raise ValueError('Soft-junction public catalog drift')
        if profile == SEEDS and address_check:
            secret['ethereumPrivateKeyHex'] = by_id['GW-S2']['secret']['privateKeyHex']
        wallets.append(dict(id=variant, catalogId=source, secret=secret, importKind='ton' if profile == TON else 'json' if profile == JSON_ONLY else 'seed' if profile == SEEDS else 'mnemonic', cryptoType=curve,
                            substrateDerivationPath=path, ethereumDerivationPath=ethereum_path))
    if profile == CHAINS:
        wallets[0]['chainImports'] = [dict(id=name, catalogId=source, secret=copy.deepcopy(by_id[source]['secret']),
            importKind=kind, cryptoType=curve, derivationPath=path, chainName=chain, chainId=chain_id,
            addressPrefix=prefix, ethereumBased=ethereum)
            for name, source, kind, curve, path, chain, chain_id, prefix, ethereum, _ in CHAIN_IMPORTS]
    return wallets

def require_snapshot(state, profile, golden):
    variants = VARIANTS[profile]
    if state.get('profile', BASE) != profile or [w['fixture'] for w in state['wallets']] != [v[0] for v in variants]:
        raise ValueError('Historical inventory does not match the required profile')
    if profile == TON:
        require_ton_snapshot(state, golden)
        return
    expected_keys = 14 if profile == CHAINS else 4 if profile == JSON_ONLY else 1 + sum((2 + (2 if v[4] is not None else 0)) if profile == SEEDS else 6 + bool(v[3]) for v in variants)
    if len(state['keychain']) != expected_keys or len({k['tag'] for k in state['keychain']}) != expected_keys:
        raise ValueError('Historical secret inventory missing or duplicated')
    clean = lambda value: value.lower().removeprefix('0x')
    for wallet, (_, _, curve, path, eth_path, key_check, address_check) in zip(state['wallets'], variants):
        if wallet.get('cryptoType', 0) != {'sr25519':0,'ed25519':1,'ecdsa':2}[curve] or wallet.get('substrateDerivationPath', '') != path or wallet.get('ethereumDerivationPath', None if profile in (SEEDS, JSON_ONLY) else ETHEREUM_ROOT) != eth_path:
            raise ValueError('Historical curve/path differs from the required inventory')
        if key_check and clean(wallet['substratePublicKey']) != clean(golden['values'][key_check]):
            raise ValueError('Historical public key differs from accepted old oracle')
        if profile in (SEEDS, JSON_ONLY) and wallet.get('mnemonic') is not None:
            raise ValueError('Seed-only historical fixture unexpectedly contains a mnemonic')
        if address_check is None:
            if wallet.get('ethereumAddress') is not None or wallet.get('ethereumPublicKey') is not None:
                raise ValueError('Unexpected linked Ethereum identity')
        elif clean(wallet['ethereumAddress']) != clean(golden['values'][address_check]):
            raise ValueError('Historical linked Ethereum identity differs from accepted old oracle')
    if profile == CURVES:
        # All four mandatory GW-M5 entries, including addresses, are independently checked.
        for variant, prefix, check in [('GW-M5-hard-soft', '0', 'GW-M5/sr25519/hard-soft/ss58-0'),
                                       ('GW-M5-soft', '42', 'GW-M5/sr25519/soft/ss58-42')]:
            wallet = next(w for w in state['wallets'] if w['fixture'] == variant)
            if wallet['substrateAddresses'][prefix] != golden['values'][check]:
                raise ValueError('Historical soft-junction address differs from accepted old oracle')

    if profile == SEEDS:
        for wallet in state['wallets']:
            if wallet['cryptoType'] == 0:
                for prefix in ['0', '42']:
                    if wallet['substrateAddresses'][prefix] != golden['values']['GW-S1/sr25519/seed/ss58-' + prefix]:
                        raise ValueError('Historical raw-seed address differs from accepted old oracle')

    if profile == JSON_ONLY:
        probes = state.get('negativeImports', [])
        expected = ['wrong-password', 'NFD-password', 'ethereum-v3']
        if [p.get('probe') for p in probes] != expected or any(p.get('rejected') is not True or p.get('keysUnchanged') is not True for p in probes):
            raise ValueError('Historical JSON rejection evidence missing or mutated secrets')

    if profile == CHAINS:
        wallet = state['wallets'][0]
        children = wallet.get('chainAccounts', [])
        if [c.get('fixture') for c in children] != [v[0] for v in CHAIN_IMPORTS] or len({c['chainId'] for c in children}) != 4:
            raise ValueError('Historical per-chain inventory missing or duplicated')
        if state.get('publicPin') != '135790' or set(wallet.get('originalRootSeeds', {})) != {'substrate', 'ethereum'}:
            raise ValueError('Original root seed capture or public PIN missing')
        for child, (_, _, kind, curve, path, _, chain_id, prefix, ethereum, check) in zip(children, CHAIN_IMPORTS):
            if (child.get('cryptoType') != {'sr25519':0,'ed25519':1,'ecdsa':2}[curve]
                or child.get('chainId') != chain_id or child.get('ethereumBased') != ethereum
                or child.get('addressPrefix') != prefix or child.get('derivationPath') != path
                or child.get('importKind') != kind or not child.get('expectedExportSeed')):
                raise ValueError('Historical per-chain descriptor or stored export capture drift')
            actual = child['accountId'] if ethereum else child['publicKey']
            if clean(actual) != clean(golden['values'][check]):
                raise ValueError('Historical child identity differs from accepted old oracle')
            if (child.get('mnemonic') is not None) != (kind == 'mnemonic'):
                raise ValueError('Historical child phrase availability drift')
        by_tag = {k['tag']: k.get('hex') for k in state['keychain']}
        for ecosystem, original in wallet['originalRootSeeds'].items():
            if not original or by_tag.get(wallet['rootSeedTags'][ecosystem]) == original:
                raise ValueError('Historical overwritten root seed behavior not preserved')

def require_ton_snapshot(state, golden):
    if len(state['keychain']) != 16 or len({k['tag'] for k in state['keychain']}) != 16 or '' not in {k['tag'] for k in state['keychain']}:
        raise ValueError('Historical TON or explicit empty-tag inventory missing/duplicated')
    if state.get('publicPin') != '135790' or state.get('emptyTagFixture', {}).get('origin') != 'explicit-old-helper-compatibility-probe':
        raise ValueError('TON public PIN or explicit empty-tag provenance missing')
    control=state['emptyTagFixture'];empty=next(k for k in state['keychain'] if k['tag']=='')
    if control.get('normalTonImportWritesEmptyTag') is not False or control.get('publicCatalog') != 'GW-S1' or control.get('bytes') != len(bytes.fromhex(empty['hex'])):
        raise ValueError('Empty-tag compatibility control provenance or bytes differ')
    for wallet in state['wallets']:
        name=wallet['fixture'];prefix=name+'/ton-native/'+('exact' if name=='GW-T1' else 'exact-split')
        if wallet.get('tonPublicKey') != golden['values'][prefix+'/publicKey'].lower().removeprefix('0x') or wallet.get('tonAddress') != golden['values'][prefix+'/v4r2-address']:
            raise ValueError('Historical TON identity differs from accepted old oracle')
        if wallet.get('tonContractVersion') != 'v4R2' or not wallet.get('tonSerializedAddress') or not wallet.get('tonPhrase'):
            raise ValueError('Historical TON stored fields missing')
        if any(wallet.get(key) is not None for key in ['substratePublicKey','substrateAccountId','ethereumPublicKey','ethereumAddress','mnemonic']):
            raise ValueError('TON-only fixture contains fabricated regular root identity')
        if name!='GW-T1' and hashlib.sha256(wallet['tonPhrase'].encode()).hexdigest()!=golden['values'][name+'/export/sha256']:
            raise ValueError('Historical typed phrase was normalized or changed')
        stored=next(k['hex'] for k in state['keychain'] if k['tag']==wallet['metaId']+'-entropy')
        if bytes.fromhex(stored)!=wallet['tonPhrase'].encode():
            raise ValueError('Historical TON entropy tag does not preserve exact UTF8')

def require_input_pins(run, manifest):
    if hashlib.sha256((Path(run) / 'inputs.json').read_bytes()).hexdigest() != manifest['inputSha256']:
        raise ValueError('Historical writer input drift')
    for pin in manifest.get('publicFixturePins', []):
        raw = Path(pin['path']).read_bytes()
        if len(raw) != pin['bytes'] or hashlib.sha256(raw).hexdigest() != pin['sha256']:
            raise ValueError('Historical encrypted fixture drift')
