"""Import the user-supplied Kenney starter subset without modifying source PNGs.

Usage: python tools/import_isometric_assets.py /path/to/starter.zip
Requires Pillow for PNG dimension validation; game runtime has no dependencies.
"""
import hashlib
import io
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path, PurePosixPath
from zipfile import ZipFile
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PACKS = {
    'terrain': ('Base', 'landscapeTiles'),
    'city': ('City', 'cityTiles'),
    'buildings': ('Buildings', 'buildingTiles'),
    'details': ('City', 'cityDetails'),
    'vehicles': ('Vehicles', 'sheet_utility'),
}
SELECTED = {
    'grass': ('terrain', 'landscapeTiles_022.png', (66, 33)),
    'water': ('terrain', 'landscapeTiles_066.png', (66, 33)),
    'sand': ('terrain', 'landscapeTiles_058.png', (66, 33)),
    'dirt': ('terrain', 'landscapeTiles_073.png', (66, 33)),
    'asphalt': ('city', 'cityTiles_080.png', (66, 33)),
    'pavement': ('city', 'cityTiles_074.png', (66, 33)),
    'house': ('buildings', 'buildingTiles_045.png', None),
    'houseBeige': ('buildings', 'buildingTiles_048.png', None),
    'office': ('buildings', 'buildingTiles_000.png', None),
    'industry': ('buildings', 'buildingTiles_032.png', None),
    'roof': ('buildings', 'buildingTiles_065.png', None),
    'flatRoof': ('buildings', 'buildingTiles_005.png', None),
    'tree': ('details', 'cityDetails_010.png', None),
}
for direction in ('NE', 'SE', 'SW', 'NW'):
    SELECTED['car' + direction] = ('vehicles', 'taxi_' + direction + '.png', None)


def main(source):
    with ZipFile(source) as archive:
        if any(PurePosixPath(n).is_absolute() or '..' in PurePosixPath(n).parts or '\\' in n
               for n in archive.namelist()):
            raise ValueError('Unsafe archive paths')
        if sum(i.file_size for i in archive.infolist()) > 64 * 1024 * 1024:
            raise ValueError('Unexpected archive size')
        manifest = {'version': 1, 'source': {'name': Path(source).name,
                    'sha256': hashlib.sha256(Path(source).read_bytes()).hexdigest()},
                    'tile': {'width': 132, 'height': 66, 'origin': 'ground-center'},
                    'atlases': {}, 'sprites': {}, 'licenses': [],
                    'roads': {'method': 'City asphalt/pavement textures clipped by logical adjacency',
                              'bits': {'north': 1, 'east': 2, 'south': 4, 'west': 8}},
                    'missingArt': ['railway', 'power plant', 'pump', 'tower', 'civic services', 'dedicated industry']}
        xml = {}
        for key, (pack, stem) in PACKS.items():
            stem = stem if stem.startswith('sheet_') else stem + '_sheet'
            prefix = f'Isometric Tiles {pack}/Spritesheet/{stem}'
            png = archive.read(prefix + '.png')
            image = Image.open(io.BytesIO(png)); image.verify()
            width, height = Image.open(io.BytesIO(png)).size
            output = ROOT / 'assets' / 'atlases' / (key + '.png')
            output.parent.mkdir(parents=True, exist_ok=True); output.write_bytes(png)
            xml_bytes = archive.read(prefix + '.xml')
            output.with_suffix('.xml').write_bytes(xml_bytes)
            xml[key] = {s.attrib['name']: s.attrib for s in ET.fromstring(xml_bytes)}
            manifest['atlases'][key] = {'file': str(output.relative_to(ROOT)), 'width': width,
                                       'height': height, 'sha256': hashlib.sha256(png).hexdigest(),
                                       'source': prefix + '.png'}
        for semantic, (atlas, name, anchor) in SELECTED.items():
            crop = {k: int(xml[atlas][name][k]) for k in ('x', 'y', 'width', 'height')}
            if crop['x'] + crop['width'] > manifest['atlases'][atlas]['width'] or \
                    crop['y'] + crop['height'] > manifest['atlases'][atlas]['height']:
                raise ValueError(f'Out of bounds sprite {name}')
            if anchor is None:
                anchor = (crop['width'] / 2, crop['height'] - (25 if atlas == 'buildings' else 1))
            manifest['sprites'][semantic] = {'atlas': atlas, 'source': name, **crop,
                'anchor': {'x': anchor[0], 'y': anchor[1]}, 'baselineElevation': 0}
        for pack in ('Base', 'City', 'Buildings', 'Vehicles'):
            license_bytes = archive.read(f'Isometric Tiles {pack}/License.txt')
            if b'CC0' not in license_bytes: raise ValueError(f'Missing CC0 grant in {pack}')
            output = ROOT / 'assets' / 'licenses' / (pack + '.txt')
            output.parent.mkdir(parents=True, exist_ok=True); output.write_bytes(license_bytes)
            manifest['licenses'].append({'pack': pack, 'file': str(output.relative_to(ROOT)),
                                        'sha256': hashlib.sha256(license_bytes).hexdigest()})
        data = json.dumps(manifest, indent=2)
        (ROOT / 'assets' / 'manifest.json').write_text(data + '\n')
        (ROOT / 'assets' / 'manifest.js').write_text('window.MetroForgeAssets = ' + data + ';\n')
        print(f'Imported {len(PACKS)} source atlases, {len(SELECTED)} sprite mappings and four CC0 licenses.')


if __name__ == '__main__':
    main(sys.argv[1])
