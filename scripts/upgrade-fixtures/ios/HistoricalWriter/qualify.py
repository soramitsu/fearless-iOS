#!/usr/bin/env python3
"""Run the compiled RC over a preserved historical writer fixture on an owned simulator.

This tool never fabricates expected secrets or inserts records for the RC. Run
prepare/build and install/launch HistoricalWriter first. It fails for missing old
state, wrong source identities, any skipped test, or changed preserved store.
"""
import argparse,hashlib,json,pathlib,plistlib,shutil,subprocess,time
from profiles import BASE, VARIANTS, require_snapshot
if not __debug__: raise RuntimeError('Run without Python optimization; source/evidence assertions are mandatory')
BUNDLE='jp.co.soramitsu.fearlesswallet.dev'
REQUIRED_TESTS={
 'testU1HistoricalMapperWalletSetOrderAndSelectionSurvive',
 'testU2EveryHistoricalPublicIdentityAndAddressSurvives',
 'testU3ProductionSigningVerifiesEveryHistoricalAccount',
 'testU4MnemonicSeedAndDecryptedJsonExportPreserveHistoricalBytes',
 'testU5AllRealKeychainValuesAndAccessProtectionSurviveRepeatedMigration',
 'testU6OriginalPinAuthenticatesAndBiometricPreferenceIsRetained',
}
def require_tests(tree, simulator):
 cases=[]
 def visit(node):
  if node.get('nodeType')=='Test Case': cases.append(node)
  for child in node.get('children',[]): visit(child)
 for node in tree.get('testNodes',[]): visit(node)
 expected={'KeychainContinuityTests/'+name+'()' for name in REQUIRED_TESTS}
 if len(cases)!=6 or {case.get('nodeIdentifier') for case in cases}!=expected or any(case.get('result')!='Passed' for case in cases):
  raise ValueError('G5 requires all six named Keychain continuity tests to pass exactly once')
 devices=tree.get('devices',[])
 if len(devices)!=1 or devices[0].get('deviceId')!=simulator or devices[0].get('osVersion') not in ('26.5','27.0') or devices[0].get('platform')!='iOS Simulator':
  raise ValueError('Unexpected runtime identity for required simulator coverage')
 return cases
