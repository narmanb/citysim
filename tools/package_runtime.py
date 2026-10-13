"""Package the same offline resources for browser and Android WebView.

python tools/package_runtime.py --android-dir app/src/main/assets
python tools/package_runtime.py --browser-zip /path/to/MetroForge-Isometric.zip
"""
import argparse
import hashlib
import json
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]

def runtime_files():
    files = {'index.html': (ROOT/'MetroForge-2000.html').read_bytes(),
             'MetroForge-2000.html': (ROOT/'MetroForge-2000.html').read_bytes(),
             'isometric-preview.html': (ROOT/'isometric-preview.html').read_bytes()}
    for name in ('src', 'assets'):
        for source in sorted((ROOT/name).rglob('*')):
            if source.is_file(): files[source.relative_to(ROOT).as_posix()] = source.read_bytes()
    manifest = json.loads(files['assets/manifest.json'])
    for entry in list(manifest['atlases'].values()) + manifest['licenses']:
        if hashlib.sha256(files[entry['file']]).hexdigest() != entry['sha256']:
            raise ValueError('Resource hash mismatch: '+entry['file'])
    files['runtime-files.json'] = (json.dumps({name: hashlib.sha256(data).hexdigest()
                                            for name,data in files.items()}, indent=2)+'\n').encode()
    files['README.txt'] = b'MetroForge 2000 isometric browser build\n\nUnzip the complete folder, then open index.html. All scripts and artwork load offline.\nThe isometric-preview.html file is an art test; index.html is the real city-builder.\nImport an existing city using City / Files > Import JSON. Saves stay in their browser origin;\nuse Export/Import when moving between an old and new folder or between browser and Android.\nSupplied artwork: Kenney, CC0. License texts are under assets/licenses/.\n'
    return files

def main():
    parser=argparse.ArgumentParser(); parser.add_argument('--android-dir',type=Path);parser.add_argument('--browser-zip',type=Path)
    args=parser.parse_args()
    if not args.android_dir and not args.browser_zip:parser.error('Choose --android-dir or --browser-zip')
    files=runtime_files()
    if args.android_dir:
        for name,data in files.items():
            output=args.android_dir/name;output.parent.mkdir(parents=True,exist_ok=True);output.write_bytes(data)
        print(f'Packaged {len(files)} offline files in {args.android_dir}')
    if args.browser_zip:
        args.browser_zip.parent.mkdir(parents=True,exist_ok=True)
        with ZipFile(args.browser_zip,'w',ZIP_DEFLATED) as archive:
            for name,data in files.items():archive.writestr(name,data)
        print(f'Browser build: {args.browser_zip} ({args.browser_zip.stat().st_size} bytes)')

if __name__=='__main__':main()
