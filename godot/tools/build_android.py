"""Export the native Android preview and record the exact source inputs."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
from zipfile import ZipFile

PROJECT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', default=shutil.which('godot') or shutil.which('godot4') or 'godot')
    parser.add_argument('--output', type=Path, default=PROJECT / 'build/MetroForge-Godot-0.3.4-Slope-Test.apk')
    args = parser.parse_args()
    version = subprocess.check_output([args.godot, '--version'], text=True).strip()
    if not version.startswith('4.6.3.stable'):
        raise SystemExit('Use Godot 4.6.3 with matching Android export templates.')
    template = Path.home() / '.local/share/godot/export_templates/4.6.3.stable/android_release.apk'
    if not template.is_file():
        raise SystemExit('Install the matching official Godot 4.6.3 Android release template.')
    sources = [PROJECT / 'project.godot', PROJECT / 'export_presets.cfg',
               PROJECT / 'main.tscn', PROJECT / 'assets/icon.svg',
               PROJECT / 'assets/manifest.json', PROJECT / 'assets/render_atlas.json',
               PROJECT / 'assets/render_atlas.png', PROJECT / 'assets/building_styles.json']
    for folder in ('model', 'view', 'ui', 'persistence'):
        sources.extend(sorted((PROJECT / folder).glob('*.gd')))
    sources.extend(sorted((PROJECT / 'view').glob('*.gdshader')))
    receipts = {p.relative_to(PROJECT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources}
    commit = subprocess.check_output(['git', '-C', str(PROJECT), 'rev-parse', 'HEAD'], text=True).strip()
    info = {'source_commit': commit, 'version': '0.3.4-terraform-preview', 'engine': version, 'export_mode': 'release',
            'android_template_sha256': hashlib.sha256(template.read_bytes()).hexdigest(),
            'built_utc': datetime.now(timezone.utc).isoformat(), 'source_sha256': receipts}
    (PROJECT / 'assets/build_info.json').write_text(json.dumps(info, indent=2) + '\n')
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    command = [args.godot, '--headless', '--audio-driver', 'Dummy', '--path', str(PROJECT),
               '--export-release', 'Android', str(output)]
    run = subprocess.run(command, text=True, capture_output=True, timeout=180)
    log = run.stdout + run.stderr
    (output.parent / 'godot-export.log').write_text(log)
    if run.returncode or 'SCRIPT ERROR:' in log or '\nERROR:' in log or not output.is_file():
        print(log[-6000:], file=sys.stderr)
        raise SystemExit('Android export failed; inspect godot-export.log.')
    with ZipFile(output) as archive:
        assert archive.testzip() is None
        assert json.loads(archive.read('assets/assets/build_info.json')) == info
        assert json.loads(archive.read('assets/assets/render_atlas.json')) == json.loads((PROJECT / 'assets/render_atlas.json').read_text())
        for source in receipts:
            if source.endswith('.gd'):
                assert 'assets/' + source[:-3] + '.gdc' in archive.namelist(), source
        assert 'lib/arm64-v8a/libgodot_android.so' in archive.namelist()
        assert not any(name.endswith(('.html', '.js')) for name in archive.namelist())
        with ZipFile(template) as official:
            for abi in ('arm64-v8a', 'armeabi-v7a'):
                name = f'lib/{abi}/libgodot_android.so'
                assert hashlib.sha256(archive.read(name)).digest() == hashlib.sha256(official.read(name)).digest(), 'APK must contain the release runtime'
    print(f'Native Android export verified: {output} ({output.stat().st_size:,} bytes)')
    print('SHA256:', hashlib.sha256(output.read_bytes()).hexdigest())


if __name__ == '__main__':
    main()
