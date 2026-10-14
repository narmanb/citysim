"""Run all native Godot checks and verify preserved source artwork."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

PROJECT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', default=shutil.which('godot') or shutil.which('godot4') or 'godot')
    args = parser.parse_args()
    # A source checkout has no generated texture imports or global-class cache.
    prepare = subprocess.run([args.godot, '--headless', '--audio-driver', 'Dummy', '--path', str(PROJECT),
                              '--editor', '--import'], text=True, capture_output=True, timeout=120)
    preparation_log = prepare.stdout + prepare.stderr
    if prepare.returncode or 'SCRIPT ERROR:' in preparation_log or '\nERROR:' in preparation_log:
        print(preparation_log, file=sys.stderr)
        raise SystemExit('Godot source import failed')
    for name in ('test_world', 'test_store', 'test_view', 'test_game'):
        command = [args.godot, '--headless', '--audio-driver', 'Dummy', '--path', str(PROJECT), '--script', f'tests/{name}.gd']
        result = subprocess.run(command, text=True, capture_output=True, timeout=90)
        output = result.stdout + result.stderr
        if result.returncode or 'SCRIPT ERROR:' in output or '\nERROR:' in output:
            print(output, file=sys.stderr)
            raise SystemExit(f'{name} failed')
        print(output.strip())
    manifest = json.loads((PROJECT / 'assets/manifest.json').read_text())
    for entry in list(manifest['atlases'].values()) + manifest['licenses']:
        source = PROJECT / entry['file']
        if hashlib.sha256(source.read_bytes()).hexdigest() != entry['sha256']:
            raise SystemExit(f'Artwork/license receipt mismatch: {source}')
    print('All five original source atlases and four CC0 licenses: PASS')


if __name__ == '__main__':
    main()
