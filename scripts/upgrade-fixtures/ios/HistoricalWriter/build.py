#!/usr/bin/env python3
"""Compile a prepared, pinned old writer with isolated old oracle libraries."""
import argparse,hashlib,json,pathlib,plistlib,shutil,subprocess
from profiles import require_input_pins
if not __debug__: raise RuntimeError('Run without Python optimization; source/evidence assertions are mandatory')
p=argparse.ArgumentParser();p.add_argument('--run-dir',required=True);a=p.parse_args();r=pathlib.Path(a.run_dir).resolve();j=json.loads((r/'source-pins.json').read_text());oracle=pathlib.Path(j['oracle']);settings=json.loads((oracle/'swift-build-settings.json').read_text());base=settings['base'];build=pathlib.Path(settings['buildDirectory']);tool=pathlib.Path(__file__).parent
require_input_pins(r,j)
for pin in j['source']+j['generated']:assert hashlib.sha256(pathlib.Path(pin.get('output',pin.get('path'))).read_bytes()).hexdigest()==pin['sha256'],pin
runtime=json.loads((oracle/'runtime-pins.json').read_text())
assert runtime['compiled'],'Missing historical compiled provenance'
for pin in runtime['compiled']: assert hashlib.sha256(pathlib.Path(pin['path']).read_bytes()).hexdigest()==pin['sha256'],pin
app=r/'HistoricalWriter.app';app.mkdir(exist_ok=True);model=r/'source/Sources/SSFAccountManagmentStorage/Resources/UserDataModel.xcdatamodeld/MultiassetUserDataModel_v12.xcdatamodel';gen=r/'generated-model';gen.mkdir(exist_ok=True)
commands=[]
def run(name,cmd):
    with (r/(name+'.log')).open('wb') as out: res=subprocess.run(cmd,stdout=out,stderr=subprocess.STDOUT)
    commands.append(dict(name=name,command=cmd,exitCode=res.returncode));(r/'build-commands.json').write_text(json.dumps(commands,indent=2)+'\n')
    if res.returncode: print((r/(name+'.log')).read_text()[-8000:]);raise SystemExit(res.returncode)
run('model-compile',['xcrun','momc','--module','HistoricalWriter','--swift-version','5',str(model),str(app/'Historical.mom')])
run('model-codegen',['xcrun','momc','--action','generate','--module','HistoricalWriter','--swift-version','5',str(model),str(gen)])
shutil.copyfile(tool/'main.swift',r/'main.swift');shutil.copyfile(r/'inputs.json',app/'inputs.json')
ent=r/'simulator-entitlements.plist';ent.write_bytes(plistlib.dumps({'application-identifier':'YLWWUD25VZ.jp.co.soramitsu.fearlesswallet.dev','keychain-access-groups':['YLWWUD25VZ.jp.co.soramitsu.fearlesswallet.dev']}))
cmd=base+['-module-name','HistoricalWriter','-parse-as-library','-L',str(build)]
for name in ['TonSwift','SSFCrypto','SSFUtils','SSFModels','secp256k1','TweetNacl','xxHash_Swift','BigInt']:cmd+=['-l'+name]
cmd+=[str(build/'libIrohaCrypto.a')]
for name in ['libed25519','sr25519lib','blake2lib']:cmd+=['-framework',name]
cmd+=['-Xlinker','-all_load',str(build/'CTweetNacl.o'),str(build/'keccak.o')]+[str(f) for f in sorted(r.glob('*.swift'))]+[str(f) for f in sorted(gen.glob('*.swift'))]+['-Xlinker','-sectcreate','-Xlinker','__TEXT','-Xlinker','__entitlements','-Xlinker',str(ent),'-o',str(app/'HistoricalWriter')]
run('swift-link',cmd)
(app/'Info.plist').write_bytes(plistlib.dumps(dict(CFBundleIdentifier='jp.co.soramitsu.fearlesswallet.dev',CFBundleExecutable='HistoricalWriter',CFBundleName='HistoricalWriter',CFBundleVersion='1',CFBundleShortVersionString='4.0.4',CFBundlePackageType='APPL',MinimumOSVersion='18.1',UIDeviceFamily=[1,2],UILaunchScreen={},UIApplicationSceneManifest={'UIApplicationSupportsMultipleScenes':False,'UISceneConfigurations':{'UIWindowSceneSessionRoleApplication':[{'UISceneConfigurationName':'Writer','UISceneDelegateClassName':'HistoricalWriter.SceneDelegate'}]}})))
run('codesign',['codesign','--force','--sign','-',str(app)])
print(str(app))
