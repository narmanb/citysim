import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from zipfile import ZipFile

ROOT=Path(__file__).resolve().parents[1]

class Packaging(unittest.TestCase):
    def test_browser_and_android_include_identical_runtime_resources(self):
        script=ROOT/'tools/package_runtime.py'
        self.assertTrue(script.exists(),'Offline runtime packager is missing')
        with tempfile.TemporaryDirectory() as tmp:
            folder=Path(tmp)/'android';archive=Path(tmp)/'browser.zip'
            subprocess.run([sys.executable,str(script),'--android-dir',str(folder),'--browser-zip',str(archive)],check=True)
            manifest=json.loads((ROOT/'assets/manifest.json').read_text())
            with ZipFile(archive) as z:
                for name in ['index.html','MetroForge-2000.html','isometric-preview.html','assets/manifest.js','src/isometric-core.js','src/isometric-art.js','src/isometric-renderer.js']+[a['file'] for a in manifest['atlases'].values()]+[a['file'] for a in manifest['licenses']]:
                    self.assertTrue((folder/name).is_file(),name)
                    self.assertEqual(z.read(name),(folder/name).read_bytes())
                for a in manifest['atlases'].values():self.assertEqual(hashlib.sha256(z.read(a['file'])).hexdigest(),a['sha256'])
            self.assertNotIn('fetch(', (folder/'src/isometric-art.js').read_text())
            self.assertIn('src="assets/manifest.js"',(folder/'index.html').read_text())

if __name__=='__main__':unittest.main()
