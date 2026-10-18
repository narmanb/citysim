"""Run all native Godot checks and verify preserved source artwork."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import os
import tempfile

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
    for name in ('test_world', 'test_terrain_bounds', 'test_terrain_geometry', 'test_terrain_rounding', 'test_terrain_foundations', 'test_terrain_style', 'test_terrain_surfaces', 'test_surface_controls', 'test_surface_cache', 'test_terrain_rounded_view', 'test_terrain_sculpt_controls', 'test_terrain_shape_view', 'test_terrain_editor', 'test_terrain_controls', 'test_automatic_growth', 'test_environment', 'test_store', 'test_city_session', 'test_layer_batch',
                 'test_render_atlas', 'test_building_assets', 'test_building_variety', 'test_view', 'test_render_cache', 'test_game',
                 'test_ui', 'test_performance_display'):
        command = [args.godot, '--headless', '--audio-driver', 'Dummy', '--path', str(PROJECT), '--script', f'tests/{name}.gd']
        with tempfile.TemporaryDirectory(prefix="metroforge-test-") as user_data:
            result = subprocess.run(command, text=True, capture_output=True, timeout=90,
                                    env={**os.environ, "XDG_DATA_HOME": user_data})
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
    layout = json.loads((PROJECT / 'assets/render_atlas.json').read_text())
    if hashlib.sha256((PROJECT / 'assets/manifest.json').read_bytes()).hexdigest() != layout['source_manifest_sha256']:
        raise SystemExit('Render atlas was generated from a different source manifest')
    if hashlib.sha256((PROJECT / layout['file']).read_bytes()).hexdigest() != layout['sha256']:
        raise SystemExit('Compact render atlas receipt mismatch')
    print('All five original source atlases and four CC0 licenses: PASS')


if __name__ == '__main__':
    main()
