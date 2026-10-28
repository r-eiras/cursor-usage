#!/usr/bin/env python3
"""Build and test Cursor Usage with the local Apple toolchain."""
from pathlib import Path
import argparse
import json
import platform
import plistlib
import shutil
import uuid
import subprocess
import tempfile
import sys

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--sdk', help='Explicit compatible macOS SDK')
parser.add_argument('--ui-tests', action='store_true', help='Run local AppKit and WebKit fixtures')
args = parser.parse_args()
root = Path(__file__).resolve().parent
with tempfile.TemporaryDirectory(prefix='cursor-usage-build-') as temporary:
    work = Path(temporary)
    flags = ['-target', f'{platform.machine()}-apple-macos14.0', '-module-cache-path', str(work/'modules')]
    if args.sdk:
        flags += ['-sdk', args.sdk]
    include = Path('/Library/Developer/CommandLineTools/usr/include/swift')
    if all((include/name).exists() and 'module SwiftBridging' in (include/name).read_text() for name in ('module.modulemap','bridging.modulemap')):
        (work/'empty.modulemap').write_text('')
        overlay = work/'overlay.json'
        overlay.write_text(json.dumps({'version':0,'case-sensitive':False,'roots':[{'type':'file','name':str(include/'module.modulemap'),'external-contents':str(work/'empty.modulemap')}]}))
        flags += ['-vfsoverlay',str(overlay)]
    def run(*command):
        subprocess.run(command,check=True)
    def test(name, sources, frameworks=()):
        executable = work/name
        command = ['swiftc',*flags,str(root/'Sources/AppSupport.swift'),*[str(root/'Sources'/source) for source in sources],str(root/'Tests'/name/'main.swift') if name != 'parsing' else str(root/'Tests/main.swift'),'-o',str(executable)]
        for framework in frameworks:
            command += ['-framework',framework]
        run(*command)
        run(str(executable))
    run(sys.executable, str(root/'Tests/Packaging/main.py'))
    test('ReleaseVersions',['ReleaseUpdates.swift'])
    test('parsing',['Usage.swift'])
    test('Analytics',['Usage.swift','Analytics.swift'])
    test('Preferences',['Usage.swift','Analytics.swift','Preferences.swift'])
    test('AccountSession',['AccountSessionStorage.swift'])
    test('LoginItem',['LoginItemManager.swift'],['ServiceManagement'])
    test('Pace',['QuotaPace.swift'])
    test('Popover',['PopoverDismissal.swift'],['AppKit'])
    test('Renewal',['RenewalAlerts.swift'])
    test('BrowserSignIn',['BrowserSignIn.swift'])
    test('AppUpdater',['ReleaseUpdates.swift','AppUpdater.swift'])
    test('ModelAlerts',['Usage.swift','Analytics.swift','Preferences.swift','ModelAlerts.swift'])
    test('NotificationRoutes',['NotificationAdvice.swift'],['UserNotifications'])
    if args.ui_tests:
        test('PreferencesUI',['Usage.swift','Analytics.swift','Preferences.swift','LoginItemManager.swift','CursorAlertControls.swift','ModelAlertControls.swift','CursorMark.swift','SettingsStyle.swift','NotificationAdvice.swift','PreferencesPanel.swift'],['AppKit','ServiceManagement','UserNotifications'])
        test('SessionCookies',[],['AppKit','WebKit'])
        test('StatusMenu',['StatusMenu.swift','StatusItemPlacement.swift'],['AppKit'])
        test('BrowserButton',['BrowserSignInButton.swift'],['AppKit'])
        test('CardUI',['Usage.swift','Analytics.swift','Preferences.swift','QuotaPace.swift','CursorMark.swift','SettingsStyle.swift','QuotaCard.swift'],['AppKit'])
        test('WebView',['Usage.swift'],['AppKit','WebKit'])
    app = work/'Cursor Usage.app'
    binary = app/'Contents/MacOS/CursorUsage'
    binary.parent.mkdir(parents=True,exist_ok=True)
    command = ['swiftc',*flags,'-O',*[str(path) for path in sorted((root/'Sources').glob('*.swift'))],'-o',str(binary)]
    for framework in ('AppKit','WebKit','UserNotifications','ServiceManagement'):
        command += ['-framework',framework]
    run(*command)
    resources = app/'Contents/Resources'
    resources.mkdir(parents=True,exist_ok=True)
    shutil.copy2(root/'Assets/Cursor.png',resources/'Cursor.png')
    with (app/'Contents/Info.plist').open('wb') as output:
        plistlib.dump({'CFBundleExecutable':'CursorUsage','CFBundleIdentifier':'local.cursorusage.CursorUsage','CFBundleName':'Cursor Usage','CFBundleDisplayName':'Cursor Usage','CFBundlePackageType':'APPL','CFBundleShortVersionString':'3.4.3','CFBundleVersion':'19','CFBundleDevelopmentRegion':'en','CFBundleLocalizations':['en','pt-BR'],'LSUIElement':True,'LSMinimumSystemVersion':'14.0','NSHighResolutionCapable':True},output)
    run('codesign','--force','--sign','-',str(app))
    # Replace the bundle atomically; never overwrite a running signed executable.
    destination = root/'Cursor Usage.app'
    prepared = root/('.cursor-usage-next-' + uuid.uuid4().hex + '.app')
    previous = root/('.cursor-usage-previous-' + uuid.uuid4().hex + '.app')
    shutil.copytree(app, prepared)
    run('codesign', '--verify', '--strict', str(prepared))
    had_previous = destination.exists()
    if had_previous:
        destination.rename(previous)
    try:
        prepared.rename(destination)
    except BaseException:
        if had_previous:
            previous.rename(destination)
        raise
    if had_previous:
        shutil.rmtree(previous)
    print(f'Built: {destination}')
