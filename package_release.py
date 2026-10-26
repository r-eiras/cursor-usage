#!/usr/bin/env python3
"""Package a built app and allowlisted source files without local account data."""
from pathlib import Path
import hashlib
import json
import plistlib
import subprocess
import zipfile

def validate_app_bundle(app):
    """Reject development files, local data and links from the user download."""
    allowed = {
        'Contents/Info.plist', 'Contents/MacOS/CursorUsage',
        'Contents/Resources/Cursor.png', 'Contents/_CodeSignature/CodeResources',
    }
    actual = set()
    for path in app.rglob('*'):
        if path.is_symlink():
            raise ValueError('Distribution bundle must not contain symbolic links')
        if path.is_file():
            actual.add(path.relative_to(app).as_posix())
    unexpected, missing = actual - allowed, allowed - actual
    if unexpected or missing:
        raise ValueError(f'Invalid distribution contents: unexpected={sorted(unexpected)}, missing={sorted(missing)}')


def main():
    root = Path(__file__).resolve().parent
    app = root / 'Cursor Usage.app'
    with (app / 'Contents/Info.plist').open('rb') as stream:
        version = plistlib.load(stream)['CFBundleShortVersionString']
    validate_app_bundle(app)
    architecture = subprocess.check_output(['lipo', '-archs', str(app / 'Contents/MacOS/CursorUsage')], text=True).strip().replace(' ', '-')
    subprocess.run(['codesign', '--verify', '--strict', str(app)], check=True)
    release = root / 'releases' / version
    release.mkdir(parents=True, exist_ok=True)
    app_zip = release / f'CursorUsage-{version}-macOS-{architecture}.zip'
    subprocess.run(['ditto', '-c', '-k', '--norsrc', '--noextattr', '--keepParent', str(app), str(app_zip)], check=True)
    files = []
    for folder in ('Sources', 'Tests', 'Assets', 'postman', 'Casks'):
        files.extend(path for path in (root / folder).rglob('*') if path.is_file() and path.suffix in ('.swift', '.py', '.png', '.js', '.json', '.yaml', '.md', '.rb'))
    files.extend(root / name for name in ('build.py', 'package_release.py', 'install.sh', 'README.md', 'README.pt-BR.md', 'INTEGRATION.md', 'DISTRIBUTION.md', 'LICENSE', '.gitignore'))
    source_zip = release / f'CursorUsage-{version}-source.zip'
    with zipfile.ZipFile(source_zip, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(files):
            archive.write(path, Path('CursorUsage') / path.relative_to(root))
        assert archive.testzip() is None
    with zipfile.ZipFile(app_zip) as archive:
        assert archive.testzip() is None
        assert all(name.startswith('Cursor Usage.app/') for name in archive.namelist())
    def sha256(path):
        return hashlib.sha256(path.read_bytes()).hexdigest()
    manifest = {'version': version, 'architecture': architecture, 'signing': 'ad-hoc; not notarized',
                'archives': {path.name: sha256(path) for path in (app_zip, source_zip)},
                'sources': {str(path.relative_to(root)): sha256(path) for path in sorted(files)}}
    (release / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Created and verified: {app_zip.name}, {source_zip.name}')
    print(f'Manifest: {release / "manifest.json"}')


if __name__ == "__main__":
    main()
