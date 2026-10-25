import copy
import unittest
import hashlib
import tempfile
from pathlib import Path
from profiles import BASE, CURVES, SEEDS, JSON_ONLY, CHAINS, CHAIN_IMPORTS, TON, VARIANTS, make_wallets, require_snapshot, require_input_pins

class ProfileInventoryTests(unittest.TestCase):
    def catalog(self):
        return dict(wallets=[dict(id=name, secret=dict(mnemonic='public fixture '+name,
            substratePath='//polkadot//0///p@ss', ethereumPath="m/44'/60'/0'/0/1",
            substratePaths=['//polkadot/0','/0'])) for name in ['GW-M1','GW-M2','GW-M4','GW-M5']])

    def test_writer_inventory_copies_exact_public_catalog_and_all_mandatory_soft_paths(self):
        catalog=self.catalog();saved=copy.deepcopy(catalog)
        wallets=make_wallets(catalog,CURVES)
        self.assertEqual(len(wallets),7)
        self.assertEqual([w['substrateDerivationPath'] for w in wallets[-2:]],['//polkadot/0','/0'])
        self.assertEqual([w['cryptoType'] for w in wallets[2:5]],['sr25519','ed25519','ecdsa'])
        self.assertEqual([w['id'] for w in make_wallets(catalog,BASE)],['GW-M1','GW-M2'])
        wallets[0]['secret']['mnemonic']='changed'
        self.assertEqual(catalog,saved)

    def test_unknown_profile_or_drifted_catalog_cannot_generate_a_replacement_fixture(self):
        with self.assertRaises(KeyError):make_wallets(self.catalog(),'unknown')
        for field,value in [('substratePath','//other'),('ethereumPath',"m/44'/60'/0'/0/0"),('substratePaths',[])]:
            catalog=self.catalog()
            index=3 if field=='substratePaths' else 2
            catalog['wallets'][index]['secret'][field]=value
            with self.subTest(field=field),self.assertRaises(ValueError):make_wallets(catalog,CURVES)

    def test_reader_gate_rejects_missing_duplicate_or_wrong_curve_path_and_golden_identity(self):
        golden=dict(values={});wallets=[]
        for i,(name,_,curve,path,eth,key,addr) in enumerate(VARIANTS[CURVES]):
            if key:golden['values'][key]='aa'
            golden['values'][addr]='bb'
            wallets.append(dict(fixture=name,cryptoType={'sr25519':0,'ed25519':1,'ecdsa':2}[curve],substrateDerivationPath=path,
                ethereumDerivationPath=eth,substratePublicKey='aa',ethereumAddress='bb',substrateAddresses={'0':'address0','42':'address42'}))
        golden['values']['GW-M5/sr25519/hard-soft/ss58-0']='address0'
        golden['values']['GW-M5/sr25519/soft/ss58-42']='address42'
        valid=dict(profile=CURVES,wallets=wallets,keychain=[dict(tag=str(i)) for i in range(48)])
        require_snapshot(valid,CURVES,golden)
        invalid=[]
        wrong=copy.deepcopy(valid);wrong['wallets'].pop();invalid.append(wrong)
        wrong=copy.deepcopy(valid);wrong['keychain'][1]=wrong['keychain'][0];invalid.append(wrong)
        for field,value in [('cryptoType',1),('substrateDerivationPath','/other'),('ethereumDerivationPath','/other'),('substratePublicKey','cc'),('ethereumAddress','cc')]:
            wrong=copy.deepcopy(valid);wrong['wallets'][0][field]=value;invalid.append(wrong)
        wrong=copy.deepcopy(valid);wrong['wallets'][-1]['substrateAddresses']['42']='other';invalid.append(wrong)
        for state in invalid:
            with self.subTest(state=state),self.assertRaises(ValueError):require_snapshot(state,CURVES,golden)

    def test_seed_inventory_preserves_exact_catalog_seed_without_inventing_mnemonic_or_ethereum(self):
        catalog=dict(wallets=[dict(id='GW-S1',secret=dict(seedHex='0x1234')),dict(id='GW-S2',secret=dict(privateKeyHex='0xabcd'))])
        original=copy.deepcopy(catalog)
        wallets=make_wallets(catalog,SEEDS)
        self.assertEqual([w['cryptoType'] for w in wallets],['sr25519','ed25519','sr25519'])
        self.assertTrue(all(w['importKind']=='seed' and w['secret']['seedHex']=='0x1234' and 'mnemonic' not in w['secret'] for w in wallets))
        self.assertNotIn('ethereumPrivateKeyHex',wallets[0]['secret'])
        self.assertIsNone(wallets[1]['ethereumDerivationPath'])
        self.assertEqual(wallets[2]['ethereumDerivationPath'],'')
        self.assertEqual(wallets[2]['secret']['ethereumPrivateKeyHex'],'0xabcd')
        self.assertEqual(catalog,original)

    def test_seed_gate_rejects_fabricated_phrase_or_optional_account_and_retains_golden_checks(self):
        golden=dict(values={});wallets=[]
        for name,_,curve,path,eth,key,addr in VARIANTS[SEEDS]:
            golden['values'][key]='aa'
            w=dict(fixture=name,cryptoType={'sr25519':0,'ed25519':1}[curve],substrateDerivationPath=path,substratePublicKey='aa',substrateAddresses={'0':'s0','42':'s42'})
            if addr:
                golden['values'][addr]='bb';w.update(ethereumAddress='bb',ethereumPublicKey='cc',ethereumDerivationPath=eth)
            wallets.append(w)
        golden['values']['GW-S1/sr25519/seed/ss58-0']='s0'
        golden['values']['GW-S1/sr25519/seed/ss58-42']='s42'
        valid=dict(profile=SEEDS,wallets=wallets,keychain=[dict(tag=str(i)) for i in range(9)])
        require_snapshot(valid,SEEDS,golden)
        for field,value in [('mnemonic','fabricated'),('ethereumAddress','bb'),('ethereumPublicKey','cc'),('substratePublicKey','ff')]:
            wrong=copy.deepcopy(valid);wrong['wallets'][0][field]=value
            with self.subTest(field=field),self.assertRaises(ValueError):require_snapshot(wrong,SEEDS,golden)
        wrong=copy.deepcopy(valid);wrong['wallets'][0]['substrateAddresses']['42']='wrong'
        with self.assertRaises(ValueError):require_snapshot(wrong,SEEDS,golden)
        wrong=copy.deepcopy(valid);wrong['keychain'].pop()
        with self.assertRaises(ValueError):require_snapshot(wrong,SEEDS,golden)

    def test_json_inventory_and_gate_require_all_curves_and_actual_rejection_outcomes(self):
        catalog=dict(wallets=[dict(id='GW-J1',secret=dict(of='GW-M1',password='Public-pässwörd'))])
        wallets=make_wallets(catalog,JSON_ONLY)
        self.assertEqual([w['cryptoType'] for w in wallets],['sr25519','ed25519','ecdsa'])
        self.assertTrue(all(w['importKind']=='json' and w['secret']==catalog['wallets'][0]['secret'] for w in wallets))
        golden=dict(values={v[5]:'aa' for v in VARIANTS[JSON_ONLY]})
        state=dict(profile=JSON_ONLY,wallets=[dict(fixture=v[0],cryptoType=i,substrateDerivationPath='',substratePublicKey='aa') for i,v in enumerate(VARIANTS[JSON_ONLY])],keychain=[dict(tag=str(i)) for i in range(4)],negativeImports=[dict(probe=p,rejected=True,keysUnchanged=True) for p in ['wrong-password','NFD-password','ethereum-v3']])
        require_snapshot(state,JSON_ONLY,golden)
        for field,value in [('rejected',False),('keysUnchanged',False),('probe','different')]:
            wrong=copy.deepcopy(state);wrong['negativeImports'][0][field]=value
            with self.subTest(field=field),self.assertRaises(ValueError):require_snapshot(wrong,JSON_ONLY,golden)
        wrong=copy.deepcopy(state);wrong['negativeImports'].pop()
        with self.assertRaises(ValueError):require_snapshot(wrong,JSON_ONLY,golden)

    def test_chain_inventory_copies_each_original_secret_and_has_distinct_historical_descriptors(self):
        catalog=self.catalog()
        catalog['wallets'] += [dict(id='GW-S1',secret=dict(seedHex='0x1234')),dict(id='GW-J1',secret=dict(password='public'))]
        before=copy.deepcopy(catalog)
        wallets=make_wallets(catalog,CHAINS)
        self.assertEqual([w['id'] for w in wallets],['GW-M1-chain'])
        children=wallets[0]['chainImports']
        self.assertEqual([c['catalogId'] for c in children],['GW-M2','GW-S1','GW-J1','GW-M2'])
        self.assertEqual([c['importKind'] for c in children],['mnemonic','seed','json','mnemonic'])
        self.assertEqual(len(set(c['chainId'] for c in children)),4)
        for child in children:
            self.assertEqual(child['secret'],next(w['secret'] for w in catalog['wallets'] if w['id']==child['catalogId']))
        children[0]['secret']['mnemonic']='changed'
        self.assertEqual(catalog,before)

    def test_chain_gate_requires_every_old_identity_capture_and_actual_root_overwrite(self):
        golden=dict(values={VARIANTS[CHAINS][0][5]:'aa',VARIANTS[CHAINS][0][6]:'bb'})
        children=[]
        for name,_,kind,curve,path,_,chain_id,prefix,ethereum,check in CHAIN_IMPORTS:
            golden['values'][check]='cc'
            child=dict(fixture=name,importKind=kind,cryptoType={'sr25519':0,'ed25519':1,'ecdsa':2}[curve],
                derivationPath=path,chainId=chain_id,addressPrefix=prefix,ethereumBased=ethereum,
                publicKey='cc',accountId='cc',expectedExportSeed='dd')
            if kind=='mnemonic': child['mnemonic']='public phrase'
            children.append(child)
        wallet=dict(fixture='GW-M1-chain',cryptoType=0,substrateDerivationPath='',ethereumDerivationPath='//44//60//0/0/0',
            substratePublicKey='aa',ethereumAddress='bb',chainAccounts=children,
            originalRootSeeds={'substrate':'original-sub','ethereum':'original-eth'},rootSeedTags={'substrate':'0','ethereum':'1'})
        state=dict(profile=CHAINS,wallets=[wallet],publicPin='135790',keychain=[dict(tag=str(i),hex='overwritten') for i in range(14)])
        require_snapshot(state,CHAINS,golden)
        invalid=[]
        wrong=copy.deepcopy(state);wrong['wallets'][0]['chainAccounts'].pop();invalid.append(wrong)
        for field,value in [('chainId','wrong'),('cryptoType',1),('publicKey','ff'),('expectedExportSeed',''),('ethereumBased',True),('derivationPath','/wrong')]:
            wrong=copy.deepcopy(state);wrong['wallets'][0]['chainAccounts'][0][field]=value;invalid.append(wrong)
        wrong=copy.deepcopy(state);wrong['wallets'][0]['chainAccounts'][1]['mnemonic']='fabricated';invalid.append(wrong)
        wrong=copy.deepcopy(state);wrong['keychain'][0]['hex']='original-sub';invalid.append(wrong)
        wrong=copy.deepcopy(state);wrong['wallets'][0]['originalRootSeeds'].pop('ethereum');invalid.append(wrong)
        wrong=copy.deepcopy(state);wrong['publicPin']='246810';invalid.append(wrong)
        for wrong in invalid:
            with self.subTest(wrong=wrong),self.assertRaises(ValueError):require_snapshot(wrong,CHAINS,golden)

    def test_ton_inventory_preserves_every_exact_typed_phrase(self):
        phrases=['one two','one  two','one two ',' one two','One two','one\ntwo','one  two ']
        catalog=dict(wallets=[dict(id=v[0],secret={('tonPhrase' if i==0 else 'storedText'):phrases[i]}) for i,v in enumerate(VARIANTS[TON])])
        before=copy.deepcopy(catalog);wallets=make_wallets(catalog,TON)
        self.assertEqual(len(wallets),7)
        self.assertTrue(all(w['importKind']=='ton' and w['ethereumDerivationPath'] is None for w in wallets))
        self.assertEqual([w['secret'] for w in wallets],[w['secret'] for w in catalog['wallets']])
        self.assertEqual(catalog,before)

    def test_ton_gate_rejects_normalization_fabricated_roots_and_unproven_empty_tag_claims(self):
        wallets=[];keys=[dict(tag='pincode',hex='313335373930'),dict(tag='',hex='00'*32)];golden=dict(values={})
        for i,v in enumerate(VARIANTS[TON]):
            name=v[0];phrase='public  typed phrase ';meta='meta'+str(i)
            wallets.append(dict(fixture=name,metaId=meta,tonPublicKey='aa',tonAddress='address',tonContractVersion='v4R2',tonSerializedAddress='bb',tonPhrase=phrase))
            prefix=name+'/ton-native/'+('exact' if i==0 else 'exact-split')
            golden['values'][prefix+'/publicKey']='aa';golden['values'][prefix+'/v4r2-address']='address'
            if i:golden['values'][name+'/export/sha256']=hashlib.sha256(phrase.encode()).hexdigest()
            keys.extend([dict(tag=meta+'-entropy',hex=phrase.encode().hex()),dict(tag=meta+'-tonSecretKey',hex='cc')])
        state=dict(profile=TON,wallets=wallets,keychain=keys,publicPin='135790',emptyTagFixture=dict(origin='explicit-old-helper-compatibility-probe',normalTonImportWritesEmptyTag=False,publicCatalog='GW-S1',bytes=32))
        require_snapshot(state,TON,golden);invalid=[]
        for field,value in [('tonPhrase','public typed phrase'),('tonPublicKey','ff'),('tonAddress','wrong'),('tonContractVersion','v5'),('substratePublicKey','aa')]:
            wrong=copy.deepcopy(state);wrong['wallets'][1][field]=value;invalid.append(wrong)
        wrong=copy.deepcopy(state);wrong['keychain'].pop(1);invalid.append(wrong)
        wrong=copy.deepcopy(state);wrong['emptyTagFixture']['normalTonImportWritesEmptyTag']=True;invalid.append(wrong)
        wrong=copy.deepcopy(state);wrong['emptyTagFixture']['origin']='normal import';invalid.append(wrong)
        wrong=copy.deepcopy(state);wrong['wallets'].pop();invalid.append(wrong)
        for wrong in invalid:
            with self.subTest(wrong=wrong),self.assertRaises(ValueError):require_snapshot(wrong,TON,golden)

    def test_writer_input_and_original_encrypted_fixture_pins_reject_post_prepare_drift(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);inputs=root/'inputs.json';fixture=root/'original.json'
            inputs.write_bytes(b'public inputs');fixture.write_bytes(b'old encrypted file')
            manifest=dict(inputSha256=hashlib.sha256(inputs.read_bytes()).hexdigest(),publicFixturePins=[dict(path=str(fixture),bytes=fixture.stat().st_size,sha256=hashlib.sha256(fixture.read_bytes()).hexdigest())])
            require_input_pins(root,manifest)
            inputs.write_bytes(b'changed')
            with self.assertRaises(ValueError):require_input_pins(root,manifest)
            inputs.write_bytes(b'public inputs');fixture.write_bytes(b'changed old encrypted file')
            with self.assertRaises(ValueError):require_input_pins(root,manifest)

if __name__=='__main__':unittest.main()
