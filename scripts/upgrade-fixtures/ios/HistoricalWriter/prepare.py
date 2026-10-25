#!/usr/bin/env python3
"""Extract the 4.0.4 storage writer; never derive expected bytes with RC code.

The runnable subset has exact old members/models/mappers. Import-only removal
lets these live in one standalone app module. Only the historical chainId and
ecosystem descriptor fields are supplied, without the unrelated registry.
No storage or crypto body is rewritten.
"""
import argparse, hashlib, json, pathlib, subprocess
from profiles import BASE, JSON_ONLY, CHAINS, TON, CHAIN_IMPORTS, VARIANTS, make_wallets
if not __debug__: raise RuntimeError('Run without Python optimization; source/evidence assertions are mandatory')
APP='195b0230743fa3c5fb74fbf05f4e4ee38b2d0bcf'
SSF='53e0a4bbea854ab32e97392365c3e523b9a0dc66'
KEYSTORE='17d16225eefbd6ce1d141ddc7447065878e277e2'
def sha(data): return hashlib.sha256(data).hexdigest()
def member(text, name):
    start=text.index(name); start=text.rfind('\n',0,start)+1
    end=text.index('{',start)+1; depth=1
    while depth:
        if text[end]=='{': depth+=1
        elif text[end]=='}': depth-=1
        end+=1
    return text[start:end]
