#!/usr/bin/env python3
"""Require actual native integration evidence and matching sanitized cores for internal28."""
import argparse
import hashlib
import json
import os
import importlib.util
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = {
    'testGameCubeBothSticksAnalogTriggersAndDisconnect()',
    'testGameCubeGXDepthAndNativeCardRelaunch()',
    'testGameCubeGCMImportBootAndState()',
    'testGameCubeOriginalDiscImportBootAndState()',
    'testGameCubeHomebrewInputStateHistoryAndRelaunch()',
    'testGameCubeLandscapeControllerFillsDisplay()',
    'testGameCubeLandscapeTouchControlsHaveSpace()',
    'testGameCubeTeardownAllowsPlayStationAndThreeDS()',
    'testGameCubeSettingsUseSingleScreenOptions()',
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_inputs():
    paths = []
    for name in ['App','Bridge','Resources','Widgets']:
        paths += [p for p in (ROOT/name).rglob('*') if p.is_file() and p.name != '.DS_Store']
    paths += [ROOT/'EmulatorApp.xcodeproj/project.pbxproj']
    paths += [ROOT/'Tests/UI/EmulatorUITests.swift']
    paths += [ROOT/'Scripts'/n for n in ['embed-core.sh','make-gamecube-homebrew.py',
               'make-gamecube-disc.py','gamecube-gx-commands.py','prepare-dolphin-audio.py',
               'dolphin-frontend.cmake','dolphin-ios-port.patch','dolphin-generic-memtools.patch']]
    paths += [ROOT/'Scripts/GameCubeFramework-Info.plist.in',ROOT/'Scripts/check-framework-metadata.py']
    if json.loads((ROOT/'TestFlight/AppInformation.json').read_text())['build'] in ['35','36','37','38']:
        paths.append(ROOT/'Tests/Fixtures/ArtworkCatalogQAProtocol.swift')
    return {p.relative_to(ROOT).as_posix():digest(p) for p in sorted(set(paths))}


def native_results(bundle, audit_history=False):
    raw = subprocess.check_output(['xcrun','xcresulttool','get','test-results','tests','--path',str(bundle),'--format','json'])
    document = json.loads(raw)
    cases = []
    def visit(nodes):
        for node in nodes:
            if node.get('nodeType') == 'Test Case':
                assert node['result'] == 'Passed' or (audit_history and node['result']=='Failed'), (bundle,node['name'],node['result'])
                cases.append({'name':node['name'],'result':node['result'],'seconds':node.get('durationInSeconds')})
            visit(node.get('children',[]))
    visit(document['testNodes'])
    assert cases and all(d['platform']=='iOS Simulator' for d in document['devices'])
    canonical = json.dumps(document,sort_keys=True,separators=(',',':')).encode()
    record = {'bundle':os.path.relpath(bundle,ROOT), 'resultJSONSHA256':hashlib.sha256(canonical).hexdigest(), 'cases':cases}
    if audit_history:
        summary=json.loads(subprocess.check_output(['xcrun','xcresulttool','get','test-results','summary','--path',str(bundle),'--format','json']))
        record.update(startedAt=summary['startTime'],finishedAt=summary['finishTime'],
            summaryJSONSHA256=hashlib.sha256(json.dumps(summary,sort_keys=True,separators=(',',':')).encode()).hexdigest())
        assert record['startedAt'] < record['finishedAt']
    return record


def verify_native_cases(results, required, audit_history=False):
    latest={}
    for result in sorted(results,key=lambda r:r.get('finishedAt',0)):
        for case in result['cases']: latest[case['name']]=case['result']
    assert required <= latest.keys()
    assert all(value=='Passed' for value in latest.values()), 'Every latest native result must pass; unresolved failures block archive'
    if not audit_history:
        assert all(case['result']=='Passed' for result in results for case in result['cases'])


def core_checks(build):
    manifest = json.loads((ROOT/'Vendor/Dolphin/source-manifest.json').read_text())
    assert digest(ROOT/'Upstream'/manifest['archive']) == manifest['archiveSHA256']
    assert manifest['upstreamRevision'] == 'f84df02055ab9610feec48e65648cac5a3c098fa'
    subprocess.run([sys.executable,str(ROOT/'Scripts/build-gamecube-core.py'),'--verify-source'],check=True)
    records = json.loads((ROOT/f'Docs/Legal/GAMECUBE-CORE-BUILD-{build}.json').read_text())
    assert records['sourceManifestSHA256'] == digest(ROOT/'Vendor/Dolphin/source-manifest.json')
    for target in ['Device','Simulator']:
        evidence = records['targets'][target]
        clean, final = evidence['cleanBuild'], evidence['frontendUpdate']
        assert clean['fullCleanDistributionBuild'] and clean['upstream']==manifest['upstreamRevision']
        assert clean['resourcePolicySHA256']==manifest['sourcePolicySHA256']
        assert clean['sourcePatchSHA256']=={n:manifest['localPatches'][n] for n in ['dolphin-generic-memtools.patch','dolphin-ios-port.patch']}
        for name,sha in final['frontendSources'].items(): assert digest(ROOT/name)==sha, name
        binary = ROOT/f'Vendor/Dolphin/{target}/EmuDenGameCube.framework/EmuDenGameCube'
        assert digest(binary)==final['frameworkSHA256']==evidence['resourceAudit']['binarySHA256']
        assert evidence['resourceAudit']['matches']==[] and evidence['resourceAudit']['removedPatternCount']==8
        assert evidence['resourceAudit']['omittedResourceMatches']==[]
        assert evidence['resourceAudit']['omittedResourceCount']==len(manifest['sourcePolicy']['omittedResources'])
        if build in ['29','30','31','32']:
            spec=importlib.util.spec_from_file_location('candidate_validation',ROOT/'Scripts/validate-testflight.py')
            validation=importlib.util.module_from_spec(spec);spec.loader.exec_module(validation)
            correction=evidence['metadataCorrection']
            assert validation.signature_free_code_sha256(binary)==correction['baseline28ExecutableCodeSHA256']==correction['newExecutableCodeSHA256']
            assert digest(binary.parent/'Info.plist')==correction['infoPlistSHA256']
            assert digest(ROOT/'Scripts/GameCubeFramework-Info.plist.in')==correction['templateSHA256']
            validation.framework_metadata.check(binary.parent,'IOS' if target=='Device' else 'IOSSIMULATOR','18.0')
        if build in ['33','34','35','36','37','38']:
            spec=importlib.util.spec_from_file_location('candidate_validation',ROOT/'Scripts/validate-testflight.py')
            validation=importlib.util.module_from_spec(spec);spec.loader.exec_module(validation)
            assert digest(binary.parent/'Info.plist')==evidence['metadata']['infoPlistSHA256']
            assert digest(ROOT/'Scripts/GameCubeFramework-Info.plist.in')==evidence['metadata']['templateSHA256']
            validation.framework_metadata.check(binary.parent,'IOS' if target=='Device' else 'IOSSIMULATOR','18.0')
            for name,sha in final['unchangedStaticArchiveSHA256'].items():
                assert digest(ROOT/'build/Build33-Core'/target/name)==sha, 'Fresh33 core/dependency archive changed: '+name
        subprocess.run([sys.executable,str(ROOT/'Scripts/check-debug-symbols.py'),str(binary),str(binary.parent)+'.dSYM'],check=True)


def verify_build38(args, record):
    baseline_path = ROOT/'Docs/BUILD-37-VERIFICATION.json'
    baseline = json.loads(baseline_path.read_text())
    current = source_inputs()
    assert current.keys() == baseline['sourceInputs'].keys()
    allowed = {'App/Domain/Library.swift', 'App/LibraryView.swift', 'App/SettingsView.swift',
               'Resources/PrivacyInfo.xcprivacy', 'EmulatorApp.xcodeproj/project.pbxproj'}
    for name, sha in baseline['sourceInputs'].items():
        if name not in allowed:
            assert current[name] == sha, '38 must preserve unchanged gameplay inputs: '+name
    assert json.loads((ROOT/'Docs/Legal/GAMECUBE-CORE-BUILD-38.json').read_text())['targets'] == json.loads((ROOT/'Docs/Legal/GAMECUBE-CORE-BUILD-37.json').read_text())['targets']
    verify_native_cases(baseline['nativeResults'], REQUIRED, True)
    for result in baseline['nativeResults']:
        assert native_results(ROOT/result['bundle'], True) == result, 'Inherited37 native evidence changed'
    renewed_required = {'testFoldedLibraryPlayDispatchesForEachConsole()',
                        'testGameCubeTeardownAllowsPlayStationAndThreeDS()',
                        'testCaptureStoreScreenshotsWithLicensedDemo()'}
    if args.record:
        results = [native_results(p.resolve(), True) for p in args.record]
        verify_native_cases(results, renewed_required, True)
        assert all(r['bundle'].startswith('build/Build38/') for r in results)
        record.write_text(json.dumps({'build':'38','publicReleaseHeld':True,
            'sourceInputs':current,'inheritedBuild37VerificationSHA256':digest(baseline_path),
            'nativeResults':results,'nativeScope':'Renewed three-console launch/switch, folded launch and licensed-demo Store captures. Exact unchanged37 core/bridge/input/save/graphics/card/artwork evidence is inherited and re-read, with earlier failures preserved.',
            'knownDeferredIssue':'Detective Pikachu native saving remains broken; owner explicitly deferred it. No fix or commercial-game compatibility asserted.'},indent=2)+'\n')
    data = json.loads(record.read_text())
    assert data['build']=='38' and data['publicReleaseHeld']
    assert data['sourceInputs']==current
    assert data['inheritedBuild37VerificationSHA256']==digest(baseline_path)
    verify_native_cases(data['nativeResults'],renewed_required,True)
    for result in data['nativeResults']:
        assert native_results(ROOT/result['bundle'],True)==result
    print('38 matching cores/symbols, inherited37 evidence and renewed launch/capture checks passed; no save fix claimed.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--record', nargs='+', type=Path, metavar='XCRESULT')
    args = parser.parse_args()
    metadata = json.loads((ROOT/'TestFlight/AppInformation.json').read_text())
    build=metadata['build'];record=ROOT/f'Docs/BUILD-{build}-VERIFICATION.json'
    assert build in ['28','29','30','31','32','33','34','35','36','37','38'] and metadata['currentEmulation']==['Nintendo 3DS','PlayStation','GameCube']
    assert json.loads((ROOT/'TestFlight/AppStoreReadiness.json').read_text())['publicReleaseCleared'] is False
    core_checks(build)
    if build == '38':
        verify_build38(args, record)
        return
    required = REQUIRED | ({'testConsoleNavigationFavoriteAndLibraryFilters()', 'testConsoleSpecificControllerConnections()',
        'testGameCubeGraphicsChangeActualEFBAndReturnToNative()', 'testPlayStationEnhancedResolutionAndLiveReturnToNative()'} if build in ['33','34','35','36','37','38'] else set())
    if build in ['34','35','36','37']:
        required |= {'testGameCubeFoldedTouchExcursionAndEditableLayout()', 'testPlayStationDualAnalogTouchAndRelease()',
                     'testSettingsOrganizationGameCubeBackgroundAndDeleteConfirmation()', 'testThreeDSFreelyMovableTouchControls()'}
        baseline=json.loads((ROOT/'Docs/Legal/GAMECUBE-CORE-BUILD-33.json').read_text())
        assert json.loads((ROOT/f'Docs/Legal/GAMECUBE-CORE-BUILD-{build}.json').read_text())['targets']==baseline['targets'], 'Build34 must reuse exact verified33 core records'
    if build=='37':
        required |= {'testMultiConsoleArtworkFillAndOfflineRelaunch()', 'testFoldedLibraryPlayDispatchesForEachConsole()',
                     'testGameCubeFoldedControllerQuickPanelAndBlankPersistence()', 'testThreeDSCoreRequestsMotionAndPauseStopsInput()',
                     'testPlayStationFoldedQuickPanelSpeedAndBlankOptions()',
                     'testLiveQuickSaveBannerForAllConsoles()', 'testRenameAndNoBlanketAgeLabelsSurviveRelaunch()',
                     'testDemoLinkRemainsAvailableWithoutLocalAgeChoice()'}
        baseline=json.loads((ROOT/'Docs/BUILD-36-VERIFICATION.json').read_text())['sourceInputs']
        current=source_inputs()
        assert current.keys()==baseline.keys(), 'Library37 must not add unrelated runtime inputs'
        allowed={'App/ArtworkCatalogView.swift','App/Domain/Library.swift','App/EmulatorSession.swift','App/GameLibrary.swift',
                 'App/LibraryView.swift','App/PlayerSettingsView.swift','App/PlayerView.swift','App/SettingsView.swift',
                 'Bridge/EmulatorBridge.mm','Tests/UI/EmulatorUITests.swift','EmulatorApp.xcodeproj/project.pbxproj'}
        for name,sha in baseline.items():
            if name not in allowed: assert current[name]==sha, 'Library37 preserves unrelated runtime inputs: '+name
        bridge=(ROOT/'Bridge/EmulatorBridge.mm').read_text()
        start=bridge.index('#if TARGET_OS_SIMULATOR\n                // Simulator diagnostics bracket the atomic snapshot.')
        end=bridge.index('#endif\n',start)+len('#endif\n')
        assert hashlib.sha256((bridge[:start]+bridge[end:]).encode()).hexdigest()==baseline['Bridge/EmulatorBridge.mm'], '37 changes bridge diagnostics only; Device bridge behavior must match36'
        project=(ROOT/'EmulatorApp.xcodeproj/project.pbxproj').read_text().replace('CURRENT_PROJECT_VERSION = 37;','CURRENT_PROJECT_VERSION = 36;')
        assert hashlib.sha256(project.encode()).hexdigest()==baseline['EmulatorApp.xcodeproj/project.pbxproj']
    if build=='36':
        required |= {'testMultiConsoleArtworkFillAndOfflineRelaunch()', 'testFoldedLibraryPlayDispatchesForEachConsole()',
                     'testGameCubeFoldedControllerQuickPanelAndBlankPersistence()', 'testThreeDSCoreRequestsMotionAndPauseStopsInput()',
                     'testPlayStationFoldedQuickPanelSpeedAndBlankOptions()'}
        baseline=json.loads((ROOT/'Docs/BUILD-35-VERIFICATION.json').read_text())['sourceInputs']
        current=source_inputs()
        assert current.keys()==baseline.keys()|{'Bridge/FrameDelivery.h'}
        allowed={'App/ControllerScene.swift','App/Domain/PlayerPreferences.swift','App/DuoLayoutSettings.swift',
                 'App/EmulatorSession.swift','App/PlayerSettingsView.swift','App/PlayerView.swift','App/TouchControls.swift',
                 'Bridge/EmulatorBridge.h','Bridge/EmulatorBridge.mm','Tests/UI/EmulatorUITests.swift','EmulatorApp.xcodeproj/project.pbxproj'}
        for name,sha in baseline.items():
            if name not in allowed: assert current[name]==sha, 'Polish36 preserves unrelated runtime inputs: '+name
    if build=='35':
        required |= {'testMultiConsoleArtworkFillAndOfflineRelaunch()', 'testFoldedLibraryPlayDispatchesForEachConsole()'}
        baseline=json.loads((ROOT/'Docs/BUILD-34-VERIFICATION.json').read_text())['sourceInputs']
        current=source_inputs()
        added={'Tests/Fixtures/ArtworkCatalogQAProtocol.swift'}
        allowed={'App/Domain/RemoteArtwork.swift','App/Domain/ArtworkSource.swift','App/ArtworkCatalogView.swift','App/LibraryView.swift',
                 'Tests/UI/EmulatorUITests.swift','EmulatorApp.xcodeproj/project.pbxproj'}
        assert current.keys()==baseline.keys()|added, 'Artwork35 adds only the original native transport fixture input'
        for name,sha in baseline.items():
            if name not in allowed: assert current[name]==sha, 'Artwork35 preserves other runtime inputs: '+name
        ui=(ROOT/'Tests/UI/EmulatorUITests.swift').read_text()
        start=ui.index('    @MainActor func testMultiConsoleArtworkFillAndOfflineRelaunch()')
        end=ui.index('    @MainActor func testArtworkCatalogBulkFillAndOfflineRelaunch()',start)
        assert hashlib.sha256((ui[:start]+ui[end:]).encode()).hexdigest()==baseline['Tests/UI/EmulatorUITests.swift'], 'Existing native cases must remain unchanged'
        project=(ROOT/'EmulatorApp.xcodeproj/project.pbxproj').read_text().replace('CURRENT_PROJECT_VERSION = 35;','CURRENT_PROJECT_VERSION = 34;')
        assert hashlib.sha256(project.encode()).hexdigest()==baseline['EmulatorApp.xcodeproj/project.pbxproj'], 'Only the project build number changes'
    if build=='32':
        data=json.loads(record.read_text())
        assert data['build']==build and data['internalOnly'] and data['publicReleaseHeld']
        assert data['ownerRequestedArchiveWithoutNewGameplayTests'] is True
        assert data['newGameplayTestsRun'] is False and data['godzillaGameplayVerified'] is False
        current=source_inputs()
        assert data['sourceInputs']==current, 'Compatibility32 inputs changed after recording'
        baseline=json.loads((ROOT/'Docs/BUILD-31-VERIFICATION.json').read_text())['sourceInputs']
        def runtime(name):
            return name.split('/')[0] in ['App','Bridge','Resources','Widgets'] or name=='Tests/UI/EmulatorUITests.swift'
        profile='Resources/GameCubeCompatibility/GZD.ini'
        assert {name for name in current if runtime(name)}=={name for name in baseline if runtime(name)}|{profile}
        for name,sha in baseline.items():
            if runtime(name) and name!='Bridge/EmulatorBridge.mm':
                assert current[name]==sha, 'Compatibility32 preserves other runtime inputs: '+name
        assert digest(ROOT/profile)==data['godzillaProfile']['sha256']==digest(ROOT/'Vendor/Dolphin/Source/Data/Sys/GameSettings/GZD.ini')
        assert {p.name for p in (ROOT/'Resources/GameCubeCompatibility').iterdir()}=={'GZD.ini'}
        print('Internal32 source/core/symbol and exact upstream-profile guards passed. Godzilla freeze/performance remain unverified; no new gameplay tests.')
        return
    if build in ['30','31']:
        data=json.loads(record.read_text())
        assert data['build']==build and data['internalOnly'] and data['publicReleaseHeld']
        assert data['ownerRequestedArchiveWithoutNewGameplayTests'] is True
        assert data['cisoGameplayVerified'] is False
        assert data['sourceInputs']==source_inputs(), 'Archive-only30 source changed after its explicit untested-format record'
        baseline=json.loads((ROOT/'Docs/BUILD-29-VERIFICATION.json').read_text())
        for name,sha in baseline['sourceInputs'].items():
            if (name.split('/')[0] in ['App','Bridge','Resources','Widgets'] or name=='Tests/UI/EmulatorUITests.swift') and name!='App/Domain/Library.swift':
                assert digest(ROOT/name)==sha, 'Archive-only30 only changes the library importer: '+name
        print(f'Internal{build} source/core/symbol/package guards passed. No new gameplay tests; specific CISO file remains unverified.')
        return
    if build=='29':
        baseline=json.loads((ROOT/'Docs/BUILD-28-VERIFICATION.json').read_text())
        current=source_inputs()
        for name,sha in baseline['sourceInputs'].items():
            if name.split('/')[0] in ['App','Bridge','Resources','Widgets'] or name=='Tests/UI/EmulatorUITests.swift':
                assert current[name]==sha, 'Metadata-only29 must preserve verified28 gameplay inputs: '+name
    if args.record:
        results = [native_results(p.resolve(),build in ['33','34','35','36','37','38']) for p in args.record]
        verify_native_cases(results,required,build in ['33','34','35','36','37','38'])
        data = {'build':build,'internalOnly':True,'publicReleaseHeld':True,'binaryUploadAuthorized':False,
                'sourceInputs':source_inputs(),'nativeResults':results,
                'limits':['Original homebrew/owned Simulator evidence, not phone speed or retail compatibility',
                          'Raw native-card sector persistence, not allocated retail save-file verification',
                          'Physical gyro/fold and signed regional/widget services remain device checks']}
        if build=='37':
            data['inheritedBuild36VerificationSHA256']=digest(ROOT/'Docs/BUILD-36-VERIFICATION.json')
            data['inheritedNativeScope']='Exact unchanged36 cores/rendering/input/settings/artwork protocols retain their actual prior evidence.37 renews live save/load across all cores, lifecycle/card/state history, motion, folded panels/launches, library navigation/delete/rename and artwork storage/offline behavior. No phone/retail compatibility claim.'
        if build=='35':
            data['inheritedBuild34VerificationSHA256']=digest(ROOT/'Docs/BUILD-34-VERIFICATION.json')
            data['inheritedNativeScope']='Build34 gameplay/control/graphics evidence is retained with unchanged non-artwork runtime inputs; new35 native test covers the changed source UI/import/offline path. No renewed phone or retail gameplay claim.'
        if build=='29':data['inheritedGameplayFrom28']='All App/Bridge/Resources/Widgets/UI-test source hashes and normalized GameCube executable bytes match28; only metadata/build/package tooling changes. Native result bundles remain actual prior evidence.'
        record.write_text(json.dumps(data,indent=2)+'\n')
    data = json.loads(record.read_text())
    assert data['build']==build and data['internalOnly'] and data['publicReleaseHeld']
    assert data['sourceInputs']==source_inputs(), 'Changed candidate inputs require renewed relevant validation/evidence'
    verify_native_cases(data['nativeResults'],required,build in ['33','34','35','36','37','38'])
    if build=='37':
        baseline=json.loads((ROOT/'Docs/BUILD-36-VERIFICATION.json').read_text())
        assert data['inheritedBuild36VerificationSHA256']==digest(ROOT/'Docs/BUILD-36-VERIFICATION.json')
        renewed=[r for r in data['nativeResults'] if r['bundle'].startswith('build/Build37/')]
        renewed_required={'testLiveQuickSaveBannerForAllConsoles()', 'testRenameAndNoBlanketAgeLabelsSurviveRelaunch()',
            'testDemoLinkRemainsAvailableWithoutLocalAgeChoice()', 'testFoldedLibraryPlayDispatchesForEachConsole()',
            'testConsoleNavigationFavoriteAndLibraryFilters()', 'testSettingsOrganizationGameCubeBackgroundAndDeleteConfirmation()',
            'testMultiConsoleArtworkFillAndOfflineRelaunch()', 'testGameCubeHomebrewInputStateHistoryAndRelaunch()',
            'testGameCubeGXDepthAndNativeCardRelaunch()', 'testGameCubeFoldedControllerQuickPanelAndBlankPersistence()',
            'testPlayStationFoldedQuickPanelSpeedAndBlankOptions()', 'testGameCubeTeardownAllowsPlayStationAndThreeDS()',
            'testThreeDSCoreRequestsMotionAndPauseStopsInput()'}
        verify_native_cases(renewed,renewed_required,True)
        inherited={os.path.relpath((ROOT/'build/Build36'/Path(r['bundle']).name).resolve(),ROOT) for r in baseline['nativeResults'] if Path(r['bundle']).parent==Path('build/Build36')}
        inherited |= {os.path.relpath((ROOT/'build/Build35/artwork-final3.xcresult').resolve(),ROOT)}
        assert all(r['bundle'].startswith('build/Build37/') or r['bundle'] in inherited for r in data['nativeResults']), '37 may inherit only the recorded36 native bundles'
    if build=='36':
        renewed=[r for r in data['nativeResults'] if r['bundle'].startswith('build/Build36/')]
        verify_native_cases(renewed,required-{'testMultiConsoleArtworkFillAndOfflineRelaunch()'},True)
        inherited_artwork=os.path.relpath((ROOT/'build/Build35/artwork-final3.xcresult').resolve(),ROOT)
        assert all(r['bundle'].startswith('build/Build36/') or r['bundle']==inherited_artwork for r in data['nativeResults']), 'Only the unchanged artwork scenario may inherit35 evidence'
    for result in data['nativeResults']:
        assert native_results(ROOT/result['bundle'],build in ['33','34','35','36','37','38'])==result, 'Native evidence differs from its actual result bundle'
    print(f'Internal{build} GameCube native evidence, exact inputs, sanitized source/core hashes and matching symbols passed; public release remains held')


if __name__ == '__main__': main()
