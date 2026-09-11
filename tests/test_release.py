"""Cross-language patch compatibility and release metadata regression tests."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import zipfile
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import release
from make_delta import make_delta, digest, CHUNK


class ReleaseTest(unittest.TestCase):
    def test_versions(self):
        self.assertEqual(release.version('v1.2.3-rc.1'), '1.2.3.0')
        for tag in ['../foo', 'v01.2.3', '1.2', '1.2.3-01', '1.2.999999']:
            with self.assertRaises(ValueError):
                release.version(tag)

    def test_stamp_exact_tag(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'scripts').mkdir()
            (root / 'scripts/build_info.gd').write_text('const VERSION="0.0.0-dev"\nconst PROTOCOL=9\n')
            (root / 'project.godot').write_text('[application]\nconfig/name="Game"\n')
            (root / 'export_presets.cfg').write_text('application/file_version=""\napplication/product_version=""\n')
            original = release.ROOT
            try:
                release.ROOT = root
                release.stamp('v1.2.3-rc.1')
                self.assertIn('const VERSION="v1.2.3-rc.1"', (root / 'scripts/build_info.gd').read_text())
                self.assertIn('config/version="v1.2.3-rc.1"', (root / 'project.godot').read_text())
                self.assertIn('application/file_version="1.2.3.0"', (root / 'export_presets.cfg').read_text())
            finally:
                release.ROOT = original

    def test_patch_round_trip(self):
        with tempfile.TemporaryDirectory() as temp:
            temp = Path(temp)
            base = temp / 'base'
            target = temp / 'target'
            helper = temp / 'n-catan-updater'
            patch = temp / 'delta.zip'
            original = os.urandom(CHUNK * 4)
            base.write_bytes(original)
            expected = original[:CHUNK] + b'x' * CHUNK + original[CHUNK * 2:] + b'tail'
            target.write_bytes(expected)
            helper.write_bytes(b'helper')
            stats = make_delta(base, target, helper, patch)
            self.assertGreaterEqual(stats['copied_bytes'], CHUNK * 3)
            with zipfile.ZipFile(patch) as z:
                plan = json.loads(z.read('delta.json'))
                literals = z.read('payload.bin')
            result = bytearray()
            cursor = 0
            for op in plan['ops']:
                if 'copy' in op:
                    result.extend(original[op['copy']:op['copy'] + op['size']])
                else:
                    result.extend(literals[cursor:cursor + op['size']])
                    cursor += op['size']
            self.assertEqual(bytes(result), expected)
            self.assertEqual(cursor, len(literals))
            self.assertEqual(plan['target_sha256'], digest(target))


if __name__ == '__main__':
    unittest.main()