def main():
    p=argparse.ArgumentParser();p.add_argument('--app-repo',required=True);p.add_argument('--shared-repo',required=True);p.add_argument('--keystore-repo',required=True);p.add_argument('--oracle',required=True);p.add_argument('--output',required=True);p.add_argument('--profile',choices=list(VARIANTS),default=BASE);a=p.parse_args()
    a.app_repo=str(pathlib.Path(a.app_repo).resolve());a.shared_repo=str(pathlib.Path(a.shared_repo).resolve());a.keystore_repo=str(pathlib.Path(a.keystore_repo).resolve())
    out=pathlib.Path(a.output).resolve();out.mkdir(parents=True,exist_ok=False);src=out/'source';src.mkdir();pins=[];generated=[]
    def read(repo,revision,path):
        data=subprocess.check_output(['git','-C',repo,'show',revision+':'+path]);target=src/path;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data);pins.append(dict(repo=repo,revision=revision,path=path,sha256=sha(data),output=str(target)));return data.decode()
    def emit(name,text):
        # Import adaptation only, all executed member bodies remain verbatim.
        clean='\n'.join(line for line in text.split('\n') if line not in ['import RobinHood','import SoraKeystore','import SSFAccountManagmentStorage'])
        target=out/name;target.write_text(clean);generated.append(dict(path=str(target),sha256=sha(target.read_bytes())))
    read(a.app_repo,APP,'fearless/Common/Storage/SelectedWalletSettings.swift')
    read(a.app_repo,APP,'fearless/Modules/AccountImport/AccountImportInteractor.swift')
    old=read(a.app_repo,APP,'fearless/Common/Operation/MetaAccountOperationFactory.swift')
    decls=['private struct AccountQuery','private struct TonAccountQuery','private enum SeedSource','func createKeypairFactory','func getJunctionResult','func deriveSeed','private func generateKeypair','private func getQuery','private func getTonQuery','func saveSecretKey','func saveEntropy','func saveDerivationPath','func saveSeed','func createMetaAccount','func newMetaAccountOperation(\n        request: MetaAccountImportMnemonicRequest','func newMetaAccountOperation(\n        request: MetaAccountImportSeedRequest','func newMetaAccountOperation(\n        request: MetaAccountImportKeystoreRequest']
    decls += ['func importChainAccountOperation(\n        request: ChainAccountImport' + kind + 'Request' for kind in ['Mnemonic','Seed','Keystore']]
    decls += ['func newTonMetaAccountOperation(\n        request: MetaAccountImportTonMnemonicRequest']
    bodies=[member(old[old.index('final class MetaAccountOperationFactory'):],d) for d in decls]
    emit('HistoricalAccountFactory.swift','import Foundation\nimport IrohaCrypto\nimport SSFUtils\nimport SSFModels\nimport SSFCrypto\nimport TonSwift\nfinal class HistoricalAccountFactory {\nprivate let keystore: KeystoreProtocol\ninit(keystore: KeystoreProtocol) { self.keystore=keystore }\n'+'\n\n'.join(b.replace('BaseOperation<SSFModels.MetaAccountModel>', 'BaseOperation<MetaAccountModel>') for b in bodies)+'\n}\n')
    memberpins=[dict(declaration=d,sha256=sha(b.encode()),bodySha256=sha(b[b.index('{'):].encode())) for d,b in zip(decls,bodies)]
    # Only a return-type module qualifier changes for the standalone module; the executed TON body is byte-exact.
    ton_adaptation=dict(original='BaseOperation<SSFModels.MetaAccountModel>',adapted='BaseOperation<MetaAccountModel>',reason='Original model is compiled in the standalone writer module; no executed statement changes')
    for name,path in [('AccountOperationFactoryError.swift','fearless/Common/Operation/AccountOperationFactoryError.swift'),('KeystoreTag.swift','fearless/Common/Model/KeystoreTag.swift'),('DerivationPathConstants.swift','fearless/Common/Helpers/DerivationPathConstants.swift'),('ManagedMetaAccountMapper.swift','fearless/Common/Storage/EntityToModel/ManagedMetaAccountMapper.swift'),('ManagedMetaAccountModel.swift','fearless/Common/Model/ChainRegistry/ManagedMetaAccountModel.swift')]:
        emit(name,read(a.app_repo,APP,path))
    request=read(a.app_repo,APP,'fearless/Modules/AccountImport/Model/AccountImportRequest.swift');emit('Request.swift','import IrohaCrypto\nimport SSFModels\n'+member(request,'struct MetaAccountImportMnemonicRequest')+'\n'+member(request,'struct MetaAccountImportSeedRequest')+'\n'+member(request,'struct MetaAccountImportKeystoreRequest')+'\n'+'\n'.join(member(request,'struct ChainAccountImport'+kind+'Request') for kind in ['Mnemonic','Seed','Keystore']))
    ton_request=read(a.shared_repo,SSF,'Sources/SSFAccountManagment/Classes/Import/AccountImportRequest.swift')
    emit('TonRequest.swift','import Foundation\n'+member(ton_request,'public struct MetaAccountImportTonMnemonicRequest'))
    emit('TonConstants.swift',read(a.app_repo,APP,'fearless/Common/Model/TonConstansts.swift'))
    emit('AccountCreateError.swift','import Foundation\n'+member(read(a.app_repo,APP,'fearless/Common/Model/AccountCreateError.swift'),'enum AccountCreateError:'))
    root='Sources/SSFModels/SSFModels/'
    model=read(a.shared_repo,SSF,root+'MetaAccountModel.swift');emit('MetaAccountModel.swift','import Foundation\nimport SSFModels\npublic typealias MetaAccountId = String\n'+member(model,'public struct MetaAccountModel:')+'\npublic extension MetaAccountModel {\n'+member(model,'func insertingChainAccount(')+'\n}')
    for name in ['SubstrateAlias.swift','WalletEcosystem.swift','TonContractVersion.swift','Currency.swift','Ecosystem.swift','AssetVisibility.swift','ChainAccountModel.swift']:
        raw=read(a.shared_repo,SSF,root+name)
        emit(name, 'import Foundation\n'+ '\n'.join(line for line in raw.splitlines() if line.startswith('public typealias ')) if name=='SubstrateAlias.swift' else 'import SSFModels\n'+raw)
    emit('TonAddress.swift','import SSFModels\n'+read(a.shared_repo,SSF,root+'Ton/TonAddress.swift'))
    emit('MetaAccountMapper.swift',read(a.shared_repo,SSF,'Sources/SSFAccountManagmentStorage/Classes/MetaAccountMapper.swift'))
    for name,path in [('BaseOperation.swift','Operations/Base/BaseOperation.swift'),('ClosureOperation.swift','Operations/Base/ClosureOperation.swift'),('CoreDataMapper.swift','DataProvider/Repository/CoreData/CoreDataMapper.swift')]:
        raw=read(a.shared_repo,SSF,'Sources/RobinHood/Classes/'+path)
        emit(name,('import Foundation\nimport CoreData\n'+member(raw,'public protocol CoreDataMapperProtocol')+'\n'+member(raw,'public extension CoreDataMapperProtocol')) if name=='CoreDataMapper.swift' else raw)
    ids=read(a.shared_repo,SSF,'Sources/RobinHood/Classes/DataProvider/Common/DataProviderPrimitives.swift');emit('Identifiable.swift',member(ids,'public protocol Identifiable'))
    chain=read(a.shared_repo,SSF,root+'ChainModel.swift')
    fields=['public typealias Id = String','public let ecosystem: Ecosystem','public let chainId: Id']
    for field in fields: assert field in chain
    emit('RegistryAlias.swift','import SSFModels\npublic final class ChainModel {\n'+'\n'.join(fields)+'\ninit(chainId: Id, ecosystem: Ecosystem) { self.chainId=chainId; self.ecosystem=ecosystem }\n}\n')
    chain_names=read(a.shared_repo,SSF,root+'Chain.swift')
    for _,_,_,_,_,name,chain_id,_,_,_ in CHAIN_IMPORTS:
        assert f'case .{name}: return "{chain_id}"' in member(chain_names,'public var genesisHash:')
    descriptor=dict(originalFields=[dict(declaration=f,sha256=sha(f.encode())) for f in fields],
        genesisHashMemberSha256=sha(member(chain_names,'public var genesisHash:').encode()),
        insertingChainAccountMemberSha256=sha(member(model,'func insertingChainAccount(').encode()),
        limit='Harness descriptor supplies only the original chainId/ecosystem fields read by the exact old import bodies; initializer is harness glue, not the full historical registry.')
    for name in ['Keychain.swift','KeystoreProtocols.swift','KeychainManager.swift']:
        emit(name,read(a.keystore_repo,KEYSTORE,'SoraKeystore/Classes/Keychain/'+name))
    for name in ['SettingsManager.swift','SettingsProtocols.swift']:
        emit(name,read(a.keystore_repo,KEYSTORE,'SoraKeystore/Classes/UserDefaults/'+name))
    settings=read(a.app_repo,APP,'fearless/Common/Extension/SettingsExtension.swift')
    emit('BiometryPreference.swift',member(settings,'enum SettingsKey:')+'\nextension SettingsManagerProtocol {\n'+member(settings,'var biometryEnabled:')+'\n}')
    modelpath='Sources/SSFAccountManagmentStorage/Resources/UserDataModel.xcdatamodeld/MultiassetUserDataModel_v12.xcdatamodel/contents'
    read(a.shared_repo,SSF,modelpath)
    oracle=pathlib.Path(a.oracle).resolve();inputs=json.loads((oracle/'inputs.json').read_text());wallets=make_wallets(inputs,a.profile)
    fixturepins=[];negative={}
    if a.profile == CHAINS:
        child=next(c for c in wallets[0]['chainImports'] if c['importKind']=='json')
        path=oracle/'public-fixtures'/'GW-J1-ecdsa.json';raw=path.read_bytes()
        child['secret']['keystoreJson']=raw.decode('utf8');fixturepins.append(dict(path=str(path),sha256=sha(raw),bytes=len(raw)))
    if a.profile == JSON_ONLY:
        for wallet in wallets:
            path=oracle/'public-fixtures'/f"GW-J1-{wallet['cryptoType']}.json"
            raw=path.read_bytes();wallet['secret']['keystoreJson']=raw.decode('utf8')
            fixturepins.append(dict(path=str(path),sha256=sha(raw),bytes=len(raw)))
        path=oracle/'public-ethereum-v3-input.json';raw=path.read_bytes()
        negative['ethereumV3']=raw.decode('utf8');fixturepins.append(dict(path=str(path),sha256=sha(raw),bytes=len(raw)))
    if a.profile == TON:
        negative['emptyTagSeedHex']=next(w['secret']['seedHex'] for w in inputs['wallets'] if w['id']=='GW-S1')
    (out/'inputs.json').write_text(json.dumps(dict(wallets=wallets,publicPin=next(w['secret']['pin'] for w in inputs['wallets'] if w['id']=='GW-P1') if a.profile in (CHAINS,TON) else '246810',profile=a.profile,negative=negative),indent=2)+'\n')
    (out/'source-pins.json').write_text(json.dumps(dict(appRevision=APP,sharedRevision=SSF,keystoreRevision=KEYSTORE,source=pins,generated=generated,members=memberpins,typeAdaptation=ton_adaptation,descriptor=descriptor,publicFixturePins=fixturepins,oracle=str(oracle),inputSha256=sha((out/'inputs.json').read_bytes()),limits=['T2 source-writer subset; not the historical application binary','Exact historical import, mapper and Keychain implementations; unrelated imports removed',descriptor['limit'],'No RC secret derivation used by writer']),indent=2)+'\n')
    print(json.dumps(dict(output=str(out),source=len(pins),members=len(memberpins))))
if __name__=='__main__': main()