def require_summary(summary):
 expected={'passedTests':6,'failedTests':0,'skippedTests':0,'expectedFailures':0,'totalTestCount':6}
 if any(type(summary.get(k)) is not int or summary[k]!=v for k,v in expected.items()):
  raise ValueError('G5 requires exactly six real passes and no failures, expected failures or skips')
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def pin(p):return dict(path=str(p),bytes=p.stat().st_size,sha256=digest(p))
def main():
 p=argparse.ArgumentParser();p.add_argument('--simulator',required=True);p.add_argument('--xctestrun',required=True);p.add_argument('--golden',required=True);p.add_argument('--writer-run',required=True);p.add_argument('--output',required=True);p.add_argument('--profile',choices=list(VARIANTS),default=BASE);a=p.parse_args();out=pathlib.Path(a.output).resolve();out.mkdir(parents=True,exist_ok=False)
 devices=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','--json'],text=True));device=next(d for ds in devices['devices'].values() for d in ds if d['udid']==a.simulator)
 assert device['name'].startswith('G5-Historical-') and device['state']=='Booted',device
 writer=pathlib.Path(a.writer_run).resolve();golden=pathlib.Path(a.golden).resolve();expected=json.loads(golden.read_text())
 assert expected['generator']['appRevision']=='195b0230743fa3c5fb74fbf05f4e4ee38b2d0bcf'
 def container():return pathlib.Path(subprocess.check_output(['xcrun','simctl','get_app_container',a.simulator,BUNDLE,'data'],text=True).strip())
 docs=container()/'Documents';snapshot=docs/'historical-state.json';state=json.loads(snapshot.read_text());assert state['appRevision']==expected['generator']['appRevision']
 require_snapshot(state,a.profile,expected)
 oldstore=docs/'CoreData/UserDataModel.sqlite';before=dict(state=digest(snapshot),store=digest(oldstore));shutil.copytree(docs,out/'before')
 # Keep the exact old payloads, model, writer and app. Never use RC to seed these.
 record=dict(profile=a.profile,runner=pin(pathlib.Path(__file__).resolve()),readerCommit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),readerTest=pin(pathlib.Path('fearlessTests/Common/Crypto/KeychainContinuityTests.swift').resolve()),format='fearless.ios.historical-keychain.qualification',version=1,startedAt=time.time(),device=device,golden=pin(golden),writerSource=pin(writer/'source-pins.json'),writerBinary=pin(writer/'HistoricalWriter.app/HistoricalWriter'),before=before,limits=['T2 old-source writer subset, not shipped binary','Simulator application identity is an explicit fixture entitlement, not distribution signing qualification','Real biometric authentication and all other historical cohorts remain open'])
 xctest=pathlib.Path(a.xctestrun).resolve();original=plistlib.loads(xctest.read_bytes());targets=[]
 def adapt(value):
  if isinstance(value,str):return value.replace('__TESTROOT__',str(xctest.parent))
  if isinstance(value,list):return [adapt(x) for x in value]
  if isinstance(value,dict):
   result={k:adapt(v) for k,v in value.items()}
   if 'TestBundlePath' in result:
    targets.append(result['TestBundlePath'].replace('__TESTHOST__',result['TestHostPath']));result.setdefault('EnvironmentVariables',{})['FEARLESS_REQUIRE_HISTORICAL_KEYCHAIN']='1';result['OnlyTestIdentifiers']=['KeychainContinuityTests']
   return result
  return value
 updated=adapt(original);assert targets,'No test target in xctestrun';configured=out/'configured.xctestrun';configured.write_bytes(plistlib.dumps(updated));record['xctestrun']=pin(xctest);record['configured']=pin(configured)
 app=xctest.parent/'Debug-iphonesimulator/fearless.app';record['compiledApp']=[pin(f) for f in sorted(app.rglob('*')) if f.is_file()]
 record['compiledTests']=[pin(f) for target in targets for f in sorted(pathlib.Path(target).rglob('*')) if f.is_file()]
 assert record['compiledTests'],'Missing compiled XCTest bundle'
 (out/'run.json').write_text(json.dumps(record,indent=2)+'\n')
 subprocess.run(['xcrun','simctl','terminate',a.simulator,BUNDLE],capture_output=True)
 cmd=['xcodebuild','-xctestrun',str(configured),'-destination','platform=iOS Simulator,id='+a.simulator,'-resultBundlePath',str(out/'result.xcresult'),'-parallel-testing-enabled','NO','-collect-test-diagnostics','never','test-without-building','-only-testing:fearlessTests/KeychainContinuityTests'];record['command']=cmd
 with (out/'test.log').open('wb') as log:r=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT)
 record['exitCode']=r.returncode;record['finishedAt']=time.time();(out/'run.json').write_text(json.dumps(record,indent=2)+'\n')
 summary=subprocess.run(['xcrun','xcresulttool','get','test-results','summary','--path',str(out/'result.xcresult'),'--format','json'],capture_output=True,text=True);(out/'summary.json').write_text(summary.stdout);(out/'summary-errors.log').write_text(summary.stderr)
 afterdocs=container()/'Documents';record['after']=dict(state=digest(afterdocs/'historical-state.json'),store=digest(afterdocs/'CoreData/UserDataModel.sqlite'));record['preserved']=record['after']==before
 for f in record['compiledApp']+record['compiledTests']:assert digest(pathlib.Path(f['path']))==f['sha256'],'Compiled app drift'
 if summary.returncode==0:record['testSummary']=json.loads(summary.stdout)
 (out/'run.json').write_text(json.dumps(record,indent=2)+'\n')
 assert r.returncode==0,'RC tests failed; preserved raw output'
 assert record['preserved'],'Historical fixture files changed'
 require_summary(record['testSummary'])
 named=subprocess.run(['xcrun','xcresulttool','get','test-results','tests','--path',str(out/'result.xcresult'),'--format','json'],capture_output=True,text=True)
 (out/'tests.json').write_text(named.stdout);(out/'tests-errors.log').write_text(named.stderr)
 assert named.returncode==0,'Could not read named test results'
 record['namedTests']=require_tests(json.loads(named.stdout),a.simulator)
 record['tests']=pin(out/'tests.json')
 (out/'run.json').write_text(json.dumps(record,indent=2)+'\n')
 print(json.dumps(dict(passed=6,failed=0,skipped=0,preserved=True,run=pin(out/'run.json'))))
if __name__=='__main__':main()
